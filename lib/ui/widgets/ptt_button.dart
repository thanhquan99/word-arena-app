import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/arena_theme.dart';
import 'package:flutter/services.dart';

import '../../net/api_client.dart';
import '../../speech/recorder.dart';
import '../../speech/stt_client.dart';

/// Hold-to-talk button: records while held, transcribes on release.
///
/// Push-to-talk rather than always-on because the two players may sit in the
/// same room, where an open microphone would pick up the opponent.
class PttButton extends StatefulWidget {
  const PttButton({
    super.key,
    required this.api,
    required this.onTranscript,
    this.enabled = true,
  });

  final ApiClient api;
  final void Function(String transcript) onTranscript;
  final bool enabled;

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton> {
  final _recorder = MicRecorder();

  SttClient? _stt;
  StreamSubscription<dynamic>? _audioSub;
  StreamSubscription<Transcript>? _transcriptSub;

  bool _recording = false;
  String _partial = '';
  String _status = 'Giữ để nói';

  @override
  void dispose() {
    _teardown();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_recording || !widget.enabled) return;
    setState(() {
      _recording = true;
      _partial = '';
      _status = 'Đang xin quyền…';
    });
    HapticFeedback.mediumImpact();

    try {
      if (!await _recorder.hasPermission()) {
        setState(() {
          _recording = false;
          _status = 'Không có quyền micro';
        });
        return;
      }

      // Tokens are single-use and expire in 15 minutes, so one is fetched per
      // recording rather than cached.
      final token = await widget.api.fetchSttToken();
      final stt = await SttClient.connect(token: token.token);
      _stt = stt;
      _transcriptSub = stt.transcripts.listen(_onTranscript);

      setState(() => _status = 'Đang nghe…');
      final audio = await _recorder.start();
      _audioSub = audio.listen(stt.sendAudio);
    } catch (e) {
      await _teardown();
      setState(() {
        _recording = false;
        _status = 'Lỗi micro';
      });
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    HapticFeedback.lightImpact();
    setState(() {
      _recording = false;
      _status = 'Đang chấm…';
    });

    await _recorder.stop();
    await _audioSub?.cancel();
    _audioSub = null;
    _stt?.commit();
  }

  void _onTranscript(Transcript t) {
    if (!mounted) return;
    if (!t.isFinal) {
      setState(() => _partial = t.text);
      return;
    }

    widget.onTranscript(t.text);
    _teardown();
    setState(() {
      _partial = '';
      _status = 'Giữ để nói';
    });
  }

  /// Closes the socket as soon as the answer is in. Leaving it open would bill
  /// for the whole match instead of the seconds actually spoken.
  Future<void> _teardown() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _transcriptSub?.cancel();
    _transcriptSub = null;
    await _stt?.close();
    _stt = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_partial.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_partial,
                style: const TextStyle(color: Arena.ink, fontSize: 16)),
          ),
        Text(_status, style: const TextStyle(color: Arena.inkSoft, fontSize: 12)),
        const SizedBox(height: 8),
        GestureDetector(
          onTapDown: (_) => _start(),
          onTapUp: (_) => _stop(),
          onTapCancel: _stop,
          child: Container(
            height: 72,
            width: double.infinity,
            decoration: BoxDecoration(
              color: !widget.enabled
                  ? Arena.surface2
                  : _recording
                      ? Arena.enemy
                      : Arena.accent,
              borderRadius: BorderRadius.circular(36),
            ),
            child: Center(
              child: Text(
                _recording ? 'THẢ ĐỂ GỬI' : 'GIỮ ĐỂ NÓI',
                style: const TextStyle(
                  color: Arena.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
