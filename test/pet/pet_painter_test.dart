import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/pet/pet_painter.dart';
import 'package:word_arena/pet/pet_spec.dart';
import 'package:word_arena/pet/pet_view.dart';

void main() {
  group('PetPainter', () {
    test('repaints when the clock advances', () {
      const a = PetPainter(spec: PetSpec.fire, pose: PetPose.fly, t: 0);
      const b = PetPainter(spec: PetSpec.fire, pose: PetPose.fly, t: .5);
      expect(b.shouldRepaint(a), isTrue);
    });

    test('repaints when the pet changes', () {
      const a = PetPainter(spec: PetSpec.fire, pose: PetPose.fly, t: 0);
      const b = PetPainter(spec: PetSpec.ice, pose: PetPose.fly, t: 0);
      expect(b.shouldRepaint(a), isTrue);
    });

    test('does not repaint when nothing changed', () {
      const a = PetPainter(spec: PetSpec.fire, pose: PetPose.fly, t: .25);
      const b = PetPainter(spec: PetSpec.fire, pose: PetPose.fly, t: .25);
      expect(b.shouldRepaint(a), isFalse);
    });

    testWidgets('paints every pose without throwing', (tester) async {
      // The painter runs on every frame of a match; an exception in one pose
      // would surface as a crash mid-fight rather than a visual glitch.
      for (final pose in PetPose.values) {
        for (final spec in PetSpec.all) {
          await tester.pumpWidget(
            MaterialApp(
              home: CustomPaint(
                size: const Size(120, 120),
                painter: PetPainter(
                  spec: spec,
                  pose: pose,
                  t: .37,
                  oneShot: .5,
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: '${spec.id}/$pose');
        }
      }
    });

    testWidgets('paints correctly at both ends of the clock', (tester) async {
      // t wraps from 1 back to 0 every cycle; the joints must not jump there.
      for (final t in const [0.0, 0.999]) {
        await tester.pumpWidget(
          MaterialApp(
            home: CustomPaint(
              size: const Size(120, 120),
              painter: PetPainter(spec: PetSpec.fire, pose: PetPose.fly, t: t),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('PetSpec', () {
    test('every pet has a distinct palette', () {
      final primaries = PetSpec.all.map((p) => p.primary).toSet();
      expect(primaries.length, PetSpec.all.length);
    });

    test('byId falls back rather than throwing on an unknown id', () {
      // Content can name a pet the build does not ship; a match must not die
      // because of it.
      expect(PetSpec.byId('nonexistent').id, PetSpec.fire.id);
      expect(PetSpec.byId('ice').id, 'ice');
    });
  });

  group('PetView', () {
    testWidgets('renders the rig', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetView(spec: PetSpec.fire, pose: PetPose.fly),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PetView), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);

      // The idle loop repeats forever, so end the test on a settled frame
      // rather than pumpAndSettle, which would never return.
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('mirrors the opponent pet', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetView(
              spec: PetSpec.ice,
              pose: PetPose.perch,
              mirrored: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
