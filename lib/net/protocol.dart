/// The match WebSocket contract.
///
/// ⚠️ This is a one-to-one translation of
/// `word-arena-api/src/ws/protocol.ts`, which is the original. The two drifting
/// apart is the most dangerous failure mode in the project: frames still send
/// and still parse, they simply mean something else, and the symptom is a match
/// that produces nonsense. Change one, change the other in the same commit.
library;

import '../content/models.dart';

const protocolVersion = 2;

enum Stance { attack, defense }

enum MatchMode { pvp, bot }

/// Why a turn went the way it did (§7.2/§7.3).
///
/// This is the only thing that can answer "why did I lose at 4/4?", so it is
/// carried all the way to the UI rather than being logged and dropped.
enum TurnReason {
  /// Decided on objective count.
  count,

  /// Counts tied, the clock decided.
  time,

  /// Counts and clock both tied.
  tie,

  /// The card carried 🎯 All-out.
  allout,

  /// Both sides defended.
  bothDefense,

  /// One attacked, one defended.
  blocked,
}

enum TurnOutcome { youWin, opponentWin, draw, bothDamaged, empty }

/// The three beats a settled turn plays out over (feature-06).
///
/// The server owns this clock and sends a deadline for each beat, so the two
/// boards stay in step — a pet must never strike after its target has already
/// moved on to the next card.
enum TurnStage {
  /// Both boards show who finished what.
  compare,

  /// Damage lands; the pets cast and recoil.
  strike,

  /// The dust settles before the next board.
  settle,
}

// ----------------------------------------------------------------- client → server

sealed class ClientMessage {
  const ClientMessage();

  Map<String, dynamic> toJson();
}

class JoinMessage extends ClientMessage {
  const JoinMessage({required this.mode, this.level = 'B1', this.resumeToken});

  final MatchMode mode;
  final String level;

  /// Present when rejoining a match in progress after a drop (§11).
  final String? resumeToken;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'join',
        'mode': mode.name,
        'level': level,
        if (resumeToken != null) 'resumeToken': resumeToken,
      };
}

class TapCardMessage extends ClientMessage {
  const TapCardMessage(this.slotIndex);

  final int slotIndex;

  @override
  Map<String, dynamic> toJson() => {'type': 'tap_card', 'slotIndex': slotIndex};
}

class SetStanceMessage extends ClientMessage {
  const SetStanceMessage(this.stance);

  final Stance stance;

  @override
  Map<String, dynamic> toJson() => {'type': 'set_stance', 'stance': stance.name};
}

class AnswerMessage extends ClientMessage {
  const AnswerMessage({required this.objectiveId, required this.transcript});

  final String objectiveId;
  final String transcript;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'answer',
        'objectiveId': objectiveId,
        'transcript': transcript,
      };
}

/// Locks in `completedTime` early, instead of waiting out the card clock.
class DoneMessage extends ClientMessage {
  const DoneMessage();

  @override
  Map<String, dynamic> toJson() => {'type': 'done'};
}

// ----------------------------------------------------------------- server → client

sealed class ServerEvent {
  const ServerEvent();

  /// Returns `null` for a frame this build does not know about, so a server
  /// that has learned a new event does not break an older client.
  static ServerEvent? fromJson(Map<String, dynamic> json) {
    return switch (json['type']) {
      'matched' => MatchedEvent.fromJson(json),
      'board' => BoardEvent.fromJson(json),
      'card_opened' => CardOpenedEvent.fromJson(json),
      'stance_locked' => StanceLockedEvent.fromJson(json),
      'resolve_start' => ResolveStartEvent.fromJson(json),
      'objective_result' => ObjectiveResultEvent.fromJson(json),
      'turn_settled' => TurnSettledEvent.fromJson(json),
      'turn_phase' => TurnPhaseEvent.fromJson(json),
      'opponent_progress' => OpponentProgressEvent.fromJson(json),
      'hp' => HpEvent.fromJson(json),
      'status' => StatusEvent.fromJson(json),
      'ended' => EndedEvent.fromJson(json),
      'error' => ErrorEvent.fromJson(json),
      _ => null,
    };
  }
}

class MatchedEvent extends ServerEvent {
  const MatchedEvent({
    required this.matchId,
    required this.you,
    required this.isBot,
    required this.resumeToken,
    required this.protocolVersion,
  });

  final String matchId;
  final String you;
  final bool isBot;
  final String resumeToken;
  final int protocolVersion;

  factory MatchedEvent.fromJson(Map<String, dynamic> json) => MatchedEvent(
        matchId: json['matchId'] as String,
        you: json['you'] as String,
        isBot: json['isBot'] as bool? ?? false,
        resumeToken: json['resumeToken'] as String? ?? '',
        protocolVersion: json['protocolVersion'] as int? ?? 0,
      );
}

