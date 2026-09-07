import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pet_spec.dart';

/// One animation inside an atlas: which frames, how fast, and whether it loops.
class PetAnimation {
  const PetAnimation({
    required this.name,
    required this.rects,
    required this.fps,
    required this.loop,
  });

  final String name;

  /// Source rectangles into the atlas image, in frame order.
  final List<Rect> rects;

  final int fps;
  final bool loop;

  Duration get duration =>
      Duration(milliseconds: (rects.length * 1000 / fps).round());
}

/// A pet's sprite sheet: one decoded image plus the frame table that indexes it.
///
/// Loaded once and shared — decoding is the expensive part (a 1024² atlas is
/// 4 MB of uncompressed RGBA in memory, and Flutter cannot use GPU texture
/// compression), so two players using the same pet must not decode it twice.
class PetAtlas {
  PetAtlas._({
    required this.image,
    required this.animations,
    required this.cell,
  });

  final ui.Image image;
  final Map<String, PetAnimation> animations;
  final double cell;

  /// Decoded atlases, keyed by pet id. Never evicted: a match uses at most two
  /// and they are needed for its whole duration.
  static final Map<String, Future<PetAtlas>> _pending = {};

  /// Atlases already decoded, so a second caller gets one synchronously.
  ///
  /// Awaiting a completed Future still defers to a microtask, which is enough
  /// to make a widget miss its first frame. [ready] lets callers skip that.
  static final Map<String, PetAtlas> _ready = {};

  /// The atlas for [petId] if it is already decoded, else null.
  static PetAtlas? ready(String petId) => _ready[petId];

  static Future<PetAtlas> load(String petId) {
    final done = _ready[petId];
    if (done != null) return SynchronousFuture(done);
    return _pending.putIfAbsent(
      petId,
      () => _load(petId).then((atlas) {
        _ready[petId] = atlas;
        return atlas;
      }),
    );
  }

  static Future<PetAtlas> _load(String petId) async {
    final dir = 'assets/pets/$petId';

    final manifest = jsonDecode(
      await rootBundle.loadString('$dir/manifest.json'),
    ) as Map<String, dynamic>;

    final data = await rootBundle.load('$dir/${manifest['atlas']}');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
    );
    final image = (await codec.getNextFrame()).image;

    final cell = (manifest['cell'] as num).toDouble();

    // The frame table maps a name to its rect, so animations can be assembled
    // by name rather than by assuming a row order.
    final rectByName = <String, Rect>{};
    for (final f in (manifest['frames'] as List).cast<Map<String, dynamic>>()) {
      final r = (f['rect'] as List).cast<num>();
      rectByName[f['name'] as String] = Rect.fromLTWH(
        r[0].toDouble(),
        r[1].toDouble(),
        r[2].toDouble(),
        r[3].toDouble(),
      );
    }

    final animations = <String, PetAnimation>{};
    (manifest['animations'] as Map<String, dynamic>).forEach((name, spec) {
      final s = spec as Map<String, dynamic>;
      final rects = [
        for (final frameName in (s['frames'] as List).cast<String>())
          if (rectByName[frameName] != null) rectByName[frameName]!,
      ];
      if (rects.isEmpty) return;
      animations[name] = PetAnimation(
        name: name,
        rects: rects,
        fps: (s['fps'] as num?)?.toInt() ?? 8,
        loop: s['loop'] as bool? ?? true,
      );
    });

    return PetAtlas._(image: image, animations: animations, cell: cell);
  }

  /// The animation for a pose, falling back to something that exists.
  ///
  /// Content and art are generated separately, so a pose named in code may not
  /// have been drawn yet. Falling back keeps the match running.
  PetAnimation? forPose(PetPose pose) {
    final wanted = switch (pose) {
      PetPose.fly => const ['fly', 'idle'],
      PetPose.perch => const ['idle', 'fly'],
      PetPose.cast => const ['cast', 'pounce', 'attack', 'idle'],
      PetPose.hurt => const ['hurt', 'idle'],
    };
    for (final name in wanted) {
      final found = animations[name];
      if (found != null) return found;
    }
    return animations.values.isEmpty ? null : animations.values.first;
  }

  /// Frees the decoded image. Only for tests — production keeps atlases for
  /// the life of the process.
  static void evictAll() {
    for (final atlas in _ready.values) {
      atlas.image.dispose();
    }
    _ready.clear();
    _pending.clear();
  }
}
