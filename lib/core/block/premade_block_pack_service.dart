import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../ai/block_chat/block_audit_log_store.dart';
import '../block_schedule/block_schedule_enforcement_service.dart';
import '../intervention/website_block_store.dart';
import '../platform/ios_rules_export_service.dart';
import '../platform/isle_apple_platform.dart';
import '../perf/isle_heavy_work.dart';
import '../perf/isle_heavy_work_reporter.dart';
import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';
import '../youtube/blocked_channel_store.dart';
import '../youtube/blocked_url_store.dart';
import '../youtube/content_filter_store.dart';
import '../youtube/models/blocked_channel.dart';
import '../youtube/models/blocked_url.dart';
import '../youtube/youtube_block_rules_sync.dart';
import '../youtube/block_keyword_policy.dart';
import 'models/premade_block_pack.dart';
import 'models/premade_pack_definition.dart';
import 'premade_block_pack_entry_effects.dart';
import 'premade_block_pack_registry.dart';

final IsleHeavyWorkReporter _premadePackSilentReporter =
    IsleHeavyWorkReporter((_, {stepLabel}) {});

/// 4VPN PremadeBlockPacks — [PremadeBlockPackRegistry] manifest 단일 출처
class PremadeBlockPackService {
  PremadeBlockPackService._();

  static const adultCombinedPackId = 'premade_adult_combined';

  static List<String> get legacyAdultPackIds =>
      PremadeBlockPackRegistry.legacyIdsFor(adultCombinedPackId);

  static List<String> get retiredStandalonePackIds =>
      PremadeBlockPackRegistry.retiredStandaloneIdsFor(adultCombinedPackId);

  static List<PremadeBlockPack>? _cache;

  static Future<void> _ensureRegistry() => PremadeBlockPackRegistry.ensureLoaded();

  static bool isLegacyAdultPackId(String packId) =>
      PremadeBlockPackRegistry.isLegacyPackId(packId);

  static bool isRetiredStandalonePackId(String packId) =>
      PremadeBlockPackRegistry.isRetiredStandalonePackId(packId);

  /// 카탈로그·적용·해제 시 단일 packId (레거시·퇴역 → manifest 정의대로)
  static String resolveCatalogPackId(String packId) =>
      PremadeBlockPackRegistry.resolvePackId(packId);

  static void invalidateCatalogCache() {
    _cache = null;
    PremadeBlockPackRegistry.invalidateCache();
  }

  static Future<PremadeBlockPack?> _loadPackAsset(String path) async {
    try {
      final raw = await rootBundle.loadString(path);
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return PremadeBlockPack.fromJson(j, assetPath: path);
    } catch (e) {
      IsleAppLogService.log('Premade pack load failed $path: $e', level: IsleLogLevel.warn);
      return null;
    }
  }

  /// manifest mergeSources → 성인 통합 팩
  static Future<PremadeBlockPack?> loadMergedAdultPack() async {
    await _ensureRegistry();
    final def = PremadeBlockPackRegistry.adultDefinition();
    if (def == null || def.kind != PremadePackKind.merge) return null;

    final paths = PremadeBlockPackRegistry.mergeAssetPaths(def);
    final parts = <PremadeBlockPack>[];
    for (final path in paths) {
      final p = await _loadPackAsset(path);
      if (p == null) return null;
      parts.add(p);
    }
    if (parts.isEmpty) return null;

    final seen = <String>{};
    final merged = <PremadeBlockPackEntry>[];

    void addEntries(List<PremadeBlockPackEntry> list) {
      for (final entry in list) {
        if (!seen.add(entry.dedupeKey)) continue;
        merged.add(entry);
      }
    }

    for (final part in parts) {
      addEntries(part.entries);
    }

    final versions = parts.map((p) => p.version).toList()..sort();
    final generated = parts.map((p) => p.generatedAt).toList()..sort();

    final siteHosts = merged.where((e) => e.kind == 'host').length;
    final channels = merged.where((e) => e.kind == 'channelURL').length;
    final keywordCount = merged.where((e) => e.kind == 'keyword').length;
    final urlContainsCount = merged.where((e) => e.kind == 'urlContains').length;

    return PremadeBlockPack(
      packId: def.packId,
      displayName: def.displayName ?? '성인 콘텐츠 필터 팩 (웹·YouTube)',
      description: def.description ??
          '성인·캠·게시판·URL($urlContainsCount)·검색($keywordCount)·YouTube (사이트 $siteHosts + 채널 $channels)',
      version: versions.last,
      generatedAt: generated.last,
      entryCount: merged.length,
      entries: merged,
      assetPath: paths.join('|'),
    );
  }

