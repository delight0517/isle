import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/feed/feed_ingest_isolate.dart';

const _sampleRss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test Channel</title>
    <item>
      <title>Alpha</title>
      <link>https://example.com/a</link>
      <pubDate>Mon, 01 Jan 2024 10:00:00 GMT</pubDate>
    </item>
    <item>
      <title>Beta</title>
      <link>https://example.com/b</link>
      <pubDate>Tue, 02 Jan 2024 10:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';

void main() {
  test('parseRssInIsolate returns feed json maps', () {
    final maps = parseRssInIsolate({
      'body': _sampleRss,
      'sourceId': 'src1',
      'channelName': 'Test',
      'sourceType': 'article',
      'maxItems': 10,
    });
    expect(maps.length, 2);
    expect(maps.map((m) => m['title']).toSet(), {'Alpha', 'Beta'});
    expect(maps.first['channel_name'], 'Test Channel');
  });

  test('dedupeAndSortInIsolate keeps newest per url', () {
    final merged = dedupeAndSortInIsolate([
      {
        'id': '1',
        'title': 'Old',
        'content_url': 'https://site.com/x',
        'published_at': '2024-01-01T00:00:00.000Z',
        'thumbnail_url': '',
        'source_type': 'article',
        'channel_id': 'c',
        'channel_name': 'C',
        'channel_avatar': '',
        'detected_topics': <String>[],
        'relevance_score': 0.5,
      },
      {
        'id': '2',
        'title': 'New',
        'content_url': 'https://site.com/x',
        'published_at': '2024-06-01T00:00:00.000Z',
        'thumbnail_url': '',
        'source_type': 'article',
        'channel_id': 'c',
        'channel_name': 'C',
        'channel_avatar': '',
        'detected_topics': <String>[],
        'relevance_score': 0.5,
      },
      {
        'id': 'dummy_skip',
        'title': 'Demo',
        'content_url': 'https://example.com/demo',
        'published_at': '2024-06-02T00:00:00.000Z',
        'thumbnail_url': '',
        'source_type': 'article',
        'channel_id': 'c',
        'channel_name': 'C',
        'channel_avatar': '',
        'detected_topics': <String>[],
        'relevance_score': 0.5,
      },
    ]);
    expect(merged.length, 1);
    expect(merged.single['title'], 'New');
  });
}
