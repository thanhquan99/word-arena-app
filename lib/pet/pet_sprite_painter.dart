import 'package:flutter/material.dart';

import 'pet_atlas.dart';

/// Draws one frame of a pet's sprite animation.
///
/// Uses [Canvas.drawAtlas] rather than `drawImageRect`: it takes one texture
/// bind and one draw call for however many sprites are passed, which is what
/// keeps a board with two animating pets off the raster thread's critical
/// path. Here it draws a single sprite, but the call shape is the same and it
/// costs nothing to use the cheaper primitive.
class PetSpritePainter extends CustomPainter {
  const PetSpritePainter({
    required this.atlas,
    required this.animation,
    required this.frame,
    this.mirrored = false,
  });

  final PetAtlas atlas;
  final PetAnimation animation;

  /// Index into [PetAnimation.rects]. Clamped, so an out-of-range value from a
  /// controller mid-rebuild draws the last frame rather than throwing.
  final int frame;

  final bool mirrored;

  @override
  void paint(Canvas canvas, Size size) {
    if (animation.rects.isEmpty) return;

    final rect = animation.rects[frame.clamp(0, animation.rects.length - 1)];

    // Fit the source cell into the widget box, preserving aspect.
    final scale = size.shortestSide / atlas.cell;
    final drawn = atlas.cell * scale;

    // RSTransform is rotate-scale-translate only — no flip. A mirrored pet is
    // drawn by flipping the canvas instead, which costs one matrix multiply.
    if (mirrored) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    // Built directly rather than via fromComponents: that constructor applies
    // its anchor in *source* pixels before scaling, which pushed the sprite
    // off-canvas entirely. scos/ssin plus an explicit top-left translate is
    // unambiguous.
    canvas.drawAtlas(
      atlas.image,
      [
        RSTransform(
          scale, // scos — cos(0) * scale
          0, // ssin — sin(0) * scale
          (size.width - drawn) / 2,
          (size.height - drawn) / 2,
        ),
      ],
      [rect],
      null,
      null,
      null,
      Paint()..filterQuality = FilterQuality.medium,
    );

    if (mirrored) canvas.restore();
  }

  @override
  bool shouldRepaint(PetSpritePainter old) =>
      old.frame != frame ||
      old.animation.name != animation.name ||
      old.atlas.image != atlas.image ||
      old.mirrored != mirrored;
}

/// Plays a [PetAnimation] and rebuilds only when the frame index changes.
///
/// A ticker running at 60 fps would rebuild ten times per 8 fps sprite frame,
/// nine of them producing an identical picture. This drives a plain [Timer]-
/// free [AnimationController] but gates the rebuild on the integer frame,
/// which is the actual visual state.
class PetSpritePlayer extends StatefulWidget {
  const PetSpritePlayer({
    super.key,
    required this.atlas,
    required this.animation,
    this.mirrored = false,
    this.onFinished,
  });

  final PetAtlas atlas;
  final PetAnimation animation;
  final bool mirrored;

  /// Called once when a non-looping animation reaches its last frame.
  final VoidCallback? onFinished;

  @override
  State<PetSpritePlayer> createState() => _PetSpritePlayerState();
}

class _PetSpritePlayerState extends State<PetSpritePlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.animation.duration,
  );

  int _frame = 0;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_tick);
    _start();
  }

  @override
  void didUpdateWidget(PetSpritePlayer old) {
    super.didUpdateWidget(old);
    if (old.animation.name != widget.animation.name) {
      _frame = 0;
      _reported = false;
      _controller.duration = widget.animation.duration;
      _start();
    }
  }

  void _start() {
    _controller.stop();
    if (widget.animation.loop) {
      _controller.repeat();
    } else {
      _controller.forward(from: 0);
    }
  }

  void _tick() {
    final count = widget.animation.rects.length;
    final next = (_controller.value * count).floor().clamp(0, count - 1);
    if (next != _frame) setState(() => _frame = next);

    if (!widget.animation.loop &&
        !_reported &&
        _controller.status == AnimationStatus.completed) {
      _reported = true;
      widget.onFinished?.call();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The atlas image is shared, so isolate repaints to this subtree.
    return RepaintBoundary(
      child: CustomPaint(
        painter: PetSpritePainter(
          atlas: widget.atlas,
          animation: widget.animation,
          frame: _frame,
          mirrored: widget.mirrored,
        ),
        size: Size.infinite,
      ),
    );
  }
}