  /// UI — toggle 팩 + 성인 통합 팩 (성인 tier는 [AdultProtectionService]와 연동)
  static Future<List<PremadeBlockPack>> loadCatalog() async {
    if (_cache != null) return _cache!;
    await _ensureRegistry();
    final packs = <PremadeBlockPack>[];
    final adult = await loadMergedAdultPack();
    if (adult != null) packs.add(adult);
    packs.addAll(await loadToggleCatalog());
    _cache = packs;
    return packs;
  }

  static Future<List<PremadeBlockPack>> loadToggleCatalog() async {
    await _ensureRegistry();
    final packs = <PremadeBlockPack>[];
    for (final def in PremadeBlockPackRegistry.toggleDefinitions()) {
      final pack = await _loadDefinition(def);
      if (pack != null) packs.add(pack);
    }
    return packs;
  }

  /// @deprecated — [loadToggleCatalog] 와 동일 (스케줄·성인 제외는 manifest `scheduleEligible`)
  static Future<List<PremadeBlockPack>> loadNonAdultCatalog() async {
    await _ensureRegistry();
    final packs = <PremadeBlockPack>[];
    for (final def in PremadeBlockPackRegistry.scheduleEligibleDefinitions()) {
      final pack = await _loadDefinition(def);
      if (pack != null) packs.add(pack);
    }
    return packs;
  }

  static Future<List<PremadeBlockPack>> loadAllRegisteredPacks() async {
    await _ensureRegistry();
    final packs = <PremadeBlockPack>[];
    for (final def in PremadeBlockPackRegistry.definitions) {
      final pack = await _loadDefinition(def);
      if (pack != null) packs.add(pack);
    }
    return packs;
  }

  static Future<PremadeBlockPack?> _loadDefinition(PremadePackDefinition def) async {
    if (def.kind == PremadePackKind.merge) {
      if (def.isAdult) return loadMergedAdultPack();
      return null;
    }
    if (def.sourceAsset == null) return null;
    return _loadPackAsset('${PremadeBlockPackRegistry.assetPrefix}${def.sourceAsset}');
  }

  static Future<PremadeBlockPack?> loadAdultPack() => loadMergedAdultPack();

  static bool isAdultPackId(String packId) =>
      PremadeBlockPackRegistry.isAdultPackId(packId);

  static Future<bool> isPackUpdateAvailableForPackId(String packId) async {
    if (isAdultPackId(packId)) {
      final pack = await loadAdultPack();
      if (pack == null) return false;
      return isPackUpdateAvailable(pack);
    }
    final pack = await packById(packId);
    if (pack == null) return false;
    return isPackUpdateAvailable(pack);
  }

  static Future<PremadeBlockPack?> packById(String packId) async {
    await _ensureRegistry();
    final resolved = resolveCatalogPackId(packId);
    final def = PremadeBlockPackRegistry.definitionFor(resolved);
    if (def == null) return null;
    return _loadDefinition(def);
  }

  static bool isPackApplied(String packId) {
    final resolved = resolveCatalogPackId(packId);
    if (resolved == adultCombinedPackId) {
      if (IsleUserDefaults.isPremadeBlockPackApplied(adultCombinedPackId)) {
        return true;
      }
      if (legacyAdultPackIds.any(IsleUserDefaults.isPremadeBlockPackApplied)) {
        return true;
      }
      return retiredStandalonePackIds
          .any(IsleUserDefaults.isPremadeBlockPackApplied);
    }
    return IsleUserDefaults.isPremadeBlockPackApplied(resolved);
  }

