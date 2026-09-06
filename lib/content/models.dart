/// Content model: a realm holds missions, a mission holds objectives.
///
/// Field names mirror the `/grade` contract exactly — the server reads
/// `objectiveId`, `objectiveText` and `gradingTier`, and rejects anything else
/// with a 400. See docs/technical/06-erd.md §3.5.
library;

enum MissionType {
  vocabulary,
  phrasalVerb,
  grammar,
  idiom,
  pronunciation,
  tense,
  roleplay,
  oddOneOut,
  sentenceBuilder,
  listening,
}

/// How long a mission takes, which drives the 2-fast / 2-medium / 1-heavy mix
/// on the map (Game_Rule §2).
enum Pace { fast, medium, heavy }

/// Which grader the server runs. `exact` and `checklist` never reach an LLM.
enum GradingTier { exact, checklist, binary, scaled }

/// How the player answers. `select` and `arrange` do not use the microphone.
enum ObjectiveMode { speak, select, arrange, listen }

/// A modifier carried by a mission (Game_Rule section 8).
///
/// `doubleDamage` rather than `double` because `double` is a Dart keyword; its
/// JSON spelling stays `"double"` to match the rules doc.
enum MissionEffect {
  heal,
  doubleDamage,
  shield,
  burn,
  reveal,
  haste,
  stun,
  gamble,
  mirror,
  silence,
  rush,
  coop,
  duel,
}

/// Parse an enum from its snake_case JSON spelling.
///
/// Throws rather than falling back to a default: silently mapping an unknown
/// value would hide a content bug until it showed up as strange gameplay.
T _enumFromJson<T extends Enum>(List<T> values, String raw, String field) {
  final wanted = raw.replaceAll('_', '').toLowerCase();
  for (final v in values) {
    if (v.name.toLowerCase() == wanted) return v;
  }
  throw FormatException('unknown $field: "$raw"');
}

class Objective {
  const Objective({
    required this.id,
    required this.text,
    required this.mode,
    required this.timeLimitSec,
    required this.gradingTier,
    this.exactAnswer,
    this.acceptedItems,
    this.minRequired,
    this.targetWord,
    this.sampleAnswers,
    this.audioUrl,
  });

  final String id;
  final String text;
  final ObjectiveMode mode;
  final int timeLimitSec;
  final GradingTier gradingTier;

  /// Required by the `exact` tier.
  final String? exactAnswer;

  /// Required by the `checklist` tier.
  final List<String>? acceptedItems;
  final int? minRequired;

  /// Pronunciation traps: graded by comparing the transcript, no LLM.
  final String? targetWord;

  /// Reference answers for the `binary` and `scaled` tiers.
  final List<String>? sampleAnswers;

  final String? audioUrl;

  bool get needsMic =>
      mode == ObjectiveMode.speak || mode == ObjectiveMode.listen;

  factory Objective.fromJson(Map<String, dynamic> json) {
    return Objective(
      id: json['id'] as String,
      text: json['text'] as String,
      mode: _enumFromJson(ObjectiveMode.values, json['mode'] as String, 'mode'),
      timeLimitSec: json['timeLimitSec'] as int,
      gradingTier: _enumFromJson(
        GradingTier.values,
        json['gradingTier'] as String,
        'gradingTier',
      ),
      exactAnswer: json['exactAnswer'] as String?,
      acceptedItems: (json['acceptedItems'] as List?)?.cast<String>(),
      minRequired: json['minRequired'] as int?,
      targetWord: json['targetWord'] as String?,
      sampleAnswers: (json['sampleAnswers'] as List?)?.cast<String>(),
      audioUrl: json['audioUrl'] as String?,
    );
  }
}

class Mission {
  const Mission({
    required this.id,
    required this.type,
    required this.tier,
    required this.pace,
    required this.prompt,
    required this.objectives,
    this.effect,
  });

  final String id;
  final MissionType type;

  /// 1..4 — feeds the damage multiplier (Game_Rule §7).
  final int tier;

  final Pace pace;

  /// What the player sees on the card, e.g. "farmer".
  final String prompt;

  final List<Objective> objectives;

  /// The modifier on this mission, or null for a plain one.
  ///
  /// Seeded at draw time by [MissionPool] rather than stored in the content, so
  /// the same mission can come back carrying something different.
  final MissionEffect? effect;

  /// Shown in the card's corner: how much damage this mission is worth.
  int get objectiveCount => objectives.length;

  /// True when no objective can be answered without the microphone, which is
  /// what makes `silence` unplayable on this mission.
  bool get isAllMic => objectives.every((o) => o.needsMic);

  /// A copy carrying [effect], which may be null to clear it.
  ///
  /// Not a general `copyWith`: the `??` idiom cannot express "set this back to
  /// null", and every draw needs to overwrite the previous draw's effect.
  Mission withEffect(MissionEffect? effect) => Mission(
        id: id,
        type: type,
        tier: tier,
        pace: pace,
        prompt: prompt,
        objectives: objectives,
        effect: effect,
      );

  factory Mission.fromJson(Map<String, dynamic> json) {
    final objectives = (json['objectives'] as List)
        .cast<Map<String, dynamic>>()
        .map(Objective.fromJson)
        .toList();

    // "double" in the content maps onto the renamed enum value.
    final rawJson = json['effect'] as String?;
    final rawEffect = rawJson == 'double' ? 'doubleDamage' : rawJson;

    final tier = json['tier'] as int;
    if (tier < 1 || tier > 4) {
      throw FormatException('tier out of range: $tier (expected 1..4)');
    }

    return Mission(
      id: json['id'] as String,
      type: _enumFromJson(MissionType.values, json['type'] as String, 'type'),
      tier: tier,
      pace: _enumFromJson(Pace.values, json['pace'] as String, 'pace'),
      prompt: json['prompt'] as String,
      objectives: objectives,
      effect: rawEffect == null
          ? null
          : _enumFromJson(MissionEffect.values, rawEffect, 'effect'),
    );
  }
}
