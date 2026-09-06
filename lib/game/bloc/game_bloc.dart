import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../content/content_repository.dart';
import '../../net/api_client.dart';
import '../../net/grade_result.dart';
import '../logic/damage.dart';
import '../logic/mission_pool.dart';
import '../logic/stun.dart';
import 'game_event.dart';
import 'game_state.dart';

/// Drives one single-player match:
///
///     idle -> resolving -> scoring -> refill -> idle
///
/// There is no `race` phase: with no opponent, a tap goes straight into the
/// mission.
class GameBloc extends Bloc<GameEvent, GameState> {
  GameBloc({
    required ContentRepository content,
    required ApiClient api,
    Random? random,
    this.playerLevel = 'B1',
  })  : _content = content,
        _api = api,
        _random = random ?? Random(),
        super(const GameState()) {
    on<GameStarted>(_onStarted);
    on<MissionTapped>(_onMissionTapped);
    on<ObjectiveAnswered>(_onObjectiveAnswered);
    on<ObjectiveTimedOut>(_onObjectiveTimedOut);
    on<GradeReceived>(_onGradeReceived);
    on<RefillTick>(_onRefillTick);
    on<StunExpired>(_onStunExpired);
  }

  final ContentRepository _content;
  final ApiClient _api;
  final Random _random;
  final String playerLevel;

  static const idleRotation = Duration(seconds: 5);

  MissionPool? _pool;
  final _stun = StunTracker();

  /// Rotates the oldest slot while nobody is playing. Only ever runs in `idle`.
  Timer? _idleTimer;
  Timer? _stunTimer;

  Future<void> _onStarted(GameStarted event, Emitter<GameState> emit) async {
    final all = await _content.loadAll();
    final pool = MissionPool(all, random: _random);
    _pool = pool;

    emit(GameState(missions: pool.slots));
    _startIdleTimer();
  }

  void _onMissionTapped(MissionTapped event, Emitter<GameState> emit) {
    if (state.phase != GamePhase.idle || state.isStunned) return;

    // The rotation clock belongs to `idle` alone. Leaving it running would let
    // a mission be swapped out from under the player mid-answer.
    _cancelIdleTimer();

    final mission = state.missions[event.slotIndex];
    emit(state.copyWith(
      phase: GamePhase.resolving,
      activeMissionIndex: event.slotIndex,
      objectiveIndex: 0,
      results: List<GradeResult?>.filled(mission.objectives.length, null),
      clearLastDamage: true,
    ));
  }

  void _onObjectiveAnswered(ObjectiveAnswered event, Emitter<GameState> emit) {
    final objective = state.activeObjective;
    if (objective == null) return;

    final index = state.objectiveIndex;

    // Fire the grade request and move on. Grading takes ~1.2s; waiting for it
    // between objectives would leave a four-step mission idle for five seconds.
    unawaited(
      _api
          .gradeObjective(
            objective: objective,
            transcript: event.transcript,
            level: playerLevel,
          )
          .then((result) {
        if (isClosed) return;
        add(GradeReceived(objectiveIndex: index, result: result));
      }),
    );

    _advance(emit);
  }

  void _onObjectiveTimedOut(ObjectiveTimedOut event, Emitter<GameState> emit) {
    final index = state.objectiveIndex;
    if (index >= state.results.length) return;

    // Nothing was said, so nothing to grade — record the miss directly.
    final results = [...state.results];
    results[index] = const GradeResult(passed: false, multiplier: 0);
    emit(state.copyWith(results: results));

    _advance(emit);
  }

  /// Steps to the next objective, or resolves the mission when they run out.
  void _advance(Emitter<GameState> emit) {
    final mission = state.activeMission;
    if (mission == null) return;

    final next = state.objectiveIndex + 1;
    if (next < mission.objectives.length) {
      emit(state.copyWith(objectiveIndex: next));
      return;
    }

    emit(state.copyWith(phase: GamePhase.scoring));
    _settleIfReady(emit);
  }

  void _onGradeReceived(GradeReceived event, Emitter<GameState> emit) {
    if (event.objectiveIndex >= state.results.length) return;

    final results = [...state.results];
    results[event.objectiveIndex] = event.result;
    emit(state.copyWith(results: results));

    // A grade can land after the player has already finished the mission.
    if (state.phase == GamePhase.scoring) _settleIfReady(emit);
  }

  /// Applies damage once every grade for the mission has arrived.
  void _settleIfReady(Emitter<GameState> emit) {
    if (state.phase != GamePhase.scoring || !state.allGradesIn) return;

    final mission = state.activeMission!;
    final completed = state.completedCount;

    final damage = computeDamage(
      completed: completed,
      tier: mission.tier,
      gradeMul: state.averageMultiplier,
    );

    final missed = [
      ...state.missedObjectives,
      for (var i = 0; i < state.results.length; i++)
        if (!(state.results[i]?.passed ?? false)) mission.objectives[i],
    ];

    final botHp = max(0, state.botHp - damage.round());

    if (completed == 0) {
      final duration = _stun.recordMiss();
      _startStunTimer(duration);
      emit(state.copyWith(
        botHp: botHp,
        lastDamage: damage,
        missStreak: _stun.streak,
        stunUntil: DateTime.now().add(duration),
        missedObjectives: missed,
      ));
    } else {
      _stun.recordSuccess();
      emit(state.copyWith(
        botHp: botHp,
        lastDamage: damage,
        missStreak: 0,
        missedObjectives: missed,
      ));
    }

    if (botHp <= 0) {
      _cancelIdleTimer();
      _cancelStunTimer();
      emit(state.copyWith(phase: GamePhase.ended, clearActiveMission: true));
      return;
    }

    _refillUsedSlot(emit);
  }

  void _refillUsedSlot(Emitter<GameState> emit) {
    final pool = _pool;
    final index = state.activeMissionIndex;
    if (pool == null || index == null) return;

    emit(state.copyWith(phase: GamePhase.refill));
    pool.replaceAt(index);

    emit(state.copyWith(
      phase: GamePhase.idle,
      missions: pool.slots,
      clearActiveMission: true,
      objectiveIndex: 0,
      results: const [],
    ));
    _startIdleTimer();
  }

  void _onRefillTick(RefillTick event, Emitter<GameState> emit) {
    final pool = _pool;
    if (pool == null || state.phase != GamePhase.idle) return;

    pool.replaceOldest();
    emit(state.copyWith(missions: pool.slots));
  }

  void _onStunExpired(StunExpired event, Emitter<GameState> emit) {
    emit(state.copyWith(clearStun: true));
  }

  void _startIdleTimer() {
    _cancelIdleTimer();
    _idleTimer = Timer.periodic(idleRotation, (_) {
      if (!isClosed) add(const RefillTick());
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void _startStunTimer(Duration duration) {
    _cancelStunTimer();
    _stunTimer = Timer(duration, () {
      if (!isClosed) add(const StunExpired());
    });
  }

  void _cancelStunTimer() {
    _stunTimer?.cancel();
    _stunTimer = null;
  }

  /// True while the idle rotation clock is running — asserted in tests.
  bool get isIdleTimerActive => _idleTimer?.isActive ?? false;

  @override
  Future<void> close() {
    _cancelIdleTimer();
    _cancelStunTimer();
    return super.close();
  }
}
