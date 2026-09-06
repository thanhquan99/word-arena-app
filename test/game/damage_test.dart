import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/game/logic/damage.dart';

void main() {
  group('tierMultiplier', () {
    test('follows the table in Game_Rule section 7', () {
      expect(tierMultiplier(1), 0.8);
      expect(tierMultiplier(2), 1.0);
      expect(tierMultiplier(3), 1.3);
      expect(tierMultiplier(4), 1.6);
    });

    test('clamps a tier outside 1..4 rather than throwing mid-match', () {
      expect(tierMultiplier(0), 0.8);
      expect(tierMultiplier(9), 1.6);
    });
  });

  group('computeDamage', () {
    test('completing nothing deals nothing, whatever the tier', () {
      for (var tier = 1; tier <= 4; tier++) {
        expect(
          computeDamage(completed: 0, tier: tier, gradeMul: 1),
          0,
          reason: 'tier $tier',
        );
      }
    });

    test('scales with the number of objectives completed', () {
      final one = computeDamage(completed: 1, tier: 2, gradeMul: 1);
      final three = computeDamage(completed: 3, tier: 2, gradeMul: 1);
      expect(three, one * 3);
    });

    test('a failed grade contributes no damage', () {
      expect(computeDamage(completed: 4, tier: 4, gradeMul: 0), 0);
    });

    test('applies the tier multiplier', () {
      // 3 objectives on a tier-4 mission: 3 * 1.6 = 4.8
      expect(computeDamage(completed: 3, tier: 4, gradeMul: 1), closeTo(4.8, 0.001));
    });

    test('applies effect and handicap multipliers', () {
      final base = computeDamage(completed: 2, tier: 2, gradeMul: 1);
      expect(
        computeDamage(completed: 2, tier: 2, gradeMul: 1, effectMul: 2),
        base * 2,
      );
      expect(
        computeDamage(completed: 2, tier: 2, gradeMul: 1, handicap: 0.8),
        closeTo(base * 0.8, 0.001),
      );
    });

    test('a partial grade lowers the damage proportionally', () {
      final full = computeDamage(completed: 3, tier: 2, gradeMul: 1);
      final partial = computeDamage(completed: 3, tier: 2, gradeMul: 0.5);
      expect(partial, closeTo(full * 0.5, 0.001));
    });

    test('never returns a negative number', () {
      expect(
        computeDamage(completed: 2, tier: 2, gradeMul: 1, handicap: -5),
        greaterThanOrEqualTo(0),
      );
    });
  });

  group('speedBonus', () {
    test('rewards finishing every objective well inside the limit', () {
      expect(
        speedBonus(completed: 3, total: 3, elapsedRatio: 0.5),
        1,
      );
    });

    test('gives nothing when objectives were missed', () {
      expect(speedBonus(completed: 2, total: 3, elapsedRatio: 0.3), 0);
    });

    test('gives nothing when the player used most of the clock', () {
      expect(speedBonus(completed: 3, total: 3, elapsedRatio: 0.9), 0);
    });
  });
}
