import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/net/match_socket.dart';
import 'package:word_arena/net/protocol.dart';

import '../support/fake_socket.dart';

void main() {
  late FakeChannel channel;
  late MatchSocket socket;

  MatchSocket build({Duration grace = const Duration(seconds: 60)}) {
    channel = FakeChannel();
    return MatchSocket(
      baseUrl: 'http://localhost:3000',
      connect: (_) => channel,
      reconnectGrace: grace,
      retryDelay: const Duration(milliseconds: 10),
    );
  }

  setUp(() {
    socket = build();
  });

  tearDown(() async {
    await socket.close();
  });

  group('connecting', () {
    test('joining sends a join frame', () async {
      await socket.join(MatchMode.bot);
      await pump();

      expect(channel.sentTypes, ['join']);
      expect(channel.lastSent?['mode'], 'bot');
    });

    test('the ws url is derived from the http base url', () async {
      // One host for everything: the client only ever configures API_URL.
      await socket.join(MatchMode.bot);
      expect(socket.isConnected, isTrue);
    });

    test('an unset API_URL fails loudly rather than connecting nowhere', () {
      final blank = MatchSocket(baseUrl: '', connect: (_) => FakeChannel());
      expect(() => blank.join(MatchMode.bot), throwsA(isA<StateError>()));
    });
  });

  group('parsing', () {
    test('every server event type is understood', () async {
      final seen = <ServerEvent>[];
      socket.events.listen(seen.add);

      await socket.join(MatchMode.bot);
      await pump();

      for (final frame in _everyEventType) {
        channel.emit(frame);
      }
      await pump(6);

      expect(seen, hasLength(_everyEventType.length));
    });

    test('a frame from a newer server is skipped, not fatal', () async {
      final events = <ServerEvent>[];
      socket.events.listen(events.add);

      await socket.join(MatchMode.bot);
      await pump();

      channel.emit({'type': 'some_future_event'});
      channel.emit({'type': 'hp', 'you': 40, 'opponent': 30});
      await pump(4);

      expect(events, hasLength(1));
      expect(events.single, isA<HpEvent>());
    });

    test('malformed json does not take the stream down', () async {
      final events = <ServerEvent>[];
      socket.events.listen(events.add);

      await socket.join(MatchMode.bot);
      await pump();

      channel.emit({'type': 'hp', 'you': 'not a number', 'opponent': 30});
      channel.emit({'type': 'hp', 'you': 40, 'opponent': 30});
      await pump(4);

      expect(events, hasLength(1));
    });
  });

  group('sending', () {
    setUp(() async {
      await socket.join(MatchMode.bot);
      await pump();
    });

    test('tap, stance, answer and done each go out once', () {
      socket
        ..tapCard(2)
        ..setStance(Stance.defense)
        ..answer('o1', 'hello')
        ..done();

      expect(channel.sentTypes, ['join', 'tap_card', 'set_stance', 'answer', 'done']);
    });

    test('an answer carries its objective id — order is the player choice', () {
      socket.answer('o3', 'hello');
      expect(channel.lastSent?['objectiveId'], 'o3');
    });
  });

  group('reconnecting — §11', () {
    test('a drop inside the grace window retries with the resume token',
        () async {
      await socket.join(MatchMode.bot);
      await pump();

      channel.emit({
        'type': 'matched',
        'matchId': 'm1',
        'you': 'a',
        'isBot': true,
        'resumeToken': 'tok-123',
        'protocolVersion': 1,
      });
      await pump();

      final first = channel;
      first.drop();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      // The retry reuses the same fake channel, so the token shows up there.
      expect(channel.sentTypes.where((t) => t == 'join').length, greaterThan(1));
      expect(channel.lastSent?['resumeToken'], 'tok-123');
    });

    test('past the grace window it gives up and says so', () async {
      final impatient = build(grace: Duration.zero);
      final events = <ServerEvent>[];
      impatient.events.listen(events.add);

      await impatient.join(MatchMode.bot);
      await pump();

      channel.drop();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(
        events.whereType<ErrorEvent>().map((e) => e.error),
        contains('reconnect_failed'),
      );
      await impatient.close();
    });

    test('a close we asked for does not trigger a retry', () async {
      await socket.join(MatchMode.bot);
      await pump();

      await socket.close();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(socket.isReconnecting, isFalse);
    });
  });
}

/// One frame of every kind the server can send, used to prove the client
/// understands the whole contract rather than the handful it happens to hit.
final _everyEventType = <Map<String, dynamic>>[
  {
    'type': 'matched',
    'matchId': 'm',
    'you': 'a',
    'isBot': true,
    'resumeToken': 't',
    'protocolVersion': 1,
  },
  {'type': 'board', 'slots': <dynamic>[], 'phase': 'idle', 'idleDeadline': null},
  {'type': 'card_opened', 'slotIndex': 0, 'mission': _mission, 'defenseAllowed': true},
  {'type': 'stance_changed', 'changed': true},
  {'type': 'turn_phase', 'stage': 'compare', 'until': 1},
  {'type': 'opponent_progress', 'done': true},
  {
    'type': 'resolve_start',
    'objectives': _mission['objectives'],
    'cardSeconds': 16,
    'startedAt': 1,
  },
  {'type': 'objective_result', 'objectiveId': 'o1', 'passed': true, 'whose': 'you'},
  {
    'type': 'turn_settled',
    'outcome': 'you_win',
    'reason': 'count',
    'you': {'n': 2, 'completedTime': 1, 'damageDealt': 3.2},
    'opponent': {'n': 1, 'completedTime': 2, 'damageDealt': 0},
    'blocked': <String>[],
    'effect': 'burn',
  },
  {'type': 'hp', 'you': 40, 'opponent': 30},
  {
    'type': 'status',
    'you': {'shield': true},
    'opponent': {'burnTurnsLeft': 2},
  },
  {'type': 'ended', 'winner': 'you'},
  {'type': 'error', 'error': 'waiting_for_opponent'},
];

const _mission = <String, dynamic>{
  'id': 'm0',
  'type': 'vocabulary',
  'tier': 2,
  'pace': 'medium',
  'prompt': 'farmer',
  'objectives': [
    {
      'id': 'o1',
      'text': 'Explain it',
      'mode': 'speak',
      'timeLimitSec': 8,
      'gradingTier': 'binary',
    },
  ],
};
