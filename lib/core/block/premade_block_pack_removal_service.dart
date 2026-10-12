import 'dart:async';
import 'dart:io' show Platform;

import '../block_schedule/block_schedule_enforcement_service.dart';
import '../intervention/website_block_store.dart';
import '../perf/isle_heavy_work.dart';
import '../platform/ios_rules_export_service.dart';
import '../platform/isle_apple_platform.dart';
import '../safety/adult_protection_service.dart';
import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';
import '../youtube/blocked_channel_store.dart';
import '../youtube/blocked_url_store.dart';
import '../youtube/content_filter_store.dart';
import '../youtube/youtube_block_rules_sync.dart';
import 'models/premade_block_pack.dart';
import 'models/pending_rule_removal.dart';
import 'premade_block_pack_entry_effects.dart';
import 'premade_block_pack_service.dart';
import 'rule_pending_removal_service.dart';

class PremadeBlockPackRemovalResult {
  const PremadeBlockPackRemovalResult({
    required this.packId,
    required this.channelsRemoved,
    required this.keywordsRemoved,
    required this.urlsRemoved,
    required this.domainsRemoved,
  });

  final String packId;
  final int channelsRemoved;
  final int keywordsRemoved;
  final int urlsRemoved;
  final int domainsRemoved;

  int get totalRemoved =>
      channelsRemoved + keywordsRemoved + urlsRemoved + domainsRemoved;

  String summary(String displayName) {
    if (totalRemoved == 0) {
      return '「$displayName」 — 제거할 항목이 없어요';
    }
    final parts = <String>[];
    if (channelsRemoved > 0) parts.add('채널 $channelsRemoved');
    if (keywordsRemoved > 0) parts.add('키워드 $keywordsRemoved');
    if (urlsRemoved > 0) parts.add('URL $urlsRemoved');
    if (domainsRemoved > 0) parts.add('사이트 $domainsRemoved');
    return '「$displayName」 제거 — ${parts.join(' · ')}';
  }
}

/// 4VPN PremadeBlockPackRemovalService — 팩 적용 시 기록한 provenance만 제거
class PremadeBlockPackRemovalService {
  PremadeBlockPackRemovalService._();

  static Set<String> resolvedPackIds(String packId) {
    if (packId == PremadeBlockPackService.adultCombinedPackId ||
        PremadeBlockPackService.isLegacyAdultPackId(packId)) {
      return {
        PremadeBlockPackService.adultCombinedPackId,
        ...PremadeBlockPackService.legacyAdultPackIds,
      };
    }
    return {packId};
  }

  static String resolvePackId(String packId) =>
      PremadeBlockPackService.isLegacyAdultPackId(packId)
          ? PremadeBlockPackService.adultCombinedPackId
          : packId;

  /// 제거 타임락 ON → N분 후 자동 연결 해제 (키워드·URL과 동일)
  static Future<RuleRemovalOutcome> requestRemoval(String packId) =>
      RulePendingRemovalService.requestPremadePackRemove(packId);

  static PendingRuleRemoval? pendingRemoval(String packId) =>
      RulePendingRemovalService.pendingPremadePack(packId);

  /// 예약된 시각에 호출 (main.dart handler)
  static Future<void> executeScheduledRemoval(String packId) async {
    await IsleHeavyWork.run(
      taskId: 'premade_block_pack_remove',
      userTitle: '차단 팩 연결 해제',
      userWhy: '예약된 시간이 되어 프리셋 팩 규칙을 제거합니다.',
      estimatedMs: 6000,
      work: (_) async {
        await _removePackBodyImmediate(packId);
      },
    );
  }

