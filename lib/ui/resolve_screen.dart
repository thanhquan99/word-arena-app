import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../content/models.dart';
import '../game/bloc/game_bloc.dart';
import '../game/bloc/game_event.dart';
import '../game/bloc/game_state.dart';
import '../net/api_client.dart';
import '../net/protocol.dart';
import 'theme/arena_theme.dart';
import 'widgets/arrange_words.dart';
import 'widgets/ptt_button.dart';
import 'widgets/select_answer.dart';

/// Playing an open card (Game_Rule v2 §3.4).
///
/// Two rules shape this screen, and both are new in v2:
///
///  * **Every objective is on screen at once.** The player picks what to do
///    first, skips what looks hard, and comes back to it. v1 marched through
///    them in order.
///  * **One clock for the whole card.** There is no per-objective timer any
///    more — how the budget is spent is the player's business.
class ResolveScreen extends StatefulWidget {
  const ResolveScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<ResolveScreen> createState() => _ResolveScreenState();
}

class _ResolveScreenState extends State<ResolveScreen> {
  /// Which objective the player is currently answering, if any.
  String? _openObjectiveId;

  Timer? _display;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    // A display-only ticker. The server owns the real clock and will settle the
    // turn whether or not this widget is on screen.
    _display = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _display?.cancel();
    super.dispose();
  }

  int _remaining(GameState state) {
    final startedAt = state.cardStartedAt;
    if (startedAt == null) return state.cardSeconds;

    final elapsed = (DateTime.now().millisecondsSinceEpoch - startedAt) / 1000;
    final left = (state.cardSeconds - elapsed).ceil();
    return left > 0 ? left : 0;
  }

  void _answer(GameState state, String objectiveId, String transcript) {
    context
        .read<GameBloc>()
        .add(ObjectiveAnswered(objectiveId: objectiveId, transcript: transcript));
    setState(() => _openObjectiveId = null);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        final mission = state.openedMission;
        if (mission == null || state.phase != GamePhase.resolving) {
          return const SizedBox.shrink();
        }

        _secondsLeft = _remaining(state);
        final open = _openObjectiveId == null
            ? null
            : state.objectives.where((o) => o.id == _openObjectiveId).firstOrNull;

        return Material(
          color: Arena.surface.withValues(alpha: 0.97),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CardClock(secondsLeft: _secondsLeft, total: state.cardSeconds),
                  const SizedBox(height: 12),
                  Text(
                    mission.prompt,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  _StanceSwitch(state: state),
                  const SizedBox(height: 12),

                  if (open == null)
                    Expanded(
                      child: _ObjectiveList(
                        state: state,
                        onPick: (objective) =>
                            setState(() => _openObjectiveId = objective.id),
                      ),
                    )
                  else
                    Expanded(
                      child: _AnswerPanel(
                        objective: open,
                        mission: mission,
                        api: widget.api,
                        onAnswer: (transcript) => _answer(state, open.id, transcript),
                        onBack: () => setState(() => _openObjectiveId = null),
                      ),
                    ),

                  const SizedBox(height: 10),
                  _OpponentProgress(state: state),
                  const SizedBox(height: 10),
                  _DoneButton(state: state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One clock for the card, counting the budget the server handed us.
class _CardClock extends StatelessWidget {
  const _CardClock({required this.secondsLeft, required this.total});

  final int secondsLeft;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : (secondsLeft / total).clamp(0.0, 1.0);
    final urgent = secondsLeft <= 5;

    return Column(
      children: [
        Text(
          '$secondsLeft s',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: urgent ? Arena.enemy : Arena.ink,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: Arena.surface2,
            valueColor: AlwaysStoppedAnimation(urgent ? Arena.enemy : Arena.accent),
          ),
        ),
      ],
    );
  }
}

/// Every objective, always visible, in whatever order the player wants them.
class _ObjectiveList extends StatelessWidget {
  const _ObjectiveList({required this.state, required this.onPick});

  final GameState state;
  final void Function(Objective) onPick;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: state.objectives.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final objective = state.objectives[index];
        final done = state.yourCompleted.contains(objective.id);
        final failed = state.yourFailed.contains(objective.id);

        return _ObjectiveTile(
          objective: objective,
          done: done,
          failed: failed,
          // A finished objective is settled; a failed one can still be retried
          // while the card clock runs.
          onTap: done || state.youAreDone ? null : () => onPick(objective),
        );
      },
    );
  }
}

class _ObjectiveTile extends StatelessWidget {
  const _ObjectiveTile({
    required this.objective,
    required this.done,
    required this.failed,
    required this.onTap,
  });

