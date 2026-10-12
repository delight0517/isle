import 'package:flutter/foundation.dart';
import 'dart:async';

import '../block/models/pending_rule_removal.dart';
import '../block/premade_block_pack_removal_service.dart';
import '../block/premade_block_pack_service.dart';
import '../block/rule_pending_removal_service.dart';
import '../block/rule_removal_lock.dart';
import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';
import 'adult_domain_catalog.dart';

/// 성인 보호 단일 출처 — 안전 모드(기본)와 4VPN `premade_adult_combined` 팩(강화) 통합.
enum AdultProtectionTier {
  off('off', '끔'),
  basic('basic', '기본'),
  full('full', '강화');

  const AdultProtectionTier(this.storageKey, this.labelKo);

  final String storageKey;
  final String labelKo;

  static AdultProtectionTier fromStorage(String? raw) {
    for (final t in values) {
      if (t.storageKey == raw) return t;
    }
    return AdultProtectionTier.off;
  }
}

class AdultProtectionSetResult {
  const AdultProtectionSetResult({
    required this.tier,
    this.packApplied = false,
    this.packRemovalScheduled = false,
    this.message,
  });

  final AdultProtectionTier tier;
  final bool packApplied;
  final bool packRemovalScheduled;
  final String? message;
}

class AdultProtectionService {
  AdultProtectionService._();

  static const packId = PremadeBlockPackService.adultCombinedPackId;

  static bool _migrationDone = false;

  @visibleForTesting
  static void resetMigrationForTest() => _migrationDone = false;

  static AdultProtectionTier get tier {
    final stored = IsleUserDefaults.adultProtectionTier;
    if (stored != null) {
      return AdultProtectionTier.fromStorage(stored);
    }
    return _inferTierFromLegacy();
  }

  static bool get isActive => tier != AdultProtectionTier.off;

  static bool get isFull => tier == AdultProtectionTier.full;

  /// [ContentSafetyGuard] · SafeSearch · 유튜브 보조 키워드
  static bool get basicLayerEnabled => isActive;

  static bool get fullPackApplied => PremadeBlockPackService.isPackApplied(packId);

  static PendingRuleRemoval? get pendingPackRemoval =>
      PremadeBlockPackRemovalService.pendingRemoval(packId);

  /// 부팅 1회 — legacy adult ID · 안전 모드 → 단일 tier
  static Future<void> migrateIfNeeded() async {
    if (_migrationDone) return;
    _migrationDone = true;

    if (IsleUserDefaults.adultProtectionTier != null) {
      await _syncLegacyContentSafetyFlag();
      return;
    }

    final inferred = _inferTierFromLegacy();
    await IsleUserDefaults.setAdultProtectionTier(inferred.storageKey);
    await _syncLegacyContentSafetyFlag();

    final applied = IsleUserDefaults.appliedPremadeBlockPackIds;
    var cleaned = false;
    for (final legacy in PremadeBlockPackService.legacyAdultPackIds) {
      if (applied.remove(legacy)) cleaned = true;
    }
    if (cleaned) {
      await IsleUserDefaults.replacePremadeBlockPackAppliedIds(applied);
    }

    if (inferred == AdultProtectionTier.full && !fullPackApplied) {
      IsleAppLogService.log(
        'AdultProtection: tier=full but pack not applied — user can sync from 보호 필터',
        level: IsleLogLevel.warn,
      );
    }

    IsleAppLogService.log('AdultProtection migrated → ${inferred.storageKey}');
  }

  static AdultProtectionTier _inferTierFromLegacy() {
    if (PremadeBlockPackService.isPackApplied(packId)) {
      return AdultProtectionTier.full;
    }
    if (PremadeBlockPackService.legacyAdultPackIds
        .any(IsleUserDefaults.isPremadeBlockPackApplied)) {
      return AdultProtectionTier.full;
    }
    if (IsleUserDefaults.contentSafetyEnabled) {
      return AdultProtectionTier.basic;
    }
    return AdultProtectionTier.off;
  }

