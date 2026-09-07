import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/pet/pet_painter.dart';
import 'package:word_arena/pet/pet_spec.dart';

/// Renders the rig to a golden so the art can be reviewed without a device.
///
/// Run with `flutter test --update-goldens test/pet/pet_golden_test.dart`.
void main() {
  testWidgets('phoenix rig sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(880, 500));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Container(
          color: const Color(0xFFFFF8EC),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // One row per pose, all four pets, at inspector size.
              for (final pose in PetPose.values)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final spec in PetSpec.all)
                        SizedBox(
                          width: 190,
                          height: 110,
                          child: CustomPaint(
                            painter: PetPainter(
                              spec: spec,
                              pose: pose,
                              t: .18,
                              oneShot: pose == PetPose.cast ||
                                      pose == PetPose.hurt
                                  ? .5
                                  : 0,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/phoenix_rig.png'),
    );
  });
}
