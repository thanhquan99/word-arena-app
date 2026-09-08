import 'package:flutter/material.dart';

import '../../content/models.dart';
import '../../game/bloc/game_state.dart';
import '../../net/protocol.dart';
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
  _Burst? _burst;

  /// Where each fighter actually is on screen, so a strike can travel between
  /// them instead of from a guessed midpoint.
  final _playerPetKey = GlobalKey();
  final _opponentPetKey = GlobalKey();

  @override
  void didUpdateWidget(BoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncStrike();
  }

  @override
  void initState() {
    super.initState();
    _syncStrike();
  }

  /// Fires the strike animation at the `strike` beat.
  ///
  /// It used to fire the moment `lastTurn` arrived — which was also the moment
  /// the board refilled, so the burst raced a new set of cards. The server now
  /// holds a beat open for exactly this (feature-06).
  void _syncStrike() {
    final state = widget.state;
    if (state.turnStage != TurnStage.strike) return;

    final turn = state.lastTurn;
    if (turn == null) return;

    // Whoever dealt damage strikes. An empty turn animates nothing.
    final youDealt = turn.you.damageDealt;
    final theyDealt = turn.opponent.damageDealt;
    final damage = youDealt > 0 ? youDealt : theyDealt;
    if (damage <= 0 || damage == _shownDamage) return;

    _shownDamage = damage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final burst = _resolveBurst(attackerIsYou: youDealt > 0);
      if (burst == null) return;

      setState(() {
        _burst = burst;
        _floatingDamage = damage.round();
        _burstId = _nextBurstId++;
      });
    });
  }

  /// Resolves the two pets' real positions into a travel path.
  _Burst? _resolveBurst({required bool attackerIsYou}) {
    final fromKey = attackerIsYou ? _playerPetKey : _opponentPetKey;
    final toKey = attackerIsYou ? _opponentPetKey : _playerPetKey;

    final from = _centreOf(fromKey);
    final to = _centreOf(toKey);
    if (from == null || to == null) return null;

    return _Burst(
      from: from,
      to: to,
      // `PetSpec.primary` is documented as covering projectiles and the impact
      // burst — the intent was there from feature-04, just never wired up.
      color: (attackerIsYou ? widget.playerPet : widget.opponentPet).primary,
    );
  }

  Offset? _centreOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final arena = _arenaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || arena == null || !box.hasSize) return null;

    final topLeft = box.localToGlobal(Offset.zero, ancestor: arena);
    return topLeft + Offset(box.size.width / 2, box.size.height / 2);
  }

  final _arenaKey = GlobalKey();

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
          child: Column(
            children: [
              // The arena sits on top, sized to its content: two fighters side
              // by side, each with their pet above their bar. Feature-04 put
              // them in narrow side columns, which left no room for a strike
              // to travel across.
              _Arena(
                key: _arenaKey,
                state: state,
                playerPet: widget.playerPet,
                opponentPet: widget.opponentPet,
                playerKey: _playerPetKey,
                opponentKey: _opponentPetKey,
                burstId: _burstId,
                burst: _burst,
                onBurstDone: () {
                  if (mounted) setState(() => _burstId = null);
                },
                floatingDamage: _floatingDamage,
                damageKey: _shownDamage,
                onDamageDone: () {
                if (mounted) setState(() => _floatingDamage = null);
                },
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _MissionGrid(
                  missions: state.slots,
                  enabled: interactive,
                  onTap: widget.onMissionTapped,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two fighters, side by side.
///
/// Each side is one column — pet portrait and name on top, health bar under
/// it, carried effects under that. Putting them level rather than stacking
/// one above the other lets a strike travel straight across, and keeps both
/// health bars readable in one glance.
class _Arena extends StatelessWidget {
  const _Arena({
    super.key,
    required this.state,
    required this.playerPet,
    required this.opponentPet,
    required this.playerKey,
    required this.opponentKey,
    required this.burstId,
    required this.burst,
    required this.onBurstDone,
    required this.floatingDamage,
    required this.damageKey,
    required this.onDamageDone,
  });

  final GameState state;
  final PetSpec playerPet;
  final PetSpec opponentPet;
  final GlobalKey playerKey;
  final GlobalKey opponentKey;

  final int? burstId;
  final _Burst? burst;
  final VoidCallback onBurstDone;

  final int? floatingDamage;
  final double? damageKey;
  final VoidCallback onDamageDone;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Fighter(
                petKey: playerKey,
                spec: playerPet,
                state: state,
                isPlayer: true,
                label: 'Bạn',
                hp: state.yourHp,
                barColour: Arena.self,
                status: state.yourStatus,
                statusLabel: 'của bạn',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Fighter(
                petKey: opponentKey,
                spec: opponentPet,
                state: state,
                isPlayer: false,
                label: state.isBot ? 'Bot' : 'Đối thủ',
                hp: state.opponentHp,
                barColour: Arena.enemy,
                status: state.opponentStatus,
                statusLabel: 'đối thủ',
                // Mirrored so the two pets face one another across the gap.
                facingLeft: true,
              ),
            ),
          ],
        ),

        if (burstId != null && burst != null)
          Positioned.fill(
            child: EffectLayer(
              key: ValueKey(burstId),
              origin: burst!.from,
              target: burst!.to,
              color: burst!.color,
              onComplete: onBurstDone,
            ),
          ),

        if (floatingDamage != null && burst != null)
          Positioned(
            left: burst!.to.dx - 30,
            top: burst!.to.dy - 40,
            child: DamageNumber(
              // A new key restarts the animation for each distinct hit.
              key: ValueKey(damageKey),
              amount: floatingDamage!,
              onComplete: onDamageDone,
            ),
          ),
      ],
    );
  }
}

