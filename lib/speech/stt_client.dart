import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Một mẩu transcript từ ElevenLabs.
class Transcript {
  const Transcript({required this.text, required this.isFinal});

  final String text;
  final bool isFinal;
}

/// Client WebSocket tới ElevenLabs Scribe v2 Realtime.
///
/// Protocol (đọc trực tiếp từ SDK chính thức `@elevenlabs/elevenlabs-js`):
///   URL     wss://api.elevenlabs.io/v1/speech-to-text/realtime
///           `?model_id=scribe_v2_realtime&audio_format=pcm_16000`
///           `&commit_strategy=manual&token=<token>`
///   Gửi     `{"message_type":"input_audio_chunk","audio_base_64":"...","sample_rate":16000}`
///   Chốt    cùng dạng, audio_base_64 rỗng + `"commit":true`
///   Nhận    `{"message_type":"partial_transcript"|"final_transcript","text":"..."}`
///
/// ⚠️ Audio phải **base64**, không phải binary thô.
class SttClient {
  SttClient._(this._channel, this._transcripts);

  final WebSocketChannel _channel;
  final Stream<Transcript> _transcripts;

  static const _host = 'wss://api.elevenlabs.io';
  static const _sampleRate = 16000;

  Stream<Transcript> get transcripts => _transcripts;

  /// Mở kết nối. Dùng `commit_strategy=manual` — mình tự chốt khi thả nút PTT,
  /// không để VAD tự đoán (push-to-talk đã là tín hiệu rõ ràng rồi).
  static Future<SttClient> connect({required String token}) async {
    final uri = Uri.parse('$_host/v1/speech-to-text/realtime').replace(
      queryParameters: {
        'model_id': 'scribe_v2_realtime',
        'audio_format': 'pcm_$_sampleRate',
        'commit_strategy': 'manual',
        'language_code': 'en',
        'token': token,
      },
    );

    final channel = WebSocketChannel.connect(uri);
    await channel.ready;

    final transcripts = channel.stream
        .map((raw) => _parse(raw))
        .where((t) => t != null)
        .cast<Transcript>()
        .asBroadcastStream();

    return SttClient._(channel, transcripts);
  }

  static Transcript? _parse(dynamic raw) {
    if (raw is! String) return null;

    final msg = jsonDecode(raw) as Map<String, dynamic>;
    final type = msg['message_type'] as String?;

    return switch (type) {
      'partial_transcript' => Transcript(
          text: msg['text'] as String? ?? '',
          isFinal: false,
        ),
      'final_transcript' || 'final_transcript_with_timestamps' => Transcript(
          text: msg['text'] as String? ?? '',
          isFinal: true,
        ),
      _ => null, // các message_type còn lại đều là lỗi — xem log nếu cần
    };
  }

  void sendAudio(Uint8List pcmChunk) {
    _channel.sink.add(jsonEncode({
      'message_type': 'input_audio_chunk',
      'audio_base_64': base64Encode(pcmChunk),
      'sample_rate': _sampleRate,
    }));
  }

  /// Báo hết audio → server trả `final_transcript`.
  void commit() {
    _channel.sink.add(jsonEncode({
      'message_type': 'input_audio_chunk',
      'audio_base_64': '',
      'commit': true,
      'sample_rate': _sampleRate,
    }));
  }

  /// ⚠️ Bắt buộc gọi khi thả nút PTT.
  /// Để hở connection = trả tiền cho toàn bộ thời lượng trận, không chỉ lúc nói.
  Future<void> close() => _channel.sink.close();
}
