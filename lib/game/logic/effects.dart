/// Mission effects (Game_Rule v2 §8) — presentation only.
///
/// The rules themselves now live on the server, in
/// `word-arena-api/src/game/rules/effects.ts`. What is left here is what the
/// player needs to read off a card before tapping it: an icon, a name, and a
/// sentence explaining the gamble.
library;

import '../../content/models.dart';

/// Who an effect aims at — Game_Rule v2 §8 groups the table this way, and the
/// badge colour follows it, so the player can read the gamble before tapping.
enum EffectGroup {
  /// Good for the winner themselves.
  self,

  /// Bad for whoever loses the turn.
  opponent,

  /// Changes the rules of the turn for both sides.
  turn,
}

/// Everything the UI needs to know about one effect.
class EffectInfo {
  const EffectInfo({
    required this.icon,
    required this.label,
    required this.description,
    required this.group,
    this.bridges = false,
  });

  /// The emoji from the rules doc. Players recognise these, and unlike the
  /// mission-type icons there is no Material equivalent to reach for.
  final String icon;

  final String label;

  /// Shown in the card's tooltip. Without it eleven icons are eleven riddles.
  final String description;

  final EffectGroup group;

  /// True for effects that only take hold on the *next* turn (§8): the winner
  /// is not under attack, so a shield has nothing to stop yet.
  final bool bridges;
}

/// Deliberately exhaustive with no `default`: a new [MissionEffect] without an
/// entry here should fail to compile.
EffectInfo effectInfo(MissionEffect effect) => switch (effect) {
      // ------------------------------------------------- §8.1 good for yourself
      MissionEffect.heal => const EffectInfo(
          icon: '💚',
          label: 'Heal',
          description: 'Thắng lượt với đủ N/N objective → hồi 3 máu.',
          group: EffectGroup.self,
        ),
      MissionEffect.doubleDamage => const EffectInfo(
          icon: '⚡',
          label: 'Double',
          description: 'Thắng lượt → damage nhân đôi.',
          group: EffectGroup.self,
        ),
      MissionEffect.gamble => const EffectInfo(
          icon: '🎲',
          label: 'Gamble',
          description:
              'Thắng lượt với đủ N/N → damage nhân ba. Thiếu dù một objective → '
              '0 damage, thắng cũng như không.',
          group: EffectGroup.self,
        ),
      MissionEffect.shield => const EffectInfo(
          icon: '🛡️',
          label: 'Shield',
          description: 'Lượt kế tiếp, chặn trọn damage đánh vào mình.',
          group: EffectGroup.self,
          bridges: true,
        ),
      MissionEffect.mirror => const EffectInfo(
          icon: '🪞',
          label: 'Mirror',
          description:
              'Lượt kế tiếp, damage đối thủ đánh vào mình dội lại họ 50% — '
              'mình vẫn ăn đủ.',
          group: EffectGroup.self,
          bridges: true,
        ),
      MissionEffect.haste => const EffectInfo(
          icon: '⏱️',
          label: 'Haste',
          description: 'Lượt kế tiếp, thời gian card của mình +50%.',
          group: EffectGroup.self,
          bridges: true,
        ),
      MissionEffect.reveal => const EffectInfo(
          icon: '👁️',
          label: 'Reveal',
          description: 'Xem trước hai card sắp xuất hiện.',
          group: EffectGroup.self,
        ),

      // ---------------------------------------------- §8.2 bad for the opponent
      MissionEffect.burn => const EffectInfo(
          icon: '🔥',
          label: 'Burn',
          description:
              'Đối thủ mất 1 máu cuối mỗi lượt, kéo dài đúng bằng số objective '
              'mình hoàn thành. Burn mới cộng thêm lượt, không tăng damage.',
          group: EffectGroup.opponent,
        ),
      MissionEffect.rush => const EffectInfo(
          icon: '⏳',
          label: 'Rush',
          description: 'Lượt kế tiếp, thời gian card của đối thủ chỉ còn 60%.',
          group: EffectGroup.opponent,
          bridges: true,
        ),
      MissionEffect.stun => const EffectInfo(
          icon: '💀',
          label: 'Stun',
          description:
              'Ở pha chọn card kế tiếp, đối thủ không bấm được trong số giây '
              'bằng số objective mình hoàn thành.',
          group: EffectGroup.opponent,
          bridges: true,
        ),

      // ------------------------------------------- §8.3 changes the whole turn
      MissionEffect.allOut => const EffectInfo(
          icon: '🎯',
          label: 'Khô máu',
          description:
              'Cấm phòng thủ. Không so sánh gì cả — mỗi bên gây damage theo số '
              'objective của mình, cả hai cùng chảy máu.',
          group: EffectGroup.turn,
        ),
    };
