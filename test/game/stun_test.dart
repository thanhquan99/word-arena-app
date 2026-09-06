import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/game/logic/stun.dart';

void main() {
  group('StunTracker', () {
    test('the first miss is the short stun', () {
      final t = StunTracker();
      expect(t.recordMiss(), const Duration(milliseconds: 1500));
    });

    test('a second miss in a row escalates to the long stun', () {
      final t = StunTracker();
      t.recordMiss();
      expect(t.recordMiss(), const Duration(seconds: 3));
    });

    test('further misses stay at the long stun', () {
      final t = StunTracker();
      t.recordMiss();
      t.recordMiss();
      expect(t.recordMiss(), const Duration(seconds: 3));
      expect(t.recordMiss(), const Duration(seconds: 3));
    });

    test('easier missions only kick in from the third miss', () {
      final t = StunTracker();
      expect(t.shouldLowerTier, isFalse);
      t.recordMiss();
      expect(t.shouldLowerTier, isFalse);
      t.recordMiss();
      expect(t.shouldLowerTier, isFalse);
      t.recordMiss();
      expect(t.shouldLowerTier, isTrue);
    });

    test('any success resets the streak', () {
      final t = StunTracker();
      t.recordMiss();
      t.recordMiss();
      expect(t.streak, 2);

      t.recordSuccess();
      expect(t.streak, 0);
      expect(t.shouldLowerTier, isFalse);
      // Back to the short stun, as if starting fresh.
      expect(t.recordMiss(), const Duration(milliseconds: 1500));
    });

    test('a success while already easing turns easing back off', () {
      final t = StunTracker();
      for (var i = 0; i < 4; i++) {
        t.recordMiss();
      }
      expect(t.shouldLowerTier, isTrue);

      t.recordSuccess();
      expect(t.shouldLowerTier, isFalse);
    });
  });
}
