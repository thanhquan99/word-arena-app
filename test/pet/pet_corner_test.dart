import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/content/models.dart';
import 'package:word_arena/game/bloc/game_state.dart';
import 'package:word_arena/net/protocol.dart';
import 'package:word_arena/pet/pet_atlas.dart';
import 'package:word_arena/pet/pet_spec.dart';
import 'package:word_arena/pet/pet_sprite_painter.dart';
import 'package:word_arena/pet/pet_view.dart';
import 'package:word_arena/ui/widgets/pet_corner.dart';

/// A board state with no missions — the pets do not read the grid.
GameState _state({
  GamePhase phase = GamePhase.idle,
  int playerHp = GameState.maxHp,
  int botHp = GameState.maxHp,
  double? youDealt,
  double? theyDealt,
  DateTime? stunUntil,
}) {
  // Since feature-06 the pets react to the `strike` beat and read who dealt
  // what straight off the result, rather than inferring direction from which
  // health bar happened to drop.
  final hasTurn = youDealt != null || theyDealt != null;

  return GameState(
    phase: phase,
    slots: const <Mission>[],
    yourHp: playerHp,
    opponentHp: botHp,
    turnStage: hasTurn ? TurnStage.strike : null,
    lastTurn: !hasTurn
        ? null
        : TurnSettledEvent(
            outcome: (youDealt ?? 0) > 0 ? TurnOutcome.youWin : TurnOutcome.opponentWin,
            reason: TurnReason.count,
            you: SideResult(n: 1, completedTime: 0, damageDealt: youDealt ?? 0),
            opponent: SideResult(n: 1, completedTime: 0, damageDealt: theyDealt ?? 0),
            blocked: const [],
          ),
    yourStatus: PlayerStatus(
      stunnedUntil: stunUntil?.millisecondsSinceEpoch,
    ),
  );
}

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox.square(dimension: 80, child: child))),
    );

/// The pose the PetView underneath is currently showing.
PetPose _pose(WidgetTester tester) =>
    tester.widget<PetView>(find.byType(PetView)).pose;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await PetAtlas.load('phoenix');
    await PetAtlas.load('tiger');
  });

  group('resting pose', () {
    testWidgets('perches while the board is idle', (tester) async {
      await tester.pumpWidget(_host(PetCorner(
        spec: PetSpec.fire,
        state: _state(),
        isPlayer: true,
      )));
      await tester.pump();
      expect(_pose(tester), PetPose.perch);
    });

    testWidgets('the acting player flies while resolving', (tester) async {
      await tester.pumpWidget(_host(PetCorner(
        spec: PetSpec.fire,
        state: _state(phase: GamePhase.resolving),
        isPlayer: true,
      )));
      await tester.pump();
      expect(_pose(tester), PetPose.fly);
    });

    testWidgets('the waiting opponent stays perched while resolving',
        (tester) async {
      await tester.pumpWidget(_host(PetCorner(
        spec: PetSpec.storm,
        state: _state(phase: GamePhase.resolving),
        isPlayer: false,
      )));
      await tester.pump();
      expect(_pose(tester), PetPose.perch);
    });

    testWidgets('a stunned player is grounded even mid-resolve',
        (tester) async {
      await tester.pumpWidget(_host(PetCorner(
        spec: PetSpec.fire,
        state: _state(
          phase: GamePhase.resolving,
          stunUntil: DateTime.now().add(const Duration(seconds: 3)),
        ),
        isPlayer: true,
      )));
      await tester.pump();
      expect(_pose(tester), PetPose.perch);
    });
  });

  group('hit reactions', () {
    testWidgets('casts when the opponent loses health', (tester) async {
      await tester.pumpWidget(_host(PetCorner(
        spec: PetSpec.fire,
        state: _state(),
        isPlayer: true,
      )));
      await tester.pump();

      await tester.pumpWidget(_host(PetCorner(
        spec: PetSpec.fire,
        state: _state(botHp: GameState.maxHp - 5, youDealt: 5),
        isPlayer: true,
      )));
      await tester.pump();
      expect(_pose(tester), PetPose.cast);
    });

    testWidgets('takes the hit when its own side loses health',
        (tester) async {
      await tester.pumpWidget(_host(PetCorner(
        spec: PetSpec.fire,
        state: _state(),
        isPlayer: true,
      )));
      await tester.pump();

      await tester.pumpWidget(_host(PetCorner(
        spec: PetSpec.fire,
        state: _state(playerHp: GameState.maxHp - 4, theyDealt: 4),
        isPlayer: true,
      )));
      await tester.pump();
      expect(_pose(tester), PetPose.hurt);
    });

    testWidgets('the same damage seen twice does not replay', (tester) async {
      Widget at(GameState s) => _host(PetCorner(
            spec: PetSpec.fire,
            state: s,
            isPlayer: true,
          ));

      await tester.pumpWidget(at(_state()));
      await tester.pump();

      final hit = _state(botHp: GameState.maxHp - 3, youDealt: 3);
      await tester.pumpWidget(at(hit));
      await tester.pump();
      expect(_pose(tester), PetPose.cast);

      // Let the one-shot finish, then rebuild with the identical state: a
      // rebuild for some unrelated reason must not fire the pose again.
      await tester.pump(const Duration(milliseconds: 700));
      expect(_pose(tester), PetPose.perch);

      await tester.pumpWidget(at(hit));
      await tester.pump();
      expect(_pose(tester), PetPose.perch);
    });

    testWidgets('returns to rest once the reaction has played', (tester) async {
      await tester.pumpWidget(_host(PetCorner(
        spec: PetSpec.fire,
        state: _state(),
        isPlayer: true,
      )));
      await tester.pump();

      await tester.pumpWidget(_host(PetCorner(
        spec: PetSpec.fire,
        state: _state(botHp: GameState.maxHp - 6, youDealt: 6),
        isPlayer: true,
      )));
      await tester.pump();
      expect(_pose(tester), PetPose.cast);

      // cast is 4 frames at 8 fps = 500ms.
      await tester.pump(const Duration(milliseconds: 700));
      expect(_pose(tester), PetPose.perch);
    });
  });

  group('rendering', () {
    testWidgets('draws through the sprite path for a pet with art',
        (tester) async {
      await tester.pumpWidget(_host(PetCorner(
        spec: PetSpec.fire,
        state: _state(),
        isPlayer: true,
      )));
      await tester.pump();
      expect(find.byType(PetSpritePlayer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mirrors the opponent so the two pets face each other',
        (tester) async {
      await tester.pumpWidget(_host(PetCorner(
        spec: PetSpec.storm,
        state: _state(),
        isPlayer: false,
      )));
      await tester.pump();
      expect(tester.widget<PetView>(find.byType(PetView)).mirrored, isTrue);
    });

    testWidgets('dims a defeated pet rather than removing it', (tester) async {
      await tester.pumpWidget(_host(PetCorner(
        spec: PetSpec.fire,
        state: _state(playerHp: 0),
        isPlayer: true,
      )));
      await tester.pump();

      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.byType(PetView), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, lessThan(1));
      expect(find.byType(PetView), findsOneWidget);
    });
  });
}
