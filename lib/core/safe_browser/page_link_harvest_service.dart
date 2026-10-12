import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import '../intervention/website_block_store.dart';
import '../platform/ios_rules_export_service.dart';
import '../platform/isle_apple_platform.dart';
import '../services/isle_app_log_service.dart';
import '../utils/url_parser.dart';
import '../youtube/block_keyword_policy.dart';
import '../youtube/blocked_channel_store.dart';
import '../youtube/blocked_url_store.dart';
import '../youtube/content_filter_store.dart';
import '../youtube/models/blocked_channel.dart';
import '../youtube/models/blocked_url.dart';
import '../youtube/youtube_block_rules_sync.dart';
import 'page_link_harvest_script.dart';

class HarvestedPageLink {
  const HarvestedPageLink({
    required this.url,
    required this.host,
    this.text = '',
  });

  final String url;
  final String host;
  final String text;

  factory HarvestedPageLink.fromJson(Map<String, dynamic> j) => HarvestedPageLink(
        url: j['url'] as String? ?? '',
        host: j['host'] as String? ?? '',
        text: j['text'] as String? ?? '',
      );
}

class PageLinkDomainGroup {
  const PageLinkDomainGroup({
    required this.host,
    required this.links,
  });

  final String host;
  final List<HarvestedPageLink> links;

  int get count => links.length;
}

class PageLinkBulkBlockResult {
  const PageLinkBulkBlockResult({
    required this.domainsAdded,
    required this.urlsAdded,
    required this.keywordsAdded,
    required this.channelsAdded,
    required this.skipped,
  });

  final int domainsAdded;
  final int urlsAdded;
  final int keywordsAdded;
  final int channelsAdded;
  final int skipped;

  int get totalAdded => domainsAdded + urlsAdded + keywordsAdded + channelsAdded;

  String summary() {
    if (totalAdded == 0) return '추가된 차단이 없어요 (이미 있거나 제외됨)';
    final parts = <String>[];
    if (domainsAdded > 0) parts.add('사이트 $domainsAdded');
    if (urlsAdded > 0) parts.add('URL $urlsAdded');
    if (keywordsAdded > 0) parts.add('키워드 $keywordsAdded');
    if (channelsAdded > 0) parts.add('채널 $channelsAdded');
    final skip = skipped > 0 ? ' · 중복 $skipped' : '';
    return '${parts.join(' · ')}$skip';
  }
}

/// 인앱 Safari — 페이지 링크 수집·일괄 차단
class PageLinkHarvestService {
  PageLinkHarvestService._();

  static Future<List<HarvestedPageLink>> harvestFrom(WebViewController controller) async {
    try {
      final raw = await controller.runJavaScriptReturningResult(
        PageLinkHarvestScript.harvest,
      );
      final jsonStr = _coerceJsString(raw);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => HarvestedPageLink.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((e) => e.url.isNotEmpty && e.host.isNotEmpty)
          .toList();
    } catch (e) {
      IsleAppLogService.log('Page link harvest failed: $e', level: IsleLogLevel.warn);
      rethrow;
    }
  }

  static String? _coerceJsString(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw;
    return raw.toString();
  }

