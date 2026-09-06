import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

/// Where missions come from.
///
/// An interface so the source can change without touching game logic: today it
/// is a bundled asset, later it will be the `missions` table in Supabase.
abstract class ContentRepository {
  Future<List<Mission>> loadAll();
}

/// Reads missions from `assets/content.json`, parsed once and cached.
class AssetContentRepository implements ContentRepository {
  AssetContentRepository({this.assetPath = 'assets/content.json'});

  final String assetPath;
  List<Mission>? _cache;

  @override
  Future<List<Mission>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final missions = (json['missions'] as List)
        .cast<Map<String, dynamic>>()
        .map(Mission.fromJson)
        .toList();

    _cache = missions;
    return missions;
  }
}

/// In-memory source for tests — no asset bundle needed.
class FakeContentRepository implements ContentRepository {
  FakeContentRepository(this.missions);

  final List<Mission> missions;

  @override
  Future<List<Mission>> loadAll() async => missions;
}
