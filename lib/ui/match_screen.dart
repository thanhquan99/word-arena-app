import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../game/bloc/game_bloc.dart';
import '../game/bloc/game_event.dart';
import '../game/bloc/game_state.dart';
import '../net/api_client.dart';
import '../net/match_socket.dart';
import '../net/protocol.dart';
import 'match_end_screen.dart';
import 'resolve_screen.dart';
import 'stance_overlay.dart';
import 'theme/arena_theme.dart';
import 'widgets/board_widget.dart';
import 'widgets/turn_result_overlay.dart';

/// Hosts one match: the board, the stance and resolve overlays, and the end
/// screen.
///
/// Since feature-05 a match is a conversation with the server, so this screen
/// also has to show what the connection is doing — a silent freeze is the one
/// thing a player cannot interpret.
class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, this.mode = MatchMode.bot});

  final MatchMode mode;

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

  GameBloc _newBloc() =>
      GameBloc(socket: MatchSocket())..add(MatchJoined(mode: widget.mode));

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
            if (state.phase == GamePhase.ended) {
              return MatchEndScreen(
                state: state,
                onPlayAgain: _restart,
                onHome: () => Navigator.of(context).pop(),
              );
            }

            if (state.slots.isEmpty) {
              return _Waiting(connection: state.connection);
            }

            return Stack(
              children: [
                BoardWidget(
                  state: state,
                  onMissionTapped: (index) => _bloc.add(CardTapped(index)),
                ),

                if (state.phase == GamePhase.stance) StanceOverlay(state: state),
                if (state.phase == GamePhase.resolving) ResolveScreen(api: _api),

                // The turn result stays up through scoring, which is the only
                // window the player has to read why the turn went that way.
                if (state.phase == GamePhase.scoring && state.lastTurn != null)
                  TurnResultOverlay(turn: state.lastTurn!),

                if (state.connection == MatchLink.connecting ||
                    state.connection == MatchLink.lost)
                  _ConnectionBanner(connection: state.connection),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Before the board arrives: connecting, or holding for a pvp opponent.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.connection});

  final MatchLink connection;

  @override
  Widget build(BuildContext context) {
    final message = switch (connection) {
      MatchLink.waitingForOpponent => 'Đang chờ đối thủ vào trận…',
      MatchLink.lost => 'Mất kết nối tới máy chủ',
      _ => 'Đang kết nối…',
    };

    return Container(
      color: Arena.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (connection != MatchLink.lost)
              const CircularProgressIndicator(color: Arena.accent),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Arena.inkSoft)),
          ],
        ),
      ),
    );
  }
}

/// A thin strip rather than a blocking dialog: the match may well still be
/// going, and a modal would hide the board it is describing.
class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.connection});

  final MatchLink connection;

  @override
  Widget build(BuildContext context) {
    final lost = connection == MatchLink.lost;

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: lost ? Arena.enemy : Arena.warn,
            borderRadius: BorderRadius.circular(Arena.radiusSm),
            border: Arena.borderSm,
          ),
          child: Text(
            lost ? 'Mất kết nối — trận đã kết thúc' : 'Đang nối lại…',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
