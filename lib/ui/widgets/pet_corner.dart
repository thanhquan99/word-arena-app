import 'package:flutter/material.dart';

import '../../game/bloc/game_state.dart';
import '../../pet/pet_spec.dart';
import '../../pet/pet_view.dart';

/// One fighter's pet, perched beside their health bar.
///
/// Derives the pose from [GameState] rather than taking commands, so the pet
/// can never drift out of sync with the match: whatever the bloc says is true
/// is what the pet shows.
class PetCorner extends StatefulWidget {
  const PetCorner({
    super.key,
    required this.spec,
    required this.state,
    required this.isPlayer,
    this.size = 56,
  });

  final PetSpec spec;
  final GameState state;

  /// True for the local player's pet, false for the opponent's. Decides which
  /// side's damage counts as "I was hit" and which way the pet faces.
  final bool isPlayer;

  final double size;

  @override
  State<PetCorner> createState() => _PetCornerState();
}

class _PetCornerState extends State<PetCorner> {
  /// Overrides the derived pose for the length of one hit reaction.
  PetPose? _reaction;

  /// The damage value already reacted to, so a rebuild for any other reason
  /// does not replay the animation.
  double? _reactedTo;

  /// Health last seen, to tell who the incoming damage landed on. GameState
  /// reports the amount but not the target.
  int? _lastSelfHp;
  int? _lastEnemyHp;

  @override
  void initState() {
    super.initState();
    _lastSelfHp = widget.state.yourHp;
    _lastEnemyHp = widget.state.opponentHp;
  }

  @override
  void didUpdateWidget(PetCorner old) {
    super.didUpdateWidget(old);
    _syncReaction();
  }

  void _syncReaction() {
    final s = widget.state;
    final damage = s.lastTurn?.you.damageDealt;

    // Track health so a later hit can be attributed even if the damage figure
    // repeats the same number.
    final selfDropped = _lastSelfHp != null && s.yourHp < _lastSelfHp!;
    final enemyDropped = _lastEnemyHp != null && s.opponentHp < _lastEnemyHp!;
    _lastSelfHp = s.yourHp;
    _lastEnemyHp = s.opponentHp;

    if (damage == null || damage <= 0) {
      _reactedTo = null;
      return;
    }
    if (damage == _reactedTo && !selfDropped && !enemyDropped) return;
    _reactedTo = damage;

    // The player's pet casts when the opponent loses health, and takes the hit
    // when the player does. The opponent's pet is the mirror of that.
    final hitMe = widget.isPlayer ? selfDropped : enemyDropped;
    final hitThem = widget.isPlayer ? enemyDropped : selfDropped;
    final PetPose? pose = hitMe
        ? PetPose.hurt
        : hitThem
            ? PetPose.cast
            : null;
    if (pose == null) return;

    setState(() => _reaction = pose);
  }

  /// The resting pose. Airborne means "this side is on the move", which is
  /// the one piece of state the pose carries beyond decoration.
  PetPose get _restingPose {
    final s = widget.state;

    // Stunned reads as grounded, whichever side it is.
    final stunned = s.stunSecondsLeft(DateTime.now().millisecondsSinceEpoch) > 0;
    if (widget.isPlayer && stunned) return PetPose.perch;

    // The player is committed to a mission during resolving, so their pet
    // flies; the opponent's waits. Outside that both are at rest.
    if (s.phase == GamePhase.resolving) {
      return widget.isPlayer ? PetPose.fly : PetPose.perch;
    }
    return PetPose.perch;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final dead = widget.isPlayer ? s.yourHp <= 0 : s.opponentHp <= 0;

    return Opacity(
      // A defeated pet dims rather than vanishing: an empty slot reads as a
      // layout bug, a faded pet reads as defeat.
      opacity: dead ? 0.35 : 1,
      child: PetView(
        spec: widget.spec,
        pose: _reaction ?? _restingPose,
        size: widget.size,
        mirrored: !widget.isPlayer,
        onPoseFinished: () {
          if (mounted) setState(() => _reaction = null);
        },
      ),
    );
  }
}
