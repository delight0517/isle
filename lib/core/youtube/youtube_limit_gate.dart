import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import 'youtube_access_guard.dart';
import 'youtube_watch_timer_store.dart';

/// 유튜브 일일·스케줄 한도 — 모든 재생 진입점 공통 가드
class YoutubeLimitGate {
  YoutubeLimitGate._();

  static bool get isLocked => YoutubeAccessGuard.shouldBlockWebView;

  static String blockedTitle(YoutubeLockReason reason) => switch (reason) {
        YoutubeLockReason.schedule => 'Isle 앱 안 YouTube 차단 중',
        YoutubeLockReason.dailyLimit => YoutubeWatchTimerStore.usesInterval
            ? '이번 주기 유튜브 한도에 도달했어요'
            : '오늘 유튜브 한도에 도달했어요',
      };

  static String blockedBody(YoutubeLockReason reason) => switch (reason) {
        YoutubeLockReason.schedule =>
          '이 스케줄에서 Isle 앱 안 YouTube 시청을 막아 두었어요.',
        YoutubeLockReason.dailyLimit =>
          '한도는 설정 화면에서만 바꿀 수 있어요. 지금은 재생할 수 없습니다.',
      };

  /// true = 진행 가능 · false = 잠금(스낵바 표시)
  static bool guard(BuildContext context) {
    final lock = YoutubeAccessGuard.activeLock();
    if (lock == null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(blockedTitle(lock)),
        backgroundColor: IsleColors.danger,
      ),
    );
    return false;
  }

  /// 집중 모드·아카이브 등 전체 화면 대체
  static Widget? lockedBody(BuildContext context) {
    final lock = YoutubeAccessGuard.activeLock();
    if (lock == null) return null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock, size: 56, color: IsleColors.danger),
            const SizedBox(height: 16),
            Text(
              blockedTitle(lock),
              style: IsleText.subtitle(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              blockedBody(lock),
              style: IsleText.caption(color: IsleColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('돌아가기'),
            ),
          ],
        ),
      ),
    );
  }
}
