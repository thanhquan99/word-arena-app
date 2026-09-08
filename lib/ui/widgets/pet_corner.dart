import 'package:flutter/material.dart';

import '../../game/bloc/game_state.dart';
import '../../net/protocol.dart';
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
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(PetCorner old) {
    super.didUpdateWidget(old);
    _syncReaction();
  }

  /// Fires cast or hurt at the `strike` beat.
  ///
  /// This used to key off `lastTurn` arriving and infer direction by watching
  /// which health bar dropped — necessary when scoring was instantaneous and
  /// the turn result was all there was to go on. The server now holds a beat
  /// open for the animation, and the result says outright who dealt what.
  void _syncReaction() {
    final s = widget.state;

    if (s.turnStage != TurnStage.strike) {
      if (s.turnStage == null) _reactedTo = null;
      return;
    }

    final turn = s.lastTurn;
    if (turn == null) return;

    final youDealt = turn.you.damageDealt;
    final theyDealt = turn.opponent.damageDealt;
    if (youDealt <= 0 && theyDealt <= 0) return; // an empty turn strikes nobody

    final marker = youDealt + theyDealt;
    if (marker == _reactedTo) return;
    _reactedTo = marker;

    // 🎯 All-out has both sides dealing damage, so both pets cast.
    final iDealt = widget.isPlayer ? youDealt : theyDealt;
    final theyDealtAtMe = widget.isPlayer ? theyDealt : youDealt;

    final PetPose pose =
        iDealt > 0 ? PetPose.cast : (theyDealtAtMe > 0 ? PetPose.hurt : PetPose.perch);
    if (pose == PetPose.perch) return;

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
