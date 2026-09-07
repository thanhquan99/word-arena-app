import 'package:flutter/material.dart';

import '../../content/models.dart';
import '../../game/logic/effects.dart';
import '../mission_visuals.dart';
import '../theme/arena_theme.dart';

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
          borderRadius: BorderRadius.circular(Arena.radius),
          splashColor: color.withValues(alpha: 0.22),
          child: Ink(
            // Flat white with a thick ink outline and a hard shadow, per the
            // Playground spec. The tier colour appears as the left stripe and
            // on the icon rather than tinting the whole card, so the English
            // prompt keeps maximum contrast.
            decoration: BoxDecoration(
              color: Arena.surface,
              borderRadius: BorderRadius.circular(Arena.radius),
              border: Arena.border,
              boxShadow: Arena.lift,
            ),
            // The tier stripe is a clipped child, not a coloured left border:
            // Flutter rejects borderRadius on a border whose sides differ in
            // colour, and inside the clip the stripe follows the corner curve.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Arena.radius - Arena.borderW),
              child: Row(
                children: [
                  Container(width: 6, color: color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                missionIcon(mission.type),
                                size: 20,
                                color: color,
                              ),
                              _SwordRow(
                                count: mission.objectiveCount,
                                color: color,
                              ),
                            ],
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                mission.prompt,
                                textAlign: TextAlign.center,
                                // Long prompts are cut rather than shrunk: the
                                // full text is shown on the resolve screen
                                // once the card is tapped.
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Arena.ink,
                                ),
                              ),
                            ),
                          ),
                          // Takes no space at all on a plain mission.
                          if (mission.effect != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: EffectBadge(effect: mission.effect!),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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

/// The effect marker on a mission card.
///
/// Shown before the card is tapped (Game_Rule section 8): taking a risky
/// mission is meant to be a decision, not a surprise. The tooltip carries the
/// rule, because thirteen unexplained icons are thirteen riddles.
class EffectBadge extends StatelessWidget {
  const EffectBadge({super.key, required this.effect});

  final MissionEffect effect;

  static const _kindColors = <EffectKind, Color>{
    EffectKind.good: Color(0xFF4CAF50),
    EffectKind.risky: Color(0xFFEF5350),
    EffectKind.special: Color(0xFF64B5F6),
  };

  @override
  Widget build(BuildContext context) {
    final info = effectInfo(effect);
    final color = _kindColors[info.kind]!;

    return Tooltip(
      message: '${info.label} — ${info.description}',
      triggerMode: TooltipTriggerMode.longPress,
      showDuration: const Duration(seconds: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(info.icon, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 3),
            Text(
              info.label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