  final Objective objective;
  final bool done;
  final bool failed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, colour) = switch ((done, failed)) {
      (true, _) => (Icons.check_circle, Arena.self),
      (_, true) => (Icons.cancel, Arena.enemy),
      _ => (Icons.radio_button_unchecked, Arena.inkSoft),
    };

    return Semantics(
      button: onTap != null,
      label: objective.text,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: done ? Arena.self.withValues(alpha: 0.12) : Arena.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colour.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: colour, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  objective.text,
                  style: TextStyle(
                    fontSize: 16,
                    color: done ? Arena.inkSoft : Arena.ink,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Icon(
                objective.needsMic ? Icons.mic : Icons.touch_app,
                size: 18,
                color: Arena.inkSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The input for one objective, plus a way back to the list.
class _AnswerPanel extends StatelessWidget {
  const _AnswerPanel({
    required this.objective,
    required this.mission,
    required this.api,
    required this.onAnswer,
    required this.onBack,
  });

  final Objective objective;
  final Mission mission;
  final ApiClient api;
  final void Function(String) onAnswer;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            // Leaving costs nothing but the seconds already spent — the
            // objective stays open for another try.
            label: const Text('Chọn objective khác'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          objective.text,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        _input(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _input() {
    switch (objective.mode) {
      case ObjectiveMode.select:
        return SelectAnswer(prompt: mission.prompt, onSelected: onAnswer);
      case ObjectiveMode.arrange:
        return ArrangeWords(prompt: mission.prompt, onSubmitted: onAnswer);
      case ObjectiveMode.speak:
      case ObjectiveMode.listen:
        return PttButton(api: api, onTranscript: onAnswer);
    }
  }
}

/// Whether the opponent has finished — nothing finer.
///
/// A count would already say more than the pace needs, and §7.3 blocks per
/// objective: anything that hints at *what* they did lets a defender read the
/// attack instead of guessing at it.
class _OpponentProgress extends StatelessWidget {
  const _OpponentProgress({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final done = state.opponentIsDone;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: done ? Arena.enemy.withValues(alpha: 0.14) : Arena.surface2,
        borderRadius: BorderRadius.circular(Arena.radiusSm),
        border: Border.all(
          color: done ? Arena.enemy : Arena.ink,
          width: Arena.borderWSm,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(done ? '⏱️' : '✍️', style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            done ? 'Đối thủ đã xong — đang chờ bạn' : 'Đối thủ đang làm…',
            style: TextStyle(
              fontSize: 13,
              fontWeight: done ? FontWeight.w700 : FontWeight.w400,
              color: done ? Arena.enemy : Arena.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// Attack or defend, switchable for as long as the card clock runs.
///
/// This used to be a three-second overlay before the objectives appeared — a
/// question about a card the player had not read yet. Attack is lit by
/// default; tapping the other side switches, and switching back is free.
class _StanceSwitch extends StatelessWidget {
  const _StanceSwitch({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final locked = state.youAreDone;

    return Row(
      children: [
        Expanded(
          child: _StanceButton(
            icon: '⚔️',
            label: 'Tấn công',
            colour: Arena.enemy,
            selected: state.yourStance == Stance.attack,
            onPressed: locked
                ? null
                : () => context.read<GameBloc>().add(
                      const StanceChosen(Stance.attack),
                    ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StanceButton(
            icon: '🛡️',
            label: state.defenseAllowed ? 'Phòng thủ' : 'Khô máu — cấm thủ',
            colour: Arena.accent,
            selected: state.yourStance == Stance.defense,
            onPressed: locked || !state.defenseAllowed
                ? null
                : () => context.read<GameBloc>().add(
                      const StanceChosen(Stance.defense),
                    ),
          ),
        ),
      ],
    );
  }
}

class _StanceButton extends StatelessWidget {
  const _StanceButton({
    required this.icon,
    required this.label,
    required this.colour,
    required this.selected,
    required this.onPressed,
  });

  final String icon;
  final String label;
  final Color colour;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return Opacity(
      opacity: disabled && !selected ? 0.4 : 1,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(Arena.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colour.withValues(alpha: 0.2) : Arena.surface2,
            borderRadius: BorderRadius.circular(Arena.radiusSm),
            border: Border.all(
              color: selected ? colour : Arena.ink,
              width: selected ? Arena.borderW : Arena.borderWSm,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 17)),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? Arena.ink : Arena.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Locks in `completedTime` without waiting out the clock.
/// Locks in `completedTime` without waiting out the clock.
///
/// Without this button the §7.2 tie-break has nothing to compare: two players
/// who both sweep the card would be separated by whoever's clock happened to
/// expire first, which is not a skill.
class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final swept = state.yourCompleted.length == state.objectives.length;

    if (state.youAreDone) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Text(
          'Đã chốt — chờ đối thủ',
          textAlign: TextAlign.center,
          style: TextStyle(color: Arena.inkSoft),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: () => context.read<GameBloc>().add(const TurnFinished()),
      icon: const Icon(Icons.flag),
      label: Text(swept ? 'Xong — chốt thời gian' : 'Xong (bỏ phần còn lại)'),
      style: FilledButton.styleFrom(
        backgroundColor: swept ? Arena.self : Arena.surface2,
        foregroundColor: swept ? Colors.white : Arena.inkSoft,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
