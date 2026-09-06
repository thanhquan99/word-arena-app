import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/content/models.dart';
import 'package:word_arena/game/logic/mission_pool.dart';

Mission _mission(String id, Pace pace, {MissionType? type, int tier = 2}) {
  return Mission(
    id: id,
    type: type ?? MissionType.vocabulary,
    tier: tier,
    pace: pace,
    prompt: id,
    objectives: [
      Objective(
        id: '$id-1',
        text: 'x',
        mode: ObjectiveMode.speak,
        timeLimitSec: 8,
        gradingTier: GradingTier.binary,
        sampleAnswers: const ['x'],
      ),
    ],
  );
}

List<Mission> _catalogue() => [
      for (var i = 0; i < 4; i++)
        _mission('fast$i', Pace.fast, type: MissionType.oddOneOut, tier: 1 + i % 2),
      for (var i = 0; i < 4; i++)
        _mission('med$i', Pace.medium, type: MissionType.vocabulary, tier: 2 + i % 2),
      for (var i = 0; i < 3; i++)
        _mission('heavy$i', Pace.heavy, type: MissionType.tense, tier: 4),
    ];

void main() {
  group('MissionPool', () {
    test('fills exactly five slots', () {
      final pool = MissionPool(_catalogue(), random: Random(42));
      expect(pool.slots, hasLength(5));
    });

    test('holds the 2 fast / 2 medium / 1 heavy mix', () {
      final pool = MissionPool(_catalogue(), random: Random(42));
      final paces = pool.slots.map((m) => m.pace).toList();
      expect(paces.where((p) => p == Pace.fast), hasLength(2));
      expect(paces.where((p) => p == Pace.medium), hasLength(2));
      expect(paces.where((p) => p == Pace.heavy), hasLength(1));
    });

    test('keeps that mix after many refills', () {
      final pool = MissionPool(_catalogue(), random: Random(7));
      for (var i = 0; i < 50; i++) {
        pool.replaceOldest();
      }
      final paces = pool.slots.map((m) => m.pace).toList();
      expect(paces.where((p) => p == Pace.fast), hasLength(2));
      expect(paces.where((p) => p == Pace.medium), hasLength(2));
      expect(paces.where((p) => p == Pace.heavy), hasLength(1));
    });

    test('a refilled slot differs in type or tier when the pace offers a choice', () {
      // Only the fast slots have more than one (type, tier) combination in this
      // catalogue, so the rule can only be asserted there.
      final pool = MissionPool(_catalogue(), random: Random(3));
      for (var round = 0; round < 30; round++) {
        final index = round % 2; // slots 0 and 1 are the fast ones
        final before = pool.slots[index];
        pool.replaceAt(index);
        final after = pool.slots[index];
        expect(
          after.type != before.type || after.tier != before.tier,
          isTrue,
          reason: 'slot $index kept the same type and tier',
        );
      }
    });

    test('never hands back the same mission, even with one combo per pace', () {
      // The medium and heavy paces here have a single (type, tier) combination,
      // so the "different type or tier" rule cannot be satisfied. The fallback
      // still has to avoid returning the identical mission.
      final pool = MissionPool(_catalogue(), random: Random(5));
      for (var round = 0; round < 30; round++) {
        for (final index in [2, 3, 4]) {
          final before = pool.slots[index];
          pool.replaceAt(index);
          expect(
            pool.slots[index].id,
            isNot(before.id),
            reason: 'slot $index handed back the same mission',
          );
        }
      }
    });

    test('replaceOldest cycles through slots instead of hammering one', () {
      final pool = MissionPool(_catalogue(), random: Random(11));
      final touched = <int>{};
      for (var i = 0; i < 5; i++) {
        touched.add(pool.replaceOldest());
      }
      expect(touched, hasLength(5), reason: 'every slot should age out once');
    });

    test('is deterministic for a given seed', () {
      final a = MissionPool(_catalogue(), random: Random(99));
      final b = MissionPool(_catalogue(), random: Random(99));
      expect(
        a.slots.map((m) => m.id).toList(),
        b.slots.map((m) => m.id).toList(),
      );
    });

    test('rejects a catalogue missing a whole pace', () {
      final onlyFast = [_mission('a', Pace.fast)];
      expect(() => MissionPool(onlyFast), throwsArgumentError);
    });

    test('slots cannot be mutated from outside', () {
      final pool = MissionPool(_catalogue(), random: Random(1));
      expect(() => pool.slots.removeAt(0), throwsUnsupportedError);
    });
  });
}
