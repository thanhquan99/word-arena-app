import 'package:flutter/material.dart';

import 'theme/arena_theme.dart';

import '../content/models.dart';
import '../game/bloc/game_state.dart';

/// End of match: the result, then the objectives that were missed.
///
/// The review is the part that makes this a learning app rather than just a
/// game — kept short, because a long list gets skipped (Game_Rule section 10).
class MatchEndScreen extends StatelessWidget {
  const MatchEndScreen({
    super.key,
    required this.state,
    required this.onPlayAgain,
    required this.onHome,
  });

  final GameState state;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  static const _maxReviewed = 5;

  @override
  Widget build(BuildContext context) {
    final won = state.botHp <= 0;
    final reviewed = state.missedObjectives.take(_maxReviewed).toList();

    return Container(
      color: Arena.bg,
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              won ? '🏆' : '💀',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 64),
            ),
            Text(
              won ? 'Thắng rồi!' : 'Hết trận',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: won ? Arena.self : Arena.enemy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Máu còn lại  ${state.playerHp} — ${state.botHp}  Đối thủ',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Arena.inkSoft),
            ),
            const SizedBox(height: 20),
            if (reviewed.isNotEmpty) ...[
              const Text(
                'Cần ôn lại',
                style: TextStyle(fontSize: 18, color: Arena.ink),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: reviewed.length,
                  itemBuilder: (context, i) => _MissedTile(reviewed[i]),
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Text(
                    'Không bỏ lỡ objective nào',
                    style: TextStyle(color: Arena.inkSoft),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ArenaButton(label: 'Chơi lại', onPressed: onPlayAgain),
            const SizedBox(height: 8),
            ArenaButton(
              label: 'Về trang chính',
              color: Arena.surface,
              compact: true,
              onPressed: onHome,
            ),
          ],
        ),
      ),
    );
  }
}

class _MissedTile extends StatelessWidget {
  const _MissedTile(this.objective);

  final Objective objective;

  @override
  Widget build(BuildContext context) {
    final sample = objective.sampleAnswers?.firstOrNull ??
        objective.exactAnswer ??
        objective.targetWord;

    return Card(
      color: Arena.surface,
      child: ListTile(
        // The mode says how it was meant to be answered, which is the part
        // worth remembering when reviewing a miss.
        leading: Icon(_modeIcon(objective.mode), color: Arena.inkSoft, size: 20),
        title: Text(
          objective.text,
          style: const TextStyle(color: Arena.ink, fontSize: 15),
        ),
        subtitle: sample == null
            ? null
            : Text(sample, style: const TextStyle(color: Arena.self)),
      ),
    );
  }
}

/// Icon for how an objective was meant to be answered.
IconData _modeIcon(ObjectiveMode mode) => switch (mode) {
      ObjectiveMode.speak => Icons.mic,
      ObjectiveMode.listen => Icons.hearing,
      ObjectiveMode.select => Icons.touch_app,
      ObjectiveMode.arrange => Icons.reorder,
    };
