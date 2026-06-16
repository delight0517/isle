import 'package:flutter/foundation.dart';

import '../../features/feed/data/models/feed_item.dart';
import '../youtube/block_keyword_policy.dart';
import '../youtube/models/blocked_channel.dart';
import '../youtube/models/blocked_url.dart';

/// 피드 차단 필터 — 대량 키워드·URL 시 isolate
class FeedBlockFilter {
  FeedBlockFilter._();

  static const _isolateRuleThreshold = 72;
  static const _isolateItemThreshold = 48;

  static Future<List<FeedItem>> apply({
    required List<FeedItem> items,
    required List<BlockedChannel> channels,
    required List<String> videoIds,
    required List<String> keywords,
    required List<BlockedUrl> blockedUrls,
    required bool enabled,
  }) async {
    if (!enabled || items.isEmpty) return items;

    final ruleCount = channels.length + videoIds.length + keywords.length + blockedUrls.length;
    final useIsolate = ruleCount >= _isolateRuleThreshold || items.length >= _isolateItemThreshold;

    if (useIsolate) {
      final maps = await compute(_filterInIsolate, {
        'items': items.map((e) => e.toJson()).toList(),
        'channels': channels.map((e) => e.toJson()).toList(),
        'video_ids': videoIds,
        'keywords': BlockKeywordPolicy.forTitleMatch(keywords),
        'blocked_urls': blockedUrls.map((e) => e.canonicalUrl).toList(),
        'blocked_video_ids': blockedUrls
            .map((e) => e.youtubeVideoId)
            .whereType<String>()
            .where((id) => id.length == 11)
            .toList(),
      });
      return maps.map((m) => FeedItem.fromJson(m)).toList();
    }

    return _filterSync(
      items: items,
      channels: channels,
      videoIds: videoIds,
      keywords: BlockKeywordPolicy.forTitleMatch(keywords),
      blockedUrls: blockedUrls,
    );
  }

  static List<FeedItem> _filterSync({
    required List<FeedItem> items,
    required List<BlockedChannel> channels,
    required List<String> videoIds,
    required List<String> keywords,
    required List<BlockedUrl> blockedUrls,
  }) {
    final urlSet = {
      for (final u in blockedUrls) u.canonicalUrl.toLowerCase(),
    };
    final blockedVidSet = {
      ...videoIds,
      for (final u in blockedUrls)
        if (u.youtubeVideoId != null && u.youtubeVideoId!.length == 11) u.youtubeVideoId!,
    };

    return items.where((i) {
      if (_urlBlocked(i.url, urlSet, blockedVidSet)) return false;
      if (_channelBlocked(i, channels)) return false;
      if (i.sourceType == 'youtube') {
        final vid = _extractVideoId(i.url);
        if (vid != null && blockedVidSet.contains(vid)) return false;
      }
      if (_keywordBlocked('${i.title} ${i.channelName}', keywords)) return false;
      return true;
    }).toList();
  }
}

List<Map<String, dynamic>> _filterInIsolate(Map<String, dynamic> args) {
  final itemMaps = (args['items'] as List).cast<Map<String, dynamic>>();
  final channelMaps = (args['channels'] as List).cast<Map<String, dynamic>>();
  final videoIds = (args['video_ids'] as List).cast<String>();
  final keywords = (args['keywords'] as List).cast<String>();
  final blockedUrls = (args['blocked_urls'] as List).cast<String>();
  final blockedVideoIds = (args['blocked_video_ids'] as List).cast<String>();

  final urlSet = blockedUrls.map((e) => e.toLowerCase()).toSet();
  final blockedVidSet = {...videoIds, ...blockedVideoIds};

  final channels = channelMaps.map((m) => BlockedChannel.fromJson(m)).toList();

  final out = <Map<String, dynamic>>[];
  for (final m in itemMaps) {
    final item = FeedItem.fromJson(m);
    if (_urlBlocked(item.url, urlSet, blockedVidSet)) continue;
    if (_channelBlocked(item, channels)) continue;
    if (item.sourceType == 'youtube') {
      final vid = _extractVideoId(item.url);
      if (vid != null && blockedVidSet.contains(vid)) continue;
    }
    if (_keywordBlocked('${item.title} ${item.channelName}', keywords)) continue;
    out.add(m);
  }
  return out;
}

bool _urlBlocked(String url, Set<String> urlSet, Set<String> blockedVidSet) {
  final lower = url.toLowerCase();
  if (urlSet.contains(lower)) return true;
  final vid = _extractVideoId(url);
  return vid != null && blockedVidSet.contains(vid);
}

bool _channelBlocked(FeedItem item, List<BlockedChannel> channels) {
  final ref = FeedChannelRef(channelId: item.channelId, channelName: item.channelName);
  for (final c in channels) {
    if (c.matches(ref)) return true;
  }
  return false;
}

bool _keywordBlocked(String haystack, List<String> keywords) {
  if (keywords.isEmpty) return false;
  final hay = haystack.toLowerCase();
  for (final kw in keywords) {
    if (kw.isNotEmpty && hay.contains(kw)) return true;
  }
  return false;
}

String? _extractVideoId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final v = uri.queryParameters['v'];
  if (v != null && v.length == 11) return v;
  if (uri.host.contains('youtu.be')) {
    final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    if (seg.length == 11) return seg;
  }
  return null;
}
