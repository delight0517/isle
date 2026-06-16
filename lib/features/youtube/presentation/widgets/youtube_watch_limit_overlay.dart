import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/navigation/isle_routes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/youtube/youtube_access_guard.dart';
import '../../../../core/youtube/youtube_watch_timer_store.dart';
import 'screen_time_guide_sheet.dart';

/// 일일 한도 또는 스케줄 잠금 시 WebView 위 오버레이
class YoutubeWatchLimitOverlay extends StatelessWidget {
  const YoutubeWatchLimitOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final lock = YoutubeAccessGuard.activeLock();
    if (lock == null) return const SizedBox.shrink();

    if (lock == YoutubeLockReason.schedule) {
      return _LockScaffold(
        icon: Icons.phonelink_lock,
        title: 'Isle 앱 안 YouTube 차단 중',
        body: '이 스케줄에서 「Isle · YouTube 시청」을 막아 두었어요.\n'
            '끄려면 스케줄 편집 → 차단·한도 대상에서 해제하세요.',
        primaryLabel: '스케줄 설정',
        onPrimary: () => context.push(IsleRoutes.blockSchedules),
        secondaryLabel: 'Safari·다른 앱 (Screen Time)',
        onSecondary: () => showScreenTimeGuideSheet(context),
      );
    }

    final reset = YoutubeWatchTimerStore.timeUntilReset();
    final h = reset.inHours;
    final m = reset.inMinutes.remainder(60);
    final interval = YoutubeWatchTimerStore.usesInterval;
    return _LockScaffold(
      icon: Icons.lock_clock,
      title: interval ? '이번 주기 유튜브 한도에 도달했어요' : '오늘 유튜브 한도에 도달했어요',
      body: interval
          ? '다음 주기까지 $h시간 $m분 남았어요.\n'
              '지금은 허용 분을 올릴 수 없습니다.'
          : '한도는 자정 이후에 바꿀 수 있어요 ($h시간 $m분 남음).\n'
              '지금은 설정에서 분을 올릴 수 없습니다.',
      primaryLabel: '설정 (타임락)',
      onPrimary: () => context.push(IsleRoutes.youtubeLimits),
    );
  }
}

class _LockScaffold extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _LockScaffold({
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: Colors.white),
                const SizedBox(height: 16),
                Text(title, style: IsleText.subtitle(color: Colors.white), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(body, style: IsleText.caption(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
                if (secondaryLabel != null && onSecondary != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!, style: IsleText.body(color: IsleColors.ocean100)),
                  ),
                ],
                TextButton(onPressed: () => context.pop(), child: Text('나가기', style: IsleText.body(color: Colors.white70))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
