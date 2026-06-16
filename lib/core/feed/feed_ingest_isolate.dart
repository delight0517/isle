import '../../features/feed/data/models/feed_item.dart';
import 'rss_feed_parser.dart';

/// RSS XML 파싱 — `compute()` isolate 진입점
List<Map<String, dynamic>> parseRssInIsolate(Map<String, dynamic> args) {
  final items = RssFeedParser.parse(
    args['body'] as String,
    sourceId: args['sourceId'] as String,
    channelName: args['channelName'] as String,
    sourceType: args['sourceType'] as String,
    maxItems: args['maxItems'] as int,
  );
  return items.map((e) => e.toJson()).toList();
}

bool _isDemoJson(Map<String, dynamic> j) {
  final id = j['id'] as String? ?? '';
  final url = j['content_url'] as String? ?? '';
  return id.startsWith('dummy_') || url.contains('example');
}

DateTime _publishedAt(Map<String, dynamic> j) =>
    DateTime.tryParse(j['published_at'] as String? ?? '') ??
    DateTime.fromMillisecondsSinceEpoch(0);

/// 중복 제거·최신순 정렬 — `compute()` isolate 진입점
List<Map<String, dynamic>> dedupeAndSortInIsolate(List<Map<String, dynamic>> maps) {
  final byUrl = <String, Map<String, dynamic>>{};
  for (final m in maps) {
    if (_isDemoJson(m)) continue;
    final url = m['content_url'] as String? ?? '';
    if (url.isEmpty) continue;
    final existing = byUrl[url];
    if (existing == null || _publishedAt(m).isAfter(_publishedAt(existing))) {
      byUrl[url] = m;
    }
  }
  final list = byUrl.values.toList()
    ..sort((a, b) => _publishedAt(b).compareTo(_publishedAt(a)));
  return list;
}

List<FeedItem> feedItemsFromJsonMaps(List<Map<String, dynamic>> maps) =>
    maps.map((m) => FeedItem.fromJson(m)).toList();
