import 'package:flutter/material.dart';

import '../../content/models.dart';
import '../../game/bloc/game_state.dart';
import 'damage_number.dart';
import 'effect_layer.dart';
import 'hp_bar_widget.dart';
import 'mission_card_widget.dart';

/// The match board: health on both flanks, missions in the middle.
///
/// Replaces the Flame `ArenaGame`. A game engine buys throughput this game does
/// not need — at roughly 60 entities the widget tree is far inside its budget,
/// and it brings rounded corners, gradients, text wrapping and hit testing for
/// free. See spec-driven-development/feature-04/plan.md.
class BoardWidget extends StatefulWidget {
  const BoardWidget({
    super.key,
    required this.state,
    required this.onMissionTapped,
  });

  final GameState state;
  final void Function(int slotIndex) onMissionTapped;

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> {
  /// The damage value currently being animated, so that a rebuild for some
  /// other reason does not re-trigger the number.
  double? _shownDamage;
  int? _floatingDamage;

  /// Restarts the particle burst; null while nothing is flying.
  int? _burstId;
  int _nextBurstId = 0;

  @override
  void didUpdateWidget(BoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDamage();
  }

  @override
  void initState() {
    super.initState();
    _syncDamage();
  }

  void _syncDamage() {
    final damage = widget.state.lastDamage;
    if (damage == null || damage <= 0 || damage == _shownDamage) return;
    _shownDamage = damage;
    // initState runs during build, so defer the setState that shows the number.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _floatingDamage = damage.round();
        _burstId = _nextBurstId++;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final interactive = state.phase == GamePhase.idle && !state.isStunned;

    return Container(
      color: const Color(0xFF1A1A2E),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HpBarWidget(
                    label: 'Bạn',
                    hp: state.playerHp,
                    maxHp: GameState.maxHp,
                    baseColor: const Color(0xFF4CAF50),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _MissionGrid(
                        missions: state.missions,
                        enabled: interactive,
                        onTap: widget.onMissionTapped,
                      ),
                    ),
                  ),
                  HpBarWidget(
                    label: 'Đối thủ',
                    hp: state.botHp,
                    maxHp: GameState.maxHp,
                    baseColor: const Color(0xFFEF5350),
                  ),
                ],
              ),
              if (_burstId != null)
                LayoutBuilder(
                  builder: (context, constraints) => EffectLayer(
                    key: ValueKey(_burstId),
                    // From the middle of the board out to the opponent's bar.
                    origin: Offset(
                      constraints.maxWidth / 2,
                      constraints.maxHeight / 2,
                    ),
                    target: Offset(
                      constraints.maxWidth,
                      constraints.maxHeight / 2,
                    ),
                    color: const Color(0xFFEF5350),
                    onComplete: () {
                      if (mounted) setState(() => _burstId = null);
                    },
                  ),
                ),
              if (_floatingDamage != null)
                DamageNumber(
                  // A new key restarts the animation for each distinct hit.
                  key: ValueKey(_shownDamage),
                  amount: _floatingDamage!,
                  onComplete: () {
                    if (mounted) setState(() => _floatingDamage = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Five slots in a 2-2-1 grid, which keeps every card thumb-reachable.
///
/// Hand-built rather than a GridView: the last row holds a single centred card,
/// which an evenly divided grid cannot express.
class _MissionGrid extends StatelessWidget {
  const _MissionGrid({
    required this.missions,
    required this.enabled,
    required this.onTap,
  });

  final List<Mission> missions;
  final bool enabled;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    Widget card(int index) => MissionCardWidget(
          mission: missions[index],
          enabled: enabled,
          onTap: () => onTap(index),
        );

    Widget row(List<int> indices) => Expanded(
          child: Row(
            children: [
              for (var i = 0; i < indices.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: card(indices[i])),
              ],
            ],
          ),
        );

    return Column(
      children: [
        row([0, 1]),
        const SizedBox(height: 10),
        row([2, 3]),
        const SizedBox(height: 10),
        // The heavy mission sits alone, half width, centred.
        Expanded(
          child: Row(
            children: [
              const Spacer(),
              Expanded(flex: 2, child: card(4)),
              const Spacer(),
            ],
          ),
        ),
      ],
    );
  }
}
