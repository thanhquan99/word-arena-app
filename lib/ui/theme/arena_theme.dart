import 'package:flutter/material.dart';

/// Direction A — "Playground": one warm, light world.
///
/// Chosen over a dark arena and a neon esports look because the game's
/// content is English text a learner has to read under time pressure, and a
/// light ground gives that text the most contrast. See
/// word-arena-docs/docs/game-design/MOBILE_GAME_ART_DESIGN_PIPELINE.md.
///
/// The generated pet sprites are drawn for this ground — dark outlines on
/// warm bodies — so they are unreadable on the dark scheme this replaces.
abstract final class Arena {
  // ---- ground ----
  static const bg = Color(0xFFFFF8EC);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFFFF3E0);

  /// Ink is both the text colour and **every** outline in the game.
  ///
  /// Deliberately not per-component: the single constant outline is what
  /// makes cards, bars, buttons and pets read as one game rather than
  /// separate widgets that happen to share a screen.
  static const ink = Color(0xFF2A1D12);
  static const inkSoft = Color(0xFF8A7561);

  // ---- semantic ----
  static const accent = Color(0xFFFFC02E);
  static const self = Color(0xFF2FB35F);
  static const enemy = Color(0xFFF4623A);

  /// Health-bar warning colours, applied below the thresholds in
  /// [hp_bar_widget.dart] so a player *sees* the mercy rule take effect.
  static const warn = Color(0xFFFF9A1F);

  /// Difficulty tier colours, indexed 1..4 to match `tierMultiplier` in
  /// game/logic/damage.dart. Clamped on read rather than thrown: bad content
  /// must not crash a running match.
  static const _tiers = [
    Color(0xFF4A9DF0), // 1 — x0.8
    Color(0xFF2FB35F), // 2 — x1.0
    Color(0xFFFF9A1F), // 3 — x1.3
    Color(0xFFF4623A), // 4 — x1.6
  ];

  static Color tier(int t) => _tiers[t.clamp(1, _tiers.length) - 1];

  // ---- shape ----
  static const radius = 20.0;
  static const radiusSm = 13.0;
  static const borderW = 3.0;
  static const borderWSm = 2.5;

  static Border get border => Border.all(color: ink, width: borderW);
  static Border get borderSm => Border.all(color: ink, width: borderWSm);

  /// Hard offset shadow with no blur — the signature of this direction. A
  /// blurred shadow reads as Material and breaks the flat, inked look.
  static const lift = [BoxShadow(color: ink, offset: Offset(0, 5))];
  static const liftSm = [BoxShadow(color: ink, offset: Offset(0, 3))];
  static const pressed = [BoxShadow(color: ink, offset: Offset(0, 1))];

  // ---- type ----
  //
  // Two faces, two roles. Baloo 2 carries the HUD; Nunito carries every piece
  // of English the player has to read. Keeping them separate is deliberate:
  // the learning content must never be set in a display face, because 60% of
  // players abandon a game over text they cannot read comfortably.
  static const display = 'Baloo2';
  static const body = 'Nunito';

  /// Display style — match verdicts, pet names, button labels.
  static TextStyle head(double size, {Color? color}) => TextStyle(
        fontFamily: display,
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? ink,
      );

  /// Content style — mission prompts, objectives, anything in English.
  static TextStyle text(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) =>
      TextStyle(
        fontFamily: body,
        fontSize: size,
        fontWeight: weight,
        color: color ?? ink,
      );

  /// Small uppercase label — section headings, type names on cards.
  static TextStyle caps(double size, {Color? color}) => TextStyle(
        fontFamily: body,
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: size * 0.09,
        color: color ?? inkSoft,
      );

  // ---- motion ----
  static const tap = Duration(milliseconds: 100);
  static const screen = Duration(milliseconds: 300);
  static const damage = Duration(milliseconds: 600);

  /// The app-wide theme. Light, with the ink colour driving text and dividers
  /// so a widget that forgets to reach for [Arena] still lands close.
  static ThemeData get theme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
      ).copyWith(
        surface: surface,
        onSurface: ink,
        primary: accent,
        onPrimary: ink,
        secondary: self,
        error: enemy,
      ),
      // Body text defaults to Nunito; the display face is applied per-widget
      // through [head] so it never leaks onto English content.
      textTheme: base.textTheme
          .apply(bodyColor: ink, displayColor: ink, fontFamily: body)
          .copyWith(
            displayLarge: base.textTheme.displayLarge
                ?.copyWith(fontFamily: display, color: ink),
            displayMedium: base.textTheme.displayMedium
                ?.copyWith(fontFamily: display, color: ink),
            headlineLarge: base.textTheme.headlineLarge
                ?.copyWith(fontFamily: display, color: ink),
            headlineMedium: base.textTheme.headlineMedium
                ?.copyWith(fontFamily: display, color: ink),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface2,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: display,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      dividerColor: ink,
    );
  }

  /// The standard raised panel: white, thick-outlined, hard-shadowed.
  static BoxDecoration panel({
    Color? color,
    double? corner,
    List<BoxShadow>? shadow,
  }) =>
      BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(corner ?? radius),
        border: border,
        boxShadow: shadow ?? lift,
      );
}

/// A button in Direction A's language: flat fill, thick outline, and a shadow
/// that collapses on press so it feels like a physical key.
///
/// Written as a widget rather than a ThemeData button style because the press
/// travel — moving down by the shadow's own offset — is not expressible
/// through [ButtonStyle].
class ArenaButton extends StatefulWidget {
  const ArenaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.icon,
    this.compact = false,
    this.content = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;

  /// Smaller padding and shadow, for buttons that sit inside a panel.
  final bool compact;

  /// Set when the label is *learning content* rather than a HUD word — a
  /// multiple-choice answer, for instance. Those keep the body face, because
  /// the English a player has to read must never be set in a display face.
  final bool content;

  @override
  State<ArenaButton> createState() => _ArenaButtonState();
}

class _ArenaButtonState extends State<ArenaButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final fill = enabled ? (widget.color ?? Arena.accent) : Arena.surface2;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: Arena.tap,
          transform: Matrix4.translationValues(0, _down ? 4 : 0, 0),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 14 : 20,
            vertical: widget.compact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(Arena.radiusSm),
            border: Arena.borderSm,
            boxShadow: _down
                ? Arena.pressed
                : (widget.compact ? Arena.liftSm : Arena.lift),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: widget.compact ? 16 : 19, color: Arena.ink),
                const SizedBox(width: 7),
              ],
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: widget.content
                    ? Arena.text(
                        widget.compact ? 14 : 16,
                        color: enabled ? Arena.ink : Arena.inkSoft,
                        weight: FontWeight.w800,
                      )
                    : Arena.head(
                        widget.compact ? 13 : 15,
                        color: enabled ? Arena.ink : Arena.inkSoft,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
