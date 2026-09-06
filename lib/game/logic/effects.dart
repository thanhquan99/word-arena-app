/// Mission effects (Game_Rule section 8).
///
/// Pure logic and presentation data — no bloc, no widgets — so the balance can
/// be tested without running the game.
library;

import '../../content/models.dart';

/// Which side of the risk/reward line an effect sits on. Drives the badge
/// colour, so the player can read the gamble before tapping.
enum EffectKind { good, risky, special }

/// Everything the game needs to know about one effect.
class EffectInfo {
  const EffectInfo({
    required this.icon,
    required this.label,
    required this.description,
    required this.kind,
    this.isImplemented = true,
  });

  /// The emoji from the rules doc. Players recognise these, and unlike the
  /// mission-type icons there is no Material equivalent to reach for.
  final String icon;

  final String label;

  /// Shown in the card's tooltip. Without it thirteen icons are thirteen
  /// riddles.
  final String description;

  final EffectKind kind;

  /// False for effects that need a real opponent. They still show their icon
  /// and say so in the tooltip; they simply do nothing in a single-player
  /// match. Waiting on the realtime feature, not forgotten.
  final bool isImplemented;
}

/// Deliberately exhaustive with no `default`: a new [MissionEffect] without an
/// entry here should fail to compile.
EffectInfo effectInfo(MissionEffect effect) => switch (effect) {
      MissionEffect.heal => const EffectInfo(
          icon: '💚',
          label: 'Heal',
          description: 'Hoàn thành đủ tất cả objective → hồi 3 máu.',
          kind: EffectKind.good,
        ),
      MissionEffect.doubleDamage => const EffectInfo(
          icon: '⚡',
          label: 'Double',
          description: 'Sát thương nhân đôi.',
          kind: EffectKind.good,
        ),
      MissionEffect.shield => const EffectInfo(
          icon: '🛡️',
          label: 'Shield',
          description: 'Miễn nhiễm đòn đánh tiếp theo.',
          kind: EffectKind.good,
        ),
      MissionEffect.burn => const EffectInfo(
          icon: '🔥',
          label: 'Burn',
          description: 'Đối thủ mất thêm 1 máu mỗi giây trong 5 giây.',
          kind: EffectKind.good,
        ),
      MissionEffect.reveal => const EffectInfo(
          icon: '👁️',
          label: 'Reveal',
          description: 'Xem trước mission sắp tới. '
              'Chưa có tác dụng ở chế độ 1 người.',
          kind: EffectKind.good,
          isImplemented: false,
        ),
      MissionEffect.haste => const EffectInfo(
          icon: '⏱️',
          label: 'Haste',
          description: 'Thời gian làm mỗi objective tăng 50%.',
          kind: EffectKind.good,
        ),
      MissionEffect.stun => const EffectInfo(
          icon: '💀',
          label: 'Stun',
          description: 'Làm hụt hết → choáng 3 giây thay vì 1.5 giây.',
          kind: EffectKind.risky,
        ),
      MissionEffect.gamble => const EffectInfo(
          icon: '🎲',
          label: 'Gamble',
          description: 'Đủ tất cả → sát thương nhân ba. '
              'Thiếu một cái → không có sát thương nào.',
          kind: EffectKind.risky,
        ),
      MissionEffect.mirror => const EffectInfo(
          icon: '🪞',
          label: 'Mirror',
          description: 'Sát thương gây ra dội lại chính mình 50%.',
          kind: EffectKind.risky,
        ),
      MissionEffect.silence => const EffectInfo(
          icon: '🔇',
          label: 'Silence',
          description: 'Các objective phải nói bị khoá.',
          kind: EffectKind.risky,
        ),
      MissionEffect.rush => const EffectInfo(
          icon: '⏳',
          label: 'Rush',
          description: 'Thời gian làm mỗi objective chỉ còn 60%.',
          kind: EffectKind.risky,
        ),
      MissionEffect.coop => const EffectInfo(
          icon: '🤝',
          label: 'Co-op',
          description: 'Cả hai cùng làm, cùng hồi máu. '
              'Chưa có tác dụng ở chế độ 1 người.',
          kind: EffectKind.special,
          isImplemented: false,
        ),
      MissionEffect.duel => const EffectInfo(
          icon: '🎯',
          label: 'Duel',
          description: 'Cả hai cùng làm, chênh lệch điểm là sát thương. '
              'Chưa có tác dụng ở chế độ 1 người.',
          kind: EffectKind.special,
          isImplemented: false,
        ),
    };

/// Risky effects are only allowed on tier 3 and above (Game_Rule section 8):
/// playing safe should not be able to deal heavy damage.
const minRiskyTier = 3;

/// Effects that may be seeded onto a mission of [tier].
///
/// [isAllMic] drops `silence` from missions where every objective needs the
/// microphone — locking those would leave nothing the player could answer.
List<MissionEffect> effectsAllowedFor({
  required int tier,
  required bool isAllMic,
}) {
  return [
    for (final effect in MissionEffect.values)
      if (_isAllowed(effect, tier: tier, isAllMic: isAllMic)) effect,
  ];
}

bool _isAllowed(
  MissionEffect effect, {
  required int tier,
  required bool isAllMic,
}) {
  if (effect == MissionEffect.silence && isAllMic) return false;
  if (effectInfo(effect).kind == EffectKind.risky && tier < minRiskyTier) {
    return false;
  }
  return true;
}

/// Lower bound on an objective's time limit, so no combination of modifiers can
/// leave a player with no time at all.
const minObjectiveSeconds = 3;

/// The time limit for one objective once every modifier is applied.
///
/// The modifiers multiply together — the rules doc does not say how they should
/// combine, and stacking them keeps each one's stated effect intact. Mercy
/// (Game_Rule section 4) applies on top of the mission's own effect.
int effectiveTimeLimit({
  required int baseSeconds,
  required MissionEffect? effect,
  required bool mercy,
}) {
  var seconds = baseSeconds.toDouble();

  seconds *= switch (effect) {
    MissionEffect.haste => 1.5,
    MissionEffect.rush => 0.6,
    _ => 1.0,
  };

  if (mercy) seconds *= 1.3;

  return seconds.round().clamp(minObjectiveSeconds, 999);
}
