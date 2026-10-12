import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/youtube/models/blocked_channel.dart';
import 'package:isle/core/youtube/models/blocked_video.dart';
import 'package:isle/core/youtube/youtube_channel_block_guard.dart';
import 'package:isle/core/youtube/youtube_channel_block_script.dart';

final _at = DateTime(2026, 6, 8);

BlockedChannel ch({String id = '', String name = ''}) => BlockedChannel(
      channelId: id,
      channelName: name,
      blockedAt: _at,
    );

BlockedVideo vid(String id) => BlockedVideo(
      videoId: id,
      blockedAt: _at,
    );

void main() {
  group('YoutubeChannelBlockGuard.matchUrl', () {
    final channels = [
      ch(id: 'UCblocked123', name: '테스트 채널'),
      ch(id: '@starcraft', name: '스타크래프트'),
    ];
    const videos = <BlockedVideo>[];
    const keywords = <String>[];

    test('allows unrelated youtube url even with noisy keyword', () {
      expect(
        YoutubeChannelBlockGuard.matchUrl(
          'https://m.youtube.com/watch?v=dQw4w9WgXcQ',
          channels: const [],
          videos: const [],
          keywords: const ['youtube'],
        ),
        isNull,
      );
    });

    test('allows unrelated youtube url', () {
      expect(
        YoutubeChannelBlockGuard.matchUrl(
          'https://m.youtube.com/watch?v=dQw4w9WgXcQ',
          channels: channels,
          videos: videos,
          keywords: keywords,
        ),
        isNull,
      );
    });

    test('blocks @handle channel home', () {
      final hit = YoutubeChannelBlockGuard.matchUrl(
        'https://m.youtube.com/@starcraft',
        channels: channels,
        videos: videos,
        keywords: keywords,
      );
      expect(hit?.kind, YoutubeBlockKind.channel);
      expect(hit?.label, contains('스타'));
    });

    test('blocks /channel/UC id', () {
      final hit = YoutubeChannelBlockGuard.matchUrl(
        'https://www.youtube.com/channel/UCblocked123',
        channels: channels,
        videos: videos,
        keywords: keywords,
      );
      expect(hit?.kind, YoutubeBlockKind.channel);
    });

    test('blocks watch url with channel_id query', () {
      final hit = YoutubeChannelBlockGuard.matchUrl(
        'https://m.youtube.com/watch?v=abc12345678&channel_id=UCblocked123',
        channels: channels,
        videos: videos,
        keywords: keywords,
      );
      expect(hit?.kind, YoutubeBlockKind.channel);
    });

    test('blocks hidden video id', () {
      final hit = YoutubeChannelBlockGuard.matchUrl(
        'https://youtu.be/abc12345678',
        channels: const [],
        videos: [vid('abc12345678')],
        keywords: const [],
      );
      expect(hit?.kind, YoutubeBlockKind.video);
    });

    test('ignores non-youtube', () {
      expect(
        YoutubeChannelBlockGuard.matchUrl(
          'https://brunch.co.kr/@writer',
          channels: channels,
          videos: videos,
          keywords: keywords,
        ),
        isNull,
      );
    });
  });

  group('YoutubeChannelBlockGuard.matchProbe', () {
    test('blocks by channel id from watch probe', () {
      final hit = YoutubeChannelBlockGuard.matchProbe(
        channels: [ch(id: 'UCprobe99', name: '프로브 채널')],
        videos: const [],
        keywords: const [],
        channelId: 'UCprobe99',
        channelName: '프로브 채널',
        videoId: 'dQw4w9WgXcQ',
        videoTitle: '제목',
      );
      expect(hit?.kind, YoutubeBlockKind.channel);
      expect(hit?.label, '프로브 채널');
    });

    test('blocks by channel name when id differs', () {
      final hit = YoutubeChannelBlockGuard.matchProbe(
        channels: [ch(id: 'UCsaved', name: '알고리즘 채널')],
        videos: const [],
        keywords: const [],
        channelId: 'UCother',
        channelName: '알고리즘 채널',
        videoId: 'abcdefghijk',
      );
      expect(hit?.kind, YoutubeBlockKind.channel);
    });

    test('blocks keyword in title', () {
      final hit = YoutubeChannelBlockGuard.matchProbe(
        channels: const [],
        videos: const [],
        keywords: const ['스타크래프트'],
        channelId: 'UCx',
        channelName: '게임',
        videoTitle: '스타크래프트 하이라이트',
        videoId: 'abcdefghijk',
      );
      expect(hit?.kind, YoutubeBlockKind.keyword);
    });
  });

  group('BlockedChannel.matches', () {
    test('matches @handle case-insensitively', () {
      final blocked = ch(id: '@StarCraft', name: 'SC');
      expect(
        blocked.matches(
            const FeedChannelRef(channelId: '@starcraft', channelName: '')),
        isTrue,
      );
    });
  });

  group('YoutubeChannelBlockScript', () {
    test('emits ids and dom sweep hooks', () {
      final script = YoutubeChannelBlockScript.build(
        [ch(id: 'UCtest123', name: 'Test')],
        blockedVideoIds: const ['abcdefghijk'],
        blockedKeywords: const ['starcraft'],
      );
      expect(script, contains('UCtest123'));
      expect(script, contains('abcdefghijk'));
      expect(script, contains('starcraft'));
      expect(script, contains('installClickGuard'));
      expect(script, contains('startIntervalSweep'));
      expect(script, contains('ytm-rich-grid-media'));
      expect(script, contains('enforceWatchPageBlock'));
      expect(script, contains('visibilitychange'));
    });

    test('light mode defers heavy sweep for search', () {
      final script = YoutubeChannelBlockScript.build(
        [ch(id: 'UCx', name: 'X')],
        lightMode: true,
      );
      expect(script, contains('const LIGHT = true'));
      expect(script, contains('1800'));
      expect(script, contains('7000'));
    });

    test('skips work when lists empty', () {
      final script = YoutubeChannelBlockScript.build(const []);
      expect(script, contains('if (!blockedIds.length'));
    });

    test('installs a fullscreen guard so preset/keyword/channel blocks '
        'cannot escape via native fullscreen playback (2026-07-13 실사용 '
        '제보 — "한도 없음" 상태에서 프리셋으로 막은 영상도 전체화면을 누르면 '
        '그대로 재생되던 버그, 한도 차단 엔진에만 있던 fullscreen 가드를 '
        '프리셋 차단 쪽에도 추가)', () {
      final script = YoutubeChannelBlockScript.build(
        [ch(id: 'UCtest123', name: 'Test')],
      );
      expect(script, contains('installFullscreenGuard'));
      expect(script, contains('webkitbeginfullscreen'));
      expect(script, contains('fullscreenchange'));
      expect(script, contains('webkitExitFullscreen'));
      expect(script, contains('document.webkitFullscreenElement'));
      expect(script, contains('setTimeout(function(){ exitAndPause(v); }, 600)'));
      expect(script, contains("urlBlocked(location.href || '')"));
    });
  });
}
