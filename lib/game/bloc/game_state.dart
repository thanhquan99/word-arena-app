import 'package:equatable/equatable.dart';

import '../../content/models.dart';
import '../../net/grade_result.dart';

/// Where the match currently is (Game_Rule section 3).
///
/// `race` is absent: single-player has no opponent to race against, so a tap
/// goes straight to `resolving`.
enum GamePhase { idle, resolving, scoring, refill, ended }

class GameState extends Equatable {
  const GameState({
    this.phase = GamePhase.idle,
    this.missions = const [],
    this.playerHp = maxHp,
    this.botHp = maxHp,
    this.activeMissionIndex,
    this.objectiveIndex = 0,
    this.results = const [],
    this.stunUntil,
    this.missStreak = 0,
    this.lastDamage,
    this.missedObjectives = const [],
  });

  static const maxHp = 50;

  final GamePhase phase;

  /// The five slots on the map.
  final List<Mission> missions;

  final int playerHp;
  final int botHp;

  /// Which slot is being played, if any.
  final int? activeMissionIndex;

  /// Position within the active mission's objectives.
  final int objectiveIndex;

  /// One entry per objective of the active mission. `null` means the grade has
  /// been requested but has not come back yet — grading runs alongside play
  /// rather than blocking it.
  final List<GradeResult?> results;

  /// When the player can act again. Null when not stunned.
  final DateTime? stunUntil;

  /// Consecutive missions where nothing was completed.
  final int missStreak;

  /// Damage from the mission that just resolved, for the floating number.
  final double? lastDamage;

  /// Objectives the player failed this match, shown in the end-of-match review.
  final List<Objective> missedObjectives;

  Mission? get activeMission =>
      activeMissionIndex == null ? null : missions[activeMissionIndex!];

  Objective? get activeObjective {
    final mission = activeMission;
    if (mission == null || objectiveIndex >= mission.objectives.length) {
      return null;
    }
    return mission.objectives[objectiveIndex];
  }

  bool get isStunned =>
      stunUntil != null && DateTime.now().isBefore(stunUntil!);

  /// True once every requested grade has come back.
  bool get allGradesIn => !results.contains(null);

  int get completedCount =>
      results.where((r) => r?.passed ?? false).length;

  /// Average grade weight across the objectives that passed, used as the
  /// `gradeMul` term in the damage formula.
  double get averageMultiplier {
    final graded = results.whereType<GradeResult>().toList();
    if (graded.isEmpty) return 0;
    final sum = graded.fold<double>(0, (acc, r) => acc + r.multiplier);
    return sum / graded.length;
  }

  GameState copyWith({
    GamePhase? phase,
    List<Mission>? missions,
    int? playerHp,
    int? botHp,
    int? activeMissionIndex,
    bool clearActiveMission = false,
    int? objectiveIndex,
    List<GradeResult?>? results,
    DateTime? stunUntil,
    bool clearStun = false,
    int? missStreak,
    double? lastDamage,
    bool clearLastDamage = false,
    List<Objective>? missedObjectives,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      missions: missions ?? this.missions,
      playerHp: playerHp ?? this.playerHp,
      botHp: botHp ?? this.botHp,
      activeMissionIndex:
          clearActiveMission ? null : (activeMissionIndex ?? this.activeMissionIndex),
      objectiveIndex: objectiveIndex ?? this.objectiveIndex,
      results: results ?? this.results,
      stunUntil: clearStun ? null : (stunUntil ?? this.stunUntil),
      missStreak: missStreak ?? this.missStreak,
      lastDamage: clearLastDamage ? null : (lastDamage ?? this.lastDamage),
      missedObjectives: missedObjectives ?? this.missedObjectives,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        missions,
        playerHp,
        botHp,
        activeMissionIndex,
        objectiveIndex,
        results,
        stunUntil,
        missStreak,
        lastDamage,
        missedObjectives,
      ];
}