class BoardEvent extends ServerEvent {
  const BoardEvent({required this.slots, required this.phase, this.idleDeadline});

  final List<Mission> slots;
  final String phase;

  /// Server clock instant the oldest card is swapped, or null outside idle.
  final int? idleDeadline;

  factory BoardEvent.fromJson(Map<String, dynamic> json) => BoardEvent(
        slots: (json['slots'] as List<dynamic>)
            .map((s) => Mission.fromJson(s as Map<String, dynamic>))
            .toList(growable: false),
        phase: json['phase'] as String,
        idleDeadline: json['idleDeadline'] as int?,
      );
}

class CardOpenedEvent extends ServerEvent {
  const CardOpenedEvent({
    required this.slotIndex,
    required this.mission,
    required this.defenseAllowed,
    this.stanceDeadline,
  });

  final int slotIndex;
  final Mission mission;

  /// False on a 🎯 All-out card, which bans Defense (§8.3).
  final bool defenseAllowed;
  final int? stanceDeadline;

  factory CardOpenedEvent.fromJson(Map<String, dynamic> json) => CardOpenedEvent(
        slotIndex: json['slotIndex'] as int,
        mission: Mission.fromJson(json['mission'] as Map<String, dynamic>),
        defenseAllowed: json['defenseAllowed'] as bool? ?? true,
        stanceDeadline: json['stanceDeadline'] as int?,
      );
}

class StanceLockedEvent extends ServerEvent {
  const StanceLockedEvent({required this.you, required this.opponent});

  final Stance you;
  final Stance opponent;

  factory StanceLockedEvent.fromJson(Map<String, dynamic> json) => StanceLockedEvent(
        you: _stance(json['you']),
        opponent: _stance(json['opponent']),
      );
}

class ResolveStartEvent extends ServerEvent {
  const ResolveStartEvent({
    required this.objectives,
    required this.cardSeconds,
    required this.startedAt,
  });

  final List<Objective> objectives;

  /// This viewer's own budget; the opponent's may differ (haste, rush, mercy).
  final int cardSeconds;
  final int startedAt;

  factory ResolveStartEvent.fromJson(Map<String, dynamic> json) => ResolveStartEvent(
        objectives: (json['objectives'] as List<dynamic>)
            .map((o) => Objective.fromJson(o as Map<String, dynamic>))
            .toList(growable: false),
        cardSeconds: json['cardSeconds'] as int,
        startedAt: json['startedAt'] as int,
      );
}

class ObjectiveResultEvent extends ServerEvent {
  const ObjectiveResultEvent({
    required this.objectiveId,
    required this.passed,
    required this.mine,
  });

  final String objectiveId;
  final bool passed;

  /// True when this is our own objective, false when it is the opponent's.
  final bool mine;

  factory ObjectiveResultEvent.fromJson(Map<String, dynamic> json) => ObjectiveResultEvent(
        objectiveId: json['objectiveId'] as String,
        passed: json['passed'] as bool,
        mine: json['whose'] == 'you',
      );
}

class SideResult {
  const SideResult({
    required this.n,
    required this.completedTime,
    required this.damageDealt,
  });

  /// Objectives completed.
  final int n;

  /// Milliseconds into the card clock when this side finished.
  final int completedTime;
  final double damageDealt;

  factory SideResult.fromJson(Map<String, dynamic> json) => SideResult(
        n: json['n'] as int,
        completedTime: (json['completedTime'] as num).round(),
        damageDealt: (json['damageDealt'] as num).toDouble(),
      );
}

class TurnSettledEvent extends ServerEvent {
  const TurnSettledEvent({
    required this.outcome,
    required this.reason,
    required this.you,
    required this.opponent,
    required this.blocked,
    this.effect,
  });

  final TurnOutcome outcome;
  final TurnReason reason;
  final SideResult you;
  final SideResult opponent;

  /// Objective ids a defender neutralised (§7.3), empty otherwise.
  final List<String> blocked;
  final MissionEffect? effect;

  factory TurnSettledEvent.fromJson(Map<String, dynamic> json) => TurnSettledEvent(
        outcome: _outcome(json['outcome']),
        reason: _reason(json['reason']),
        you: SideResult.fromJson(json['you'] as Map<String, dynamic>),
        opponent: SideResult.fromJson(json['opponent'] as Map<String, dynamic>),
        blocked: (json['blocked'] as List<dynamic>? ?? const [])
            .map((b) => b as String)
            .toList(growable: false),
        effect: _effect(json['effect']),
      );
}

/// Which beat of the scoring phase is playing, and when it ends.
class TurnPhaseEvent extends ServerEvent {
  const TurnPhaseEvent({required this.stage, required this.until});

  final TurnStage stage;

  /// Server clock instant this beat ends.
  final int until;

