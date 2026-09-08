import 'package:equatable/equatable.dart';

import '../../content/models.dart';
import '../../net/protocol.dart';

/// Where the match is (Game_Rule v2 §3).
///
/// `stance` is gone: choosing attack or defend used to be its own three-second
/// phase before the objectives appeared. It is now a switch on the play screen,
/// so a card opens straight into `resolving`.
enum GamePhase { idle, race, resolving, scoring, ended }

/// What the client knows about the match.
///
/// Every field here is something the **server** said. The client computes no
/// rules of its own — the one thing it derives is a countdown for display, and
/// even that reads a deadline the server set.
class GameState extends Equatable {
  const GameState({
    this.phase = GamePhase.idle,
    this.slots = const [],
    this.openedSlotIndex,
    this.openedMission,
    this.objectives = const [],
    this.yourCompleted = const {},
    this.opponentCompleted = const {},
    this.yourFailed = const {},
    this.yourStance = Stance.attack,
    this.defenseAllowed = true,
    this.cardSeconds = 0,
    this.cardStartedAt,
    this.youAreDone = false,
    this.opponentIsDone = false,
    this.turnStage,
    this.stageDeadline,
    this.yourHp = maxHp,
    this.opponentHp = maxHp,
    this.yourStatus = const PlayerStatus(),
    this.opponentStatus = const PlayerStatus(),
    this.lastTurn,
    this.winner,
    this.connection = MatchLink.disconnected,
    this.isBot = false,
  });

  static const maxHp = 50;

  final GamePhase phase;

  /// The four cards on the board (§2).
  final List<Mission> slots;

  final int? openedSlotIndex;
  final Mission? openedMission;

  /// Every objective of the open card, shown at once so the player picks their
  /// own order (§3.4).
  final List<Objective> objectives;

  final Set<String> yourCompleted;

  /// The opponent's progress, needed to explain §7.3 blocking after the fact.
  final Set<String> opponentCompleted;

  /// Objectives we answered and got wrong — still retryable while the clock runs.
  final Set<String> yourFailed;

  /// Attack from the moment the card opens, switchable while the clock runs.
  final Stance yourStance;

  /// False on a 🎯 All-out card, which bans Defense (§8.3).
  final bool defenseAllowed;

  /// Our own card budget in seconds; the opponent's may differ.
  final int cardSeconds;

  /// Server clock instant the card started, for the display countdown.
  final int? cardStartedAt;
  final bool youAreDone;

  /// They have pressed Done and are waiting on you.
  ///
  /// Whether, not how far. §7.3 blocks per objective, so even a count would
  /// tell a defender more than the rule intends; the breakdown arrives with
  /// [lastTurn], once there is nothing left to exploit.
  final bool opponentIsDone;

  /// Which beat of the scoring phase is playing, or null outside it.
  final TurnStage? turnStage;

  /// Server clock instant the current beat ends.
  final int? stageDeadline;

  final int yourHp;
  final int opponentHp;

  final PlayerStatus yourStatus;
  final PlayerStatus opponentStatus;

  final TurnSettledEvent? lastTurn;

  /// `you`, `opponent` or `draw` once the match is over.
  final String? winner;

  final MatchLink connection;
  final bool isBot;

  bool get hasOpenCard => openedMission != null;

  /// Whether tapping a card should do anything right now.
  ///
  /// The stun lockout (§8.2) is deliberately *not* checked here — it is a
  /// server rule, and the server simply ignores a tap it does not accept. The
  /// client greys the cards to explain, using [stunSecondsLeft].
  bool get canTap => phase == GamePhase.idle && connection == MatchLink.ready;

  /// Seconds of stun lockout left, or zero. Display only.
  int stunSecondsLeft(int nowMs) {
    final until = yourStatus.stunnedUntil;
    if (until == null) return 0;
    final left = ((until - nowMs) / 1000).ceil();
    return left > 0 ? left : 0;
  }

  GameState copyWith({
    GamePhase? phase,
    List<Mission>? slots,
    int? openedSlotIndex,
    Mission? openedMission,
    List<Objective>? objectives,
    Set<String>? yourCompleted,
    Set<String>? opponentCompleted,
    Set<String>? yourFailed,
    Stance? yourStance,
    bool? defenseAllowed,
    int? cardSeconds,
    int? cardStartedAt,
    bool? youAreDone,
    bool? opponentIsDone,
    TurnStage? turnStage,
    int? stageDeadline,
    int? yourHp,
    int? opponentHp,
    PlayerStatus? yourStatus,
    PlayerStatus? opponentStatus,
    TurnSettledEvent? lastTurn,
    String? winner,
    MatchLink? connection,
    bool? isBot,
    bool clearCard = false,
    bool clearLastTurn = false,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      slots: slots ?? this.slots,
      openedSlotIndex: clearCard ? null : (openedSlotIndex ?? this.openedSlotIndex),
      openedMission: clearCard ? null : (openedMission ?? this.openedMission),
      objectives: clearCard ? const [] : (objectives ?? this.objectives),
      yourCompleted: clearCard ? const {} : (yourCompleted ?? this.yourCompleted),
      opponentCompleted:
          clearCard ? const {} : (opponentCompleted ?? this.opponentCompleted),
      yourFailed: clearCard ? const {} : (yourFailed ?? this.yourFailed),
      yourStance: clearCard ? Stance.attack : (yourStance ?? this.yourStance),
      defenseAllowed: clearCard ? true : (defenseAllowed ?? this.defenseAllowed),
      cardSeconds: clearCard ? 0 : (cardSeconds ?? this.cardSeconds),
      cardStartedAt: clearCard ? null : (cardStartedAt ?? this.cardStartedAt),
      youAreDone: clearCard ? false : (youAreDone ?? this.youAreDone),
      opponentIsDone: clearCard ? false : (opponentIsDone ?? this.opponentIsDone),
      turnStage: clearCard ? null : (turnStage ?? this.turnStage),
      stageDeadline: clearCard ? null : (stageDeadline ?? this.stageDeadline),
      yourHp: yourHp ?? this.yourHp,
      opponentHp: opponentHp ?? this.opponentHp,
      yourStatus: yourStatus ?? this.yourStatus,
      opponentStatus: opponentStatus ?? this.opponentStatus,
      lastTurn: clearLastTurn ? null : (lastTurn ?? this.lastTurn),
      winner: winner ?? this.winner,
      connection: connection ?? this.connection,
      isBot: isBot ?? this.isBot,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        slots,
        openedSlotIndex,
        openedMission,
        objectives,
        yourCompleted,
        opponentCompleted,
        yourFailed,
        yourStance,
        defenseAllowed,
        cardSeconds,
        cardStartedAt,
        youAreDone,
        opponentIsDone,
        turnStage,
        stageDeadline,
        yourHp,
        opponentHp,
        yourStatus,
        opponentStatus,
        lastTurn,
        winner,
        connection,
        isBot,
      ];
}

/// Where the socket stands, so the UI can say "reconnecting" rather than freeze.
///
/// Named `MatchLink` rather than `ConnectionState` because Flutter already
/// exports that name from `async.dart`, and the clash reaches every widget.
enum MatchLink { disconnected, connecting, waitingForOpponent, ready, lost }
