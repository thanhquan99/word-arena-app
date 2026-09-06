import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../content/content_repository.dart';
import '../game/bloc/game_bloc.dart';
import '../game/bloc/game_event.dart';
import '../game/bloc/game_state.dart';
import '../net/api_client.dart';
import 'match_end_screen.dart';
import 'resolve_screen.dart';
import 'widgets/board_widget.dart';

/// Hosts one match: the board, the resolve overlay, and the end screen.
class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final _api = ApiClient();
  late GameBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = _newBloc();
  }

  GameBloc _newBloc() => GameBloc(
        content: AssetContentRepository(),
        api: _api,
      )..add(const GameStarted());

  @override
  void dispose() {
    _bloc.close();
    _api.dispose();
    super.dispose();
  }

  void _restart() {
    final old = _bloc;
    setState(() => _bloc = _newBloc());
    old.close();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        body: BlocBuilder<GameBloc, GameState>(
          builder: (context, state) {
            if (state.missions.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.phase == GamePhase.ended) {
              return MatchEndScreen(
                state: state,
                onPlayAgain: _restart,
                onHome: () => Navigator.of(context).pop(),
              );
            }

            return Stack(
              children: [
                BoardWidget(
                  state: state,
                  onMissionTapped: (index) =>
                      _bloc.add(MissionTapped(index)),
                ),
                if (state.phase == GamePhase.resolving)
                  ResolveScreen(api: _api),
                if (state.isStunned) _StunOverlay(until: state.stunUntil!),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Shown while the player is stunned.
///
/// Counts down rather than just saying "stunned": without a number the pause
/// reads as the game having frozen.
class _StunOverlay extends StatefulWidget {
  const _StunOverlay({required this.until});

  final DateTime until;

  @override
  State<_StunOverlay> createState() => _StunOverlayState();
}

class _StunOverlayState extends State<_StunOverlay> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.until.difference(DateTime.now());
    final seconds = (remaining.inMilliseconds / 1000).clamp(0.0, 99.0);

    return IgnorePointer(
      child: Container(
        color: Colors.red.withValues(alpha: 0.2),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💫', style: TextStyle(fontSize: 56)),
              const Text(
                'Choáng!',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${seconds.toStringAsFixed(1)}s',
                style: const TextStyle(fontSize: 22, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
