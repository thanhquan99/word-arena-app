import 'package:flutter/material.dart';

import '../../net/protocol.dart';
import '../theme/arena_theme.dart';

/// Effects still hanging over a player (Game_Rule v2 §8).
///
/// Without this the bridging effects are invisible: a player takes reflected
/// damage, or finds their clock short, with nothing on screen that says why.
class StatusBar extends StatelessWidget {
  const StatusBar({
    super.key,
    required this.status,
    required this.label,
    this.nowMs,
  });

  final PlayerStatus status;
  final String label;

  /// Injectable so a test does not have to race the wall clock.
  final int? nowMs;

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();

    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final chips = <Widget>[
      if (status.shield) const _Chip(icon: '🛡️', text: 'Chắn'),
      if (status.mirror) const _Chip(icon: '🪞', text: 'Dội'),
      if (status.haste) const _Chip(icon: '⏱️', text: '+50%'),
      if (status.rush) const _Chip(icon: '⏳', text: '−40%'),
      if (status.burnTurnsLeft > 0)
        _Chip(icon: '🔥', text: '${status.burnTurnsLeft} lượt'),
      if (_stunLeft(now) > 0) _Chip(icon: '💀', text: '${_stunLeft(now)}s'),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: 'Trạng thái $label',
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: chips,
      ),
    );
  }

  int _stunLeft(int now) {
    final until = status.stunnedUntil;
    if (until == null) return 0;
    final left = ((until - now) / 1000).ceil();
    return left > 0 ? left : 0;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Arena.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Arena.ink, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 2),
          Text(
            text,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Arena.ink,
            ),
          ),
        ],
      ),
    );
  }
}
