import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/content/models.dart';
import 'package:word_arena/net/protocol.dart';
import 'package:word_arena/ui/widgets/turn_result_overlay.dart';

/// This overlay is where the v2 rules are taught. If it explains a turn wrongly
/// the player learns the wrong rule, so each `reason` gets its own test.
void main() {
  TurnSettledEvent turn({
    TurnOutcome outcome = TurnOutcome.youWin,
    TurnReason reason = TurnReason.count,
    int yourN = 3,
    int theirN = 2,
    int yourTime = 8200,
    int theirTime = 9100,
    double yourDamage = 4.8,
    double theirDamage = 0,
    List<String> blocked = const [],
    MissionEffect? effect,
  }) =>
      TurnSettledEvent(
        outcome: outcome,
        reason: reason,
        you: SideResult(n: yourN, completedTime: yourTime, damageDealt: yourDamage),
        opponent: SideResult(n: theirN, completedTime: theirTime, damageDealt: theirDamage),
        blocked: blocked,
        effect: effect,
      );

  Future<void> show(WidgetTester tester, TurnSettledEvent event) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TurnResultOverlay(turn: event))),
    );
    await tester.pump();
  }

  group('reason: count', () {
    testWidgets('a win names both counts', (tester) async {
      await show(tester, turn());

      expect(find.text('Thắng lượt'), findsOneWidget);
      expect(find.textContaining('3 objective'), findsWidgets);
    });

    testWidgets('a loss says the damage was discarded — §7.2 winner-takes-all',
        (tester) async {
      await show(tester, turn(
        outcome: TurnOutcome.opponentWin,
        yourN: 2,
        theirN: 3,
        yourDamage: 0,
        theirDamage: 4.8,
      ));

      // Doing two objectives and getting nothing for them is the single most
      // confusing outcome in v2, so it is said in words.
      expect(find.textContaining('bị bỏ vì thua lượt'), findsOneWidget);
    });
  });

  group('reason: time — §7.2 tie-break', () {
    testWidgets('both clocks are shown so the loss is checkable',
        (tester) async {
      await show(tester, turn(
        reason: TurnReason.time,
        outcome: TurnOutcome.opponentWin,
        yourN: 4,
        theirN: 4,
        yourTime: 24000,
        theirTime: 21000,
        yourDamage: 0,
        theirDamage: 6.4,
      ));

      expect(find.text('24.0 s'), findsOneWidget);
      expect(find.text('21.0 s'), findsOneWidget);
      expect(find.textContaining('xong sớm hơn'), findsOneWidget);
    });

    testWidgets('winning on the clock is explained too', (tester) async {
      await show(tester, turn(
        reason: TurnReason.time,
        yourN: 4,
        theirN: 4,
        yourTime: 21000,
        theirTime: 24000,
      ));

      expect(find.text('Thắng lượt'), findsOneWidget);
      expect(find.textContaining('bạn xong sớm hơn'), findsOneWidget);
    });
  });

  group('reason: tie', () {
    testWidgets('an exact tie costs nobody health', (tester) async {
      await show(tester, turn(
        outcome: TurnOutcome.draw,
        reason: TurnReason.tie,
        yourN: 2,
        theirN: 2,
        yourTime: 18000,
        theirTime: 18000,
        yourDamage: 0,
      ));

      expect(find.text('Hoà lượt'), findsOneWidget);
      expect(find.textContaining('Không ai mất máu'), findsOneWidget);
      expect(find.text('không gây damage'), findsNWidgets(2));
    });
  });

  group('reason: blocked — §7.3', () {
    testWidgets('the doc example: guarding the wrong objectives still costs you',
        (tester) async {
      // The attacker finished objectives 1 and 2; the defender finished 3 and
      // 4, which blocks nothing. Two damage lands anyway.
      await show(tester, turn(
        outcome: TurnOutcome.opponentWin,
        reason: TurnReason.blocked,
        yourN: 2,
        theirN: 2,
        yourDamage: 0,
        theirDamage: 3.2,
        blocked: const [],
      ));

      expect(find.textContaining('chỉ chặn được đúng objective'), findsOneWidget);
      // Nothing was blocked, so no block note is shown to soften it.
      expect(find.textContaining('Chặn được'), findsNothing);
    });

    testWidgets('a partial block reports how many objectives it stopped',
        (tester) async {
      await show(tester, turn(
        reason: TurnReason.blocked,
        blocked: const ['o1', 'o2'],
      ));

      expect(find.textContaining('Chặn được 2 objective'), findsOneWidget);
    });
  });

  group('reason: allout — §8.3', () {
    testWidgets('both sides deal damage and the overlay says why',
        (tester) async {
      await show(tester, turn(
        outcome: TurnOutcome.bothDamaged,
        reason: TurnReason.allout,
        yourN: 4,
        theirN: 2,
        yourDamage: 6.4,
        theirDamage: 3.2,
        effect: MissionEffect.allOut,
      ));

      expect(find.text('Khô máu — cả hai cùng mất'), findsOneWidget);
      expect(find.text('−6 máu'), findsOneWidget);
      expect(find.text('−3 máu'), findsOneWidget);
    });
  });

  group('reason: both_defense', () {
    testWidgets('an empty turn is named as one', (tester) async {
      await show(tester, turn(
        outcome: TurnOutcome.empty,
        reason: TurnReason.bothDefense,
        yourDamage: 0,
      ));

      expect(find.text('Vòng trống'), findsOneWidget);
      expect(find.textContaining('Cả hai cùng phòng thủ'), findsOneWidget);
    });
  });

  group('the objective table — §7.3', () {
    List<Objective> objectives(int n) => [
          for (var i = 1; i <= n; i++)
            Objective.fromJson({
              'id': 'o$i',
              'text': 'Objective $i',
              'mode': 'speak',
              'timeLimitSec': 8,
              'gradingTier': 'binary',
            }),
        ];

    Future<void> showTable(
      WidgetTester tester, {
      required TurnSettledEvent event,
      required Set<String> yours,
      required Set<String> theirs,
      int count = 4,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TurnResultOverlay(
            turn: event,
            objectives: objectives(count),
            yourCompleted: yours,
            opponentCompleted: theirs,
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('every objective gets a row', (tester) async {
      await showTable(
        tester,
        event: turn(),
        yours: const {'o1', 'o2'},
        theirs: const {'o3'},
      );

      for (var i = 1; i <= 4; i++) {
        expect(find.text('Objective $i'), findsOneWidget);
      }
    });

    testWidgets('marks show who finished what', (tester) async {
      await showTable(
        tester,
        event: turn(),
        yours: const {'o1', 'o2'},
        theirs: const {'o3'},
        count: 3,
      );

      // o1, o2 ours; o3 theirs — three ticks, three crosses.
      expect(find.text('✅'), findsNWidgets(3));
      expect(find.text('✖️'), findsNWidgets(3));
    });

    testWidgets('a blocked objective is marked with a shield', (tester) async {
      await showTable(
        tester,
        event: turn(reason: TurnReason.blocked, blocked: const ['o1']),
        yours: const {'o1'},
        theirs: const {'o1'},
        count: 2,
      );

      expect(find.text('✅🛡️'), findsNWidgets(2));
    });

    testWidgets('the doc example: guarding what was never attacked blocks nothing',
        (tester) async {
      // The attacker did 1 and 2; the defender did 3 and 4. No shields — and
      // seeing that is what makes "I defended and still took full damage" stop
      // looking like a bug.
      await showTable(
        tester,
        event: turn(
          outcome: TurnOutcome.opponentWin,
          reason: TurnReason.blocked,
          blocked: const [],
        ),
        yours: const {'o3', 'o4'},
        theirs: const {'o1', 'o2'},
      );

      expect(find.text('✅🛡️'), findsNothing);
      expect(find.text('✅'), findsNWidgets(4));
    });

    testWidgets('no table when the card is unknown', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TurnResultOverlay(turn: turn())),
      ));
      await tester.pump();

      expect(find.text('Bạn'), findsOneWidget); // the scoreline heading only
    });
  });

  group('effects', () {
    testWidgets('a bridging effect warns it lands next turn', (tester) async {
      await show(tester, turn(effect: MissionEffect.shield));

      expect(find.textContaining('có hiệu lực ở lượt sau'), findsOneWidget);
    });

    testWidgets('an immediate effect makes no such promise', (tester) async {
      await show(tester, turn(effect: MissionEffect.heal));

      expect(find.textContaining('có hiệu lực ở lượt sau'), findsNothing);
      expect(find.textContaining('Heal'), findsOneWidget);
    });

    testWidgets('a plain card mentions no effect at all', (tester) async {
      await show(tester, turn());

      expect(find.textContaining('lượt sau'), findsNothing);
    });
  });
}
