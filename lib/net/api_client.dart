import 'dart:convert';

import 'package:http/http.dart' as http;

import '../content/models.dart';
import 'grade_result.dart';

/// A short-lived STT token from the API server. Single-use, 15 minute TTL.
class SttToken {
  const SttToken({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => 'ApiException: $message';
}

/// Client for `word-arena-api`.
///
/// The base URL is supplied at build time:
/// `--dart-define=API_URL=http://192.168.2.241:3000`
///
/// On a real phone this has to be the dev machine's LAN address — a device
/// cannot reach the Mac's `localhost`.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? const String.fromEnvironment('API_URL'),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _gradeTimeout = Duration(seconds: 3);

  Future<SttToken> fetchSttToken() async {
    if (baseUrl.isEmpty) {
      throw ApiException(
        'API_URL is not set — run with --dart-define=API_URL=http://<lan-ip>:3000',
      );
    }

    final http.Response res;
    try {
      res = await _client
          .post(Uri.parse('$baseUrl/stt-token'))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      throw ApiException('could not reach the API at $baseUrl: $e');
    }

    if (res.statusCode != 200) {
      throw ApiException('API returned ${res.statusCode}: ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return SttToken(
      token: body['token'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(body['expiresAt'] as int),
    );
  }

  /// Grades one objective.
  ///
  /// Never throws: a match must not stall because the server is slow or down.
  /// Any failure returns a degraded pass, which favours the player — being
  /// wrongly marked down over a network hiccup is the worst kind of
  /// frustration.
  Future<GradeResult> gradeObjective({
    required Objective objective,
    required String transcript,
    String? level,
  }) async {
    if (baseUrl.isEmpty) return GradeResult.degradedPass();

    final payload = <String, dynamic>{
      'objectiveId': objective.id,
      'tier': objective.gradingTier.name,
      'objectiveText': objective.text,
      'transcript': transcript,
      if (objective.exactAnswer != null) 'exactAnswer': objective.exactAnswer,
      if (objective.acceptedItems != null) 'acceptedItems': objective.acceptedItems,
      if (objective.minRequired != null) 'minRequired': objective.minRequired,
      if (objective.targetWord != null) 'targetWord': objective.targetWord,
      if (objective.sampleAnswers != null) 'sampleAnswers': objective.sampleAnswers,
      'level': ?level,
    };

    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/grade'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_gradeTimeout);

      if (res.statusCode == 200) {
        return GradeResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }

      // A 400 means the payload and the server contract have drifted apart.
      // Log loudly: this is a bug to fix, not a transient failure to absorb.
      // ignore: avoid_print
      print('[grade] contract mismatch ${res.statusCode}: ${res.body}');
      return GradeResult.degradedPass();
    } catch (e) {
      // ignore: avoid_print
      print('[grade] ${objective.id} could not be graded, letting it pass: $e');
      return GradeResult.degradedPass();
    }
  }

  void dispose() => _client.close();
}
