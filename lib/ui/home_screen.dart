import 'package:flutter/material.dart';

import 'theme/arena_theme.dart';

import '../spike/mic_spike_screen.dart';
import 'match_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Arena.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Word Arena', style: Arena.head(42)),
              const SizedBox(height: 48),
              ArenaButton(
                label: 'Chơi',
                icon: Icons.sports_esports,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MatchScreen()),
                ),
              ),
              const SizedBox(height: 12),
              // Kept from the mic spike: still the quickest way to check the
              // speech pipeline in isolation.
              ArenaButton(
                label: 'Mic spike (debug)',
                color: Arena.surface,
                compact: true,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MicSpikeScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
