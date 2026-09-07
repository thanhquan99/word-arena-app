import 'package:flutter/material.dart';

import 'pet_spec.dart';
import 'pet_view.dart';

/// Spike harness for the pet rig.
///
/// Not part of the game: it exists so the rig can be judged on a real device
/// at real sizes, and so the Rive-vs-painter question can be answered by
/// looking rather than by argument.
class PetDemoScreen extends StatefulWidget {
  const PetDemoScreen({super.key});

  @override
  State<PetDemoScreen> createState() => _PetDemoScreenState();
}

class _PetDemoScreenState extends State<PetDemoScreen> {
  PetSpec _spec = PetSpec.fire;
  PetPose _pose = PetPose.fly;

  /// Bumped on every one-shot so the widget rebuilds and replays it, even
  /// when the pose value itself has not changed.
  int _shotId = 0;

  void _fire(PetPose pose) {
    setState(() {
      _pose = pose;
      _shotId++;
    });
  }

  /// Called by [PetView] when a one-shot animation has actually finished, so
  /// the rest pose is restored on the real frame rather than a guessed delay.
  void _restore() {
    if (mounted && _pose != PetPose.fly) setState(() => _pose = PetPose.fly);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EC),
      appBar: AppBar(
        title: const Text('Pet rig — spike'),
        backgroundColor: const Color(0xFFFFF3E0),
        foregroundColor: PetSpec.outline,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Big, so the joints are actually visible.
            Center(
              child: PetView(
                key: ValueKey('big-$_shotId'),
                spec: _spec,
                pose: _pose,
                size: 220,
                onPoseFinished: _restore,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _spec.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: PetSpec.outline,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // At the size it actually ships at, next to a health bar.
            const _Label('Kích thước thật trên board (52px)'),
            Row(
              children: [
                PetView(spec: _spec, pose: _pose, size: 52),
                const SizedBox(width: 8),
                Expanded(child: _FakeHpBar(color: _spec.primary)),
                const SizedBox(width: 8),
                PetView(
                  spec: PetSpec.ice,
                  pose: PetPose.perch,
                  size: 52,
                  mirrored: true,
                ),
              ],
            ),
            const SizedBox(height: 24),

            const _Label('Chọn pet'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in PetSpec.all)
                  _Chip(
                    label: p.shortName,
                    color: p.primary,
                    selected: p.id == _spec.id,
                    onTap: () => setState(() => _spec = p),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            const _Label('Trạng thái'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  label: 'Bay',
                  color: _spec.primary,
                  selected: _pose == PetPose.fly,
                  onTap: () => setState(() => _pose = PetPose.fly),
                ),
                _Chip(
                  label: 'Đậu',
                  color: _spec.primary,
                  selected: _pose == PetPose.perch,
                  onTap: () => setState(() => _pose = PetPose.perch),
                ),
                _Chip(
                  label: 'Chưởng',
                  color: _spec.dark,
                  selected: false,
                  onTap: () => _fire(PetPose.cast),
                ),
                _Chip(
                  label: 'Bị đánh',
                  color: _spec.dark,
                  selected: false,
                  onTap: () => _fire(PetPose.hurt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: Color(0xFF8A7561),
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: PetSpec.outline, width: 2.5),
          boxShadow: const [
            BoxShadow(color: PetSpec.outline, offset: Offset(0, 3)),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : PetSpec.outline,
          ),
        ),
      ),
    );
  }
}

class _FakeHpBar extends StatelessWidget {
  const _FakeHpBar({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: 15,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: PetSpec.outline, width: 3),
        ),
        child: FractionallySizedBox(
          widthFactor: .68,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      );
}
