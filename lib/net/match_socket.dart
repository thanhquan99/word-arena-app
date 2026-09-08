import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'protocol.dart';

/// The connection to a match on `word-arena-api`.
///
/// This is a transport and nothing more: it does not know the rules, and never
/// decides anything about the game. Every rule lives on the server, which is
/// what makes the §7.2 clock tie-break and the §3.2 race trustworthy.
///
/// Not to be confused with `lib/speech/stt_client.dart`, which also speaks
/// WebSocket but talks to ElevenLabs about one player's microphone. The two
/// share no code on purpose.
class MatchSocket {
  MatchSocket({
    String? baseUrl,
    WebSocketChannel Function(Uri)? connect,
    Duration reconnectGrace = const Duration(seconds: 60),
    Duration retryDelay = const Duration(seconds: 2),
  })  : _baseUrl = baseUrl ?? const String.fromEnvironment('API_URL'),
        _connect = connect ?? WebSocketChannel.connect,
        _reconnectGrace = reconnectGrace,
        _retryDelay = retryDelay;

  final String _baseUrl;
  final WebSocketChannel Function(Uri) _connect;

  /// §11 — how long a dropped client keeps trying before giving the match up.
  final Duration _reconnectGrace;
  final Duration _retryDelay;

  final _events = StreamController<ServerEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retryTimer;

  JoinMessage? _lastJoin;
  String? _resumeToken;
  DateTime? _droppedAt;
  bool _closedByUs = false;

  /// Every frame the server sends, already parsed.
  Stream<ServerEvent> get events => _events.stream;

  bool get isConnected => _channel != null;

  /// True while a dropped connection is still inside its grace window.
  bool get isReconnecting => _droppedAt != null && !_closedByUs;

  Uri get _uri {
    if (_baseUrl.isEmpty) {
      throw StateError(
        'API_URL is not set — run with --dart-define=API_URL=http://<lan-ip>:3000',
      );
    }
    // The match socket lives on the same host as the HTTP API, so the base URL
    // is reused and only the scheme changes.
    final http = Uri.parse(_baseUrl);
    return http.replace(scheme: http.scheme == 'https' ? 'wss' : 'ws', path: '/match');
  }

  Future<void> join(MatchMode mode, {String level = 'B1'}) async {
    _lastJoin = JoinMessage(mode: mode, level: level);
    _closedByUs = false;
    _openChannel();
    send(_lastJoin!);
  }

  void send(ClientMessage message) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode(message.toJson()));
  }

  void tapCard(int slotIndex) => send(TapCardMessage(slotIndex));

  void setStance(Stance stance) => send(SetStanceMessage(stance));

  void answer(String objectiveId, String transcript) =>
      send(AnswerMessage(objectiveId: objectiveId, transcript: transcript));

  /// Locks in `completedTime` without waiting out the card clock (§3.4).
  void done() => send(const DoneMessage());

  Future<void> close() async {
    _closedByUs = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _teardown();
    await _events.close();
  }

  // ------------------------------------------------------------------ internals

  void _openChannel() {
    final channel = _connect(_uri);
    _channel = channel;

    _subscription = channel.stream.listen(
      _onFrame,
      onDone: _onDisconnected,
      onError: (Object _) => _onDisconnected(),
      cancelOnError: false,
    );
  }

  void _onFrame(dynamic raw) {
    if (raw is! String) return;

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // A frame we cannot read is the server's problem, not a reason to drop
      // the match — skip it and keep listening.
      return;
    }

    final ServerEvent? event;
    try {
      event = ServerEvent.fromJson(json);
    } catch (_) {
      return;
    }
    if (event == null) return;

    // Remember the token so a reconnect can prove which seat we were in.
    if (event is MatchedEvent) {
      _resumeToken = event.resumeToken;
      _droppedAt = null;
    }

    if (!_events.isClosed) _events.add(event);
  }

  void _onDisconnected() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    if (_closedByUs || _lastJoin == null) return;

    _droppedAt ??= DateTime.now();

    // §11: a minute to get back in. Past that the server has already called
    // the match, so there is nothing left to reconnect to.
    if (DateTime.now().difference(_droppedAt!) > _reconnectGrace) {
      _droppedAt = null;
      if (!_events.isClosed) {
        _events.add(const ErrorEvent(error: 'reconnect_failed'));
      }
      return;
    }

    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, _retry);
  }

  void _retry() {
    if (_closedByUs || _lastJoin == null) return;

    try {
      _openChannel();
    } catch (_) {
      _onDisconnected();
      return;
    }

    final previous = _lastJoin!;
    send(JoinMessage(
      mode: previous.mode,
      level: previous.level,
      resumeToken: _resumeToken,
    ));
  }

  Future<void> _teardown() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }
}
