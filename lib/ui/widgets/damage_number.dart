import 'package:flutter/material.dart';

/// A damage number that floats up and fades out, then reports that it is done.
///
/// The parent removes it on [onComplete] — otherwise every hit would leave a
/// widget behind and a long match would slowly lose frames.
class DamageNumber extends StatefulWidget {
  const DamageNumber({
    super.key,
    required this.amount,
    required this.onComplete,
  });

  final int amount;
  final VoidCallback onComplete;

  @override
  State<DamageNumber> createState() => _DamageNumberState();
}

class _DamageNumberState extends State<DamageNumber>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 800);
  static const _riseDistance = 60.0;

  late final AnimationController _controller = AnimationController(
    duration: _duration,
    vsync: this,
  );

  late final Animation<double> _rise = Tween<double>(
    begin: 0,
    end: -_riseDistance,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  late final Animation<double> _fade = Tween<double>(
    begin: 1,
    end: 0,
  ).animate(_controller);

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    // Leaking a controller here would cost a ticker on every single hit.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _rise.value),
          child: Opacity(opacity: _fade.value, child: child),
        ),
        child: Text(
          '-${widget.amount}',
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Color(0xFFEF5350),
            shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
          ),
        ),
      ),
    );
  }
}
