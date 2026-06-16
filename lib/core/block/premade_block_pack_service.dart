import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

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

/// 4VPN PremadeBlockPacks 포터블 JSON — Isle 차단 레이어에 일괄 적용
class PremadeBlockPackService {
  PremadeBlockPackService._();

  static const catalogAssetPaths = [
    'assets/premade_block_packs/premade_adult_youtube_200.json',
    'assets/premade_block_packs/premade_adult_sites_200.json',
    'assets/premade_block_packs/premade_gaming_400.json',
  ];

  static List<PremadeBlockPack>? _cache;

  static Future<List<PremadeBlockPack>> loadCatalog() async {
    if (_cache != null) return _cache!;
    final packs = <PremadeBlockPack>[];
    for (final path in catalogAssetPaths) {
      try {
        final raw = await rootBundle.loadString(path);
        final j = jsonDecode(raw) as Map<String, dynamic>;
        packs.add(PremadeBlockPack.fromJson(j, assetPath: path));
      } catch (e) {
        IsleAppLogService.log('Premade pack load failed $path: $e', level: IsleLogLevel.warn);
      }
    }
    _cache = packs;
    return packs;
  }

  static Future<PremadeBlockPack?> packById(String packId) async {
    final list = await loadCatalog();
    for (final p in list) {
      if (p.packId == packId) return p;
    }
    return null;
  }

  static bool isPackApplied(String packId) =>
      IsleUserDefaults.isPremadeBlockPackApplied(packId);

  /// 채널·키워드·URL·Safari 도메인 — 중복 스kip · 2.5s 후 rules export
  static Future<PremadeBlockPackApplyResult> applyPack(String packId) =>
      IsleHeavyWork.run(
        taskId: 'premade_block_pack',
        userTitle: '차단 팩을 적용하는 중',
        userWhy: '수백 개의 차단 규칙을 안전하게 저장하는 작업이에요. '
            '지금은 이게 최우선 — 끝나면 Safari·피드·유튜브에 반영돼요.',
        estimatedMs: 9000,
        work: (r) => _applyPackBody(packId, r),
      );

  static Future<PremadeBlockPackApplyResult> _applyPackBody(
    String packId,
    IsleHeavyWorkReporter r,
  ) async {
    final pack = await packById(packId);
    if (pack == null) {
      throw StateError('Unknown pack: $packId');
    }

    var channelsAdded = 0;
    var keywordsAdded = 0;
    var urlsAdded = 0;
    var domainsAdded = 0;
    var skipped = 0;

    final channels = List<BlockedChannel>.from(BlockedChannelStore.loadAll());
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

      switch (entry.kind) {
        case 'channelURL':
          final handle = _normalizeHandle(entry.pattern);
          if (handle.isEmpty) {
            skipped++;
            break;
          }
          final channelId = handle.startsWith('@') ? handle : '@$handle';
          final slug = handle.startsWith('@') ? handle.substring(1) : handle;
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
          }
          if (_addUrl('https://www.youtube.com/$channelId', urlSet, urls, now)) {
            urlsAdded++;
          }
        case 'host':
          final rawPattern = entry.pattern.trim();
          if (rawPattern.contains('/')) {
            final urlRule = rawPattern.startsWith('http') ? rawPattern : 'https://$rawPattern';
            if (urlSet.contains(urlRule.toLowerCase())) {
              skipped++;
            } else if (_addUrl(urlRule, urlSet, urls, now)) {
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
          }
          if (BlockKeywordPolicy.isSafePremadeKeyword(domain) &&
              _addKeyword(domain, keywordSet, keywords)) {
            keywordsAdded++;
          }
          final stem = domain.split('.').first;
          if (stem.length >= 6 &&
              BlockKeywordPolicy.isSafePremadeKeyword(stem) &&
              _addKeyword(stem, keywordSet, keywords)) {
            keywordsAdded++;
          }
          if (_addUrl('https://$domain', urlSet, urls, now)) urlsAdded++;
        case 'keyword':
          if (_addKeyword(entry.pattern, keywordSet, keywords)) {
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
          } else if (_addUrl(canonical, urlSet, urls, now)) {
            urlsAdded++;
          }
        default:
          skipped++;
      }

      // UI 프레임 양보 (대량 적용 시 jank 방지)
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

    await IsleUserDefaults.markPremadeBlockPackApplied(packId);

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

    return PremadeBlockPackApplyResult(
      packId: packId,
      channelsAdded: channelsAdded,
      keywordsAdded: keywordsAdded,
      urlsAdded: urlsAdded,
      domainsAdded: domainsAdded,
      skipped: skipped,
    );
  }

  static String _normalizeHandle(String raw) {
    var h = raw.trim().toLowerCase();
    if (h.isEmpty) return '';
    if (!h.startsWith('@')) h = '@$h';
    return h;
  }

  static bool _addKeyword(String raw, Set<String> set, List<String> list) {
    final k = raw.trim().toLowerCase();
    if (k.isEmpty || set.contains(k) || !BlockKeywordPolicy.isSafePremadeKeyword(k)) {
      return false;
    }
    set.add(k);
    list.add(k);
    return true;
  }

  static bool _addUrl(
    String raw,
    Set<String> set,
    List<BlockedUrl> list,
    DateTime now,
  ) {
    final u = raw.trim();
    if (u.isEmpty) return false;
    final lower = u.toLowerCase();
    if (set.contains(lower)) return false;
    set.add(lower);
    list.add(
      BlockedUrl(
        canonicalUrl: u.startsWith('http') ? u : 'https://$u',
        blockedAt: now,
      ),
    );
    return true;
  }
}
