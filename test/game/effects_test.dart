import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/content/models.dart';
import 'package:word_arena/game/logic/damage.dart';
import 'package:word_arena/game/logic/effects.dart';
import 'package:word_arena/game/logic/mission_pool.dart';

Objective _objective(String id, {ObjectiveMode mode = ObjectiveMode.speak}) =>
    Objective(
      id: id,
      text: 'say something',
      mode: mode,
      timeLimitSec: 8,
      gradingTier: GradingTier.binary,
      sampleAnswers: const ['ok'],
    );

Mission _mission(
  String id,
  Pace pace, {
  int tier = 2,
  MissionType type = MissionType.vocabulary,
  List<ObjectiveMode> modes = const [ObjectiveMode.speak, ObjectiveMode.speak],
}) =>
    Mission(
      id: id,
      type: type,
      tier: tier,
      pace: pace,
      prompt: id,
      objectives: [
        for (var i = 0; i < modes.length; i++) _objective('$id-$i', mode: modes[i]),
      ],
    );

void main() {
  group('effectMultiplier', () {
    test('a plain mission is unaffected', () {
      expect(effectMultiplier(null, completed: 2, total: 4), 1.0);
    });

    test('double pays twice regardless of how much was completed', () {
      expect(
        effectMultiplier(MissionEffect.doubleDamage, completed: 1, total: 4),
        2.0,
      );
    });

    test('gamble pays triple only on a clean sweep', () {
      expect(
        effectMultiplier(MissionEffect.gamble, completed: 4, total: 4),
        3.0,
      );
    });

    test('gamble one objective short pays nothing at all', () {
      // All-or-nothing, not a reduction: this is the whole point of the effect.
      expect(
        effectMultiplier(MissionEffect.gamble, completed: 3, total: 4),
        0.0,
      );
    });

    test('mirror leaves the outgoing damage alone', () {
      // Its kickback lands on the player's own health, handled in the bloc.
      expect(
        effectMultiplier(MissionEffect.mirror, completed: 2, total: 2),
        1.0,
      );
    });
  });

  group('effectiveTimeLimit', () {
    test('leaves a plain objective at its own limit', () {
      expect(
        effectiveTimeLimit(baseSeconds: 8, effect: null, mercy: false),
        8,
      );
    });

    test('haste stretches the clock', () {
      expect(
        effectiveTimeLimit(
          baseSeconds: 8,
          effect: MissionEffect.haste,
          mercy: false,
        ),
        12,
      );
    });

    test('rush shortens it', () {
      expect(
        effectiveTimeLimit(
          baseSeconds: 10,
          effect: MissionEffect.rush,
          mercy: false,
        ),
        6,
      );
    });

    test('mercy stacks on top of the mission effect', () {
      // 6 * 0.6 * 1.3 = 4.68 -> 5
      expect(
        effectiveTimeLimit(
          baseSeconds: 6,
          effect: MissionEffect.rush,
          mercy: true,
        ),
        5,
      );
    });

    test('never leaves the player with less than the floor', () {
      expect(
        effectiveTimeLimit(
          baseSeconds: 1,
          effect: MissionEffect.rush,
          mercy: false,
        ),
        minObjectiveSeconds,
      );
    });
  });

  group('effectsAllowedFor', () {
    test('a low tier mission offers no risky effect', () {
      final allowed = effectsAllowedFor(tier: 2, isAllMic: false);

      expect(
        allowed.where((e) => effectInfo(e).kind == EffectKind.risky),
        isEmpty,
      );
      expect(allowed, contains(MissionEffect.heal));
    });

    test('tier 3 unlocks the risky effects', () {
      final allowed = effectsAllowedFor(tier: minRiskyTier, isAllMic: false);

      expect(allowed, contains(MissionEffect.gamble));
    });

    test('silence is withheld when every objective needs the microphone', () {
      // Locking the mic on an all-speaking mission would leave nothing to
      // answer with.
      final allowed = effectsAllowedFor(tier: 4, isAllMic: true);

      expect(allowed, isNot(contains(MissionEffect.silence)));
      expect(allowed, contains(MissionEffect.gamble));
    });
  });

  group('effect seeding', () {
    List<Mission> catalogue() => [
          for (var i = 0; i < 6; i++)
            _mission('fast$i', Pace.fast, tier: 1 + (i % 4)),
          for (var i = 0; i < 6; i++)
            _mission('med$i', Pace.medium, tier: 1 + (i % 4)),
          for (var i = 0; i < 6; i++)
            _mission('heavy$i', Pace.heavy, tier: 1 + (i % 4)),
        ];

    test('roughly a third of drawn missions carry an effect', () {
      final pool = MissionPool(catalogue(), random: Random(7));

      var withEffect = 0;
      const draws = 1000;
      for (var i = 0; i < draws; i++) {
        pool.replaceOldest();
        withEffect += pool.slots.where((m) => m.effect != null).length;
      }

      final rate = withEffect / (draws * pool.slots.length);
      expect(rate, greaterThan(0.30));
      expect(rate, lessThan(0.40));
    });

    test('a risky effect never lands on a low tier mission', () {
      final pool = MissionPool(catalogue(), random: Random(11));

      for (var i = 0; i < 1000; i++) {
        pool.replaceOldest();
        for (final mission in pool.slots) {
          final effect = mission.effect;
          if (effect == null) continue;
          if (effectInfo(effect).kind == EffectKind.risky) {
            expect(
              mission.tier,
              greaterThanOrEqualTo(minRiskyTier),
              reason: '${effectInfo(effect).label} on tier ${mission.tier}',
            );
          }
        }
      }
    });

    test('silence never lands on an all-microphone mission', () {
      final allMic = [
        for (var i = 0; i < 6; i++)
          _mission('fast$i', Pace.fast, tier: 4),
        for (var i = 0; i < 6; i++)
          _mission('med$i', Pace.medium, tier: 4),
        for (var i = 0; i < 6; i++)
          _mission('heavy$i', Pace.heavy, tier: 4),
      ];
      final pool = MissionPool(allMic, random: Random(3));

      for (var i = 0; i < 500; i++) {
        pool.replaceOldest();
        for (final mission in pool.slots) {
          expect(mission.effect, isNot(MissionEffect.silence));
        }
      }
    });

    test('the same seed produces the same effects', () {
      List<MissionEffect?> run() {
        final pool = MissionPool(catalogue(), random: Random(42));
        for (var i = 0; i < 20; i++) {
          pool.replaceOldest();
        }
        return pool.slots.map((m) => m.effect).toList();
      }

      expect(run(), run());
    });
  });
}
