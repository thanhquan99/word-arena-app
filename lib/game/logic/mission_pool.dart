/// Keeps the five mission slots on the map filled (Game_Rule section 2).
///
/// Pure logic — no Flame, no bloc — so the refill rules can be tested without
/// running the game.
library;

import 'dart:math';

import '../../content/models.dart';
import 'effects.dart';

/// The map always shows this mix, so a round never becomes all-heavy or
/// all-trivial.
/// Roughly a third of missions carry an effect (Game_Rule section 8) — often
/// enough to matter, rare enough that a plain mission still reads as normal.
const effectChance = 0.35;

const slotPaces = <Pace>[
  Pace.fast,
  Pace.fast,
  Pace.medium,
  Pace.medium,
  Pace.heavy,
];

/// Chooses the effect for a freshly drawn mission, or null for a plain one.
///
/// Injectable so tests can pin a specific effect instead of hunting for a seed
/// that happens to roll one.
typedef EffectChooser = MissionEffect? Function(Mission mission, Random random);

class MissionPool {
  MissionPool(
    List<Mission> all, {
    Random? random,
    EffectChooser chooseEffect = rollEffect,
  })  : _random = random ?? Random(),
        _chooseEffect = chooseEffect,
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
  final EffectChooser _chooseEffect;
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
      if (pool.isNotEmpty) {
        return _withEffect(pool[_random.nextInt(pool.length)]);
      }
    }

    return _withEffect(candidates[_random.nextInt(candidates.length)]);
  }

  /// Attaches this draw's effect.
  ///
  /// Rolled per draw rather than stored in the content, so the same mission
  /// coming back around can carry something different. Builds a fresh [Mission]
  /// because the content objects are shared between slots.
  Mission _withEffect(Mission mission) =>
      mission.withEffect(_chooseEffect(mission, _random));
}

/// The default effect roll (Game_Rule section 8).
MissionEffect? rollEffect(Mission mission, Random random) {
  if (random.nextDouble() >= effectChance) return null;

  final allowed = effectsAllowedFor(
    tier: mission.tier,
    isAllMic: mission.isAllMic,
  );
  if (allowed.isEmpty) return null;

  return allowed[random.nextInt(allowed.length)];
}