  static List<PageLinkDomainGroup> groupByDomain(
    List<HarvestedPageLink> links, {
    String? excludePageHost,
  }) {
    final pageHost = excludePageHost?.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final map = <String, List<HarvestedPageLink>>{};
    for (final link in links) {
      final host = link.host.toLowerCase();
      if (host.isEmpty) continue;
      if (pageHost != null && pageHost.isNotEmpty && host == pageHost) continue;
      map.putIfAbsent(host, () => []).add(link);
    }
    final groups = map.entries
        .map((e) => PageLinkDomainGroup(host: e.key, links: e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return groups;
  }

  static String? youtubeHandleFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final path = uri.path;
    final m = RegExp(r'^/@([\w.\-]+)').firstMatch(path);
    if (m != null) return '@${m.group(1)!.toLowerCase()}';
    return null;
  }

  static Future<PageLinkBulkBlockResult> applyBulk({
    required List<PageLinkDomainGroup> selectedGroups,
    required bool blockDomains,
    required bool blockUrls,
    required bool blockKeywords,
    required bool blockYoutubeChannels,
  }) async {
    var domainsAdded = 0;
    var urlsAdded = 0;
    var keywordsAdded = 0;
    var channelsAdded = 0;
    var skipped = 0;

    final domains = List<String>.from(WebsiteBlockStore.loadDomains());
    final domainSet = domains.map((e) => e.toLowerCase()).toSet();

    final keywords = List<String>.from(ContentFilterStore.loadKeywords());
    final keywordSet = keywords.map((e) => e.toLowerCase()).toSet();

    final urls = List<BlockedUrl>.from(BlockedUrlStore.loadAll());
    final urlSet = urls.map((e) => e.canonicalUrl.toLowerCase()).toSet();

    final channels = List<BlockedChannel>.from(BlockedChannelStore.loadAll());
    final channelKeys = {
      for (final c in channels) c.channelId.toLowerCase(),
      for (final c in channels) c.channelName.toLowerCase(),
    };

    final now = DateTime.now();

    for (final group in selectedGroups) {
      final host = group.host;
      if (blockDomains) {
        if (!BlockKeywordPolicy.isSafePremadeWebsiteDomain(host)) {
          skipped++;
        } else if (domainSet.contains(host)) {
          skipped++;
        } else {
          domains.add(host);
          domainSet.add(host);
          domainsAdded++;
        }
      }

      if (blockKeywords) {
        if (_addKeyword(host, keywordSet, keywords)) keywordsAdded++;
        final stem = host.split('.').first;
        if (stem.length >= 6 && _addKeyword(stem, keywordSet, keywords)) {
          keywordsAdded++;
        }
      }

      for (final link in group.links) {
        if (blockUrls) {
          final lower = link.url.toLowerCase();
          if (urlSet.contains(lower)) {
            skipped++;
          } else {
            urlSet.add(lower);
            urls.add(
              BlockedUrl(
                canonicalUrl: link.url,
                label: link.text.isNotEmpty ? link.text : host,
                youtubeVideoId: UrlParser.extractYouTubeVideoId(link.url),
                blockedAt: now,
              ),
            );
            urlsAdded++;
          }
        }

        if (blockYoutubeChannels) {
          final handle = youtubeHandleFromUrl(link.url);
          if (handle == null) continue;
          final slug = handle.substring(1);
          if (channelKeys.contains(handle) || channelKeys.contains(slug)) {
            skipped++;
          } else {
            channels.add(
              BlockedChannel(
                channelId: handle,
                channelName: slug,
                blockedAt: now,
              ),
            );
            channelKeys.add(handle);
            channelKeys.add(slug);
            channelsAdded++;
          }
        }
      }
    }

    if (domainsAdded > 0) await WebsiteBlockStore.saveDomains(domains);
    if (keywordsAdded > 0) await ContentFilterStore.saveKeywords(keywords);
    if (urlsAdded > 0) await BlockedUrlStore.saveAll(urls);
    if (channelsAdded > 0) await BlockedChannelStore.saveAll(channels);

    YoutubeBlockRulesSync.scheduleExport();
    if (IsleApplePlatform.isScreenTimeHost) {
      await IosRulesExportService.exportNow();
    }

    IsleAppLogService.log(
      'Page bulk block: +dom$domainsAdded +url$urlsAdded +kw$keywordsAdded +ch$channelsAdded skip$skipped',
    );

    return PageLinkBulkBlockResult(
      domainsAdded: domainsAdded,
      urlsAdded: urlsAdded,
      keywordsAdded: keywordsAdded,
      channelsAdded: channelsAdded,
      skipped: skipped,
    );
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
}
