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
import 'theme/arena_theme.dart';

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

/// Colour for a mission's difficulty tier (1..4).
///
/// Delegates to [Arena.tier] so the palette lives in one place; it clamps
/// rather than throws, matching `tierMultiplier` in game/logic/damage.dart —
/// bad content should not be able to crash a match that is already running.
Color tierColor(int tier) => Arena.tier(tier);
