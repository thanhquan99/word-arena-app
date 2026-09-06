import 'dart:async';
import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:word_arena/content/content_repository.dart';
import 'package:word_arena/content/models.dart';
import 'package:word_arena/game/bloc/game_bloc.dart';
import 'package:word_arena/game/bloc/game_event.dart';
import 'package:word_arena/game/bloc/game_state.dart';
import 'package:word_arena/net/api_client.dart';
import 'package:word_arena/net/grade_result.dart';

class _MockApi extends Mock implements ApiClient {}

class _FakeObjective extends Fake implements Objective {}

Objective _objective(String id) => Objective(
      id: id,
      text: 'say something',
      mode: ObjectiveMode.speak,
      timeLimitSec: 8,
      gradingTier: GradingTier.binary,
      sampleAnswers: const ['ok'],
    );

Mission _mission(
  String id,
  Pace pace, {
  int objectives = 2,
  int tier = 2,
  MissionType type = MissionType.vocabulary,
}) =>
    Mission(
      id: id,
      type: type,
      tier: tier,
      pace: pace,
      prompt: id,
      objectives: [for (var i = 0; i < objectives; i++) _objective('$id-$i')],
    );

/// Enough variety per pace that the pool can always refill a slot.
List<Mission> _catalogue() => [
      for (var i = 0; i < 4; i++)
        _mission('fast$i', Pace.fast, type: MissionType.oddOneOut, tier: 1 + i % 2),
      for (var i = 0; i < 4; i++)
        _mission('med$i', Pace.medium, tier: 2 + i % 2),
      for (var i = 0; i < 4; i++)
        _mission('heavy$i', Pace.heavy, type: MissionType.tense, tier: 4),
    ];

const _pass = GradeResult(passed: true, multiplier: 1);
const _fail = GradeResult(passed: false, multiplier: 0);

