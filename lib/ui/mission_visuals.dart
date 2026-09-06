/// How each mission type and tier looks on the board.
///
/// Material icons rather than emoji: an icon is a vector shipped with the app,
/// so it renders identically everywhere. Emoji depend on a system font and the
/// mission type is not worth that risk. Effects do use emoji — see
/// `game/logic/effects.dart` — because those icons come straight from the rules
/// doc and players recognise them.
library;

import 'package:flutter/material.dart';

import '../content/models.dart';

/// The icon shown in a mission card's top-left corner.
///
/// Deliberately exhaustive with no `default`: adding a [MissionType] without
/// giving it an icon should fail to compile, not fall back to something wrong.
IconData missionIcon(MissionType type) => switch (type) {
      MissionType.vocabulary => Icons.menu_book,
      MissionType.phrasalVerb => Icons.link,
      MissionType.grammar => Icons.rule,
      MissionType.idiom => Icons.format_quote,
      MissionType.pronunciation => Icons.record_voice_over,
      MissionType.tense => Icons.schedule,
      MissionType.roleplay => Icons.theater_comedy,
      MissionType.oddOneOut => Icons.search_off,
      MissionType.sentenceBuilder => Icons.reorder,
      MissionType.listening => Icons.hearing,
    };

/// Vietnamese label for a mission type, used in the end-of-match review.
String missionTypeLabel(MissionType type) => switch (type) {
      MissionType.vocabulary => 'Từ vựng',
      MissionType.phrasalVerb => 'Cụm động từ',
      MissionType.grammar => 'Ngữ pháp',
      MissionType.idiom => 'Thành ngữ',
      MissionType.pronunciation => 'Phát âm',
      MissionType.tense => 'Chia thì',
      MissionType.roleplay => 'Đóng vai',
      MissionType.oddOneOut => 'Tìm từ lạc',
      MissionType.sentenceBuilder => 'Ráp câu',
      MissionType.listening => 'Nghe',
    };

const _tierColors = <Color>[
  Color(0xFF64B5F6), // 1 — blue
  Color(0xFF4CAF50), // 2 — green
  Color(0xFFFFA726), // 3 — orange
  Color(0xFFEF5350), // 4 — red
];

/// Colour for a mission's difficulty tier (1..4).
///
/// Clamps rather than throws, matching `tierMultiplier` in game/logic/damage.dart:
/// bad content should not be able to crash a match that is already running.
Color tierColor(int tier) => _tierColors[tier.clamp(1, _tierColors.length) - 1];
