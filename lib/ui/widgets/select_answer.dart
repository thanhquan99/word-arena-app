import 'package:flutter/material.dart';

/// Tap-to-choose answers, used by Odd One Out.
///
/// The choices come from the mission prompt ("apple / banana / carrot"), so no
/// extra content field is needed.
class SelectAnswer extends StatelessWidget {
  const SelectAnswer({
    super.key,
    required this.prompt,
    required this.onSelected,
  });

  final String prompt;
  final void Function(String answer) onSelected;

  List<String> get _choices =>
      prompt.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (final choice in _choices)
          ElevatedButton(
            onPressed: () => onSelected(choice),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            child: Text(choice, style: const TextStyle(fontSize: 16)),
          ),
      ],
    );
  }
}
