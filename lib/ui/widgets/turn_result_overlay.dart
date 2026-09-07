import 'package:flutter/material.dart';

import '../../content/models.dart';
import '../../game/logic/effects.dart';
import '../../net/protocol.dart';
import '../theme/arena_theme.dart';

/// What just happened, and — the part that matters — **why**.
///
/// Three v2 outcomes are counter-intuitive enough that a player will read them
/// as a bug unless the game explains itself:
///
///  * losing on the clock at an identical objective count (§7.2)
///  * losing everything despite finishing plenty (§7.2 is winner-takes-all)
///  * defending well and still taking full damage, because the block landed on
///    objectives the attacker never attempted (§7.3)
class TurnResultOverlay extends StatelessWidget {
  const TurnResultOverlay({
    super.key,
    required this.turn,
    this.objectives = const [],
    this.yourCompleted = const {},
    this.opponentCompleted = const {},
  });

  final TurnSettledEvent turn;

  /// The card just played, so the table can name each row.
  final List<Objective> objectives;
  final Set<String> yourCompleted;

  /// Only shown here, once the turn has settled — during play it would let a
  /// defender copy the attacker's choices instead of guessing (§7.3).
  final Set<String> opponentCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Arena.ink.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Arena.surface,
            borderRadius: BorderRadius.circular(Arena.radius),
            border: Arena.border,
            boxShadow: Arena.lift,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_headline, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _headlineColour)),
              const SizedBox(height: 4),
              Text(
                _explanation,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Arena.inkSoft),
              ),
              const SizedBox(height: 16),

              _Scoreline(turn: turn),

              if (objectives.isNotEmpty) ...[
                const SizedBox(height: 14),
                _ObjectiveTable(
                  objectives: objectives,
                  yourCompleted: yourCompleted,
                  opponentCompleted: opponentCompleted,
                  blocked: turn.blocked.toSet(),
                ),
              ],

              if (turn.blocked.isNotEmpty) ...[
                const SizedBox(height: 12),
                _BlockedNote(count: turn.blocked.length),
              ],

              if (turn.effect != null) ...[
                const SizedBox(height: 12),
                _EffectLine(effect: turn.effect!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _headline => switch (turn.outcome) {
        TurnOutcome.youWin => 'Thắng lượt',
        TurnOutcome.opponentWin => 'Thua lượt',
        TurnOutcome.bothDamaged => 'Khô máu — cả hai cùng mất',
        TurnOutcome.empty => 'Vòng trống',
        TurnOutcome.draw => 'Hoà lượt',
      };

  Color get _headlineColour => switch (turn.outcome) {
        TurnOutcome.youWin => Arena.self,
        TurnOutcome.opponentWin => Arena.enemy,
        _ => Arena.inkSoft,
      };

  /// The sentence that stops the player thinking the game is broken.
  String get _explanation {
    final you = turn.you;
    final them = turn.opponent;

    return switch (turn.reason) {
      TurnReason.count => turn.outcome == TurnOutcome.youWin
          ? 'Bạn hoàn thành ${you.n} objective, đối thủ ${them.n}.'
          : 'Đối thủ hoàn thành ${them.n} objective, bạn ${you.n}. '
              'Damage bạn làm ra bị bỏ vì thua lượt.',
      TurnReason.time => turn.outcome == TurnOutcome.youWin
          ? 'Cùng ${you.n} objective — bạn xong sớm hơn.'
          : 'Cùng ${you.n} objective — đối thủ xong sớm hơn, nên bạn ăn full damage.',
      TurnReason.tie => 'Cùng số objective và cùng thời gian. Không ai mất máu.',
      TurnReason.allout =>
        'Card 🎯 không so sánh — mỗi bên gây damage theo số objective của mình.',
      TurnReason.bothDefense => 'Cả hai cùng phòng thủ nên không ai gây được damage.',
      TurnReason.blocked => turn.outcome == TurnOutcome.youWin
          ? 'Đối thủ phòng thủ nhưng không chặn hết.'
          : 'Bạn phòng thủ — chỉ chặn được đúng objective đối thủ cũng làm được.',
    };
  }
}

/// Both sides side by side. The clock is always shown, not only when it
/// decided the turn, so the player learns to read it before it costs them one.
class _Scoreline extends StatelessWidget {
  const _Scoreline({required this.turn});

  final TurnSettledEvent turn;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SideColumn(
            title: 'Bạn',
            side: turn.you,
            colour: Arena.self,
            highlight: turn.outcome == TurnOutcome.youWin,
          ),
        ),
        Container(width: 1, height: 78, color: Arena.inkSoft.withValues(alpha: 0.3)),
        Expanded(
          child: _SideColumn(
            title: 'Đối thủ',
            side: turn.opponent,
            colour: Arena.enemy,
            highlight: turn.outcome == TurnOutcome.opponentWin,
          ),
        ),
      ],
    );
  }
}

