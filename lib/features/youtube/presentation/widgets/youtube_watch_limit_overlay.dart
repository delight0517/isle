import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/block_schedule/schedule_block_user_message.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/navigation/isle_navigation.dart';
import '../../../../core/navigation/isle_routes.dart';
import '../../../../core/navigation/schedule_overlay_navigation.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/block_schedule/schedule_target_access_guard.dart';
import '../../../../core/youtube/youtube_access_guard.dart';
import '../../../../core/youtube/youtube_watch_timer_store.dart';
import 'screen_time_guide_sheet.dart';

/// 일일 한도 또는 스케줄 잠금 시 WebView 위 오버레이 (YouTube 전용 단일 잠금 UI)
class YoutubeWatchLimitOverlay extends StatelessWidget {
  const YoutubeWatchLimitOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final lock = YoutubeAccessGuard.activeLock();
    if (lock == null) return const SizedBox.shrink();

    if (lock == YoutubeLockReason.schedule) {
      final copy = ScheduleBlockUserMessage.youtubeWebViewScheduleLockCopy();
      return _LockScaffold(
        icon: Icons.phonelink_lock,
        title: copy.title,
        body: copy.body,
        primaryLabel: copy.primaryButtonLabel ?? '이 스케줄 편집',
        onPrimary: () =>
            openBlockScheduleFromOverlay(context, scheduleId: copy.scheduleId),
        secondaryLabel: 'Safari·다른 앱 (Screen Time)',
        onSecondary: () => showScreenTimeGuideSheet(context),
      );
    }

    if (lock == YoutubeLockReason.scheduleLimit) {
      final etaSeconds = ScheduleTargetAccessGuard.youtubeScheduleLimitEtaSecondsSync();
      final waitLine = etaSeconds == null
          ? '다음 리필 창이 되면 다시 볼 수 있어요.'
          : '${_formatWait(etaSeconds)} 후 다시 볼 수 있어요.';
      return _LockScaffold(
        icon: Icons.hourglass_disabled,
        badge: '리필 한도',
        title: '이 시간대 유튜브 리필 한도를 다 썼어요',
        body: '스케줄이 정한 유튜브 리필 한도에 도달했어요.\n'
            '$waitLine\n'
            '(겹친 스케줄 중 가장 빡빡한 규칙이 적용됩니다.)',
        primaryLabel: '스케줄 목록',
        onPrimary: () => openBlockScheduleFromOverlay(context),
      );
    }

    final reset = YoutubeWatchTimerStore.timeUntilReset();
    final h = reset.inHours;
    final m = reset.inMinutes.remainder(60);
    final wait = h > 0 ? '$h시간 $m분' : '$m분';
    final used = YoutubeWatchTimerStore.secondsUsed ~/ 60;
    final cap = YoutubeWatchTimerStore.limitSeconds ~/ 60;
    final interval = YoutubeWatchTimerStore.usesInterval;
    return _LockScaffold(
      icon: Icons.hourglass_disabled,
      badge: '시청 한도',
      title: interval ? '이번 주기 YouTube 시간을 다 썼어요' : '오늘 YouTube 시간을 다 썼어요',
      body: interval
          ? '이번 주기 $used / $cap분 사용 · 다음 주기까지 $wait\n'
              '스케줄 차단이 아니라 설정한 시청 한도예요.'
          : '오늘 $used / $cap분 사용 · 자정까지 $wait\n'
              '스케줄 차단이 아니라 설정한 시청 한도예요.',
      primaryLabel: '유튜브 시청 한도 설정',
      onPrimary: () => _replaceLockedBrowserWithLimits(context),
    );
  }

  String _formatWait(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '$h시간 $m분';
    if (m > 0) return '$m분';
    return '곧';
  }

  void _replaceLockedBrowserWithLimits(BuildContext context) {
    final opened = IsleNavigation.pushReplacement(
      IsleRoutes.youtubeLimits,
      from: context,
    );
    if (opened) return;
    if (context.mounted) context.go(IsleRoutes.youtubeLimits);
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
  final String? badge;

  const _LockScaffold({
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.badge,
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
                if (badge != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(badge!,
                        style: IsleText.caption(color: Colors.white70)),
                  ),
                  const SizedBox(height: 12),
                ],
                Icon(icon, size: 56, color: Colors.white),
                const SizedBox(height: 16),
                Text(title,
                    style: IsleText.subtitle(color: Colors.white),
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(body,
                    style: IsleText.caption(color: Colors.white70),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
                if (secondaryLabel != null && onSecondary != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!,
                        style: IsleText.body(color: IsleColors.ocean100)),
                  ),
                ],
                TextButton(
                    onPressed: () => context.pop(),
                    child: Text('나가기',
                        style: IsleText.body(color: Colors.white70))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
