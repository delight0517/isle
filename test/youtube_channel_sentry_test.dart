import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/youtube/models/blocked_channel.dart';
import 'package:isle/core/youtube/youtube_channel_block_script.dart';
import 'package:isle/core/youtube/youtube_channel_pattern_normalizer.dart';

void main() {
  group('YoutubeChannelPatternNormalizer', () {
    test('UC id passthrough', () {
      expect(
        YoutubeChannelPatternNormalizer.normalizeEntry('UCabcdefghijk'),
        ['UCabcdefghijk'],
      );
    });

    test('@handle lowercased', () {
      expect(
        YoutubeChannelPatternNormalizer.normalizeEntry('@WinterStarcraft'),
        ['@winterstarcraft'],
      );
    });
  });

  group('YoutubeChannelBlockScript', () {
    test('includes search preview selectors', () {
      final js = YoutubeChannelBlockScript.build([
        BlockedChannel(
          channelId: '@winterstarcraft',
          channelName: 'WinterStarcraft',
          blockedAt: DateTime(2026),
        ),
      ]);
      expect(js, contains('ytd-search-video-renderer'));
      expect(js, contains('ytm-media-item-renderer'));
      expect(js, contains('isle-yt-channel-css'));
      expect(js, contains('hideBlockedChannelLinkContainers'));
      expect(js, contains('isle-yt-channel-blocked-banner'));
    });

    test('immediately checks fullscreen state after installing the guard', () {
      final js = YoutubeChannelBlockScript.build([
        BlockedChannel(
          channelId: 'UCtest123',
          channelName: 'Test',
          blockedAt: DateTime(2026),
        ),
      ]);
      expect(js, contains('installFullscreenGuard'));
      expect(js, contains('runImmediateFullscreenCheck'));
      expect(js, contains('webkitbeginfullscreen'));
      expect(js, contains('fullscreenchange'));
    });
  });
}
