import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A health bar for one side of the match.
class HpBar extends PositionComponent {
  HpBar({
    required this.label,
    required this.maxHp,
    required this.color,
    required super.position,
    required super.size,
  });

  final String label;
  final int maxHp;
  final Color color;

  int _hp = 0;

  late final RectangleComponent _fill;
  late final TextComponent _text;

  @override
  Future<void> onLoad() async {
    _hp = maxHp;

    final track = RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.white24,
    );

    _fill = RectangleComponent(
      size: Vector2(size.x, size.y),
      paint: Paint()..color = color,
    );

    _text = TextComponent(
      text: '$label  $maxHp',
      anchor: Anchor.centerLeft,
      position: Vector2(6, size.y / 2),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );

    addAll([track, _fill, _text]);
  }

  /// Health never renders below zero, however far the damage overshot.
  set hp(int value) {
    final clamped = value.clamp(0, maxHp);
    if (clamped == _hp) return;
    _hp = clamped;
    _fill.size = Vector2(size.x * (_hp / maxHp), size.y);
    _text.text = '$label  $_hp';
  }

  int get hp => _hp;
}
