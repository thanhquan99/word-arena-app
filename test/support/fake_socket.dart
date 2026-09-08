import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// An in-memory stand-in for the match socket.
///
/// Frames pushed with [emit] arrive as if the server had sent them; frames the
/// client sends land in [sent]. No sockets, no ports, no waiting.
class FakeChannel extends StreamChannelMixin implements WebSocketChannel {
  FakeChannel() {
    _sink = _RecordingSink(this);
  }

  final _incoming = StreamController<dynamic>.broadcast();
  final List<Map<String, dynamic>> sent = [];
  late final _RecordingSink _sink;

  bool closed = false;

  /// Frame types the client has sent, in order.
  List<String> get sentTypes => sent.map((m) => m['type'] as String).toList();

  Map<String, dynamic>? get lastSent => sent.isEmpty ? null : sent.last;

  /// Pushes a server frame at the client.
  void emit(Map<String, dynamic> message) {
    if (!_incoming.isClosed) _incoming.add(jsonEncode(message));
  }

  /// Drops the connection, as a network failure would.
  void drop() {
    if (!_incoming.isClosed) _incoming.close();
  }

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  int? get closeCode => closed ? 1000 : null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();

  void _record(dynamic raw) {
    if (raw is String) sent.add(jsonDecode(raw) as Map<String, dynamic>);
  }
}

class _RecordingSink implements WebSocketSink {
  _RecordingSink(this._channel);

  final FakeChannel _channel;
  final _done = Completer<void>();

  @override
  void add(dynamic data) => _channel._record(data);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    _channel.closed = true;
    if (!_done.isCompleted) _done.complete();
    await _channel._incoming.close();
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.forEach(add);

  @override
  Future<void> get done => _done.future;
}

/// Lets queued microtasks and the bloc's event loop settle.
Future<void> pump([int rounds = 3]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
