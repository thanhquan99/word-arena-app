import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/pet/pet_atlas.dart';
import 'package:word_arena/pet/pet_spec.dart';
import 'package:word_arena/pet/pet_sprite_painter.dart';
import 'package:word_arena/pet/pet_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PetAtlas', () {
    test('loads the generated phoenix atlas', () async {
      final atlas = await PetAtlas.load('phoenix');
      expect(atlas.cell, 256);
      expect(atlas.image.width, 1024);
      expect(atlas.animations.keys, containsAll(['idle', 'fly', 'cast', 'hurt']));
      for (final anim in atlas.animations.values) {
        expect(anim.rects, hasLength(4), reason: anim.name);
      }
    });

    test('loads the generated tiger atlas with its own pose names', () async {
      final atlas = await PetAtlas.load('tiger');
      // The tiger was generated with walk/pounce rather than fly/cast.
      expect(atlas.animations.keys, containsAll(['idle', 'walk', 'pounce', 'hurt']));
    });

    test('caches, so two players on one pet decode a single image', () async {
      // Deliberately not evicting first: disposing the shared ui.Image would
      // break every later test that already holds it.
      final a = await PetAtlas.load('phoenix');
      final b = await PetAtlas.load('phoenix');
      expect(identical(a, b), isTrue);
      expect(identical(a.image, b.image), isTrue);
      expect(PetAtlas.ready('phoenix'), same(a),
          reason: 'a decoded atlas must be available synchronously');
    });

    test('maps every pose onto an animation the atlas actually has', () async {
      // The tiger has no 'fly' or 'cast'; the mapping must still resolve.
      final tiger = await PetAtlas.load('tiger');
      for (final pose in PetPose.values) {
        expect(tiger.forPose(pose), isNotNull, reason: '$pose');
      }
      expect(tiger.forPose(PetPose.cast)!.name, 'pounce');
      expect(tiger.forPose(PetPose.fly)!.name, 'idle');
    });

    test('loop flags follow the manifest', () async {
      final atlas = await PetAtlas.load('phoenix');
      expect(atlas.animations['idle']!.loop, isTrue);
      expect(atlas.animations['cast']!.loop, isFalse);
      expect(atlas.animations['hurt']!.loop, isFalse);
    });

    test('a missing pet throws rather than returning an empty atlas', () async {
      await expectLater(PetAtlas.load('no-such-pet'), throwsA(anything));
    });
  });

  group('PetSpritePainter', () {
    late PetAtlas atlas;

    setUp(() async => atlas = await PetAtlas.load('phoenix'));

    test('repaints when the frame advances', () {
      final anim = atlas.animations['idle']!;
      final a = PetSpritePainter(atlas: atlas, animation: anim, frame: 0);
      final b = PetSpritePainter(atlas: atlas, animation: anim, frame: 1);
      expect(b.shouldRepaint(a), isTrue);
    });

    test('does not repaint on an identical frame', () {
      final anim = atlas.animations['idle']!;
      final a = PetSpritePainter(atlas: atlas, animation: anim, frame: 2);
      final b = PetSpritePainter(atlas: atlas, animation: anim, frame: 2);
      expect(b.shouldRepaint(a), isFalse);
    });

    testWidgets('an out-of-range frame clamps instead of throwing',
        (tester) async {
      // A controller can outrun the frame list for one build after a pose
      // change; that must not crash a live match.
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(120, 120),
            painter: PetSpritePainter(
              atlas: atlas,
              animation: atlas.animations['idle']!,
              frame: 99,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PetView with sprites', () {
    // Warm the cache first: PetAtlas.load then resolves from cache inside the
    // widget, keeping these tests off real async. A looping sprite animation
    // never settles, so pumpAndSettle is unusable and runAsync hangs on the
    // ticker.
    setUp(() async {
      await PetAtlas.load('phoenix');
      await PetAtlas.load('tiger');
    });

    testWidgets('plays the atlas once it loads', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetView(spec: PetSpec.fire, pose: PetPose.fly, size: 120),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(PetSpritePlayer), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Advance through a couple of sprite frames.
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports when a one-shot pose finishes', (tester) async {
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PetView(
              spec: PetSpec.fire,
              pose: PetPose.cast,
              size: 120,
              onPoseFinished: () => finished = true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // cast is 4 frames at 8 fps = 500ms.
      await tester.pump(const Duration(milliseconds: 700));
      expect(finished, isTrue);
    });

    testWidgets('falls back to the vector rig for a pet with no atlas',
        (tester) async {
      // leaf ships no generated art yet.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetView(spec: PetSpec.leaf, pose: PetPose.fly, size: 120),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(PetSpritePlayer), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
