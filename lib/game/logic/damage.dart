/// Damage rules from Game_Rule section 7.
///
/// Pure functions — no Flame, no bloc, no I/O — so the balance can be tested
/// and tuned without running the game.
library;

import 'dart:math' as math;

const _tierMultipliers = <double>[0.8, 1.0, 1.3, 1.6];

/// Multiplier for a mission's difficulty tier (1..4).
///
/// A tier outside the range is clamped rather than rejected: bad content should
/// not be able to crash a match in progress.
double tierMultiplier(int tier) {
  final index = tier.clamp(1, _tierMultipliers.length) - 1;
  return _tierMultipliers[index];
}

/// Damage dealt for one mission.
///
/// [completed] is how many objectives the player finished, [gradeMul] the
/// average multiplier the server returned for them (0 when everything failed,
/// 1 when everything passed).
double computeDamage({
  required int completed,
  required int tier,
  required double gradeMul,
  double effectMul = 1.0,
  double handicap = 1.0,
}) {
  final raw = completed *
      tierMultiplier(tier) *
      gradeMul *
      effectMul *
      handicap;
  return math.max(0, raw);
}

/// Extra damage for clearing a mission quickly.
///
/// Only awarded on a clean sweep: partial credit already scales the base
/// damage, so rewarding speed on a half-finished mission would pay twice.
int speedBonus({
  required int completed,
  required int total,
  required double elapsedRatio,
}) {
  if (total == 0 || completed < total) return 0;
  return elapsedRatio < 0.6 ? 1 : 0;
}
