import 'package:xml/xml.dart';

import '../../features/feed/data/models/feed_item.dart';
import '../utils/topic_matcher.dart';
import '../utils/url_parser.dart';

/// RSS 2.0 / Atom → FeedItem (외부 API 없음)
class RssFeedParser {
  RssFeedParser._();

  static List<FeedItem> parse(
    String body, {
    required String sourceId,
    required String channelName,
    required String sourceType,
    int maxItems = 20,
  }) {
    try {
      final doc = XmlDocument.parse(body);
      final root = doc.rootElement;
      if (root.localName == 'feed') {
        return _parseAtom(root, sourceId: sourceId, channelName: channelName, sourceType: sourceType, max: maxItems);
      }
      return _parseRss2(root, sourceId: sourceId, channelName: channelName, sourceType: sourceType, max: maxItems);
    } catch (_) {
      return [];
    }
  }

  static List<FeedItem> _parseRss2(
    XmlElement root, {
    required String sourceId,
    required String channelName,
    required String sourceType,
    required int max,
  }) {
    final channel = root.findElements('channel').firstOrNull ?? root;
    final feedTitle = channel.findElements('title').firstOrNull?.innerText ?? channelName;
    final out = <FeedItem>[];
    for (final item in channel.findElements('item').take(max)) {
      final link = item.findElements('link').firstOrNull?.innerText.trim() ??
          item.findElements('guid').firstOrNull?.innerText.trim() ??
          '';
      if (link.isEmpty || !link.startsWith('http')) continue;
      final title = item.findElements('title').firstOrNull?.innerText.trim() ?? link;
      final pub = item.findElements('pubDate').firstOrNull?.innerText;
      final thumb = item.findElements('enclosure').firstOrNull?.getAttribute('url') ??
          item.findElements('media:thumbnail').firstOrNull?.getAttribute('url');
      out.add(_item(
        url: link,
        title: title,
        channelId: sourceId,
        channelName: feedTitle.isNotEmpty ? feedTitle : channelName,
        sourceType: sourceType,
        publishedAt: _parseDate(pub),
        thumbnailUrl: thumb,
      ));
    }
    return out;
  }

  static List<FeedItem> _parseAtom(
    XmlElement feed, {
    required String sourceId,
    required String channelName,
    required String sourceType,
    required int max,
  }) {
    final feedTitle = feed.findElements('title').firstOrNull?.innerText ?? channelName;
    final out = <FeedItem>[];
    for (final entry in feed.findElements('entry').take(max)) {
      var link = entry.findElements('link').firstWhere(
            (e) => e.getAttribute('rel') == 'alternate' || e.getAttribute('href') != null,
            orElse: () => entry.findElements('link').first,
          ).getAttribute('href') ??
          entry.findElements('link').firstOrNull?.innerText ??
          '';
      link = link.trim();
      if (link.isEmpty) {
        final id = entry.findElements('id').firstOrNull?.innerText ?? '';
        if (id.startsWith('http')) link = id;
      }
      if (link.isEmpty) continue;

      final title = entry.findElements('title').firstOrNull?.innerText.trim() ?? link;
      final pub = entry.findElements('published').firstOrNull?.innerText ??
          entry.findElements('updated').firstOrNull?.innerText;

      String? thumb;
      for (final m in entry.findAllElements('thumbnail')) {
        thumb ??= m.getAttribute('url');
      }
      for (final m in entry.findAllElements('content')) {
        final url = RegExp(r'https?://[^\s"<>]+').firstMatch(m.innerText)?.group(0);
        if (thumb == null && url != null && url.contains('i.ytimg.com')) thumb = url;
      }

      final ytId = UrlParser.extractYouTubeVideoId(link);
      if (ytId != null && (thumb == null || thumb.isEmpty)) {
        thumb = UrlParser.youTubeThumbnail(ytId);
      }

      out.add(_item(
        url: link,
        title: title,
        channelId: sourceId,
        channelName: feedTitle,
        sourceType: ytId != null ? 'youtube' : sourceType,
        publishedAt: _parseDate(pub),
        thumbnailUrl: thumb,
      ));
    }
    return out;
  }

  static FeedItem _item({
    required String url,
    required String title,
    required String channelId,
    required String channelName,
    required String sourceType,
    required DateTime publishedAt,
    String? thumbnailUrl,
  }) {
    final topics = TopicMatcher.detectTopics('$title $channelName');
    return FeedItem(
      id: 'ingest_${url.hashCode}',
      title: title,
      url: url,
      thumbnailUrl: thumbnailUrl ?? '',
      sourceType: sourceType,
      channelId: channelId,
      channelName: channelName,
      channelAvatar: '',
      detectedTopics: topics,
      relevanceScore: 0.72,
      publishedAt: publishedAt,
    );
  }

  static DateTime _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return DateTime.now();
    return DateTime.tryParse(raw) ?? DateTime.now();
  }
}
