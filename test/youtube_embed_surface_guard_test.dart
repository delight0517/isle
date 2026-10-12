import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/youtube/models/blocked_channel.dart';
import 'package:isle/core/youtube/youtube_embed_surface_guard_script.dart';

void main() {
  test('embed surface guard applies block rules and heartbeat', () {
    final js = YoutubeEmbedSurfaceGuardScript.build(
      channels: [
        BlockedChannel(
          channelId: 'UC123',
          channelName: 'Test Channel',
          blockedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      blockedVideoIds: const ['abcdefghijk'],
      blockedKeywords: const ['금지어'],
      playbackBlocked: false,
      hideInlinePreview: false,
    );
    expect(js, contains('IsleEmbedSurface'));
    expect(js, contains('IsleChannel'));
    expect(js, contains('heartbeat'));
    expect(js, contains('matchesBlock'));
    expect(js, contains('Test Channel'));
    expect(js, contains('abcdefghijk'));
    expect(js, contains('금지어'));
  });

  test('installs a fullscreen guard so blocked embeds cannot escape via '
      'native fullscreen playback (2026-07-13 실사용 제보 — 프리셋/키워드로 '
      '막힌 임베드 영상도 전체화면을 누르면 그대로 재생되던 버그)', () {
    final js = YoutubeEmbedSurfaceGuardScript.build(
      channels: const [],
      blockedVideoIds: const [],
      blockedKeywords: const [],
      playbackBlocked: false,
      hideInlinePreview: false,
    );
    expect(js, contains('installFullscreenGuard'));
    expect(js, contains('runImmediateFullscreenCheck'));
    expect(js, contains('webkitbeginfullscreen'));
    expect(js, contains('fullscreenchange'));
    expect(js, contains('webkitExitFullscreen'));
  });
}
