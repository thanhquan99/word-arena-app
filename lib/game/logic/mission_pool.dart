/// Keeps the five mission slots on the map filled (Game_Rule section 2).
///
/// Pure logic — no Flame, no bloc — so the refill rules can be tested without
/// running the game.
library;

import 'dart:math';

import '../../content/models.dart';

/// The map always shows this mix, so a round never becomes all-heavy or
/// all-trivial.
const slotPaces = <Pace>[
  Pace.fast,
  Pace.fast,
  Pace.medium,
  Pace.medium,
  Pace.heavy,
];

class MissionPool {
  MissionPool(List<Mission> all, {Random? random})
      : _random = random ?? Random(),
        _byPace = {
          for (final pace in Pace.values)
            pace: all.where((m) => m.pace == pace).toList(),
        } {
    for (final pace in Pace.values) {
      if (_byPace[pace]!.isEmpty) {
        throw ArgumentError('no missions with pace ${pace.name}');
      }
    }
    for (var i = 0; i < slotPaces.length; i++) {
      _slots.add(_draw(slotPaces[i], avoid: null));
    }
  }

  final Random _random;
  final Map<Pace, List<Mission>> _byPace;
  final List<Mission> _slots = [];

  /// Insertion order, oldest first — used to pick what the 5s timer replaces.
  final List<int> _age = [0, 1, 2, 3, 4];

  List<Mission> get slots => List.unmodifiable(_slots);

  /// Replaces the slot that has been on the map longest (the 5s idle timer).
  int replaceOldest() {
    final index = _age.first;
    replaceAt(index);
    return index;
  }

  /// Replaces one slot, keeping that slot's pace so the mix stays 2/2/1.
  void replaceAt(int index) {
    final outgoing = _slots[index];
    _slots[index] = _draw(slotPaces[index], avoid: outgoing);
    _age
      ..remove(index)
      ..add(index);
  }

  /// Picks a mission of [pace], avoiding whatever just left that slot.
  ///
  /// "Different" means a different type *or* a different tier: replacing
  /// `farmer` with `teacher` would technically be a new mission, but it reads
  /// as the same thing coming back (Game_Rule section 3.1).
  Mission _draw(Pace pace, {required Mission? avoid}) {
    final candidates = _byPace[pace]!;

    if (avoid != null) {
      final different = candidates
          .where((m) => m.type != avoid.type || m.tier != avoid.tier)
          .toList();
      // Fall back to any other mission when the content is too thin to satisfy
      // the rule — better a repeat than an empty slot.
      final pool = different.isNotEmpty
          ? different
          : candidates.where((m) => m.id != avoid.id).toList();
      if (pool.isNotEmpty) return pool[_random.nextInt(pool.length)];
    }

    return candidates[_random.nextInt(candidates.length)];
  }
}
