import 'package:flutter/material.dart';

import '../../content/models.dart';
import '../../game/bloc/game_state.dart';
import '../../pet/pet_spec.dart';
import '../theme/arena_theme.dart';
import 'damage_number.dart';
import 'effect_layer.dart';
import 'hp_bar_widget.dart';
import 'status_bar.dart';
import 'mission_card_widget.dart';
import 'pet_corner.dart';

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
    this.playerPet = PetSpec.fire,
    this.opponentPet = PetSpec.storm,
  });

  final GameState state;
  final void Function(int slotIndex) onMissionTapped;

  /// Each side's pet. Defaults pair the phoenix against the tiger, which are
  /// the two sheets that ship; a pet with no art falls back to the vector rig
  /// inside [PetView], so any pairing is safe.
  final PetSpec playerPet;
  final PetSpec opponentPet;

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
    // The floating number shows what *we* dealt this turn. A turn we lost deals
    // nothing (§7.2 is winner-takes-all), so nothing floats.
    final damage = widget.state.lastTurn?.you.damageDealt;
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
    // The server refuses taps from a stunned player anyway (§8.2); greying
    // the cards is how the client explains why.
    final stunned = state.stunSecondsLeft(DateTime.now().millisecondsSinceEpoch) > 0;
    final interactive = state.canTap && !stunned;

    return Container(
      // The warm ground of Direction A. The generated pet sprites are drawn
      // with dark outlines for exactly this background — on the dark scheme
      // this replaced, their outlines vanished.
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.55, -0.85),
          radius: 1.2,
          colors: [Color(0xFFFFE9C4), Arena.bg],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Flank(
                    pet: PetCorner(
                      spec: widget.playerPet,
                      state: state,
                      isPlayer: true,
                    ),
                    bar: HpBarWidget(
                      label: 'Bạn',
                      hp: state.yourHp,
                      maxHp: GameState.maxHp,
                      baseColor: Arena.self,
                    ),
                    status: StatusBar(status: state.yourStatus, label: 'của bạn'),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _MissionGrid(
                        missions: state.slots,
                        enabled: interactive,
                        onTap: widget.onMissionTapped,
                      ),
                    ),
                  ),
                  _Flank(
                    pet: PetCorner(
                      spec: widget.opponentPet,
                      state: state,
                      isPlayer: false,
                    ),
                    bar: HpBarWidget(
                      label: 'Đối thủ',
                      hp: state.opponentHp,
                      maxHp: GameState.maxHp,
                      baseColor: Arena.enemy,
                    ),
                    status: StatusBar(status: state.opponentStatus, label: 'đối thủ'),
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
                    color: Arena.enemy,
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

/// A fighter's column: their pet above, their health bar below.
///
/// The pet sits on top rather than alongside because the bars run the full
/// height of the board — putting the pet beside one would eat into the mission
/// grid, which is the part players actually aim at.
class _Flank extends StatelessWidget {
  const _Flank({required this.pet, required this.bar, required this.status});

  final Widget pet;
  final Widget bar;

  /// Carried effects (§8). Empty most turns, so it takes no space by default.
  final Widget status;

  /// Width of the pet column. The health bar is 34px, so this trades 22px of
  /// mission-grid width per side for a sprite that reads as a creature rather
  /// than an icon: the generated art carries stripes, feathers and a face,
  /// none of which survives at bar width.
  static const _width = 56.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: _width, child: pet),
          const SizedBox(height: 4),
          status,
          const SizedBox(height: 4),
          Expanded(child: Center(child: bar)),
        ],
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

    // Four cards on an even 2x2 grid (Game_Rule v2 §2). The old five-card
    // board needed a 2-2-1 shape with one card stranded at half width; four
    // divides cleanly, which is the whole reason the count changed.
    return Column(
      children: [
        row([0, 1]),
        const SizedBox(height: 10),
        row([2, 3]),
      ],
    );
  }
}
