import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Ghi âm mic thành PCM16 stream cho STT.
///
/// ⚠️ `record` mặc định 44100Hz / 2 channel — ElevenLabs cần `pcm_16000`,
/// nên phải set rõ 16000 / 1 ở đây.
class MicRecorder {
  final _recorder = AudioRecorder();

  static const _config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 16000, // ElevenLabs pcm_16000
    numChannels: 1, // mono
    echoCancel: true, // 2 người ngồi cùng phòng → mic thu tiếng nhau
    noiseSuppress: true,
  );

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Bắt đầu ghi. Trả stream các chunk PCM16 thô.
  Future<Stream<Uint8List>> start() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Không có quyền micro');
    }
    return _recorder.startStream(_config);
  }

  Future<void> stop() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  /// Bắt buộc gọi khi rời màn hình — nếu không sẽ giữ mic và rò tài nguyên.
  Future<void> dispose() => _recorder.dispose();
}
