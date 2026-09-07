import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../net/match_socket.dart';
import '../../net/protocol.dart';
import 'game_event.dart';
import 'game_state.dart';

/// Translates between the match socket and the UI.
///
/// That is the whole job. Since feature-05 every rule lives on the server —
/// there is no damage formula here, no board pool, no timer that decides
/// anything. The bloc turns [ServerEvent]s into [GameState] and player taps
/// into [ClientMessage]s, and nothing else.
///
/// The card clock is a case in point: the server owns it, and the countdown
/// the player sees is computed from a deadline the server set. If this class
/// and the server ever disagree, the server is right.
class GameBloc extends Bloc<GameEvent, GameState> {
  GameBloc({required MatchSocket socket})
      : _socket = socket,
        super(const GameState()) {
    on<MatchJoined>(_onJoined);
    on<CardTapped>(_onCardTapped);
    on<StanceChosen>(_onStanceChosen);
    on<ObjectiveAnswered>(_onObjectiveAnswered);
    on<TurnFinished>(_onTurnFinished);
    on<ServerEventReceived>(_onServerEvent);
    on<ConnectionChanged>(_onConnectionChanged);

    _subscription = _socket.events.listen(
      (event) => add(ServerEventReceived(event)),
      onDone: () => add(const ConnectionChanged(true)),
    );
  }

  final MatchSocket _socket;
  late final StreamSubscription<ServerEvent> _subscription;

  // -------------------------------------------------------------- player intent

  Future<void> _onJoined(MatchJoined event, Emitter<GameState> emit) async {
    emit(state.copyWith(connection: MatchLink.connecting, isBot: event.mode == MatchMode.bot));
    await _socket.join(event.mode, level: event.level);
  }

  void _onCardTapped(CardTapped event, Emitter<GameState> emit) {
    if (!state.canTap) return;
    // No optimistic phase change: the server runs a 250ms race window (§3.2)
    // and may well open a different card than the one just tapped.
    _socket.tapCard(event.slotIndex);
  }

  void _onStanceChosen(StanceChosen event, Emitter<GameState> emit) {
    if (state.phase != GamePhase.stance) return;
    if (event.stance == Stance.defense && !state.defenseAllowed) return;

    _socket.setStance(event.stance);
    emit(state.copyWith(yourStance: event.stance));
  }

  void _onObjectiveAnswered(ObjectiveAnswered event, Emitter<GameState> emit) {
    if (state.phase != GamePhase.resolving || state.youAreDone) return;
    _socket.answer(event.objectiveId, event.transcript);
  }

  void _onTurnFinished(TurnFinished event, Emitter<GameState> emit) {
    if (state.phase != GamePhase.resolving || state.youAreDone) return;

    _socket.done();
    emit(state.copyWith(youAreDone: true));
  }

  // ------------------------------------------------------------ from the server

  void _onServerEvent(ServerEventReceived wrapper, Emitter<GameState> emit) {
    switch (wrapper.event) {
      case MatchedEvent(:final isBot):
        emit(state.copyWith(connection: MatchLink.ready, isBot: isBot));

      case BoardEvent(:final slots, :final phase):
        emit(state.copyWith(
          slots: slots,
          phase: _phaseFrom(phase),
          connection: MatchLink.ready,
          // A board frame means the previous turn is over and the card is gone.
          clearCard: phase == 'idle',
        ));

      case CardOpenedEvent(
          :final slotIndex,
          :final mission,
          :final defenseAllowed,
          :final stanceDeadline,
        ):
        emit(state.copyWith(
          phase: GamePhase.stance,
          openedSlotIndex: slotIndex,
          openedMission: mission,
          objectives: mission.objectives,
          defenseAllowed: defenseAllowed,
          stanceDeadline: stanceDeadline,
          clearLastTurn: true,
        ));

      case StanceLockedEvent(:final you, :final opponent):
        emit(state.copyWith(yourStance: you, opponentStance: opponent));

      case ResolveStartEvent(:final objectives, :final cardSeconds, :final startedAt):
        emit(state.copyWith(
          phase: GamePhase.resolving,
          objectives: objectives,
          cardSeconds: cardSeconds,
          cardStartedAt: startedAt,
          youAreDone: false,
        ));

      case ObjectiveResultEvent(:final objectiveId, :final passed, :final mine):
        emit(_withGrade(objectiveId, passed: passed, mine: mine));

      case TurnSettledEvent turn:
        emit(state.copyWith(phase: GamePhase.scoring, lastTurn: turn));

      case TurnPhaseEvent(:final stage, :final until):
        emit(state.copyWith(turnStage: stage, stageDeadline: until));

      case OpponentProgressEvent(:final completed, :final total, :final done):
        emit(state.copyWith(
          opponentProgress: completed,
          opponentTotal: total,
          opponentIsDone: done,
        ));

      case HpEvent(:final you, :final opponent):
        emit(state.copyWith(yourHp: you, opponentHp: opponent));

      case StatusEvent(:final you, :final opponent):
        emit(state.copyWith(yourStatus: you, opponentStatus: opponent));

      case EndedEvent(:final winner):
        emit(state.copyWith(phase: GamePhase.ended, winner: winner));

      case ErrorEvent error:
        emit(_withError(error));
    }
  }

  GameState _withGrade(String objectiveId, {required bool passed, required bool mine}) {
    if (!mine) {
      final completed = {...state.opponentCompleted};
      passed ? completed.add(objectiveId) : completed.remove(objectiveId);
      return state.copyWith(opponentCompleted: completed);
    }

    final completed = {...state.yourCompleted};
    final failed = {...state.yourFailed};

    if (passed) {
      completed.add(objectiveId);
      failed.remove(objectiveId);
    } else {
      completed.remove(objectiveId);
      // Kept so the card can show ✖️ — the objective is still retryable while
      // the clock runs (§3.4).
      failed.add(objectiveId);
    }

    return state.copyWith(yourCompleted: completed, yourFailed: failed);
  }

  GameState _withError(ErrorEvent error) {
    if (error.isWaiting) {
      return state.copyWith(connection: MatchLink.waitingForOpponent);
    }
    if (error.error == 'reconnect_failed') {
      return state.copyWith(connection: MatchLink.lost);
    }
    return state;
  }

  void _onConnectionChanged(ConnectionChanged event, Emitter<GameState> emit) {
    if (!event.lost) return;
    if (state.phase == GamePhase.ended) return;

    emit(state.copyWith(
      connection: _socket.isReconnecting ? MatchLink.connecting : MatchLink.lost,
    ));
  }

  GamePhase _phaseFrom(String raw) => switch (raw) {
        'race' => GamePhase.race,
        'stance' => GamePhase.stance,
        'resolving' => GamePhase.resolving,
        'scoring' => GamePhase.scoring,
        'ended' => GamePhase.ended,
        _ => GamePhase.idle,
      };

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _socket.close();
    return super.close();
  }
}
