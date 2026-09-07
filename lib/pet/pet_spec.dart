import 'package:flutter/material.dart';

/// One pet's identity: the colours its element is drawn in, and the names of
/// the Rive properties those colours are bound to.
///
/// The whole point of this type is that adding a pet is data, not art: a new
/// [PetSpec] drives the same rig and the same effects. Only the four colours
/// and the labels change. See word-arena-docs/docs/game-design for the
/// design rationale.
class PetSpec {
  const PetSpec({
    required this.id,
    required this.name,
    this.atlasId,
    required this.shortName,
    required this.primary,
    required this.secondary,
    required this.light,
    required this.dark,
    required this.ultimateName,
  });

  /// Stable key used for persistence and content references.
  final String id;

  /// Directory under `assets/pets/` holding this pet's generated sprite atlas.
  ///
  /// Separate from [id] because art and content are generated independently:
  /// several pets can share one atlas while their palettes differ, and a pet
  /// with no art yet simply leaves this null and falls back to the vector rig.
  final String? atlasId;

  /// Where [PetAtlas] should look, or null when this pet has no sprites.
  String? get atlasPath => atlasId;

  final String name;

  /// Shown next to the health bar, where the full name would not fit.
  final String shortName;

  /// Body, wings, projectiles, impact burst.
  final Color primary;

  /// Crest, tail, breast, damage numbers.
  final Color secondary;

  /// Top of the body gradient, rim light, eye iris.
  final Color light;

  /// Bottom of the gradient, outer feathers, the far wing.
  final Color dark;

  final String ultimateName;

  /// Outline colour, shared by every pet.
  ///
  /// Deliberately not per-pet: the constant black outline is what keeps a pet
  /// looking like it belongs on the same board as the mission cards. A pet
  /// that recoloured its own outline would drift out of the art direction.
  static const outline = Color(0xFF2A1D12);

  static const fire = PetSpec(
    id: 'fire',
    atlasId: 'phoenix',
    name: 'Phượng Hoàng Lửa',
    shortName: 'Hoả Phượng',
    primary: Color(0xFFE0552A),
    secondary: Color(0xFFFFB020),
    light: Color(0xFFFFD166),
    dark: Color(0xFFA8321A),
    ultimateName: 'LIỆT DIỄM',
  );

  static const ice = PetSpec(
    id: 'ice',
    // Shares the phoenix sheet; the palette is what separates the two.
    atlasId: 'phoenix',
    name: 'Phượng Hoàng Băng',
    shortName: 'Băng Phượng',
    primary: Color(0xFF2F8FD0),
    secondary: Color(0xFF9FE4FF),
    light: Color(0xFFD8F4FF),
    dark: Color(0xFF1C5F96),
    ultimateName: 'TUYỆT ĐÔNG',
  );

  static const storm = PetSpec(
    id: 'storm',
    atlasId: 'tiger',
    name: 'Mãnh Hổ Sấm',
    shortName: 'Lôi Hổ',
    primary: Color(0xFF8A63D2),
    secondary: Color(0xFFFFE45E),
    light: Color(0xFFC9AEF0),
    dark: Color(0xFF5B3F97),
    ultimateName: 'CỬU LÔI',
  );

  static const leaf = PetSpec(
    id: 'leaf',
    name: 'Phượng Hoàng Mộc',
    shortName: 'Mộc Phượng',
    primary: Color(0xFF3F9E57),
    secondary: Color(0xFFC3EA6B),
    light: Color(0xFFE3F7A8),
    dark: Color(0xFF256B38),
    ultimateName: 'SINH CƠ',
  );

  static const all = <PetSpec>[fire, ice, storm, leaf];

  static PetSpec byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => fire);
}

/// What the pet is doing. Drives both the Rive state machine and the
/// fallback painter, so the two stay interchangeable.
enum PetPose {
  /// Airborne: this side is acting.
  fly,

  /// Perched: this side is waiting.
  perch,

  /// One-shot, on dealing damage.
  cast,

  /// One-shot, on taking damage.
  hurt,
}
