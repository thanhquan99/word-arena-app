import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../content/models.dart';
import '../game/bloc/game_bloc.dart';
import '../game/bloc/game_event.dart';
import '../game/bloc/game_state.dart';
import '../game/logic/effects.dart';
import '../net/protocol.dart';
import 'theme/arena_theme.dart';

/// Picking a stance on the open card (Game_Rule v2 §3.3).
///
/// Both players get this, whoever tapped the card — tapping first only chooses
/// *which* card opens, it grants no advantage in the turn. Three seconds to
/// decide, and saying nothing means ⚔️ Attack.
class StanceOverlay extends StatefulWidget {
  const StanceOverlay({super.key, required this.state});

  final GameState state;

  @override
  State<StanceOverlay> createState() => _StanceOverlayState();
}

class _StanceOverlayState extends State<StanceOverlay> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Display only. The server applies the Attack default whether or not this
    // countdown is on screen.
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int get _secondsLeft {
    final deadline = widget.state.stanceDeadline;
    if (deadline == null) return 0;
    final left = ((deadline - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    return left > 0 ? left : 0;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final mission = state.openedMission;
    if (mission == null) return const SizedBox.shrink();

    final chosen = state.yourStance;
    final effect = mission.effect;

    return Container(
      color: Arena.ink.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Arena.surface,
            borderRadius: BorderRadius.circular(Arena.radius),
            border: Arena.border,
            boxShadow: Arena.lift,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mission.prompt,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              if (effect != null) ...[
                const SizedBox(height: 10),
                _EffectNote(effect: effect),
              ],
              const SizedBox(height: 18),

              Text(
                'Chọn thế trận  ·  $_secondsLeft s',
                style: const TextStyle(fontSize: 14, color: Arena.inkSoft),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _StanceButton(
                      icon: '⚔️',
                      label: 'Tấn công',
                      caption: 'Làm nhiều objective hơn để gây damage',
                      colour: Arena.enemy,
                      selected: chosen == Stance.attack,
                      onPressed: () => context
                          .read<GameBloc>()
                          .add(const StanceChosen(Stance.attack)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StanceButton(
                      icon: '🛡️',
                      label: 'Phòng thủ',
                      caption: state.defenseAllowed
                          // §7.3 is the rule players get wrong most often, so
                          // the button says it rather than only naming itself.
                          ? 'Chặn đúng objective đối thủ cũng làm được'
                          : 'Card 🎯 Khô máu không cho phòng thủ',
                      colour: Arena.accent,
                      selected: chosen == Stance.defense,
                      onPressed: state.defenseAllowed
                          ? () => context
                              .read<GameBloc>()
                              .add(const StanceChosen(Stance.defense))
                          : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Text(
                chosen == null
                    ? 'Không chọn → mặc định tấn công'
                    : 'Đã chọn — chờ đối thủ',
                style: const TextStyle(fontSize: 12, color: Arena.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EffectNote extends StatelessWidget {
  const _EffectNote({required this.effect});

  final MissionEffect effect;

  @override
  Widget build(BuildContext context) {
    final info = effectInfo(effect);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Arena.surface2,
        borderRadius: BorderRadius.circular(Arena.radiusSm),
        border: Arena.borderSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(info.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${info.label} — ${info.description}',
              style: const TextStyle(fontSize: 12, color: Arena.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _StanceButton extends StatelessWidget {
  const _StanceButton({
    required this.icon,
    required this.label,
    required this.caption,
    required this.colour,
    required this.selected,
    required this.onPressed,
  });

  final String icon;
  final String label;
  final String caption;
  final Color colour;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(Arena.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? colour.withValues(alpha: 0.2) : Arena.surface2,
            borderRadius: BorderRadius.circular(Arena.radiusSm),
            border: Border.all(
              color: selected ? colour : Arena.ink,
              width: selected ? Arena.borderW : Arena.borderWSm,
            ),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Arena.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
