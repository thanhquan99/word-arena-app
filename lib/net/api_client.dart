import 'dart:convert';

import 'package:http/http.dart' as http;

/// Token STT do API server cấp. Sống 15 phút, dùng một lần.
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

/// Client gọi `word-arena-api`.
///
/// Base URL truyền lúc build:
/// `--dart-define=API_URL=http://192.168.2.241:3000`
///
/// Phải là IP LAN của máy dev — iPhone thật không thấy `localhost` của Mac.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? const String.fromEnvironment('API_URL'),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<SttToken> fetchSttToken() async {
    if (baseUrl.isEmpty) {
      throw ApiException('Thiếu API_URL — chạy với --dart-define=API_URL=http://<ip-lan>:3000');
    }

    final http.Response res;
    try {
      res = await _client
          .post(Uri.parse('$baseUrl/stt-token'))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      throw ApiException('Không gọi được API ($baseUrl): $e');
    }

    if (res.statusCode != 200) {
      throw ApiException('API trả ${res.statusCode}: ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return SttToken(
      token: body['token'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(body['expiresAt'] as int),
    );
  }

  void dispose() => _client.close();
}
