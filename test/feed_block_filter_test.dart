import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/feed/feed_block_filter.dart';
import 'package:isle/core/youtube/models/blocked_channel.dart';
import 'package:isle/core/youtube/models/blocked_url.dart';
import 'package:isle/features/feed/data/models/feed_item.dart';

FeedItem _item({
  required String title,
  String channelName = 'ch',
  String url = 'https://example.com/a',
}) =>
    FeedItem(
      id: title,
      title: title,
      url: url,
      thumbnailUrl: '',
      sourceType: 'article',
      channelId: 'c1',
      channelName: channelName,
      channelAvatar: '',
      detectedTopics: const [],
      relevanceScore: 0.5,
      publishedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  test('filters by keyword sync path', () async {
    final items = [
      _item(title: '연예 뉴스'),
      _item(title: '기술 블로그'),
    ];
    final out = await FeedBlockFilter.apply(
      items: items,
      channels: const [],
      videoIds: const [],
      keywords: const ['연예'],
      blockedUrls: const [],
      enabled: true,
    );
    expect(out.length, 1);
    expect(out.first.title, '기술 블로그');
  });

  test('filters by channel and url', () async {
    final items = [
      _item(
        title: 'vid',
        channelName: 'PewDiePie',
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      ),
      _item(title: 'ok'),
    ];
    final out = await FeedBlockFilter.apply(
      items: items,
      channels: [
        BlockedChannel(
          channelId: '@pewdiepie',
          channelName: 'pewdiepie',
          blockedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      videoIds: const [],
      keywords: const [],
      blockedUrls: [
        BlockedUrl(
          canonicalUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          youtubeVideoId: 'dQw4w9WgXcQ',
          blockedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      enabled: true,
    );
    expect(out.length, 1);
    expect(out.first.title, 'ok');
  });
}
