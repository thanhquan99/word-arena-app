import 'package:equatable/equatable.dart';

import '../../net/protocol.dart';

sealed class GameEvent extends Equatable {
  const GameEvent();

  @override
  List<Object?> get props => [];
}

// ------------------------------------------------------------ player intent

/// Connect and ask for a seat.
class MatchJoined extends GameEvent {
  const MatchJoined({this.mode = MatchMode.bot, this.level = 'B1'});

  final MatchMode mode;
  final String level;

  @override
  List<Object?> get props => [mode, level];
}

/// The player tapped a card on the board (§3.2).
class CardTapped extends GameEvent {
  const CardTapped(this.slotIndex);
  final int slotIndex;

  @override
  List<Object?> get props => [slotIndex];
}

/// The player picked ⚔️ or 🛡️ (§3.3).
class StanceChosen extends GameEvent {
  const StanceChosen(this.stance);
  final Stance stance;

  @override
  List<Object?> get props => [stance];
}

/// The player answered one objective. They pick the order (§3.4), so which
/// objective it was has to travel with the answer.
class ObjectiveAnswered extends GameEvent {
  const ObjectiveAnswered({required this.objectiveId, required this.transcript});

  final String objectiveId;
  final String transcript;

  @override
  List<Object?> get props => [objectiveId, transcript];
}

/// The player pressed Done, locking in `completedTime` early (§7.2).
class TurnFinished extends GameEvent {
  const TurnFinished();
}

// ------------------------------------------------------- from the server

/// A frame arrived. The bloc translates it into state; it decides nothing.
class ServerEventReceived extends GameEvent {
  const ServerEventReceived(this.event);
  final ServerEvent event;

  @override
  List<Object?> get props => [event];
}

/// The socket dropped and is retrying, or has given up (§11).
class ConnectionChanged extends GameEvent {
  const ConnectionChanged(this.lost);
  final bool lost;

  @override
  List<Object?> get props => [lost];
}
