import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/content/models.dart';

void main() {
  // Reads the real content file rather than a fixture: the point is to catch a
  // broken content.json before it reaches a match.
  //
  // Loaded straight off disk instead of through rootBundle — unit tests run
  // without an asset bundle.
  late List<Mission> missions;

  setUpAll(() {
    final raw = File('assets/content.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    missions = (json['missions'] as List)
        .cast<Map<String, dynamic>>()
        .map(Mission.fromJson)
        .toList();
  });

  group('content.json', () {
    test('parses every mission', () {
      expect(missions, hasLength(15));
    });

    test('objective ids are unique across the whole file', () {
      final ids = <String>[];
      for (final m in missions) {
        for (final o in m.objectives) {
          ids.add(o.id);
        }
      }
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every mission has at least one objective', () {
      for (final m in missions) {
        expect(m.objectives, isNotEmpty, reason: 'mission ${m.id}');
      }
    });

    test('tier stays within 1..4', () {
      for (final m in missions) {
        expect(m.tier, inInclusiveRange(1, 4), reason: 'mission ${m.id}');
      }
    });

    test('the map can be filled with the 2 fast / 2 medium / 1 heavy mix', () {
      int count(Pace p) => missions.where((m) => m.pace == p).length;
      expect(count(Pace.fast), greaterThanOrEqualTo(2));
      expect(count(Pace.medium), greaterThanOrEqualTo(2));
      expect(count(Pace.heavy), greaterThanOrEqualTo(1));
    });
  });

  group('required fields per grading tier', () {
    // The server rejects an objective that is missing the field its tier needs,
    // so this is checked here rather than discovered mid-match.
    test('exact carries exactAnswer', () {
      for (final o in _objectivesWith(missions, GradingTier.exact)) {
        expect(o.exactAnswer, isNotNull, reason: o.id);
        expect(o.exactAnswer, isNotEmpty, reason: o.id);
      }
    });

    test('checklist carries acceptedItems and a reachable minRequired', () {
      for (final o in _objectivesWith(missions, GradingTier.checklist)) {
        expect(o.acceptedItems, isNotNull, reason: o.id);
        expect(o.minRequired, isNotNull, reason: o.id);
        expect(
          o.minRequired!,
          lessThanOrEqualTo(o.acceptedItems!.length),
          reason: '${o.id}: minRequired exceeds the list it draws from',
        );
      }
    });

    test('binary carries either sampleAnswers or targetWord', () {
      for (final o in _objectivesWith(missions, GradingTier.binary)) {
        final hasReference =
            (o.sampleAnswers?.isNotEmpty ?? false) || o.targetWord != null;
        expect(hasReference, isTrue, reason: o.id);
      }
    });

    test('scaled carries sampleAnswers', () {
      for (final o in _objectivesWith(missions, GradingTier.scaled)) {
        expect(o.sampleAnswers, isNotNull, reason: o.id);
        expect(o.sampleAnswers, isNotEmpty, reason: o.id);
      }
    });
  });

  group('Mission.fromJson', () {
    test('rejects an unknown enum instead of guessing', () {
      expect(
        () => Mission.fromJson({
          'id': 'x',
          'type': 'not_a_type',
          'tier': 1,
          'pace': 'fast',
          'prompt': 'x',
          'objectives': <Map<String, dynamic>>[],
        }),
        throwsFormatException,
      );
    });

    test('rejects a tier outside 1..4', () {
      expect(
        () => Mission.fromJson({
          'id': 'x',
          'type': 'vocabulary',
          'tier': 9,
          'pace': 'fast',
          'prompt': 'x',
          'objectives': <Map<String, dynamic>>[],
        }),
        throwsFormatException,
      );
    });
  });

  group('Objective.needsMic', () {
    test('select and arrange do not use the microphone', () {
      for (final o in missions.expand((m) => m.objectives)) {
        if (o.mode == ObjectiveMode.select || o.mode == ObjectiveMode.arrange) {
          expect(o.needsMic, isFalse, reason: o.id);
        }
      }
    });
  });
}

Iterable<Objective> _objectivesWith(List<Mission> missions, GradingTier tier) =>
    missions.expand((m) => m.objectives).where((o) => o.gradingTier == tier);
