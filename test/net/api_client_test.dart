import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:word_arena/content/models.dart';
import 'package:word_arena/net/api_client.dart';

/// Talks to a running word-arena-api. Skips itself when the server is not up,
/// so `flutter test` stays green without one.
Future<bool> _serverIsUp(String baseUrl) async {
  try {
    final res = await http
        .get(Uri.parse('$baseUrl/health'))
        .timeout(const Duration(milliseconds: 800));
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

Objective _objective({
  required String id,
  required GradingTier tier,
  String? exactAnswer,
  List<String>? acceptedItems,
  int? minRequired,
  String? targetWord,
  List<String>? sampleAnswers,
}) =>
    Objective(
      id: id,
      text: 'test objective',
      mode: ObjectiveMode.speak,
      timeLimitSec: 8,
      gradingTier: tier,
      exactAnswer: exactAnswer,
      acceptedItems: acceptedItems,
      minRequired: minRequired,
      targetWord: targetWord,
      sampleAnswers: sampleAnswers,
    );

void main() {
  const baseUrl = 'http://localhost:3000';
  late bool up;

  setUpAll(() async => up = await _serverIsUp(baseUrl));

  group('gradeObjective against a live server', () {
    late ApiClient api;
    setUp(() => api = ApiClient(baseUrl: baseUrl));
    tearDown(() => api.dispose());

    test('exact tier passes on a matching answer', () async {
      if (!up) return;
      final result = await api.gradeObjective(
        objective: _objective(
          id: 'odd-1-1',
          tier: GradingTier.exact,
          exactAnswer: 'carrot',
        ),
        transcript: 'carrot',
      );
      expect(result.passed, isTrue);
      expect(result.usedLlm, isFalse);
      expect(result.degraded, isFalse);
    }, skip: false);

    test('checklist tier returns proportional partial credit', () async {
      if (!up) return;
      final result = await api.gradeObjective(
        objective: _objective(
          id: 'vocab-1-1',
          tier: GradingTier.checklist,
          acceptedItems: const ['farm', 'farming', 'farmer', 'farmland'],
          minRequired: 3,
        ),
        transcript: 'farm farming',
      );
      expect(result.passed, isFalse);
      expect(result.multiplier, closeTo(2 / 3, 0.01));
      expect(result.matchedItems, ['farm', 'farming']);
    });

    test('a pronunciation trap is graded without an LLM call', () async {
      if (!up) return;
      final result = await api.gradeObjective(
        objective: _objective(
          id: 'pron-1-1',
          tier: GradingTier.binary,
          targetWord: 'thought',
        ),
        transcript: 'thought',
      );
      expect(result.passed, isTrue);
      expect(result.usedLlm, isFalse);
    });
  });

  group('when the server is unreachable', () {
    test('the objective is let through rather than failed', () async {
      final api = ApiClient(baseUrl: 'http://127.0.0.1:59999');
      addTearDown(api.dispose);

      final result = await api.gradeObjective(
        objective: _objective(
          id: 'x',
          tier: GradingTier.binary,
          sampleAnswers: const ['anything'],
        ),
        transcript: 'hello',
      );

      expect(result.passed, isTrue, reason: 'a network fault must not cost a point');
      expect(result.degraded, isTrue);
    });

    test('an unset API_URL behaves the same way', () async {
      final api = ApiClient(baseUrl: '');
      addTearDown(api.dispose);

      final result = await api.gradeObjective(
        objective: _objective(
          id: 'x',
          tier: GradingTier.exact,
          exactAnswer: 'a',
        ),
        transcript: 'a',
      );

      expect(result.degraded, isTrue);
    });
  });
}
