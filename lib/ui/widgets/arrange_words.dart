import 'package:flutter/material.dart';

import '../theme/arena_theme.dart';

/// Drag the scrambled words into order, used by Sentence Builder.
///
/// Sends the joined sentence as the transcript, so the server grades it with
/// the same `exact` tier it would use for a spoken answer.
class ArrangeWords extends StatefulWidget {
  const ArrangeWords({
    super.key,
    required this.prompt,
    required this.onSubmitted,
  });

  final String prompt;
  final void Function(String sentence) onSubmitted;

  @override
  State<ArrangeWords> createState() => _ArrangeWordsState();
}

class _ArrangeWordsState extends State<ArrangeWords> {
  late List<String> _words;

  @override
  void initState() {
    super.initState();
    _words = widget.prompt
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ReorderableListView(
            shrinkWrap: true,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                _words.insert(newIndex, _words.removeAt(oldIndex));
              });
            },
            children: [
              for (final word in _words)
                ListTile(
                  key: ValueKey(word),
                  dense: true,
                  title: Text(word, style: const TextStyle(fontSize: 16)),
                  trailing: const Icon(Icons.drag_handle),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ArenaButton(
          label: 'Xong',
          icon: Icons.check,
          onPressed: () => widget.onSubmitted(_words.join(' ')),
        ),
      ],
    );
  }
}
