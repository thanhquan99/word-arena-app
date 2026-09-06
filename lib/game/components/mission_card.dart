import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../content/models.dart';

/// One mission slot on the map.
///
/// Purely presentational: it renders a [Mission] and reports taps. All the
/// rules live in the bloc, so this stays easy to reason about.
class MissionCard extends PositionComponent with TapCallbacks {
  MissionCard({
    required this.mission,
    required this.onTapped,
    required super.position,
    required super.size,
  });

  Mission mission;
  final VoidCallback onTapped;

  bool _enabled = true;

  /// Greys the card out while the player is stunned or busy elsewhere.
  set enabled(bool value) {
    if (_enabled != value) {
      _enabled = value;
      _refresh();
    }
  }

  late final RectangleComponent _background;
  late final TextComponent _prompt;
  late final TextComponent _objectiveCount;

  static const _tierColors = <int, Color>{
    1: Color(0xFF64B5F6),
    2: Color(0xFF4CAF50),
    3: Color(0xFFFFA726),
    4: Color(0xFFEF5350),
  };

  Color get _tierColor => _tierColors[mission.tier] ?? _tierColors[2]!;

  @override
  Future<void> onLoad() async {
    _background = RectangleComponent(
      size: size,
      paint: Paint()..color = _tierColor.withValues(alpha: 0.18),
    );

    final border = RectangleComponent(
      size: size,
      paint: Paint()
        ..color = _tierColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    _prompt = TextComponent(
      text: mission.prompt,
      anchor: Anchor.center,
      position: size / 2,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );

    // The number of objectives is the damage this mission is worth, so it sits
    // in the corner where the player can weigh it before tapping.
    _objectiveCount = TextComponent(
      text: '${mission.objectiveCount}',
      anchor: Anchor.topRight,
      position: Vector2(size.x - 8, 6),
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _tierColor,
        ),
      ),
    );

    addAll([_background, border, _prompt, _objectiveCount]);
  }

  /// Swaps in a new mission without rebuilding the component.
  void update_(Mission next) {
    mission = next;
    _prompt.text = next.prompt;
    _objectiveCount.text = '${next.objectiveCount}';
    _refresh();
  }

  void _refresh() {
    final alpha = _enabled ? 0.18 : 0.06;
    _background.paint = Paint()..color = _tierColor.withValues(alpha: alpha);
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (_enabled) onTapped();
  }
}
