import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/youtube/models/blocked_channel.dart';
import 'package:isle/core/youtube/youtube_channel_block_guard.dart';
import 'package:isle/core/youtube/youtube_link_canonical.dart';

final _at = DateTime(2026, 6, 17);

BlockedChannel ch({String id = 'UCblocked123', String name = '테스트 채널'}) =>
    BlockedChannel(channelId: id, channelName: name, blockedAt: _at);

void main() {
  group('YoutubeLinkCanonical', () {
    test('unwraps google redirect to watch url', () {
      const wrapped =
          'https://www.google.com/url?q=https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      expect(
        YoutubeLinkCanonical.normalizeForBlockCheck(wrapped),
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
    });
  });

  group('Feed viewer bypass — channel metadata without url channel id', () {
    test('matchProbe blocks watch url when feed channelId is blocked', () {
      const watch = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      final hit = YoutubeChannelBlockGuard.matchProbe(
        channels: [ch()],
        videos: const [],
        keywords: const [],
        blockedUrls: const [],
        channelId: 'UCblocked123',
        channelName: '테스트 채널',
        videoId: 'dQw4w9WgXcQ',
        videoTitle: '',
        url: watch,
      );
      expect(hit, isNotNull);
      expect(hit!.snackMessage, contains('차단'));
    });
  });

  group('Google redirect bypass', () {
    test('matchUrl sees channel after canonical unwrap', () {
      const wrapped =
          'https://www.google.com/url?q=https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      final canonical = YoutubeLinkCanonical.normalizeForBlockCheck(wrapped);
      final hit = YoutubeChannelBlockGuard.matchUrl(
        canonical,
        channels: [ch()],
        videos: const [],
        keywords: const [],
      );
      expect(hit, isNull);
    });

    test('matchProbe blocks google wrapper with feed metadata', () {
      const wrapped =
          'https://www.google.com/url?q=https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      final canonical = YoutubeLinkCanonical.normalizeForBlockCheck(wrapped);
      final hit = YoutubeChannelBlockGuard.matchProbe(
        channels: [ch()],
        videos: const [],
        keywords: const [],
        blockedUrls: const [],
        channelId: 'UCblocked123',
        channelName: '테스트 채널',
        videoId: 'dQw4w9WgXcQ',
        videoTitle: '',
        url: canonical,
      );
      expect(hit, isNotNull);
    });
  });
}
