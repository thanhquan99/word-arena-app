import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/pet/pet_atlas.dart';
import 'package:word_arena/pet/pet_spec.dart';
import 'package:word_arena/pet/pet_sprite_painter.dart';

/// Renders every frame of every animation through the real drawAtlas path, so
/// the atlas plumbing is verified visually rather than only by rect maths.
///
/// Run with: flutter test --update-goldens test/pet/pet_sprite_golden_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await PetAtlas.load('phoenix');
    await PetAtlas.load('tiger');
  });

  for (final pet in const ['phoenix', 'tiger']) {
    testWidgets('$pet sprite sheet', (tester) async {
      final atlas = PetAtlas.ready(pet)!;
      final names = atlas.animations.keys.toList();

      await tester.binding.setSurfaceSize(const Size(680, 700));
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Container(
            color: const Color(0xFFFFF8EC),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                for (final name in names)
                  Expanded(
                    child: Row(
                      children: [
                        for (
                          var i = 0;
                          i < atlas.animations[name]!.rects.length;
                          i++
                        )
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: CustomPaint(
                                painter: PetSpritePainter(
                                  atlas: atlas,
                                  animation: atlas.animations[name]!,
                                  frame: i,
                                  // Mirror the last frame of each row to prove
                                  // the opponent-facing path works too.
                                  mirrored: i == 3,
                                ),
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
        matchesGoldenFile('goldens/sprite_$pet.png'),
      );
    });
  }

  testWidgets('pose mapping picks a real animation for every pose', (
    tester,
  ) async {
    // Guards the fallback chain in PetAtlas.forPose: the tiger has no 'fly'
    // or 'cast', so a naive lookup would draw nothing.
    for (final pet in const ['phoenix', 'tiger']) {
      final atlas = PetAtlas.ready(pet)!;
      for (final pose in PetPose.values) {
        expect(atlas.forPose(pose), isNotNull, reason: '$pet/$pose');
      }
    }
  });
}
