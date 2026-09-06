import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

/// A damage number that floats up and fades out.
///
/// Removes itself once the animation finishes — otherwise every hit would
/// leave a component behind and a long match would slowly lose frames.
class DamageText extends TextComponent {
  DamageText({required int amount, required Vector2 position})
      : super(
          text: '-$amount',
          position: position,
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFFEF5350),
            ),
          ),
        );

  static const _duration = 0.8;

  @override
  Future<void> onLoad() async {
    add(
      MoveEffect.by(
        Vector2(0, -60),
        EffectController(duration: _duration, curve: Curves.easeOut),
      ),
    );
    add(
      OpacityEffect.fadeOut(
        EffectController(duration: _duration),
        onComplete: removeFromParent,
      ),
    );
  }
}
