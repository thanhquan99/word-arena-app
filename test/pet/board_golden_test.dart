import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/content/models.dart';
import 'package:word_arena/game/bloc/game_state.dart';
import 'package:word_arena/pet/pet_atlas.dart';
import 'package:word_arena/ui/widgets/board_widget.dart';

/// Renders the whole board with pets in place, so the layout is checked
/// visually rather than only by widget-tree assertions.
///
/// Run with: flutter test --update-goldens test/pet/board_golden_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await PetAtlas.load('phoenix');
    await PetAtlas.load('tiger');
  });

  Mission mission(
    String prompt,
    MissionType type,
    int tier,
    int n,
    Pace pace,
  ) =>
      Mission(
        id: prompt,
        type: type,
        tier: tier,
        pace: pace,
        prompt: prompt,
        objectives: [
          for (var i = 0; i < n; i++)
            Objective(
              id: '$prompt-$i',
              text: 'objective ${i + 1}',
              mode: ObjectiveMode.speak,
              timeLimitSec: 8,
              gradingTier: GradingTier.binary,
            ),
        ],
      );

  testWidgets('board with both pets', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));

    final state = GameState(
      missions: [
        mission('farmer', MissionType.vocabulary, 2, 4, Pace.medium),
        mission('look after', MissionType.phrasalVerb, 3, 4, Pace.medium),
        mission('thought / taught', MissionType.pronunciation, 2, 2, Pace.fast),
        mission('apple / carrot', MissionType.oddOneOut, 1, 2, Pace.fast),
        mission('He goes to school', MissionType.tense, 4, 4, Pace.heavy),
      ],
      playerHp: 38,
      botHp: 21,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BoardWidget(state: state, onMissionTapped: (_) {}),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(BoardWidget),
      matchesGoldenFile('goldens/board_with_pets.png'),
    );
  });
}
