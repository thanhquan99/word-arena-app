import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/ui/mission_visuals.dart';
import 'package:word_arena/ui/theme/arena_theme.dart';

void main() {
  group('Arena tokens', () {
    test('tier colours are indexed 1..4 and clamp outside that', () {
      // Content can name a tier the build does not know; a bad value must not
      // crash a running match (mirrors tierMultiplier in damage.dart).
      expect(Arena.tier(1), const Color(0xFF4A9DF0));
      expect(Arena.tier(4), const Color(0xFFF4623A));
      expect(Arena.tier(0), Arena.tier(1));
      expect(Arena.tier(99), Arena.tier(4));
      expect(Arena.tier(-5), Arena.tier(1));
    });

    test('mission_visuals delegates to the theme, so there is one palette', () {
      for (var t = 1; t <= 4; t++) {
        expect(tierColor(t), Arena.tier(t));
      }
    });

    test('every tier colour is distinct', () {
      final seen = {for (var t = 1; t <= 4; t++) Arena.tier(t)};
      expect(seen, hasLength(4));
    });

    test('shadows are hard offsets, never blurred', () {
      // A blurred shadow reads as Material and breaks the flat inked look
      // this direction is built on.
      for (final list in [Arena.lift, Arena.liftSm, Arena.pressed]) {
        for (final shadow in list) {
          expect(shadow.blurRadius, 0, reason: 'shadow must not blur');
          expect(shadow.color, Arena.ink);
        }
      }
    });

    test('pressed sits closer to the surface than lift', () {
      // The press travel is what makes a button feel physical.
      expect(Arena.pressed.first.offset.dy,
          lessThan(Arena.lift.first.offset.dy));
    });

    test('borders all use the one ink colour', () {
      for (final border in [Arena.border, Arena.borderSm]) {
        expect(border.top.color, Arena.ink);
        expect(border.isUniform, isTrue,
            reason: 'Flutter rejects borderRadius on a non-uniform border');
      }
    });
  });

  group('Arena.theme', () {
    test('is light, on the warm ground', () {
      final t = Arena.theme;
      expect(t.colorScheme.brightness, Brightness.light);
      expect(t.scaffoldBackgroundColor, Arena.bg);
      expect(t.colorScheme.onSurface, Arena.ink);
    });

    test('maps semantic roles onto the palette', () {
      final s = Arena.theme.colorScheme;
      expect(s.primary, Arena.accent);
      expect(s.secondary, Arena.self);
      expect(s.error, Arena.enemy);
    });
  });

  group('ArenaButton', () {
    testWidgets('reports taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: ArenaButton(label: 'Đấu', onPressed: () => taps++),
          ),
        ),
      ));
      await tester.tap(find.text('Đấu'));
      expect(taps, 1);
    });

    testWidgets('sinks while held, then returns', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(child: ArenaButton(label: 'Đấu', onPressed: () {})),
        ),
      ));

      Matrix4? transform() => tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .transform;

      final rest = transform()!.getTranslation().y;

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Đấu')),
      );
      await tester.pump();
      expect(transform()!.getTranslation().y, greaterThan(rest),
          reason: 'the button should move down under the finger');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(transform()!.getTranslation().y, rest);
    });

    testWidgets('a disabled button is dimmed and inert', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(child: ArenaButton(label: 'Đấu', onPressed: null)),
        ),
      ));
      final style = tester.widget<Text>(find.text('Đấu')).style!;
      expect(style.color, Arena.inkSoft);

      // Tapping must not throw.
      await tester.tap(find.text('Đấu'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