class _SideColumn extends StatelessWidget {
  const _SideColumn({
    required this.title,
    required this.side,
    required this.colour,
    required this.highlight,
  });

  final String title;
  final SideResult side;
  final Color colour;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Arena.inkSoft)),
        const SizedBox(height: 4),
        Text(
          '${side.n}',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: highlight ? colour : Arena.ink,
          ),
        ),
        const Text('objective', style: TextStyle(fontSize: 10, color: Arena.inkSoft)),
        const SizedBox(height: 6),
        Text(
          '${(side.completedTime / 1000).toStringAsFixed(1)} s',
          style: const TextStyle(fontSize: 13, color: Arena.inkSoft),
        ),
        const SizedBox(height: 4),
        Text(
          side.damageDealt > 0 ? '−${side.damageDealt.round()} máu' : 'không gây damage',
          style: TextStyle(
            fontSize: 12,
            fontWeight: side.damageDealt > 0 ? FontWeight.w700 : FontWeight.normal,
            color: side.damageDealt > 0 ? colour : Arena.inkSoft,
          ),
        ),
      ],
    );
  }
}

/// Who finished what, row by row.
///
/// This is the only place §7.3 can be learned: seeing a shield sitting on an
/// objective the attacker never attempted is what makes "I defended and still
/// took full damage" stop looking like a bug.
class _ObjectiveTable extends StatelessWidget {
  const _ObjectiveTable({
    required this.objectives,
    required this.yourCompleted,
    required this.opponentCompleted,
    required this.blocked,
  });

  final List<Objective> objectives;
  final Set<String> yourCompleted;
  final Set<String> opponentCompleted;
  final Set<String> blocked;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: SizedBox.shrink()),
            SizedBox(
              width: 44,
              child: Text('Bạn',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Arena.inkSoft)),
            ),
            SizedBox(
              width: 44,
              child: Text('Đối thủ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Arena.inkSoft)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final objective in objectives)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    objective.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Arena.ink),
                  ),
                ),
                _Mark(
                  done: yourCompleted.contains(objective.id),
                  blocked: blocked.contains(objective.id),
                ),
                _Mark(
                  done: opponentCompleted.contains(objective.id),
                  blocked: blocked.contains(objective.id),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.done, required this.blocked});

  final bool done;

  /// A shield sits on an objective both sides finished — the defender
  /// neutralised it (§7.3).
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Text(
        done ? (blocked ? '✅🛡️' : '✅') : '✖️',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}

class _BlockedNote extends StatelessWidget {
  const _BlockedNote({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Arena.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(Arena.radiusSm),
        border: Border.all(color: Arena.accent),
      ),
      child: Text(
        '🛡️ Chặn được $count objective',
        style: const TextStyle(fontSize: 12, color: Arena.ink),
      ),
    );
  }
}

class _EffectLine extends StatelessWidget {
  const _EffectLine({required this.effect});

  final MissionEffect effect;

  @override
  Widget build(BuildContext context) {
    final info = effectInfo(effect);

    return Text(
      '${info.icon} ${info.label}'
      '${info.bridges ? ' — có hiệu lực ở lượt sau' : ''}',
      style: const TextStyle(fontSize: 12, color: Arena.inkSoft),
    );
  }
}