  static Future<void> _syncLegacyContentSafetyFlag() async {
    final on = isActive;
    if (IsleUserDefaults.contentSafetyEnabled != on) {
      await IsleUserDefaults.setContentSafetyEnabled(on);
    }
  }

  /// 강화 tier + 팩 적용 보장 (tier=full인데 팩만 빠진 경우 포함)
  static Future<AdultProtectionSetResult> ensureFullPackApplied() async {
    if (!isFull) {
      return setTier(AdultProtectionTier.full);
    }
    if (!fullPackApplied) {
      final result = await PremadeBlockPackService.applyPack(packId);
      return AdultProtectionSetResult(
        tier: AdultProtectionTier.full,
        packApplied: true,
        message: result.summary('성인 콘텐츠 필터 팩'),
      );
    }
    return const AdultProtectionSetResult(
      tier: AdultProtectionTier.full,
      message: '강화 보호가 이미 켜져 있어요',
    );
  }

  static Future<AdultProtectionSetResult> setTier(AdultProtectionTier newTier) async {
    final prev = tier;
    if (prev == newTier) {
      return AdultProtectionSetResult(tier: newTier);
    }

    await IsleUserDefaults.setAdultProtectionTier(newTier.storageKey);
    await _syncLegacyContentSafetyFlag();

    switch (newTier) {
      case AdultProtectionTier.off:
        if (fullPackApplied) {
          final outcome = await PremadeBlockPackRemovalService.requestRemoval(packId);
          return AdultProtectionSetResult(
            tier: newTier,
            packRemovalScheduled: outcome.kind != RuleRemovalOutcomeKind.immediate,
            message: outcome.kind == RuleRemovalOutcomeKind.immediate
                ? '성인 보호를 껐어요'
                : null,
          );
        }
        return const AdultProtectionSetResult(
          tier: AdultProtectionTier.off,
          message: '성인 보호를 껐어요',
        );
      case AdultProtectionTier.basic:
        if (fullPackApplied) {
          final outcome = await PremadeBlockPackRemovalService.requestRemoval(packId);
          return AdultProtectionSetResult(
            tier: newTier,
            packRemovalScheduled: outcome.kind != RuleRemovalOutcomeKind.immediate,
            message: outcome.kind == RuleRemovalOutcomeKind.immediate
                ? '기본 보호만 켰어요 (SafeSearch · 주요 URL)'
                : '기본 보호로 전환 — 강화 팩 해제 ${RuleRemovalLock.lockEnabled ? "예약" : "완료"}',
          );
        }
        return const AdultProtectionSetResult(
          tier: AdultProtectionTier.basic,
          message: '기본 보호 켬 — SafeSearch · 주요 성인 URL',
        );
      case AdultProtectionTier.full:
        if (!fullPackApplied) {
          await PremadeBlockPackService.applyPack(packId);
          return const AdultProtectionSetResult(
            tier: AdultProtectionTier.full,
            packApplied: true,
            message: '강화 보호 켬 — 웹·YouTube 필터 팩 적용',
          );
        }
        return const AdultProtectionSetResult(
          tier: AdultProtectionTier.full,
          message: '강화 보호가 이미 켜져 있어요',
        );
    }
  }

  /// 강화 tier — 팩 JSON 신규 항목만 동기화
  static Future<AdultProtectionSetResult> syncFullPack() async {
    if (tier != AdultProtectionTier.full) {
      throw StateError('강화 보호가 켜져 있을 때만 동기화할 수 있어요');
    }
    final result = await PremadeBlockPackService.applyPack(packId);
    return AdultProtectionSetResult(
      tier: AdultProtectionTier.full,
      packApplied: true,
      message: result.summary('성인 보호 (강화)'),
    );
  }

  static List<String> exportBlockDomains() {
    if (!isActive) return const [];
    return List<String>.from(AdultDomainCatalog.suffixes);
  }

  static bool hostMatches(String host) {
    if (!isActive) return false;
    return AdultDomainCatalog.hostMatches(host);
  }
}