  /// 연결된 팩 JSON 버전이 앱에 내장된 것보다 오래됐을 때 true (4VPN 「업데이트」 배지).
  static bool isPackUpdateAvailable(PremadeBlockPack pack) {
    if (!isPackApplied(pack.packId)) return false;
    final linked = IsleUserDefaults.getPremadeBlockPackAppliedVersion(pack.packId);
    if (linked == null || linked.isEmpty) return false;
    return pack.version.compareTo(linked) > 0;
  }

  static String? linkedPackVersion(String packId) {
    final resolved = resolveCatalogPackId(packId);
    return IsleUserDefaults.getPremadeBlockPackAppliedVersion(resolved);
  }

  /// 채널·키워드·URL·Safari 도메인 — 중복 skip · 사용자 제외 목록 존중 · 2.5s 후 rules export
  static Future<PremadeBlockPackApplyResult> applyPack(
    String packId, {
    bool silent = false,
  }) {
    if (silent) {
      return _applyPackBody(packId, _premadePackSilentReporter);
    }
    return IsleHeavyWork.run(
      taskId: 'premade_block_pack',
      userTitle: '차단 팩을 적용하는 중',
      userWhy: '수백 개의 차단 규칙을 안전하게 저장하는 작업이에요. '
          '지금은 이게 최우선 — 끝나면 Safari·피드·유튜브에 반영돼요.',
      estimatedMs: 9000,
      work: (r) => _applyPackBody(packId, r),
    );
  }

  static PremadePackEntryStatus entryStatus({
    required String packId,
    required PremadeBlockPackEntry entry,
  }) {
    final resolved = resolveCatalogPackId(packId);
    if (IsleUserDefaults.isPremadePackEntryExcluded(resolved, entry.dedupeKey)) {
      return PremadePackEntryStatus.excluded;
    }
    if (!isPackApplied(resolved)) return PremadePackEntryStatus.notApplied;

    final candidates = PremadeBlockPackEntryEffects.provenanceCandidates(entry);
    if (candidates.isEmpty) return PremadePackEntryStatus.notApplied;

    final candidateKeys = {
      for (final c in candidates) PremadeBlockPackEntryEffects.provenanceKey(c),
    };
    final provenance = IsleUserDefaults.getPremadePackProvenanceRaw(resolved);
    for (final raw in provenance) {
      final key =
          '${raw['storeKind']}|${(raw['value'] as String?)?.toLowerCase()}';
      if (candidateKeys.contains(key)) {
        return PremadePackEntryStatus.active;
      }
    }
    return PremadePackEntryStatus.pending;
  }

