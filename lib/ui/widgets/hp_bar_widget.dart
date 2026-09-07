import 'package:flutter/material.dart';

import '../theme/arena_theme.dart';

/// Health fraction below which the mercy rule applies (Game_Rule section 4):
/// objective time limits are extended for a player who is losing badly.
///
/// The bar turns red at exactly this point, so the player can see the rule
/// take effect rather than just feeling the timer change.
const mercyThreshold = 0.3;

/// A vertical health bar for one side of the match.
///
/// Fills from the bottom up, which reads as a tank draining — the horizontal
/// bars this replaced put the two players at opposite edges of the screen and
/// left the middle cramped.
class HpBarWidget extends StatelessWidget {
  const HpBarWidget({
    super.key,
    required this.label,
    required this.hp,
    required this.maxHp,
    required this.baseColor,
  });

  final String label;
  final int hp;
  final int maxHp;

  /// Colour while health is comfortable; the warning colours override it.
  final Color baseColor;

  static const _width = 34.0;

  /// Never below empty or above full, however far the damage overshot.
  double get _fraction => maxHp <= 0 ? 0 : (hp / maxHp).clamp(0.0, 1.0);

  Color get _color {
    if (_fraction < mercyThreshold) return Arena.enemy;
    if (_fraction < 0.5) return Arena.warn;
    return baseColor;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: _width,
            decoration: BoxDecoration(
              color: Arena.surface2,
              borderRadius: BorderRadius.circular(_width / 2),
              border: Arena.border,
            ),
            padding: const EdgeInsets.all(3),
            // The fill is bottom-aligned so it drains downward.
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: _fraction,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  // No glow: Direction A is flat and inked, and a blurred
                  // halo here reads as a different game from the cards.
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(_width / 2),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$hp',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Arena.inkSoft,
          ),
        ),
      ],
    );
  }
}
