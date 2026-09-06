import 'package:flutter/material.dart';

import '../../content/models.dart';
import '../mission_visuals.dart';

/// One mission slot on the map.
///
/// Purely presentational: it renders a [Mission] and reports taps. All the
/// rules live in the bloc, so this stays easy to reason about.
class MissionCardWidget extends StatelessWidget {
  const MissionCardWidget({
    super.key,
    required this.mission,
    required this.enabled,
    required this.onTap,
  });

  final Mission mission;

  /// False while the player is stunned or busy with another mission.
  final bool enabled;

  final VoidCallback onTap;

  /// A mission is worth at most four objectives (Game_Rule section 5), so the
  /// sword row can never overflow the corner.
  static const _maxSwords = 4;

  @override
  Widget build(BuildContext context) {
    final color = tierColor(mission.tier);

    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withValues(alpha: 0.3),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.28),
                  color.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: 2),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(missionIcon(mission.type), size: 20, color: color),
                    _SwordRow(count: mission.objectiveCount, color: color),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      mission.prompt,
                      textAlign: TextAlign.center,
                      // Long prompts are cut rather than shrunk: the full text
                      // is shown on the resolve screen once the card is tapped.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One sword per objective — the damage this mission can deal.
///
/// A count rather than a number: the player reads "how much is this worth" at a
/// glance while racing, without stopping to parse a digit.
class _SwordRow extends StatelessWidget {
  const _SwordRow({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Material ships no sword glyph, so this is the emoji from the rules doc.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count.clamp(0, MissionCardWidget._maxSwords); i++)
          const Padding(
            padding: EdgeInsets.only(left: 1),
            child: Text('⚔️', style: TextStyle(fontSize: 11)),
          ),
      ],
    );
  }
}
