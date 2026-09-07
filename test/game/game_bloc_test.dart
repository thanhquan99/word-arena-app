
import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/game/bloc/game_bloc.dart';
import 'package:word_arena/game/bloc/game_event.dart';
import 'package:word_arena/game/bloc/game_state.dart';
import 'package:word_arena/net/match_socket.dart';
import 'package:word_arena/net/protocol.dart';

import '../support/fake_socket.dart';

/// The bloc is a translator now: server frames in, state out; taps in, frames
/// out. These tests hold it to exactly that and nothing more — every rule it
/// used to own lives on the server since feature-05.
void main() {
  late FakeChannel channel;
  late GameBloc bloc;

  setUp(() {
    channel = FakeChannel();
    bloc = GameBloc(
      socket: MatchSocket(baseUrl: 'http://localhost:3000', connect: (_) => channel),
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  Future<void> joined({bool bot = true}) async {
    bloc.add(MatchJoined(mode: bot ? MatchMode.bot : MatchMode.pvp));
    await pump();
    channel.emit(_matched(isBot: bot));
    await pump();
  }

  group('joining', () {
    test('starts disconnected', () {
      expect(bloc.state.connection, MatchLink.disconnected);
      expect(bloc.state.slots, isEmpty);
    });

    test('a join frame goes out and matched turns the link ready', () async {
      await joined();

      expect(channel.sentTypes, contains('join'));
      expect(bloc.state.connection, MatchLink.ready);
      expect(bloc.state.isBot, isTrue);
    });

    test('waiting for an opponent is a state, not an error to swallow', () async {
      bloc.add(const MatchJoined(mode: MatchMode.pvp));
      await pump();
      channel.emit({'type': 'error', 'error': 'waiting_for_opponent'});
      await pump();

      expect(bloc.state.connection, MatchLink.waitingForOpponent);
    });
  });

  group('the board', () {
    test('four cards arrive and land in state', () async {
      await joined();
      channel.emit(_board());
      await pump();

      expect(bloc.state.slots, hasLength(4));
      expect(bloc.state.phase, GamePhase.idle);
    });

    test('a tap is forwarded without guessing what the server will do',
        () async {
      await joined();
      channel.emit(_board());
      await pump();

      bloc.add(const CardTapped(2));
      await pump();

      expect(channel.sentTypes, contains('tap_card'));
      // The server runs a 250ms race and may open a different card, so the
      // client must not move the phase itself.
      expect(bloc.state.phase, GamePhase.idle);
    });

    test('taps before the link is ready go nowhere', () async {
      bloc.add(const CardTapped(0));
      await pump();

      expect(channel.sentTypes, isNot(contains('tap_card')));
    });
  });

  group('stance — §3.3', () {
    test('an opened card moves to the stance phase for both players', () async {
      await joined();
      channel.emit(_cardOpened());
      await pump();

      expect(bloc.state.phase, GamePhase.stance);
      expect(bloc.state.openedMission, isNotNull);
      expect(bloc.state.objectives, hasLength(2));
    });

    test('choosing a stance sends it and shows it immediately', () async {
      await joined();
      channel.emit(_cardOpened());
      await pump();

      bloc.add(const StanceChosen(Stance.defense));
      await pump();

      expect(channel.sentTypes, contains('set_stance'));
      expect(bloc.state.yourStance, Stance.defense);
    });

    test('Defense is refused on a 🎯 All-out card', () async {
      await joined();
      channel.emit(_cardOpened(defenseAllowed: false));
      await pump();

      bloc.add(const StanceChosen(Stance.defense));
      await pump();

      expect(channel.sentTypes, isNot(contains('set_stance')));
      expect(bloc.state.yourStance, isNull);
    });

    test('the locked stances of both sides are recorded', () async {
      await joined();
      channel.emit(_cardOpened());
      await pump();
      channel.emit({'type': 'stance_locked', 'you': 'attack', 'opponent': 'defense'});
      await pump();

      expect(bloc.state.yourStance, Stance.attack);
      expect(bloc.state.opponentStance, Stance.defense);
    });
  });

  group('resolving — §3.4', () {
    Future<void> resolving() async {
      await joined();
      channel.emit(_cardOpened());
      await pump();
      channel.emit(_resolveStart());
      await pump();
    }

    test('the card clock and every objective arrive together', () async {
      await resolving();

      expect(bloc.state.phase, GamePhase.resolving);
      expect(bloc.state.cardSeconds, 16);
      expect(bloc.state.objectives, hasLength(2));
    });

    test('answers carry their objective id — the player picks the order',
        () async {
      await resolving();

      bloc.add(const ObjectiveAnswered(objectiveId: 'o2', transcript: 'hello'));
      await pump();

      expect(channel.lastSent?['objectiveId'], 'o2');
    });

    test('a passed grade marks the objective done', () async {
      await resolving();
      channel.emit(_objectiveResult('o1', passed: true));
      await pump();

      expect(bloc.state.yourCompleted, contains('o1'));
      expect(bloc.state.yourFailed, isEmpty);
    });

    test('a failed grade is kept so the card can show ✖️ and be retried',
        () async {
      await resolving();
      channel.emit(_objectiveResult('o1', passed: false));
      await pump();

      expect(bloc.state.yourCompleted, isEmpty);
      expect(bloc.state.yourFailed, contains('o1'));
    });

    test('retrying a failed objective clears the failure', () async {
      await resolving();
      channel.emit(_objectiveResult('o1', passed: false));
      await pump();
      channel.emit(_objectiveResult('o1', passed: true));
      await pump();

      expect(bloc.state.yourCompleted, contains('o1'));
      expect(bloc.state.yourFailed, isEmpty);
    });

    test("the opponent's progress is tracked separately", () async {
      await resolving();
      channel.emit(_objectiveResult('o1', passed: true, mine: false));
      await pump();

      expect(bloc.state.opponentCompleted, contains('o1'));
      expect(bloc.state.yourCompleted, isEmpty);
    });

    test('Done locks the turn in early — §7.2 needs a time to compare',
        () async {
      await resolving();

      bloc.add(const TurnFinished());
      await pump();

      expect(channel.sentTypes, contains('done'));
      expect(bloc.state.youAreDone, isTrue);
    });

    test('answers after Done are not sent', () async {
      await resolving();
      bloc.add(const TurnFinished());
      await pump();

      final before = channel.sent.length;
      bloc.add(const ObjectiveAnswered(objectiveId: 'o1', transcript: 'x'));
      await pump();

      expect(channel.sent.length, before);
    });
  });

  group('scoring', () {
    test('a settled turn is kept whole so the UI can explain it', () async {
      await joined();
      channel.emit(_turnSettled(reason: 'time', outcome: 'opponent_win'));
      await pump();

      expect(bloc.state.phase, GamePhase.scoring);
      expect(bloc.state.lastTurn?.reason, TurnReason.time);
      expect(bloc.state.lastTurn?.outcome, TurnOutcome.opponentWin);
    });

    test('blocked objectives survive into state', () async {
      await joined();
      channel.emit(_turnSettled(reason: 'blocked', blocked: ['o1']));
      await pump();

      expect(bloc.state.lastTurn?.blocked, ['o1']);
    });

    test('health comes from the server, never from a local sum', () async {
      await joined();
      channel.emit({'type': 'hp', 'you': 44, 'opponent': 39});
      await pump();

      expect(bloc.state.yourHp, 44);
      expect(bloc.state.opponentHp, 39);
    });

    test('carried effects are recorded for both sides', () async {
      await joined();
      channel.emit({
        'type': 'status',
        'you': {'shield': true, 'burnTurnsLeft': 0},
        'opponent': {'burnTurnsLeft': 3, 'rush': true},
      });
      await pump();

      expect(bloc.state.yourStatus.shield, isTrue);
      expect(bloc.state.opponentStatus.burnTurnsLeft, 3);
      expect(bloc.state.opponentStatus.rush, isTrue);
    });
  });

  group('end of match', () {
    test('the winner comes from the server, not from health', () async {
      await joined();
      channel.emit({'type': 'ended', 'winner': 'you'});
      await pump();

      expect(bloc.state.phase, GamePhase.ended);
      expect(bloc.state.winner, 'you');
    });

    test('a draw is a real outcome', () async {
      await joined();
      channel.emit({'type': 'ended', 'winner': 'draw'});
      await pump();

      expect(bloc.state.winner, 'draw');
    });
  });

  group('what the bloc no longer does', () {
    test('a card refill clears everything scoped to the turn', () async {
      await joined();
      channel.emit(_cardOpened());
      await pump();
      channel.emit(_resolveStart());
      await pump();
      channel.emit(_objectiveResult('o1', passed: true));
      await pump();

      channel.emit(_board());
      await pump();

      expect(bloc.state.openedMission, isNull);
      expect(bloc.state.yourCompleted, isEmpty);
      expect(bloc.state.objectives, isEmpty);
    });

    test('an unknown frame is ignored rather than fatal', () async {
      await joined();
      final before = bloc.state;

      channel.emit({'type': 'some_future_event', 'payload': 1});
      await pump();

      expect(bloc.state, before);
    });
  });
}

// ---------------------------------------------------------------- fixtures

Map<String, dynamic> _matched({bool isBot = true}) => {
      'type': 'matched',
      'matchId': 'm1',
      'you': 'a',
      'isBot': isBot,
      'resumeToken': 'tok',
      'protocolVersion': 1,
    };

Map<String, dynamic> _mission(String id) => {
      'id': id,
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
        {
          'id': 'o2',
          'text': 'Use it in a sentence',
          'mode': 'speak',
          'timeLimitSec': 8,
          'gradingTier': 'binary',
        },
      ],
    };

Map<String, dynamic> _board() => {
      'type': 'board',
      'slots': [for (var i = 0; i < 4; i++) _mission('m$i')],
      'phase': 'idle',
      'idleDeadline': null,
    };

Map<String, dynamic> _cardOpened({bool defenseAllowed = true}) => {
      'type': 'card_opened',
      'slotIndex': 0,
      'mission': _mission('m0'),
      'defenseAllowed': defenseAllowed,
      'stanceDeadline': DateTime.now().millisecondsSinceEpoch + 3000,
    };

Map<String, dynamic> _resolveStart() => {
      'type': 'resolve_start',
      'objectives': (_mission('m0')['objectives'] as List<dynamic>),
      'cardSeconds': 16,
      'startedAt': DateTime.now().millisecondsSinceEpoch,
    };

Map<String, dynamic> _objectiveResult(String id, {required bool passed, bool mine = true}) => {
      'type': 'objective_result',
      'objectiveId': id,
      'passed': passed,
      'whose': mine ? 'you' : 'opponent',
    };

Map<String, dynamic> _turnSettled({
  String reason = 'count',
  String outcome = 'you_win',
  List<String> blocked = const [],
}) =>
    {
      'type': 'turn_settled',
      'outcome': outcome,
      'reason': reason,
      'you': {'n': 2, 'completedTime': 8200, 'damageDealt': 3.2},
      'opponent': {'n': 1, 'completedTime': 9100, 'damageDealt': 0},
      'blocked': blocked,
      'effect': null,
    };
