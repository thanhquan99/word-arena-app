/// What the server returns for one graded objective.
///
/// Mirrors `GradeResult` in word-arena-api. See docs/technical/05-grading-system.md.
class GradeResult {
  const GradeResult({
    required this.passed,
    required this.multiplier,
    this.level,
    this.feedback,
    this.matchedItems,
    this.tookMs = 0,
    this.usedLlm = false,
    this.degraded = false,
  });

  final bool passed;

  /// Damage weight in [0, 1]. The app multiplies this in and never needs to
  /// know which grading tier produced it.
  final double multiplier;

  /// Only on the `scaled` tier: bad / normal / good / excellent.
  final String? level;

  /// Short Vietnamese hint. Absent on the LLM tiers — asking the model to also
  /// explain itself costs ~26% more latency, so detailed feedback comes from
  /// the background review pass instead.
  final String? feedback;

  /// Only on the `checklist` tier: which items were recognised.
  final List<String>? matchedItems;

  final int tookMs;
  final bool usedLlm;

  /// True when the app made this up locally because the server was
  /// unreachable — the objective was let through rather than failed.
  final bool degraded;

  /// A pass invented locally so a network problem never costs the player a point.
  factory GradeResult.degradedPass() =>
      const GradeResult(passed: true, multiplier: 1, degraded: true);

  factory GradeResult.fromJson(Map<String, dynamic> json) {
    return GradeResult(
      passed: json['passed'] as bool,
      multiplier: (json['multiplier'] as num).toDouble(),
      level: json['level'] as String?,
      feedback: json['feedback'] as String?,
      matchedItems: (json['matchedItems'] as List?)?.cast<String>(),
      tookMs: json['tookMs'] as int? ?? 0,
      usedLlm: json['usedLlm'] as bool? ?? false,
      degraded: json['degraded'] as bool? ?? false,
    );
  }
}