  factory TurnPhaseEvent.fromJson(Map<String, dynamic> json) => TurnPhaseEvent(
        stage: _stage(json['stage']),
        until: json['until'] as int,
      );
}

/// How far along the opponent is — a count only.
///
/// Deliberately carries no objective id. §7.3 blocks per objective, so seeing
/// *which* one the opponent just finished would let a defender watch and block
/// correctly rather than guess. The breakdown comes later, in the comparison
/// table, once there is nothing left to exploit.
class OpponentProgressEvent extends ServerEvent {
  const OpponentProgressEvent({
    required this.completed,
    required this.total,
    required this.done,
  });

  final int completed;
  final int total;

  /// They have pressed Done and are waiting on you.
  final bool done;

  factory OpponentProgressEvent.fromJson(Map<String, dynamic> json) =>
      OpponentProgressEvent(
        completed: json['completed'] as int,
        total: json['total'] as int,
        done: json['done'] as bool? ?? false,
      );
}

class HpEvent extends ServerEvent {
  const HpEvent({required this.you, required this.opponent});

  final int you;
  final int opponent;

  factory HpEvent.fromJson(Map<String, dynamic> json) =>
      HpEvent(you: json['you'] as int, opponent: json['opponent'] as int);
}

/// Effects still hanging over a player (§8) — the bridging four plus burn.
class PlayerStatus {
  const PlayerStatus({
    this.shield = false,
    this.mirror = false,
    this.haste = false,
    this.rush = false,
    this.burnTurnsLeft = 0,
    this.stunnedUntil,
  });

  final bool shield;
  final bool mirror;
  final bool haste;
  final bool rush;
  final int burnTurnsLeft;
  final int? stunnedUntil;

  bool get isEmpty =>
      !shield && !mirror && !haste && !rush && burnTurnsLeft == 0 && stunnedUntil == null;

  factory PlayerStatus.fromJson(Map<String, dynamic> json) => PlayerStatus(
        shield: json['shield'] as bool? ?? false,
        mirror: json['mirror'] as bool? ?? false,
        haste: json['haste'] as bool? ?? false,
        rush: json['rush'] as bool? ?? false,
        burnTurnsLeft: json['burnTurnsLeft'] as int? ?? 0,
        stunnedUntil: json['stunnedUntil'] as int?,
      );
}

class StatusEvent extends ServerEvent {
  const StatusEvent({required this.you, required this.opponent});

  final PlayerStatus you;
  final PlayerStatus opponent;

  factory StatusEvent.fromJson(Map<String, dynamic> json) => StatusEvent(
        you: PlayerStatus.fromJson(json['you'] as Map<String, dynamic>),
        opponent: PlayerStatus.fromJson(json['opponent'] as Map<String, dynamic>),
      );
}

class EndedEvent extends ServerEvent {
  const EndedEvent(this.winner);

  /// One of `you`, `opponent`, `draw`.
  final String winner;

  bool get won => winner == 'you';
  bool get drew => winner == 'draw';

  factory EndedEvent.fromJson(Map<String, dynamic> json) =>
      EndedEvent(json['winner'] as String? ?? 'draw');
}

class ErrorEvent extends ServerEvent {
  const ErrorEvent({required this.error, this.detail});

  final String error;
  final String? detail;

  /// The server is holding this player until an opponent arrives.
  bool get isWaiting => error == 'waiting_for_opponent';

  factory ErrorEvent.fromJson(Map<String, dynamic> json) => ErrorEvent(
        error: json['error'] as String? ?? 'unknown',
        detail: json['detail'] as String?,
      );
}

// ------------------------------------------------------------------------ helpers

TurnStage _stage(Object? raw) => switch (raw) {
      'strike' => TurnStage.strike,
      'settle' => TurnStage.settle,
      _ => TurnStage.compare,
    };

Stance _stance(Object? raw) =>
    raw == 'defense' ? Stance.defense : Stance.attack;

TurnOutcome _outcome(Object? raw) => switch (raw) {
      'you_win' => TurnOutcome.youWin,
      'opponent_win' => TurnOutcome.opponentWin,
      'both_damaged' => TurnOutcome.bothDamaged,
      'empty' => TurnOutcome.empty,
      _ => TurnOutcome.draw,
    };

TurnReason _reason(Object? raw) => switch (raw) {
      'count' => TurnReason.count,
      'time' => TurnReason.time,
      'allout' => TurnReason.allout,
      'both_defense' => TurnReason.bothDefense,
      'blocked' => TurnReason.blocked,
      _ => TurnReason.tie,
    };

MissionEffect? _effect(Object? raw) {
  if (raw is! String) return null;
  for (final effect in MissionEffect.values) {
    if (effect.name == raw) return effect;
  }
  return null;
}
