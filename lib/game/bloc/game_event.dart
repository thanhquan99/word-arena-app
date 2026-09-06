import 'package:equatable/equatable.dart';

import '../../net/grade_result.dart';

sealed class GameEvent extends Equatable {
  const GameEvent();

  @override
  List<Object?> get props => [];
}

/// Load content and deal the first five missions.
class GameStarted extends GameEvent {
  const GameStarted();
}

/// The player picked a mission from the map.
class MissionTapped extends GameEvent {
  const MissionTapped(this.slotIndex);
  final int slotIndex;

  @override
  List<Object?> get props => [slotIndex];
}

/// The player answered the current objective. The grade is requested in the
/// background; play moves on immediately.
class ObjectiveAnswered extends GameEvent {
  const ObjectiveAnswered(this.transcript);
  final String transcript;

  @override
  List<Object?> get props => [transcript];
}

/// The clock ran out on the current objective.
class ObjectiveTimedOut extends GameEvent {
  const ObjectiveTimedOut();
}

/// A grade arrived — possibly long after the player moved past that objective.
class GradeReceived extends GameEvent {
  const GradeReceived({required this.objectiveIndex, required this.result});
  final int objectiveIndex;
  final GradeResult result;

  @override
  List<Object?> get props => [objectiveIndex, result.passed, result.multiplier];
}

/// Five seconds passed with nobody picking a mission: rotate the oldest slot.
class RefillTick extends GameEvent {
  const RefillTick();
}

/// The stun wore off.
class StunExpired extends GameEvent {
  const StunExpired();
}