  static Future<PremadeBlockPackRemovalResult> _removePackBodyImmediate(
    String packId,
  ) async {
    final resolvedId = resolvePackId(packId);
    final packIds = resolvedPackIds(resolvedId);

    final entries = <PremadePackProvenanceEntry>[];
    for (final id in packIds) {
      for (final raw in IsleUserDefaults.getPremadePackProvenanceRaw(id)) {
        final e = PremadePackProvenanceEntry.fromJson(raw);
        if (e.storeKind.isNotEmpty && e.value.isNotEmpty) entries.add(e);
      }
    }

    if (entries.isEmpty && !PremadeBlockPackService.isPackApplied(resolvedId)) {
      return PremadeBlockPackRemovalResult(
        packId: resolvedId,
        channelsRemoved: 0,
        keywordsRemoved: 0,
        urlsRemoved: 0,
        domainsRemoved: 0,
      );
    }

    var channelsRemoved = 0;
    var keywordsRemoved = 0;
    var urlsRemoved = 0;
    var domainsRemoved = 0;

    final channels = List.of(BlockedChannelStore.loadAll());
    final channelKeys = entries
        .where((e) => e.storeKind == 'channel')
        .map((e) => e.value.toLowerCase())
        .toSet();
    if (channelKeys.isNotEmpty) {
      final before = channels.length;
      channels.removeWhere((c) {
        final id = c.channelId.toLowerCase();
        final name = c.channelName.toLowerCase();
        return channelKeys.contains(id) || channelKeys.contains(name);
      });
      channelsRemoved = before - channels.length;
      if (channelsRemoved > 0) {
        await BlockedChannelStore.saveAll(channels);
      }
    }

    final keywordKeys = entries
        .where((e) => e.storeKind == 'keyword')
        .map((e) => e.value.toLowerCase())
        .toSet();
    if (keywordKeys.isNotEmpty) {
      final keywords = List<String>.from(ContentFilterStore.loadKeywords());
      final before = keywords.length;
      keywords.removeWhere((k) => keywordKeys.contains(k.toLowerCase()));
      keywordsRemoved = before - keywords.length;
      if (keywordsRemoved > 0) {
        await ContentFilterStore.saveKeywords(keywords);
      }
    }

    final urlKeys = entries
        .where((e) => e.storeKind == 'url')
        .map((e) => e.value.toLowerCase())
        .toSet();
    if (urlKeys.isNotEmpty) {
      final urls = List.of(BlockedUrlStore.loadAll());
      final before = urls.length;
      urls.removeWhere((u) => urlKeys.contains(u.canonicalUrl.toLowerCase()));
      urlsRemoved = before - urls.length;
      if (urlsRemoved > 0) {
        await BlockedUrlStore.saveAll(urls);
      }
    }

    final domainKeys = entries
        .where((e) => e.storeKind == 'domain')
        .map((e) => e.value.toLowerCase())
        .toSet();
    if (domainKeys.isNotEmpty) {
      final domains = List<String>.from(WebsiteBlockStore.loadDomains());
      final before = domains.length;
      domains.removeWhere((d) => domainKeys.contains(d.toLowerCase()));
      domainsRemoved = before - domains.length;
      if (domainsRemoved > 0) {
        await WebsiteBlockStore.saveDomains(domains);
      }
    }

    for (final id in packIds) {
      await IsleUserDefaults.clearPremadePackProvenance(id);
      await IsleUserDefaults.clearPremadePackExclusions(id);
      await IsleUserDefaults.unmarkPremadeBlockPackApplied(id);
    }

    if (resolvedId == PremadeBlockPackService.adultCombinedPackId &&
        AdultProtectionService.tier == AdultProtectionTier.full) {
      await IsleUserDefaults.setAdultProtectionTier(AdultProtectionTier.basic.storageKey);
      await IsleUserDefaults.setContentSafetyEnabled(true);
    }

    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 2500), () async {
        YoutubeBlockRulesSync.scheduleExport();
        if (IsleApplePlatform.isScreenTimeHost) {
          await IosRulesExportService.exportNow();
        } else if (Platform.isAndroid) {
          await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
        }
      }),
    );

    IsleAppLogService.log(
      'Premade pack remove $resolvedId: -ch$channelsRemoved -kw$keywordsRemoved '
      '-url$urlsRemoved -dom$domainsRemoved',
    );

    return PremadeBlockPackRemovalResult(
      packId: resolvedId,
      channelsRemoved: channelsRemoved,
      keywordsRemoved: keywordsRemoved,
      urlsRemoved: urlsRemoved,
      domainsRemoved: domainsRemoved,
    );
  }

  /// 팩 항목 1개 — 차단 해제 + 이후 자동 동기화에서 재추가 방지
  static Future<PremadeBlockPackRemovalResult> excludeEntry({
    required String packId,
    required PremadeBlockPackEntry entry,
  }) async {
    final resolvedId = resolvePackId(packId);
    await IsleUserDefaults.addPremadePackExclusion(resolvedId, entry.dedupeKey);

    final candidates = PremadeBlockPackEntryEffects.provenanceCandidates(entry);
    final candidateKeys = {
      for (final c in candidates) PremadeBlockPackEntryEffects.provenanceKey(c),
    };

    final provenanceRaw = IsleUserDefaults.getPremadePackProvenanceRaw(resolvedId);
    final toRemove = provenanceRaw.where((raw) {
      final key =
          '${raw['storeKind']}|${(raw['value'] as String?)?.toLowerCase()}';
      return candidateKeys.contains(key);
    }).toList();

    if (toRemove.isEmpty) {
      return PremadeBlockPackRemovalResult(
        packId: resolvedId,
        channelsRemoved: 0,
        keywordsRemoved: 0,
        urlsRemoved: 0,
        domainsRemoved: 0,
      );
    }

    var channelsRemoved = 0;
    var keywordsRemoved = 0;
    var urlsRemoved = 0;
    var domainsRemoved = 0;

    final channelKeys = toRemove
        .where((e) => e['storeKind'] == 'channel')
        .map((e) => (e['value'] as String).toLowerCase())
        .toSet();
    if (channelKeys.isNotEmpty) {
      final channels = List.of(BlockedChannelStore.loadAll());
      final before = channels.length;
      channels.removeWhere((c) {
        final id = c.channelId.toLowerCase();
        final name = c.channelName.toLowerCase();
        return channelKeys.contains(id) || channelKeys.contains(name);
      });
      channelsRemoved = before - channels.length;
      if (channelsRemoved > 0) await BlockedChannelStore.saveAll(channels);
    }

    final keywordKeys = toRemove
        .where((e) => e['storeKind'] == 'keyword')
        .map((e) => (e['value'] as String).toLowerCase())
        .toSet();
    if (keywordKeys.isNotEmpty) {
      final keywords = List<String>.from(ContentFilterStore.loadKeywords());
      final before = keywords.length;
      keywords.removeWhere((k) => keywordKeys.contains(k.toLowerCase()));
      keywordsRemoved = before - keywords.length;
      if (keywordsRemoved > 0) await ContentFilterStore.saveKeywords(keywords);
    }

    final urlKeys = toRemove
        .where((e) => e['storeKind'] == 'url')
        .map((e) => (e['value'] as String).toLowerCase())
        .toSet();
    if (urlKeys.isNotEmpty) {
      final urls = List.of(BlockedUrlStore.loadAll());
      final before = urls.length;
      urls.removeWhere((u) => urlKeys.contains(u.canonicalUrl.toLowerCase()));
      urlsRemoved = before - urls.length;
      if (urlsRemoved > 0) await BlockedUrlStore.saveAll(urls);
    }

    final domainKeys = toRemove
        .where((e) => e['storeKind'] == 'domain')
        .map((e) => (e['value'] as String).toLowerCase())
        .toSet();
    if (domainKeys.isNotEmpty) {
      final domains = List<String>.from(WebsiteBlockStore.loadDomains());
      final before = domains.length;
      domains.removeWhere((d) => domainKeys.contains(d.toLowerCase()));
      domainsRemoved = before - domains.length;
      if (domainsRemoved > 0) await WebsiteBlockStore.saveDomains(domains);
    }

    await IsleUserDefaults.removePremadePackProvenanceEntries(resolvedId, toRemove);

    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 2500), () async {
        YoutubeBlockRulesSync.scheduleExport();
        if (IsleApplePlatform.isScreenTimeHost) {
          await IosRulesExportService.exportNow();
        } else if (Platform.isAndroid) {
          await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
        }
      }),
    );

    IsleAppLogService.log(
      'Premade pack exclude $resolvedId ${entry.dedupeKey}: '
      '-ch$channelsRemoved -kw$keywordsRemoved -url$urlsRemoved -dom$domainsRemoved',
    );

    return PremadeBlockPackRemovalResult(
      packId: resolvedId,
      channelsRemoved: channelsRemoved,
      keywordsRemoved: keywordsRemoved,
      urlsRemoved: urlsRemoved,
      domainsRemoved: domainsRemoved,
    );
  }
}
