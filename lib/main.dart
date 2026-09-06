import 'package:flutter/material.dart';

import 'ui/home_screen.dart';

void main() => runApp(const WordArenaApp());

class WordArenaApp extends StatelessWidget {
  const WordArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word Arena',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
