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
        YoutubeLockReason.scheduleLimit => '이 시간대 유튜브 리필 한도에 도달했어요',
        YoutubeLockReason.dailyLimit => YoutubeWatchTimerStore.usesInterval
            ? '이번 주기 유튜브 한도에 도달했어요'
            : '오늘 유튜브 한도에 도달했어요',
        YoutubeLockReason.budget => '유튜브 사용권을 다 썼어요',
      };

  static String blockedBody(YoutubeLockReason reason) => switch (reason) {
        YoutubeLockReason.schedule => '이 스케줄에서 Isle 앱 안 YouTube 시청을 막아 두었어요.',
        YoutubeLockReason.scheduleLimit =>
          '이 시간대 스케줄이 정한 유튜브 리필 한도를 다 썼어요.\n'
              '다음 리필 창이 되면 다시 볼 수 있어요.',
        YoutubeLockReason.dailyLimit => _dailyLimitBody(),
        YoutubeLockReason.budget =>
          '${YoutubeWatchTimerStore.formatStatusLine()}\n잠시 쉬면 다시 충전돼요.',
      };

  static String _dailyLimitBody() {
    final used = YoutubeWatchTimerStore.secondsUsed ~/ 60;
    final cap = YoutubeWatchTimerStore.limitSeconds ~/ 60;
    final reset = YoutubeWatchTimerStore.timeUntilReset();
    final h = reset.inHours;
    final m = reset.inMinutes.remainder(60);
    final wait = h > 0 ? '$h시간 $m분' : '$m분';
    if (YoutubeWatchTimerStore.usesInterval) {
      return '이번 주기 $used / $cap분을 모두 썼어요.\n'
          '다음 주기까지 $wait 남았어요. (스케줄 차단이 아닙니다)';
    }
    return '오늘 $used / $cap분을 모두 썼어요.\n'
        '자정 이후 다시 볼 수 있어요 ($wait 남음). (스케줄 차단이 아닙니다)';
  }

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
