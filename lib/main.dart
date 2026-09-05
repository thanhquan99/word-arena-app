import 'package:flutter/material.dart';

import 'spike/mic_spike_screen.dart';

void main() => runApp(const WordArenaApp());

class WordArenaApp extends StatelessWidget {
  const WordArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word Arena',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      // Tạm trỏ thẳng vào màn hình spike — sẽ thay bằng game thật ở Phase 3.
      home: const MicSpikeScreen(),
    );
  }
}
