import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/content/models.dart';
import 'package:word_arena/game/bloc/game_bloc.dart';
import 'package:word_arena/game/bloc/game_event.dart';
import 'package:word_arena/game/bloc/game_state.dart';
import 'package:word_arena/net/api_client.dart';
import 'package:word_arena/net/match_socket.dart';
import 'package:word_arena/net/protocol.dart';
import 'package:word_arena/ui/resolve_screen.dart';

import '../support/fake_socket.dart';

/// `resolve_screen.dart` had no test at all before feature-05, and feature-05
/// rewrites it end to end — the two rules it now embodies (§3.4: pick your own
/// order, one clock for the card) are exactly the kind that break quietly.
void main() {
  late FakeChannel channel;
  late GameBloc bloc;

  Mission mission({int objectives = 3}) => Mission.fromJson({
        'id': 'm0',
        'type': 'vocabulary',
        'tier': 2,
        'pace': 'medium',
        'prompt': 'farmer',
        'objectives': [
          for (var i = 1; i <= objectives; i++)
            {
              'id': 'o$i',
              'text': 'Objective number $i',
              'mode': i.isEven ? 'select' : 'speak',
              'timeLimitSec': 8,
              'gradingTier': 'binary',
            },
        ],
      });

  GameState resolving({
    Set<String> completed = const {},
    Set<String> failed = const {},
    bool done = false,
    int cardSeconds = 20,
  }) {
    final m = mission();
    return GameState(
      phase: GamePhase.resolving,
      slots: [m],
      openedSlotIndex: 0,
      openedMission: m,
      objectives: m.objectives,
      yourCompleted: completed,
      yourFailed: failed,
      youAreDone: done,
      cardSeconds: cardSeconds,
      cardStartedAt: DateTime.now().millisecondsSinceEpoch,
      connection: MatchLink.ready,
    );
  }

  setUp(() {
    channel = FakeChannel();
    bloc = GameBloc(
      socket: MatchSocket(baseUrl: 'http://localhost:3000', connect: (_) => channel),
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  Future<void> show(WidgetTester tester, GameState state) async {
    bloc.emit(state);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(body: ResolveScreen(api: ApiClient(baseUrl: ''))),
        ),
      ),
    );
    await tester.pump();
  }

  group('§3.4 every objective at once', () {
    testWidgets('all objectives are on screen from the start', (tester) async {
      await show(tester, resolving());

      expect(find.text('Objective number 1'), findsOneWidget);
      expect(find.text('Objective number 2'), findsOneWidget);
      expect(find.text('Objective number 3'), findsOneWidget);
    });

    testWidgets('tapping the third objective opens it, not the first',
        (tester) async {
      await show(tester, resolving());

      await tester.tap(find.text('Objective number 3'));
      await tester.pump();

      // The answer panel shows only the chosen objective.
      expect(find.text('Objective number 1'), findsNothing);
      expect(find.text('Objective number 3'), findsOneWidget);
    });

    testWidgets('backing out returns to the full list', (tester) async {
      await show(tester, resolving());

      await tester.tap(find.text('Objective number 2'));
      await tester.pump();
      await tester.tap(find.text('Chọn objective khác'));
      await tester.pump();

      expect(find.text('Objective number 1'), findsOneWidget);
      expect(find.text('Objective number 3'), findsOneWidget);
    });

    testWidgets('a failed objective can be opened again', (tester) async {
      await show(tester, resolving(failed: {'o1'}));

      await tester.tap(find.text('Objective number 1'));
      await tester.pump();

      expect(find.text('Chọn objective khác'), findsOneWidget);
    });

    testWidgets('a completed objective cannot be reopened', (tester) async {
      await show(tester, resolving(completed: {'o1'}));

      await tester.tap(find.text('Objective number 1'));
      await tester.pump();

      // Still the list, not the answer panel.
      expect(find.text('Chọn objective khác'), findsNothing);
      expect(find.text('Objective number 2'), findsOneWidget);
    });
  });

  group('marks', () {
    testWidgets('done shows a tick, failed shows a cross', (tester) async {
      await show(tester, resolving(completed: {'o1'}, failed: {'o2'}));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('speaking and tapping objectives are told apart', (tester) async {
      await show(tester, resolving());

      expect(find.byIcon(Icons.mic), findsNWidgets(2)); // o1 and o3
      expect(find.byIcon(Icons.touch_app), findsOneWidget); // o2
    });
  });

  group('§3.4 one clock for the card', () {
    testWidgets('a single countdown is shown, not one per objective',
        (tester) async {
      await show(tester, resolving(cardSeconds: 20));

      expect(find.textContaining(' s'), findsOneWidget);
    });

    testWidgets('the countdown reflects the budget the server sent',
        (tester) async {
      await show(tester, resolving(cardSeconds: 24));

      expect(find.textContaining('24 s'), findsOneWidget);
    });

    testWidgets('an expired clock floors at zero rather than going negative',
        (tester) async {
      final m = mission();
      bloc.emit(GameState(
        phase: GamePhase.resolving,
        slots: [m],
        openedSlotIndex: 0,
        openedMission: m,
        objectives: m.objectives,
        cardSeconds: 5,
        // Started well before the budget allows.
        cardStartedAt: DateTime.now().millisecondsSinceEpoch - 30000,
        connection: MatchLink.ready,
      ));
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: Scaffold(body: ResolveScreen(api: ApiClient(baseUrl: ''))),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('0 s'), findsOneWidget);
    });
  });

  group('the Done button — §7.2', () {
    testWidgets('pressing Done sends the frame that locks completedTime',
        (tester) async {
      // The socket has to be live for the frame to go anywhere, so this one
      // test drives the real join before forcing the resolving state.
      bloc.add(const MatchJoined(mode: MatchMode.bot));
      await tester.pump();
      await tester.pump();

      await show(tester, resolving());

      await tester.tap(find.textContaining('Xong'));
      await tester.pump();

      expect(channel.sentTypes, contains('done'));
    });

    testWidgets('a clean sweep is offered as the good outcome', (tester) async {
      await show(tester, resolving(completed: {'o1', 'o2', 'o3'}));

      expect(find.text('Xong — chốt thời gian'), findsOneWidget);
    });

    testWidgets('an unfinished card warns what Done costs', (tester) async {
      await show(tester, resolving(completed: {'o1'}));

      expect(find.text('Xong (bỏ phần còn lại)'), findsOneWidget);
    });

    testWidgets('after Done the screen waits rather than offering more taps',
        (tester) async {
      await show(tester, resolving(done: true));

      expect(find.text('Đã chốt — chờ đối thủ'), findsOneWidget);
      expect(find.textContaining('Xong'), findsNothing);
    });
  });
}