/// One side: portrait and name, then the health bar, then carried effects.
class _Fighter extends StatelessWidget {
  const _Fighter({
    required this.petKey,
    required this.spec,
    required this.state,
    required this.isPlayer,
    required this.label,
    required this.hp,
    required this.barColour,
    required this.status,
    required this.statusLabel,
    this.facingLeft = false,
  });

  final GlobalKey petKey;
  final PetSpec spec;
  final GameState state;
  final bool isPlayer;

  /// Who this is — "Bạn", or the opponent's name.
  final String label;
  final int hp;
  final Color barColour;
  final PlayerStatus status;
  final String statusLabel;

  /// Flips the portrait so the two pets look at each other.
  final bool facingLeft;

  @override
  Widget build(BuildContext context) {
    final pet = _PetSlot(
      key: petKey,
      child: facingLeft
          ? Transform.flip(
              flipX: true,
              child: PetCorner(spec: spec, state: state, isPlayer: isPlayer),
            )
          : PetCorner(spec: spec, state: state, isPlayer: isPlayer),
    );

    final nameplate = Column(
      crossAxisAlignment:
          facingLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Arena.ink,
          ),
        ),
        Text(
          spec.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: spec.primary,
          ),
        ),
        Text(
          '$hp / ${GameState.maxHp}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Arena.inkSoft,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment:
              facingLeft ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: facingLeft
              ? [Flexible(child: nameplate), const SizedBox(width: 8), pet]
              : [pet, const SizedBox(width: 8), Flexible(child: nameplate)],
        ),
        const SizedBox(height: 6),
        HpBarWidget(
          label: '',
          hp: hp,
          maxHp: GameState.maxHp,
          baseColor: barColour,
          axis: HpBarAxis.horizontal,
        ),
        const SizedBox(height: 5),
        StatusBar(status: status, label: statusLabel),
      ],
    );
  }
}

/// A fixed box for one pet, carrying a key so a strike can find where it is.
class _PetSlot extends StatelessWidget {
  const _PetSlot({super.key, required this.child});

  final Widget child;

  static const _size = 84.0;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: _size, child: child);
}

/// Where a strike travels and in what colour, resolved from real screen
/// positions rather than guessed from the board's midpoint.
class _Burst {
  const _Burst({required this.from, required this.to, required this.color});

  final Offset from;
  final Offset to;
  final Color color;
}

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
