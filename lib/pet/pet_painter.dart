import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pet_spec.dart';

/// Draws the phoenix in profile, rigged as seven joints on independent clocks.
///
/// This is the fallback for [PetView] when no `.riv` asset ships for a pet,
/// and it is also the reference the Rive rig is built to match: the joint
/// pivots below are the same coordinates the artboard uses.
///
/// Everything is in the design space described by [_designSize]; the painter
/// scales that to whatever box it is given, so one set of coordinates serves
/// the 52px board portrait and the 190px inspector alike.
class PetPainter extends CustomPainter {
  const PetPainter({
    required this.spec,
    required this.pose,
    required this.t,
    this.oneShot = 0,
  });

  final PetSpec spec;
  final PetPose pose;

  /// Looping clock, 0..1 over [cycle].
  final double t;

  /// One-shot progress, 0..1, for [PetPose.cast] and [PetPose.hurt].
  /// Zero when no one-shot is running.
  final double oneShot;

  /// Period of the idle loop, in seconds. Every joint's rate is a fraction of
  /// this and none divide evenly into it, so the loop never visibly repeats.
  static const cycle = 3.4;

  /// The coordinate space the paths below are authored in. Chosen to leave
  /// room for the crest above and the tail behind without clipping.
  static const _designSize = Size(146, 142);
  static const _designOrigin = Offset(-8, -38);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / _designSize.width,
      size.height / _designSize.height,
    );
    canvas.save();
    canvas.translate(
      (size.width - _designSize.width * scale) / 2,
      (size.height - _designSize.height * scale) / 2,
    );
    canvas.scale(scale);
    canvas.translate(-_designOrigin.dx, -_designOrigin.dy);

    _paintBird(canvas);
    canvas.restore();
  }

  // ---- joint clocks -------------------------------------------------------
  // Each joint runs at its own rate and phase. Nothing shares a period, so
  // the eye cannot lock onto the loop — that phase offset is what separates
  // "alive" from "GIF".

  double _wave(double period, {double phase = 0}) =>
      math.sin((t * cycle / period + phase) * 2 * math.pi);

  bool get _flying => pose != PetPose.perch;

  void _paintBird(Canvas canvas) {
    final casting = pose == PetPose.cast && oneShot > 0;
    final hurting = pose == PetPose.hurt && oneShot > 0;

    // Body: a slow figure-of-eight drift while airborne, a breath while perched.
    final bodyDx = _flying ? _wave(3.4) * 1.2 : 0.0;
    final bodyDy = _flying ? _wave(3.4, phase: .25) * 2.2 - 1.4 : _wave(3.9) * .6;
    var bodyRot = _flying ? _wave(3.4) * 0.024 : 0.0;
    var bodyScale = 1.0;

    if (casting) {
      // Recoil, then lunge forward. The overshoot is what reads as force.
      final p = oneShot;
      final lunge = p < .35 ? p / .35 : (1 - (p - .35) / .65);
      bodyRot += (p < .35 ? .09 : -.12) * lunge;
      bodyScale = 1 + (p < .35 ? -.10 : .13) * lunge;
    }
    if (hurting) {
      bodyRot += math.sin(oneShot * math.pi * 3) * .10 * (1 - oneShot);
    }

    canvas.save();
    canvas.translate(52 + bodyDx, 52 + bodyDy);
    canvas.rotate(bodyRot);
    canvas.scale(bodyScale);
    canvas.translate(-52, -52);

    _paintTail(canvas, casting);
    _paintFarWing(canvas, casting);
    _paintLegs(canvas);
    _paintTorso(canvas);
    _paintNearWing(canvas, casting);
    _paintNeckAndHead(canvas, casting, hurting);

    canvas.restore();
  }

  // ---- pieces -------------------------------------------------------------

  Paint get _stroke => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = PetSpec.outline;

  Paint _fill(Color c) => Paint()
    ..style = PaintingStyle.fill
    ..color = c;

  void _shape(Canvas canvas, Path path, Color fill, {double width = 2.5}) {
    canvas.drawPath(path, _fill(fill));
    canvas.drawPath(path, _stroke..strokeWidth = width);
  }

  /// Five streamers from the hip, the outer ones darker so the fan has depth.
  void _paintTail(Canvas canvas, bool casting) {
    final sway = _wave(3.4, phase: -.065) * (_flying ? .075 : .045);
    canvas.save();
    canvas.translate(76, 56);
    canvas.rotate(sway);
    canvas.translate(-76, -56);

    _shape(canvas, _p('M74 50 Q100 50 124 34 Q104 62 78 60 Z'), spec.dark, width: 2.3);
    _shape(canvas, _p('M74 56 Q102 66 126 66 Q100 80 78 70 Z'), spec.dark, width: 2.3);
    _shape(canvas, _p('M74 53 Q100 58 122 48 Q100 72 78 65 Z'), spec.primary, width: 2.3);
    _shape(canvas, _p('M74 59 Q96 74 116 84 Q92 84 76 72 Z'), spec.primary, width: 2.3);
    _shape(canvas, _p('M74 56 Q94 66 110 64 Q92 78 76 69 Z'), spec.secondary, width: 2.3);

    canvas.restore();
  }

  /// Behind the torso, slightly out of phase with the near wing. This is the
  /// joint that creates depth — without it the bird reads as a flat cutout.
  void _paintFarWing(Canvas canvas, bool casting) {
    final beat = _flying ? _wave(0.72, phase: .1) : 0.0;
    final rot = _flying ? (0.10 - beat * 0.19) : 0.35;
    final sc = _flying ? (0.96 + beat * .06) : 0.70;

    canvas.save();
    canvas.translate(52, 44);
    canvas.rotate(rot);
    canvas.scale(sc);
    canvas.translate(-52, -44);

    _shape(canvas, _p('M52 44 Q42 16 56 -12 Q64 12 66 34 Z'), spec.dark, width: 2.4);

    canvas.restore();
  }

  /// Only swings while airborne; perched, the bird stands on them.
  void _paintLegs(Canvas canvas) {
    final sway = _flying ? _wave(3.4, phase: -.13) * .06 : 0.0;
    canvas.save();
    canvas.translate(54, 65);
    canvas.rotate(sway);
    canvas.translate(-54, -65);

    // Far leg, darker, reads as behind.
    _limb(canvas, _p('M60 64 L63 76 L59 82'), spec.dark, 6, 3.6);
    _limb(canvas, _p('M59 82 L52 85'), spec.dark, 4.6, 2.6);
    _limb(canvas, _p('M59 82 L64 86'), spec.dark, 4.6, 2.6);

    // Near leg with three toes.
    _limb(canvas, _p('M52 64 L55 77 L49 85'), spec.secondary, 7.4, 4.4);
    for (final toe in const ['M49 85 L40 88', 'M49 85 L47 92', 'M49 85 L57 89']) {
      _limb(canvas, _p(toe), spec.secondary, 5.2, 2.9);
    }
    canvas.restore();
  }

  /// A limb is an outline stroke with the colour stroked on top, which gives
  /// a solid inked look without building a closed path for every bone.
  void _limb(Canvas canvas, Path path, Color color, double outer, double inner) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outer
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = PetSpec.outline,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = inner
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  void _paintTorso(Canvas canvas) {
    final body = _p('M40 45 Q55 37 71 45 Q81 51 77 60 Q67 70 52 68 Q40 63 37 54 Q36 48 40 45 Z');
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [spec.light, spec.primary, spec.dark],
          stops: const [0, .48, 1],
        ).createShader(const Rect.fromLTWH(36, 37, 46, 33)),
    );
    canvas.drawPath(body, _stroke..strokeWidth = 2.7);

    _shape(canvas, _p('M41 50 Q48 47 52 53 Q53 61 48 66 Q41 64 38 56 Q37 52 41 50 Z'),
        spec.secondary, width: 1.9);

    // Rim light along the spine.
    canvas.drawPath(
      _p('M43 45 Q57 39 71 47'),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = spec.light.withValues(alpha: .72),
    );
  }

  /// The big one. A phoenix wing has to out-mass the torso, or the bird reads
  /// as a chicken — that was the single biggest fix during art review.
  void _paintNearWing(Canvas canvas, bool casting) {
    final beat = _flying ? _wave(0.72) : 0.0;
    var rot = _flying ? (0.16 - beat * 0.42) : 0.42;
    var sc = _flying ? (1 + beat * .06) : 0.72;

    if (casting) {
      final p = oneShot;
      rot = p < .35 ? .45 * (p / .35) : -.60 * (1 - (p - .35) / .65);
      sc = 1 + (p < .35 ? -.18 : .22) * (p < .35 ? p / .35 : 1 - (p - .35) / .65);
    }

    canvas.save();
    canvas.translate(50, 45);
    canvas.rotate(rot);
    canvas.scale(sc);
    canvas.translate(-50, -45);

    _shape(canvas, _p('M50 46 Q40 14 52 -20 Q60 8 64 34 Z'), spec.dark);
    _shape(canvas, _p('M51 46 Q48 12 66 -18 Q68 10 68 36 Z'), spec.primary);
    _shape(canvas, _p('M52 47 Q56 14 80 -10 Q74 14 72 38 Z'), spec.primary);
    _shape(canvas, _p('M53 48 Q64 20 90 4 Q78 22 74 42 Z'), spec.dark);
    _shape(canvas, _p('M45 47 Q44 26 60 14 Q74 26 74 46 Q60 54 45 47 Z'),
        spec.secondary, width: 2.6);
    canvas.drawPath(
      _p('M49 45 Q50 31 60 23 Q69 32 69 44 Q59 49 49 45 Z'),
      _fill(spec.light.withValues(alpha: .7)),
    );

    canvas.restore();
  }

  /// The neck pivots at the shoulder so the whole S-curve and the head move
  /// together: a bird's head leads its body, it does not bob in place.
  ///
  /// Painted last so the crest sweeps over the wing instead of under it.
  void _paintNeckAndHead(Canvas canvas, bool casting, bool hurting) {
    var rot = _flying ? _wave(3.4, phase: -.09) * .04 : _wave(3.9, phase: -.09) * .02;
    var dx = 0.0, dy = 0.0;

    if (casting) {
      final p = oneShot;
      if (p < .4) {
        rot += .23 * (p / .4);
        dx = 4 * (p / .4);
      } else {
        final q = 1 - (p - .4) / .6;
        rot += -.26 * q;
        dx = -5 * q;
        dy = -3 * q;
      }
    }
    if (hurting) {
      final q = 1 - oneShot;
      rot += .28 * q;
      dx = 5 * q;
    }

    canvas.save();
    canvas.translate(44 + dx, 46 + dy);
    canvas.rotate(rot);
    canvas.translate(-44, -46);

    // Neck: slim S from the shoulder, back and up, then forward to the skull.
    final neck = _p('M42 47 Q33 43 29 34 Q26 26 30 20 Q34 16 37 19 Q33 25 34 32 Q37 40 46 45 Z');
    canvas.drawPath(
      neck,
      Paint()
        ..shader = LinearGradient(
          colors: [spec.light, spec.primary],
        ).createShader(const Rect.fromLTWH(26, 16, 20, 31)),
    );
    canvas.drawPath(neck, _stroke..strokeWidth = 2.5);

    _paintCrest(canvas);

    // Skull: a wedge, wider than the neck.
    final skull = _p('M28 13.5 Q37.5 12.5 39.5 19.5 Q39.5 26.5 32.5 29 Q23 29 21 22.5 Q21 15.5 28 13.5 Z');
    canvas.drawPath(
      skull,
      Paint()
        ..shader = LinearGradient(
          colors: [spec.light, spec.primary],
        ).createShader(const Rect.fromLTWH(21, 12, 19, 17)),
    );
    canvas.drawPath(skull, _stroke..strokeWidth = 2.5);

    // Brow ridge: the hard angle that stops it reading as a plush toy.
    canvas.drawPath(
      _p('M23.5 19.5 Q27.5 16.8 31.5 18.8'),
      _stroke..strokeWidth = 2.1,
    );

    _paintEye(canvas, hurting);
    _paintBeak(canvas);

    canvas.restore();
  }

  void _paintCrest(Canvas canvas) {
    final sway = _wave(1.5, phase: -.073) * .12;
    canvas.save();
    canvas.translate(34, 18);
    canvas.rotate(sway);
    canvas.translate(-34, -18);

    _shape(canvas, _p('M36 19 Q50 10 58 -6 Q52 12 39 22 Z'), spec.dark, width: 2.3);
    _shape(canvas, _p('M34 17 Q47 5 52 -10 Q48 8 38 20 Z'), spec.primary, width: 2.3);
    _shape(canvas, _p('M31 15 Q40 3 42 -11 Q41 6 35 18 Z'), spec.secondary, width: 2.3);
    _shape(canvas, _p('M28 14 Q31 3 29 -7 Q34 4 32 17 Z'), spec.light, width: 2.1);

    canvas.restore();
  }

  void _paintEye(Canvas canvas, bool hurting) {
    const centre = Offset(28, 21);

    // A blink every few seconds, and eyes squeezed shut while hurt. The blink
    // costs almost nothing and is the detail people notice first.
    final blinking = hurting ||
        (t * cycle) % 4.6 > 4.44;

    canvas.drawOval(
      Rect.fromCenter(center: centre, width: 7, height: 7.4),
      _fill(const Color(0xFFFFFAF0)),
    );
    if (!blinking) {
      canvas.drawCircle(const Offset(27.2, 21.3), 2.1, _fill(PetSpec.outline));
      canvas.drawCircle(const Offset(27.2, 21.3), 1, _fill(spec.light));
      canvas.drawCircle(const Offset(26.2, 20), .9, _fill(Colors.white));
    } else {
      canvas.drawArc(
        Rect.fromCenter(center: centre, width: 7.6, height: 8),
        math.pi, math.pi, true, _fill(spec.primary),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: centre, width: 7, height: 7.4),
      _stroke..strokeWidth = 1.9,
    );
  }

  /// Long and hooked. In profile the beak is the strongest silhouette cue —
  /// it is what makes the shape read as a bird at 44 logical pixels.
  void _paintBeak(Canvas canvas) {
    _shape(canvas, _p('M23 18.5 L4 23 Q2 24.4 4.6 25.6 L23 26 Z'), spec.secondary, width: 2.1);
    _shape(canvas, _p('M6 24.8 L23 26 L22 28.4 Q13 27.6 6 25.4 Z'), spec.secondary, width: 2);
    canvas.drawCircle(const Offset(19, 22.4), .6, _fill(PetSpec.outline));
  }

  @override
  bool shouldRepaint(PetPainter old) =>
      old.t != t ||
      old.pose != pose ||
      old.oneShot != oneShot ||
      old.spec.id != spec.id;

  // ---- tiny SVG path subset ----------------------------------------------

  /// Parses the M/L/Q/Z subset the art above is authored in.
  ///
  /// Deliberately not a general SVG parser: the paths are ours, the command
  /// set is fixed, and a real parser would be a dependency for no gain.
  static Path _p(String d) {
    final path = Path();
    final tokens = RegExp(r'[MLQZ]|-?\d*\.?\d+')
        .allMatches(d)
        .map((m) => m.group(0)!)
        .toList();

    var i = 0;
    double num_() => double.parse(tokens[i++]);

    while (i < tokens.length) {
      switch (tokens[i++]) {
        case 'M':
          path.moveTo(num_(), num_());
        case 'L':
          path.lineTo(num_(), num_());
        case 'Q':
          path.quadraticBezierTo(num_(), num_(), num_(), num_());
        case 'Z':
          path.close();
      }
    }
    return path;
  }
}