  static Future<PremadeBlockPackApplyResult> _applyPackBody(
    String packId,
    IsleHeavyWorkReporter r,
  ) async {
    final resolvedId = resolveCatalogPackId(packId);
    final pack = await packById(resolvedId);
    if (pack == null) {
      throw StateError('Unknown pack: $packId');
    }

    var channelsAdded = 0;
    var keywordsAdded = 0;
    var urlsAdded = 0;
    var domainsAdded = 0;
    var skipped = 0;
    final provenance = <Map<String, dynamic>>[];

    final channels = BlockedChannelStore.currentList();
    final channelKeys = {
      for (final c in channels) c.channelId.toLowerCase(),
      for (final c in channels) c.channelName.toLowerCase(),
    };

    final keywords = List<String>.from(ContentFilterStore.loadKeywords());
    final keywordSet = keywords.map((e) => e.toLowerCase()).toSet();

    final urls = List<BlockedUrl>.from(BlockedUrlStore.loadAll());
    final urlSet = urls.map((e) => e.canonicalUrl.toLowerCase()).toSet();

    final domains = List<String>.from(WebsiteBlockStore.loadDomains());
    final domainSet = domains.map((e) => e.toLowerCase()).toSet();

    final seenInPack = <String>{};
    final now = DateTime.now();
    final entryTotal = pack.entries.length;
    var processed = 0;

    for (final entry in pack.entries) {
      processed++;
      if (entryTotal > 20 && processed % 15 == 0) {
        r.progress(
          0.1 + (processed / entryTotal) * 0.75,
          stepLabel: '규칙 적용 $processed / $entryTotal',
        );
      }
      if (!seenInPack.add(entry.dedupeKey)) {
        skipped++;
        continue;
      }
      if (IsleUserDefaults.isPremadePackEntryExcluded(resolvedId, entry.dedupeKey)) {
        skipped++;
        continue;
      }

      switch (entry.kind) {
        case 'channelURL':
          final handle = _normalizeHandle(entry.pattern);
          if (handle.isEmpty) {
            skipped++;
            break;
          }
          // 채널 ID(UC...)는 handle이 아니다 — @ 접두사를 강제로 붙이면 실제
          // 매칭(YoutubeChannelPatternNormalizer, 대소문자 보존·@ 없음)과
          // 영원히 어긋난다(2026-07-16, 게임 프리셋 채널 미차단 근본 원인).
          final isChannelId =
              RegExp(r'^UC[\w-]{10,}$', caseSensitive: false).hasMatch(handle);
          final channelId = isChannelId
              ? handle
              : (handle.startsWith('@') ? handle : '@$handle');
          final slug = isChannelId
              ? handle
              : (handle.startsWith('@') ? handle.substring(1) : handle);
          if (channelKeys.contains(channelId.toLowerCase()) ||
              channelKeys.contains(slug.toLowerCase())) {
            skipped++;
          } else {
            channels.add(
              BlockedChannel(
                channelId: channelId,
                channelName: slug,
                blockedAt: now,
              ),
            );
            channelKeys.add(channelId.toLowerCase());
            channelKeys.add(slug.toLowerCase());
            channelsAdded++;
            provenance.add({
              'storeKind': 'channel',
              'value': channelId,
            });
          }
          if (_addUrl(
            'https://www.youtube.com/$channelId',
            urlSet,
            urls,
            now,
            provenance: provenance,
          )) {
            urlsAdded++;
          }
        case 'host':
        case 'wildcard':
          final rawPattern = entry.pattern.trim();
          if (rawPattern.contains('/')) {
            final urlRule = rawPattern.startsWith('http') ? rawPattern : 'https://$rawPattern';
            if (urlSet.contains(urlRule.toLowerCase())) {
              skipped++;
            } else if (_addUrl(urlRule, urlSet, urls, now, provenance: provenance)) {
              urlsAdded++;
            } else {
              skipped++;
            }
            break;
          }
          final domain = WebsiteBlockStore.normalizeDomain(entry.pattern) ??
              entry.pattern.trim().toLowerCase().split('/').first;
          if (domain.isEmpty || !BlockKeywordPolicy.isSafePremadeWebsiteDomain(domain)) {
            skipped++;
            break;
          }
          if (domainSet.contains(domain)) {
            skipped++;
          } else {
            domains.add(domain);
            domainSet.add(domain);
            domainsAdded++;
            provenance.add({'storeKind': 'domain', 'value': domain});
          }
          if (BlockKeywordPolicy.isSafePremadeKeyword(domain) &&
              _addKeyword(domain, keywordSet, keywords, provenance: provenance)) {
            keywordsAdded++;
          }
          final stem = domain.split('.').first;
          if (stem.length >= 6 &&
              BlockKeywordPolicy.isSafePremadeKeyword(stem) &&
              _addKeyword(stem, keywordSet, keywords, provenance: provenance)) {
            keywordsAdded++;
          }
          if (_addUrl('https://$domain', urlSet, urls, now, provenance: provenance)) {
            urlsAdded++;
          }
        case 'keyword':
        case 'genreKeyword':
          if (_addKeyword(entry.pattern, keywordSet, keywords, provenance: provenance)) {
            keywordsAdded++;
          } else {
            skipped++;
          }
        case 'urlContains':
        case 'videoURL':
          final url = entry.pattern.trim();
          if (url.isEmpty) {
            skipped++;
            break;
          }
          final canonical = url.startsWith('http') ? url : 'https://$url';
          if (urlSet.contains(canonical.toLowerCase())) {
            skipped++;
          } else if (_addUrl(canonical, urlSet, urls, now, provenance: provenance)) {
            urlsAdded++;
          }
        default:
          skipped++;
      }

      if (processed % 8 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    r.progress(0.92, stepLabel: '저장·동기화');
    if (channelsAdded > 0) {
      BlockedChannelStore.scheduleSave(channels);
      await BlockedChannelStore.flushPending();
    }
    if (keywordsAdded > 0) {
      await ContentFilterStore.saveKeywords(keywords);
    }
    if (urlsAdded > 0) {
      await BlockedUrlStore.saveAll(urls);
    }
    if (domainsAdded > 0) {
      await WebsiteBlockStore.saveDomains(domains);
    }

    await IsleUserDefaults.markPremadeBlockPackApplied(resolvedId, version: pack.version);
    for (final legacy in legacyAdultPackIds) {
      await IsleUserDefaults.markPremadeBlockPackApplied(legacy, version: pack.version);
    }
    for (final retired in retiredStandalonePackIds) {
      await IsleUserDefaults.markPremadeBlockPackApplied(retired, version: pack.version);
    }
    await IsleUserDefaults.appendPremadePackProvenance(resolvedId, provenance);

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
      'Premade pack ${pack.packId}: +ch$channelsAdded +kw$keywordsAdded '
      '+url$urlsAdded +dom$domainsAdded skip$skipped',
    );

    // 프리셋 팩은 blockedChannelsProvider 알림자를 안 거치고 스토어에 직접
    // 쓰기 때문에 그쪽에 붙인 audit 로그 훅을 안 탄다 — "이 채널이 왜
    // 차단됐지?" 진단할 때 이 경로가 로그에 안 남으면 원인 분석에 구멍이
    // 생긴다(2026-07-20 사용자 요청). 채널별로 안 남기고 팩 단위 요약 하나만.
    if (channelsAdded > 0 || keywordsAdded > 0 || urlsAdded > 0 || domainsAdded > 0) {
      try {
        await BlockAuditLogStore.ensureOpen();
        await BlockAuditLogStore.record(
          command: '(프리셋 팩) ${pack.packId}',
          action: 'apply_premade_pack',
          summary: '「${pack.packId}」 적용 — 채널 +$channelsAdded · 키워드 +$keywordsAdded · '
              'URL +$urlsAdded · 도메인 +$domainsAdded (스킵 $skipped)',
          steps: const [],
          success: true,
        );
      } catch (_) {}
    }

    return PremadeBlockPackApplyResult(
      packId: resolvedId,
      channelsAdded: channelsAdded,
      keywordsAdded: keywordsAdded,
      urlsAdded: urlsAdded,
      domainsAdded: domainsAdded,
      skipped: skipped,
    );
  }

  static String _normalizeHandle(String raw) => PremadeBlockPackEntryEffects.normalizeHandle(raw);

  static bool _addKeyword(
    String raw,
    Set<String> set,
    List<String> list, {
    List<Map<String, dynamic>>? provenance,
  }) {
    final k = raw.trim().toLowerCase();
    if (k.isEmpty || set.contains(k) || !BlockKeywordPolicy.isSafePremadeKeyword(k)) {
      return false;
    }
    set.add(k);
    list.add(k);
    provenance?.add({'storeKind': 'keyword', 'value': k});
    return true;
  }

  static bool _addUrl(
    String raw,
    Set<String> set,
    List<BlockedUrl> list,
    DateTime now, {
    List<Map<String, dynamic>>? provenance,
  }) {
    final u = raw.trim();
    if (u.isEmpty) return false;
    final lower = u.toLowerCase();
    if (set.contains(lower)) return false;
    set.add(lower);
    final canonical = u.startsWith('http') ? u : 'https://$u';
    list.add(
      BlockedUrl(
        canonicalUrl: canonical,
        blockedAt: now,
      ),
    );
    provenance?.add({'storeKind': 'url', 'value': canonical});
    return true;
  }
}
