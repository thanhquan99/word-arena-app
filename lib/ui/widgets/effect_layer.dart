import 'dart:math';

import 'package:flutter/material.dart';

/// A burst of particles flying from a mission card toward the opponent.
///
/// Hand-written on a [CustomPainter] rather than pulled from a package or a
/// game engine: this is the same canvas an engine would draw on, and at this
/// scale the loop is a dozen lines.
class EffectLayer extends StatefulWidget {
  const EffectLayer({
    super.key,
    required this.origin,
    required this.target,
    required this.color,
    required this.onComplete,
  });

  /// Where the burst starts, in this widget's coordinates.
  final Offset origin;

  /// Where the particles converge — the opponent's health bar.
  final Offset target;

  final Color color;
  final VoidCallback onComplete;

  /// Hard ceiling. Particles are cheap, but an unbounded count in a long match
  /// is how a smooth game starts dropping frames.
  static const maxParticles = 50;

  @override
  State<EffectLayer> createState() => _EffectLayerState();
}

class _EffectLayerState extends State<EffectLayer>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 700);

  late final AnimationController _controller = AnimationController(
    duration: _duration,
    vsync: this,
  );

  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    final random = Random();
    _particles = [
      for (var i = 0; i < EffectLayer.maxParticles; i++)
        _Particle(
          // A spread of start times turns one flat volley into a stream.
          delay: random.nextDouble() * 0.35,
          // Scatter around the origin so they do not all trace one line.
          scatter: Offset(
            (random.nextDouble() - 0.5) * 70,
            (random.nextDouble() - 0.5) * 70,
          ),
          radius: 1.5 + random.nextDouble() * 2.5,
        ),
    ];

    _controller.forward().whenComplete(() {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // Without this the whole board repaints on every frame of the burst.
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _EffectPainter(
              particles: _particles,
              progress: _controller.value,
              origin: widget.origin,
              target: widget.target,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.delay,
    required this.scatter,
    required this.radius,
  });

  final double delay;
  final Offset scatter;
  final double radius;
}

class _EffectPainter extends CustomPainter {
  const _EffectPainter({
    required this.particles,
    required this.progress,
    required this.origin,
    required this.target,
    required this.color,
  });

  final List<_Particle> particles;
  final double progress;
  final Offset origin;
  final Offset target;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      // Each particle runs its own clock inside the shared animation.
      final local = (progress - particle.delay) / (1 - particle.delay);
      if (local <= 0 || local >= 1) continue;

      final eased = Curves.easeInCubic.transform(local);
      final start = origin + particle.scatter * (1 - eased);
      final position = Offset.lerp(start, target, eased)!;

      // Bright at first, gone by the time it lands.
      paint.color = color.withValues(alpha: (1 - eased).clamp(0.0, 1.0));
      canvas.drawCircle(position, particle.radius * (1 - eased * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_EffectPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.origin != origin ||
      oldDelegate.target != target ||
      oldDelegate.color != color;
}