void main() {
  setUpAll(() => registerFallbackValue(_FakeObjective()));

  late _MockApi api;

  GameBloc build({
    GradeResult grade = _pass,
    MissionEffect? effect,
    List<Mission>? catalogue,
  }) {
    when(() => api.gradeObjective(
          objective: any(named: 'objective'),
          transcript: any(named: 'transcript'),
          level: any(named: 'level'),
        )).thenAnswer((_) async => grade);

    return GameBloc(
      content: FakeContentRepository(catalogue ?? _catalogue()),
      api: api,
      random: Random(42),
      // Pinning the effect keeps these tests readable: the alternative is
      // hunting for a seed that happens to roll the one under test.
      chooseEffect: (_, _) => effect,
    );
  }

  /// Plays slot [slot] to completion and returns once the mission has settled.
  Future<void> playMission(GameBloc bloc, {int slot = 0}) async {
    bloc.add(const GameStarted());
    await Future<void>.delayed(Duration.zero);
    bloc.add(MissionTapped(slot));
    await Future<void>.delayed(Duration.zero);

    final total = bloc.state.activeMission!.objectives.length;
    for (var i = 0; i < total; i++) {
      bloc.add(const ObjectiveAnswered('an answer'));
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  setUp(() => api = _MockApi());

  group('GameStarted', () {
    blocTest<GameBloc, GameState>(
      'deals five missions and sits in idle',
      build: build,
      act: (bloc) => bloc.add(const GameStarted()),
      verify: (bloc) {
        expect(bloc.state.missions, hasLength(5));
        expect(bloc.state.phase, GamePhase.idle);
        expect(bloc.state.playerHp, GameState.maxHp);
        expect(bloc.state.botHp, GameState.maxHp);
      },
    );

    // A plain test rather than blocTest: blocTest closes the bloc before
    // running verify, and closing cancels the timer being asserted on.
    test('starts the idle rotation clock', () async {
      final bloc = build();
      addTearDown(bloc.close);

      bloc.add(const GameStarted());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.isIdleTimerActive, isTrue);
    });
  });

  group('MissionTapped', () {
    blocTest<GameBloc, GameState>(
      'enters resolving on the tapped slot',
      build: build,
      act: (bloc) async {
        bloc.add(const GameStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const MissionTapped(0));
      },
      verify: (bloc) {
        expect(bloc.state.phase, GamePhase.resolving);
        expect(bloc.state.activeMissionIndex, 0);
        expect(bloc.state.objectiveIndex, 0);
      },
    );

    // Regression guard: if the rotation clock keeps running, a mission can be
    // swapped out from under the player while they are answering it.
    //
    // A plain test because blocTest closes the bloc before verify, which would
    // cancel the timer regardless of whether the code did.
    test('cancels the idle rotation clock on entry', () async {
      final bloc = build();
      addTearDown(bloc.close);

      bloc.add(const GameStarted());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.isIdleTimerActive, isTrue, reason: 'precondition');

      bloc.add(const MissionTapped(0));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.isIdleTimerActive, isFalse);
    });

    blocTest<GameBloc, GameState>(
      'ignores a tap while stunned',
      build: build,
      seed: () => GameState(
        missions: _catalogue().take(5).toList(),
        stunUntil: DateTime.now().add(const Duration(seconds: 3)),
      ),
      act: (bloc) => bloc.add(const MissionTapped(0)),
      expect: () => <GameState>[],
    );

    blocTest<GameBloc, GameState>(
      'ignores a tap outside idle',
      build: build,
      seed: () => GameState(
        phase: GamePhase.resolving,
        missions: _catalogue().take(5).toList(),
      ),
      act: (bloc) => bloc.add(const MissionTapped(1)),
      expect: () => <GameState>[],
    );
  });

  group('playing a mission through', () {
    blocTest<GameBloc, GameState>(
      'walks the objectives, settles, and returns to idle',
      build: build,
      act: (bloc) async {
        bloc.add(const GameStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const MissionTapped(0));
        await Future<void>.delayed(Duration.zero);

        final count = bloc.state.activeMission!.objectives.length;
        for (var i = 0; i < count; i++) {
          bloc.add(const ObjectiveAnswered('an answer'));
          await Future<void>.delayed(Duration.zero);
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        expect(bloc.state.phase, GamePhase.idle);
        expect(bloc.state.activeMissionIndex, isNull);
        expect(bloc.state.botHp, lessThan(GameState.maxHp));
      },
    );

    blocTest<GameBloc, GameState>(
      'does not wait for a grade before moving to the next objective',
      build: () {
        // A grade that never arrives: play must continue regardless.
        when(() => api.gradeObjective(
              objective: any(named: 'objective'),
              transcript: any(named: 'transcript'),
              level: any(named: 'level'),
            )).thenAnswer((_) => Completer<GradeResult>().future);
        return GameBloc(
          content: FakeContentRepository(_catalogue()),
          api: api,
          random: Random(42),
        );
      },
      act: (bloc) async {
        bloc.add(const GameStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const MissionTapped(0));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ObjectiveAnswered('an answer'));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(bloc.state.objectiveIndex, 1,
            reason: 'should have advanced without the grade');
        expect(bloc.state.results.first, isNull,
            reason: 'the grade is still outstanding');
      },
    );

    blocTest<GameBloc, GameState>(
      'a late grade still lands on the right objective',
      build: build,
      act: (bloc) async {
        bloc.add(const GameStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const MissionTapped(0));
        await Future<void>.delayed(Duration.zero);

        // Arrives after the player has already moved on.
        bloc.add(const GradeReceived(objectiveIndex: 0, result: _pass));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) => expect(bloc.state.results[0]?.passed, isTrue),
    );

    blocTest<GameBloc, GameState>(
      'a timed-out objective is recorded as a miss without calling the API',
      build: build,
      act: (bloc) async {
        bloc.add(const GameStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const MissionTapped(0));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ObjectiveTimedOut());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(bloc.state.results[0]?.passed, isFalse);
        verifyNever(() => api.gradeObjective(
              objective: any(named: 'objective'),
              transcript: any(named: 'transcript'),
              level: any(named: 'level'),
            ));
      },
    );
  });

  group('stun', () {
    blocTest<GameBloc, GameState>(
      'a wasted mission stuns the player and bumps the streak',
      build: () => build(grade: _fail),
      act: (bloc) async {
        bloc.add(const GameStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const MissionTapped(0));
        await Future<void>.delayed(Duration.zero);

        final count = bloc.state.activeMission!.objectives.length;
        for (var i = 0; i < count; i++) {
          bloc.add(const ObjectiveAnswered('wrong'));
          await Future<void>.delayed(Duration.zero);
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        expect(bloc.state.missStreak, 1);
        expect(bloc.state.stunUntil, isNotNull);
      },
    );

    blocTest<GameBloc, GameState>(
      'clearing at least one objective resets the streak',
      build: build,
      seed: () => GameState(
        missions: _catalogue().take(5).toList(),
        missStreak: 2,
      ),
      act: (bloc) async {
        bloc.add(const MissionTapped(0));
        await Future<void>.delayed(Duration.zero);

        final count = bloc.state.activeMission!.objectives.length;
        for (var i = 0; i < count; i++) {
          bloc.add(const ObjectiveAnswered('an answer'));
          await Future<void>.delayed(Duration.zero);
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) => expect(bloc.state.missStreak, 0),
    );
  });

  group('idle rotation', () {
    blocTest<GameBloc, GameState>(
      'rotates the oldest slot when nobody picks a mission',
      build: build,
      act: (bloc) async {
        bloc.add(const GameStarted());
        await Future<void>.delayed(Duration.zero);
        final before = bloc.state.missions.map((m) => m.id).toList();

        bloc.add(const RefillTick());
        await Future<void>.delayed(Duration.zero);

        final after = bloc.state.missions.map((m) => m.id).toList();
        expect(after, isNot(before));
      },
      verify: (bloc) => expect(bloc.state.missions, hasLength(5)),
    );

    blocTest<GameBloc, GameState>(
      'does not rotate while a mission is being played',
      build: build,
      seed: () => GameState(
        phase: GamePhase.resolving,
        missions: _catalogue().take(5).toList(),
      ),
      act: (bloc) => bloc.add(const RefillTick()),
      expect: () => <GameState>[],
    );
  });

  group('end of match', () {
    blocTest<GameBloc, GameState>(
      'ends once the opponent is out of health',
      build: build,
      seed: () => GameState(
        missions: _catalogue().take(5).toList(),
        botHp: 1,
      ),
      act: (bloc) async {
        bloc.add(const MissionTapped(0));
        await Future<void>.delayed(Duration.zero);

        final count = bloc.state.activeMission!.objectives.length;
        for (var i = 0; i < count; i++) {
          bloc.add(const ObjectiveAnswered('an answer'));
          await Future<void>.delayed(Duration.zero);
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        expect(bloc.state.phase, GamePhase.ended);
        expect(bloc.state.botHp, 0);
        expect(bloc.isIdleTimerActive, isFalse,
            reason: 'the clock should stop once the match is over');
      },
    );

    blocTest<GameBloc, GameState>(
      'collects missed objectives for the post-match review',
      build: () => build(grade: _fail),
      act: (bloc) async {
        bloc.add(const GameStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const MissionTapped(0));
        await Future<void>.delayed(Duration.zero);

        final count = bloc.state.activeMission!.objectives.length;
        for (var i = 0; i < count; i++) {
          bloc.add(const ObjectiveAnswered('wrong'));
          await Future<void>.delayed(Duration.zero);
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) => expect(bloc.state.missedObjectives, isNotEmpty),
    );
  });

  group('mission effects', () {
    test('heal pays nothing when objectives were missed', () async {
      // The payout is conditional on a clean sweep (Game_Rule section 8.1).
      final bloc = build(grade: _fail, effect: MissionEffect.heal);
      addTearDown(bloc.close);

      await playMission(bloc);

      expect(bloc.state.playerHp, GameState.maxHp);
      expect(bloc.state.completedCount, 0);
    });

    test('heal cannot push health above the maximum', () async {
      final bloc = build(effect: MissionEffect.heal);
      addTearDown(bloc.close);

      await playMission(bloc);

      expect(bloc.state.playerHp, GameState.maxHp);
    });

    test('mirror sends half the damage back at the player', () async {
      final bloc = build(effect: MissionEffect.mirror);
      addTearDown(bloc.close);

      await playMission(bloc);

      final dealt = GameState.maxHp - bloc.state.botHp;
      expect(dealt, greaterThan(0));
      // Losing health to your own attack is the whole point of the effect.
      expect(bloc.state.playerHp, lessThan(GameState.maxHp));
    });

    test('gamble one objective short deals nothing', () async {
      final bloc = build(grade: _fail, effect: MissionEffect.gamble);
      addTearDown(bloc.close);

      await playMission(bloc);

      expect(bloc.state.botHp, GameState.maxHp);
    });

    test('the stun effect skips the escalation ladder', () async {
      final bloc = build(grade: _fail, effect: MissionEffect.stun);
      addTearDown(bloc.close);

      await playMission(bloc);

      // A first miss normally costs 1.5s; the effect makes it the full 3s.
      final remaining = bloc.state.stunUntil!.difference(DateTime.now());
      expect(remaining.inMilliseconds, greaterThan(2000));
    });

    test('burn keeps draining the opponent after the mission', () async {
      final bloc = build(effect: MissionEffect.burn);
      addTearDown(bloc.close);

      await playMission(bloc);
      final afterMission = bloc.state.botHp;

      await Future<void>.delayed(const Duration(milliseconds: 1100));

      expect(bloc.state.botHp, lessThan(afterMission));
    });

    // Regression guard: a burn left running past close() would keep draining
    // health after the match is over.
    //
    // A plain test because blocTest closes the bloc before verify, which would
    // cancel the timer regardless of whether the code did.
    test('closing the bloc cancels the burn clock', () async {
      final bloc = build(effect: MissionEffect.burn);

      await playMission(bloc);
      expect(bloc.isBurnTimerActive, isTrue);

      await bloc.close();

      expect(bloc.isBurnTimerActive, isFalse);
    });
  });
}
