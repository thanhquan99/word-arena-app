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
                if (state.isStunned) const _StunOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StunOverlay extends StatelessWidget {
  const _StunOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: Colors.red.withValues(alpha: 0.2),
        child: const Center(
          child: Text(
            'Choáng!',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
