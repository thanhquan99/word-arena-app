import 'package:flutter/material.dart';

import 'theme/arena_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    // The server decides the winner — a draw is possible when both sides
    // reach zero on the same turn (§11), so health alone cannot say.
    final won = state.winner == 'you';
    final drew = state.winner == 'draw';

    return Container(
      color: Arena.bg,
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              drew ? '🤝' : (won ? '🏆' : '💀'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 64),
            ),
            Text(
              drew ? 'Hoà' : (won ? 'Thắng rồi!' : 'Hết trận'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: drew ? Arena.inkSoft : (won ? Arena.self : Arena.enemy),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Máu còn lại  ${state.yourHp} — ${state.opponentHp}  Đối thủ',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Arena.inkSoft),
            ),
            const SizedBox(height: 20),
            // The post-match review (§10) is on hold: missed objectives used to
            // be accumulated client-side, and the server does not report them
            // yet. Reinstating it needs a protocol addition, not a widget.
            const Expanded(child: SizedBox.shrink()),
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
