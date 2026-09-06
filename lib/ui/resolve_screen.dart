import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../content/models.dart';
import '../game/bloc/game_bloc.dart';
import '../game/bloc/game_event.dart';
import '../game/bloc/game_state.dart';
import '../game/logic/effects.dart';
import '../net/api_client.dart';
import 'widgets/hp_bar_widget.dart';
import 'widgets/arrange_words.dart';
import 'widgets/ptt_button.dart';
import 'widgets/select_answer.dart';

/// Overlay shown while a mission is being played.
class ResolveScreen extends StatefulWidget {
  const ResolveScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<ResolveScreen> createState() => _ResolveScreenState();
}

class _ResolveScreenState extends State<ResolveScreen> {
  Timer? _countdown;
  int _secondsLeft = 0;
  String? _watchedObjectiveId;

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  /// Restarts the clock whenever the objective changes.
  void _syncCountdown(Objective objective, GameState state) {
    if (_watchedObjectiveId == objective.id) return;
    _watchedObjectiveId = objective.id;

    _countdown?.cancel();

    // Mercy rule (Game_Rule section 4): a player who is losing badly gets more
    // time, on top of whatever the mission's own effect does.
    final mercy = state.playerHp / GameState.maxHp < mercyThreshold;
    setState(() => _secondsLeft = effectiveTimeLimit(
          baseSeconds: objective.timeLimitSec,
          effect: state.activeMission?.effect,
          mercy: mercy,
        ));

    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        context.read<GameBloc>().add(const ObjectiveTimedOut());
      }
    });
  }

  void _answer(String transcript) {
    _countdown?.cancel();
    context.read<GameBloc>().add(ObjectiveAnswered(transcript));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        final mission = state.activeMission;
        final objective = state.activeObjective;
        if (mission == null || objective == null) {
          return const SizedBox.shrink();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncCountdown(objective, state);
        });

        return Container(
          color: Colors.black.withValues(alpha: 0.88),
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: Column(
              children: [
                _ProgressDots(state: state),
                const SizedBox(height: 16),
                Text(
                  mission.prompt,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_secondsLeft s',
                  style: TextStyle(
                    fontSize: 18,
                    color: _secondsLeft <= 3 ? Colors.red : Colors.white54,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  objective.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
                const Spacer(),
                _AnswerInput(
                  objective: objective,
                  mission: mission,
                  api: widget.api,
                  onAnswer: _answer,
                  // Silence locks the spoken objectives (Game_Rule section 8.2).
                  silenced: mission.effect == MissionEffect.silence &&
                      objective.needsMic,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Picks the input for the objective's mode. Only `speak` and `listen` reach
/// for the microphone.
class _AnswerInput extends StatelessWidget {
  const _AnswerInput({
    required this.objective,
    required this.mission,
    required this.api,
    required this.onAnswer,
    required this.silenced,
  });

  final Objective objective;
  final Mission mission;
  final ApiClient api;
  final void Function(String) onAnswer;

  /// True when `silence` has locked this objective.
  final bool silenced;

  @override
  Widget build(BuildContext context) {
    if (silenced) return _SilencedNotice(onExpired: () => onAnswer(''));

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

/// One dot per objective: grey while the grade is outstanding, then green or
/// red when it lands.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < state.results.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: switch (state.results[i]) {
                  null => i < state.objectiveIndex
                      ? Colors.grey // answered, still grading
                      : Colors.white24, // not reached yet
                  final r when r.passed => Colors.green,
                  _ => Colors.red,
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Shown when `silence` has locked a spoken objective.
///
/// It expires on its own rather than waiting for the objective clock: there is
/// nothing to do here, and leaving the player staring at a dead screen for the
/// full limit would just be a pause.
class _SilencedNotice extends StatefulWidget {
  const _SilencedNotice({required this.onExpired});

  final VoidCallback onExpired;

  @override
  State<_SilencedNotice> createState() => _SilencedNoticeState();
}

class _SilencedNoticeState extends State<_SilencedNotice> {
  static const _pause = Duration(seconds: 2);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_pause, () {
      if (mounted) widget.onExpired();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.6)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔇', style: TextStyle(fontSize: 40)),
          SizedBox(height: 8),
          Text(
            'Bị khoá — không nói được objective này',
            style: TextStyle(fontSize: 15, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
