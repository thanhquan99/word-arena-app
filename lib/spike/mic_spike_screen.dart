import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../net/api_client.dart';
import '../speech/recorder.dart';
import '../speech/stt_client.dart';

/// Một lần thử PTT.
class Attempt {
  Attempt({required this.text, required this.latencyMs, required this.ok});
  final String text;
  final int latencyMs;
  final bool ok;
}

/// Màn hình spike mic — code tạm, chỉ để đo 4 tiêu chí ở tasks.md Task 11:
///  1. Độ trễ thả nút → final transcript (<500ms, 20/20 lần)
///  2. Độ chính xác giọng Việt nói tiếng Anh (>=80%)
///  3. Chi phí thật (xem dashboard ElevenLabs)
///  4. WebSocket đóng hẳn khi thả nút (chống rò tiền)
class MicSpikeScreen extends StatefulWidget {
  const MicSpikeScreen({super.key});

  @override
  State<MicSpikeScreen> createState() => _MicSpikeScreenState();
}

class _MicSpikeScreenState extends State<MicSpikeScreen> {
  final _api = ApiClient();
  final _recorder = MicRecorder();

  SttClient? _stt;
  StreamSubscription<dynamic>? _audioSub;
  StreamSubscription<Transcript>? _transcriptSub;
  Stopwatch? _sinceRelease;

  bool _recording = false;
  String _partial = '';
  String _status = 'Giữ nút để nói';
  final _attempts = <Attempt>[];

  int get _okCount => _attempts.where((a) => a.ok).length;

  @override
  void dispose() {
    _audioSub?.cancel();
    _transcriptSub?.cancel();
    _stt?.close();
    _recorder.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _onPressStart() async {
    if (_recording) return;
    setState(() {
      _recording = true;
      _partial = '';
      _status = 'Đang xin token…';
    });
    HapticFeedback.mediumImpact();

    try {
      if (!await _recorder.hasPermission()) {
        setState(() {
          _recording = false;
          _status = '❌ Không có quyền micro';
        });
        return;
      }

      // Token single-use, sống 15 phút → xin mới mỗi lần bấm.
      final token = await _api.fetchSttToken();
      final stt = await SttClient.connect(token: token.token);
      _stt = stt;

      _transcriptSub = stt.transcripts.listen(_onTranscript);

      setState(() => _status = '🎤 Đang nghe…');
      final audio = await _recorder.start();
      _audioSub = audio.listen(stt.sendAudio);
    } catch (e) {
      await _teardown();
      setState(() {
        _recording = false;
        _status = '❌ $e';
      });
    }
  }

  Future<void> _onPressEnd() async {
    if (!_recording) return;
    HapticFeedback.lightImpact();

    setState(() {
      _recording = false;
      _status = '⏳ Đang chờ transcript…';
    });

    // Bấm giờ từ lúc thả nút — đây là con số tiêu chí 1.
    _sinceRelease = Stopwatch()..start();

    await _recorder.stop();
    await _audioSub?.cancel();
    _audioSub = null;
    _stt?.commit();

    // Không nhận được final trong 3s → tính là hụt.
    Timer(const Duration(seconds: 3), () {
      if (_sinceRelease?.isRunning ?? false) {
        _record(text: _partial, ok: false);
        setState(() => _status = '❌ Quá hạn — không có final transcript');
      }
    });
  }

  void _onTranscript(Transcript t) {
    if (!t.isFinal) {
      setState(() => _partial = t.text);
      return;
    }
    _record(text: t.text, ok: t.text.trim().isNotEmpty);
    setState(() {
      _partial = t.text;
      _status = 'Xong — giữ nút để thử tiếp';
    });
  }

  void _record({required String text, required bool ok}) {
    final ms = _sinceRelease?.elapsedMilliseconds ?? -1;
    _sinceRelease?.stop();
    _attempts.insert(0, Attempt(text: text, latencyMs: ms, ok: ok));
    // Đóng WebSocket ngay khi có kết quả — tiêu chí 4, chống rò tiền.
    _teardown();
  }

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
    final latencies = _attempts.where((a) => a.ok).map((a) => a.latencyMs).toList();
    final avg = latencies.isEmpty
        ? 0
        : latencies.reduce((a, b) => a + b) ~/ latencies.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mic Spike'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(_attempts.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          _MetricsBar(
            total: _attempts.length,
            ok: _okCount,
            avgMs: avg,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(_status, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 8),
                Text(
                  _partial.isEmpty ? '—' : _partial,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _attempts.length,
              itemBuilder: (_, i) {
                final a = _attempts[i];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    a.ok ? Icons.check_circle : Icons.error,
                    color: a.ok ? Colors.green : Colors.red,
                  ),
                  title: Text(a.text.isEmpty ? '(rỗng)' : a.text),
                  trailing: Text(
                    '${a.latencyMs}ms',
                    style: TextStyle(
                      color: a.latencyMs < 500 ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: GestureDetector(
              onTapDown: (_) => _onPressStart(),
              onTapUp: (_) => _onPressEnd(),
              onTapCancel: _onPressEnd,
              child: Container(
                height: 96,
                decoration: BoxDecoration(
                  color: _recording ? Colors.red : Colors.blue,
                  borderRadius: BorderRadius.circular(48),
                ),
                child: Center(
                  child: Text(
                    _recording ? 'ĐANG NGHE — thả để gửi' : 'GIỮ ĐỂ NÓI',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsBar extends StatelessWidget {
  const _MetricsBar({required this.total, required this.ok, required this.avgMs});

  final int total;
  final int ok;
  final int avgMs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Metric(label: 'Lần thử', value: '$total'),
          _Metric(label: 'Thành công', value: '$ok/$total'),
          _Metric(
            label: 'Độ trễ TB',
            value: avgMs == 0 ? '—' : '${avgMs}ms',
            highlight: avgMs > 0 && avgMs < 500,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: highlight ? Colors.green : null,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
