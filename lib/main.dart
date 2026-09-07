import 'package:flutter/material.dart';

import 'ui/home_screen.dart';
import 'ui/theme/arena_theme.dart';

void main() => runApp(const WordArenaApp());

class WordArenaApp extends StatelessWidget {
  const WordArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word Arena',
      theme: Arena.theme,
      home: const HomeScreen(),
    );
  }
}
