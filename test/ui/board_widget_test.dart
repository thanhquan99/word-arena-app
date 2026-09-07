import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/content/models.dart';
import 'package:word_arena/game/bloc/game_state.dart';
import 'package:word_arena/game/logic/effects.dart';
import 'package:word_arena/ui/widgets/board_widget.dart';
import 'package:word_arena/ui/widgets/mission_card_widget.dart';

Objective _objective(String id) => Objective(
      id: id,
      text: 'say something',
      mode: ObjectiveMode.speak,
      timeLimitSec: 8,
      gradingTier: GradingTier.binary,
      sampleAnswers: const ['ok'],
    );

Mission _mission(
  String id, {
  String prompt = 'farmer',
  int objectives = 2,
  int tier = 2,
  MissionType type = MissionType.vocabulary,
  MissionEffect? effect,
}) =>
    Mission(
      id: id,
      type: type,
      tier: tier,
      pace: Pace.fast,
      prompt: prompt,
      objectives: [for (var i = 0; i < objectives; i++) _objective('$id-$i')],
      effect: effect,
    );

GameState _state({
  GamePhase phase = GamePhase.idle,
  List<Mission>? missions,
  int playerHp = 50,
  int botHp = 50,
}) =>
    GameState(
      phase: phase,
      slots: missions ?? [for (var i = 0; i < 4; i++) _mission('m$i')],
      yourHp: playerHp,
      opponentHp: botHp,
      // Taps only reach the bloc once the socket is up (§3.2 is server-run).
      connection: MatchLink.ready,
    );

Widget _host(GameState state, {void Function(int)? onTap}) => MaterialApp(
      home: Scaffold(
        body: BoardWidget(
          state: state,
          onMissionTapped: onTap ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('renders one card per mission slot', (tester) async {
    await tester.pumpWidget(_host(_state()));

    expect(find.byType(MissionCardWidget), findsNWidgets(4));
  });

  testWidgets('shows both health bars', (tester) async {
    await tester.pumpWidget(_host(_state(playerHp: 41, botHp: 32)));

    expect(find.text('Bạn'), findsOneWidget);
    expect(find.text('Đối thủ'), findsOneWidget);
    expect(find.text('41'), findsOneWidget);
    expect(find.text('32'), findsOneWidget);
  });

  testWidgets('a tap on a card reports its slot index', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(_host(_state(), onTap: tapped.add));

    await tester.tap(find.byType(MissionCardWidget).first);
    await tester.pump();

    expect(tapped, [0]);
  });

  testWidgets('cards ignore taps while a mission is being resolved',
      (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      _host(_state(phase: GamePhase.resolving), onTap: tapped.add),
    );

    await tester.tap(find.byType(MissionCardWidget).first);
    await tester.pump();

    expect(tapped, isEmpty);
  });

  testWidgets('a long prompt is truncated rather than overflowing',
      (tester) async {
    // The longest prompt in the sample content, which used to spill out of a
    // fixed-size Flame rectangle.
    const long = 'often / she / to / goes / the / gym';
    await tester.pumpWidget(_host(_state(
      missions: [for (var i = 0; i < 4; i++) _mission('m$i', prompt: long)],
    )));

    // A widget test fails on overflow, so reaching this point is the assertion.
    final text = tester.widget<Text>(find.text(long).first);
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('one sword per objective marks what the mission is worth',
      (tester) async {
    await tester.pumpWidget(_host(_state(
      missions: [
        _mission('a', objectives: 4),
        for (var i = 1; i < 4; i++) _mission('m$i', objectives: 2),
      ],
    )));

    // 4 + (3 slots x 2) = 10 swords on a four-card board.
    expect(find.text('⚔️'), findsNWidgets(10));
  });

  testWidgets('a plain mission shows no effect badge', (tester) async {
    await tester.pumpWidget(_host(_state()));

    expect(find.byType(EffectBadge), findsNothing);
  });

  testWidgets('an effect is announced before the card is tapped',
      (tester) async {
    // Game_Rule section 8: taking a risky mission is meant to be a decision,
    // so the badge has to be readable while the card is still untapped.
    await tester.pumpWidget(_host(_state(
      missions: [
        _mission('a', tier: 4, effect: MissionEffect.gamble),
        for (var i = 1; i < 4; i++) _mission('m$i'),
      ],
    )));

    expect(find.byType(EffectBadge), findsOneWidget);
    expect(find.text(effectInfo(MissionEffect.gamble).label), findsOneWidget);
  });

  testWidgets('an effect explains itself before the card is tapped',
      (tester) async {
    // Every effect works for real since feature-05, so the tooltip teaches the
    // rule rather than apologising for a missing opponent.
    await tester.pumpWidget(_host(_state(
      missions: [
        _mission('a', effect: MissionEffect.allOut),
        for (var i = 1; i < 4; i++) _mission('m$i'),
      ],
    )));

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, contains('Khô máu'));
    expect(tooltip.message, contains('Cấm phòng thủ'));
  });
}
