import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../services/isle_app_log_service.dart';
import 'models/premade_pack_definition.dart';

/// 4VPN PremadeBlockPacks — `manifest.json` 단일 출처 (JSON 추가 시 manifest만 갱신)
class PremadeBlockPackRegistry {
  PremadeBlockPackRegistry._();

  static const manifestAsset =
      'assets/premade_block_packs/manifest.json';

  static const assetPrefix = 'assets/premade_block_packs/';

  static List<PremadePackDefinition>? _definitions;
  static Map<String, PremadePackDefinition>? _byId;

  static Future<void> ensureLoaded() async {
    if (_definitions != null) return;
    await _loadManifest();
  }

  static Future<void> _loadManifest() async {
    try {
      final raw = await rootBundle.loadString(manifestAsset);
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final list = (j['packs'] as List<dynamic>? ?? [])
          .map((e) => PremadePackDefinition.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((d) => d.packId.isNotEmpty)
          .toList();
      _definitions = list;
      _byId = {for (final d in list) d.packId: d};
      IsleAppLogService.log('4VPN preset manifest: ${list.length} packs');
    } catch (e, st) {
      IsleAppLogService.log(
        '4VPN preset manifest load failed: $e',
        level: IsleLogLevel.error,
        stack: st,
      );
      _definitions = const [];
      _byId = {};
    }
  }

  static void invalidateCache() {
    _definitions = null;
    _byId = null;
  }

  static List<PremadePackDefinition> get definitions {
    return _definitions ?? const [];
  }

  static PremadePackDefinition? definitionFor(String packId) {
    if (_byId == null) return null;
    final resolved = resolvePackId(packId);
    return _byId![resolved];
  }

  static String resolvePackId(String packId) {
    final defs = _definitions;
    if (defs == null || defs.isEmpty) {
      if (packId == 'premade_adult_sites_200' ||
          packId == 'premade_adult_youtube_200' ||
          packId == 'premade_link_aggregator_seo') {
        return _fallbackAdultCombined;
      }
      return packId;
    }
    for (final d in defs) {
      if (d.packId == packId) return packId;
      if (d.legacyIds.contains(packId)) return d.packId;
      if (d.retiredStandaloneIds.contains(packId)) return d.packId;
    }
    return packId;
  }

  static const _fallbackAdultCombined = 'premade_adult_combined';

  static bool isLegacyPackId(String packId) {
    final defs = _definitions;
    if (defs == null) return false;
    for (final d in defs) {
      if (d.legacyIds.contains(packId)) return true;
    }
    return false;
  }

  static bool isRetiredStandalonePackId(String packId) {
    final defs = _definitions;
    if (defs == null) return false;
    for (final d in defs) {
      if (d.retiredStandaloneIds.contains(packId)) return true;
    }
    return false;
  }

  static bool isAdultPackId(String packId) =>
      definitionFor(packId)?.isAdult ?? false;

  static bool isSensitivePack(String packId) {
    final def = definitionFor(packId);
    if (def == null) {
      return packId.contains('adult') || packId.contains('illegal');
    }
    return def.sensitive ||
        def.isAdult ||
        def.category == PremadePackCategory.illegal ||
        def.category == PremadePackCategory.gambling;
  }

  static List<String> legacyIdsFor(String packId) =>
      definitionFor(packId)?.legacyIds ?? const [];

  static List<String> retiredStandaloneIdsFor(String packId) =>
      definitionFor(packId)?.retiredStandaloneIds ?? const [];

  static String get adultCombinedPackId {
    if (_definitions == null) return 'premade_adult_combined';
    for (final d in _definitions!) {
      if (d.isAdult && d.kind == PremadePackKind.merge) return d.packId;
    }
    return 'premade_adult_combined';
  }

  static List<PremadePackDefinition> toggleDefinitions() {
    final defs = _definitions;
    if (defs == null) return const [];
    return defs.where((d) => d.uiMode == PremadePackUiMode.toggle).toList();
  }

  static List<PremadePackDefinition> scheduleEligibleDefinitions() {
    final defs = _definitions;
    if (defs == null) return const [];
    return defs.where((d) => d.scheduleEligible).toList();
  }

  static PremadePackDefinition? adultDefinition() {
    for (final d in definitions) {
      if (d.uiMode == PremadePackUiMode.adultProtection) return d;
    }
    return null;
  }

  static String assetPathForDefinition(PremadePackDefinition def) {
    if (def.kind == PremadePackKind.single && def.sourceAsset != null) {
      return '$assetPrefix${def.sourceAsset}';
    }
    return def.mergeSourceAssets.map((f) => '$assetPrefix$f').join('|');
  }

  static List<String> mergeAssetPaths(PremadePackDefinition def) =>
      def.mergeSourceAssets.map((f) => '$assetPrefix$f').toList();

  static IconData iconFor(PremadePackDefinition def) {
    switch (def.category) {
      case PremadePackCategory.adult:
        return Icons.visibility_off;
      case PremadePackCategory.illegal:
        return Icons.gavel_outlined;
      case PremadePackCategory.gaming:
        return Icons.sports_esports_outlined;
      case PremadePackCategory.gambling:
        return Icons.casino_outlined;
      case PremadePackCategory.other:
        return Icons.shield_outlined;
    }
  }

  static Color accentFor(PremadePackDefinition def) {
    switch (def.category) {
      case PremadePackCategory.adult:
        return IsleColors.danger;
      case PremadePackCategory.illegal:
        return const Color(0xFFB45309);
      case PremadePackCategory.gaming:
        return IsleColors.ocean700;
      case PremadePackCategory.gambling:
        return const Color(0xFF7C3AED);
      case PremadePackCategory.other:
        return IsleColors.ocean500;
    }
  }

  static String labelForPackId(String packId) {
    final def = definitionFor(packId);
    if (def != null) {
      if (def.displayName != null && def.displayName!.isNotEmpty) {
        return def.displayName!;
      }
      return def.category.labelKo;
    }
    if (packId.contains('adult')) return '성인 보호';
    if (packId.contains('gaming')) return '게임 프리셋';
    if (packId.contains('gambling')) return '도박·토토 프리셋';
    return '프리셋 팩';
  }
}
