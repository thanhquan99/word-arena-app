import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'bloc/game_bloc.dart';
import 'bloc/game_event.dart';
import 'bloc/game_state.dart';
import 'components/damage_text.dart';
import 'components/hp_bar.dart';
import 'components/mission_card.dart';

/// Renders the match. All rules live in [GameBloc]; this only draws what the
/// state says and forwards taps back as events.
class ArenaGame extends FlameGame {
  ArenaGame({required this.bloc});

  final GameBloc bloc;

  final List<MissionCard> _cards = [];
  late final HpBar _playerBar;
  late final HpBar _botBar;

  double? _lastDamageShown;

  @override
  Color backgroundColor() => const Color(0xFF1A1A2E);

  @override
  Future<void> onLoad() async {
    const barHeight = 24.0;
    const margin = 16.0;

    _botBar = HpBar(
      label: 'Đối thủ',
      maxHp: GameState.maxHp,
      color: const Color(0xFFEF5350),
      position: Vector2(margin, margin),
      size: Vector2(size.x - margin * 2, barHeight),
    );

    _playerBar = HpBar(
      label: 'Bạn',
      maxHp: GameState.maxHp,
      color: const Color(0xFF4CAF50),
      position: Vector2(margin, size.y - margin - barHeight),
      size: Vector2(size.x - margin * 2, barHeight),
    );

    await addAll([_botBar, _playerBar]);
    _layoutCards();
  }

  /// Five slots in a 2-2-1 grid, which keeps every card thumb-reachable.
  void _layoutCards() {
    const margin = 16.0;
    const gap = 12.0;
    const topOffset = 70.0;

    final available = size.y - topOffset - 80;
    final cardW = (size.x - margin * 2 - gap) / 2;
    final cardH = (available - gap * 2) / 3;

    final positions = <Vector2>[
      Vector2(margin, topOffset),
      Vector2(margin + cardW + gap, topOffset),
      Vector2(margin, topOffset + cardH + gap),
      Vector2(margin + cardW + gap, topOffset + cardH + gap),
      Vector2(margin + (cardW + gap) / 2, topOffset + (cardH + gap) * 2),
    ];

    for (var i = 0; i < positions.length; i++) {
      final index = i;
      final card = MissionCard(
        mission: bloc.state.missions[i],
        onTapped: () => bloc.add(MissionTapped(index)),
        position: positions[i],
        size: Vector2(cardW, cardH),
      );
      _cards.add(card);
      add(card);
    }
  }

  /// Pushes a new state onto the board.
  void applyState(GameState state) {
    if (_cards.length != state.missions.length) return;

    final interactive = state.phase == GamePhase.idle && !state.isStunned;
    for (var i = 0; i < _cards.length; i++) {
      _cards[i].update_(state.missions[i]);
      _cards[i].enabled = interactive;
    }

    _botBar.hp = state.botHp;
    _playerBar.hp = state.playerHp;

    _showDamageOnce(state.lastDamage);
  }

  /// Spawns the floating number only when the value actually changes, so a
  /// rebuild for some other reason does not re-trigger the animation.
  void _showDamageOnce(double? damage) {
    if (damage == null || damage <= 0 || damage == _lastDamageShown) return;
    _lastDamageShown = damage;

    add(DamageText(
      amount: damage.round(),
      position: Vector2(size.x / 2, size.y * 0.3),
    ));
  }
}
