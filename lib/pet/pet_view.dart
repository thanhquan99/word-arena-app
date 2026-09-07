import 'package:flutter/material.dart';

import 'pet_atlas.dart';
import 'pet_painter.dart';
import 'pet_spec.dart';
import 'pet_sprite_painter.dart';

/// A pet on the board.
///
/// Draws from a generated sprite atlas when one ships for the pet, and falls
/// back to [PetPainter] — a complete seven-joint vector rig — when it does
/// not. The fallback is not a placeholder: a pet whose art has not been
/// generated yet still animates, so content and art can land independently.
///
/// See word-arena-docs/docs/technical/09-sprite-sheet-spike.md for why sprite
/// sheets won over Rive here: no runtime dependency, at the cost of ~4 MB of
/// texture memory per atlas.
class PetView extends StatefulWidget {
  const PetView({
    super.key,
    required this.spec,
    this.pose = PetPose.perch,
    this.size = 52,
    this.mirrored = false,
    this.onPoseFinished,
  });

  final PetSpec spec;
  final PetPose pose;
  final double size;

  /// The opponent's pet faces the other way, so the two face each other.
  final bool mirrored;

  /// Fires when a one-shot pose ([PetPose.cast], [PetPose.hurt]) has played
  /// out, so the caller can return the pet to its resting pose.
  final VoidCallback? onPoseFinished;

  /// How long a one-shot pose runs when drawn by the vector fallback.
  static const oneShotDuration = Duration(milliseconds: 580);

  @override
  State<PetView> createState() => _PetViewState();
}

class _PetViewState extends State<PetView> with TickerProviderStateMixin {
  /// Clocks for the vector fallback, created only if the fallback is actually
  /// used. A sprite-backed pet needs no tickers at all, and leaving them
  /// running would both waste frames and outlive the element tree.
  AnimationController? _idle;
  AnimationController? _shot;

  PetAtlas? _atlas;

  @override
  void initState() {
    super.initState();
    // If this pet's sheet is already decoded, take it now so the first frame
    // draws the sprite rather than one frame of the vector fallback.
    final id = widget.spec.atlasId;
    if (id != null) _atlas = PetAtlas.ready(id);
    if (_atlas == null) {
      _ensureFallbackClocks();
      _loadAtlas();
    }
    if (_isOneShot(widget.pose)) _shot?.forward(from: 0);
  }

  /// Spins up the fallback clocks on first use.
  void _ensureFallbackClocks() {
    _idle ??= AnimationController(
      duration: const Duration(milliseconds: (PetPainter.cycle * 1000) ~/ 1),
      vsync: this,
    )..repeat();
    _shot ??= AnimationController(
      duration: PetView.oneShotDuration,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(PetView old) {
    super.didUpdateWidget(old);
    if (widget.spec.atlasId != old.spec.atlasId) {
      final id = widget.spec.atlasId;
      _atlas = id == null ? null : PetAtlas.ready(id);
      if (_atlas == null) {
        _ensureFallbackClocks();
        _loadAtlas();
      }
    }
    if (widget.pose != old.pose && _isOneShot(widget.pose)) {
      _shot?.forward(from: 0);
    }
  }

  static bool _isOneShot(PetPose p) => p == PetPose.cast || p == PetPose.hurt;

  Future<void> _loadAtlas() async {
    final atlasId = widget.spec.atlasId;
    if (atlasId == null) return;  // no art generated yet — use the vector rig
    try {
      final atlas = await PetAtlas.load(atlasId);
      // The pet may have changed while the bundle read was in flight.
      if (mounted && widget.spec.atlasId == atlasId) {
        setState(() => _atlas = atlas);
      }
    } catch (e) {
      // Expected while a pet's art is still being generated. Logged rather
      // than thrown: a missing sprite must never take the match down.
      debugPrint('PetView: no atlas "$atlasId", using vector rig ($e)');
    }
  }

  @override
  void dispose() {
    _idle?.dispose();
    _shot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atlas = _atlas;
    final animation = atlas?.forPose(widget.pose);

    final Widget child;
    if (atlas != null && animation != null) {
      child = PetSpritePlayer(
        // A new key restarts playback when the pose changes, so a repeated
        // hit replays the animation instead of being swallowed.
        key: ValueKey('${widget.spec.atlasId}-${animation.name}-${widget.pose}'),
        atlas: atlas,
        animation: animation,
        mirrored: widget.mirrored,
        onFinished: _isOneShot(widget.pose) ? widget.onPoseFinished : null,
      );
    } else {
      _ensureFallbackClocks();
      final idle = _idle!;
      final shot = _shot!;
      child = AnimatedBuilder(
        // Both clocks: the loop always runs, the one-shot overlays it.
        animation: Listenable.merge([idle, shot]),
        builder: (context, _) => CustomPaint(
          painter: PetPainter(
            spec: widget.spec,
            pose: widget.pose,
            t: idle.value,
            oneShot: _isOneShot(widget.pose) ? shot.value : 0,
          ),
        ),
      );
      // The vector rig faces left by design; mirror it the same way.
      if (widget.mirrored) {
        return RepaintBoundary(
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Transform.flip(flipX: true, child: child),
          ),
        );
      }
    }

    return RepaintBoundary(
      child: SizedBox(width: widget.size, height: widget.size, child: child),
    );
  }
}
