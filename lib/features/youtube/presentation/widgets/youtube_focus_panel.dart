import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/block_schedule/schedule_active_service.dart';
import '../../../../core/navigation/isle_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/youtube/youtube_schedule_lock_store.dart';
import '../../../../core/platform/platform_block_intent.dart';
import '../../../../core/youtube/youtube_watch_timer_store.dart';
import 'screen_time_guide_sheet.dart';

/// 유튜브 허브·한도 설정 — 분 한도 / 스케줄 / Screen Time 안내
class YoutubeFocusPanel extends StatelessWidget {
  const YoutubeFocusPanel({
    super.key,
    this.compact = false,
    this.onLimitsScreen = false,
  });

  final bool compact;
  /// 한도 설정 화면이면 「분 한도」칩 대신 아래 슬라이더 안내
  final bool onLimitsScreen;

  @override
  Widget build(BuildContext context) {
    final scheduleOn = IsleUserDefaults.youtubeScheduleLockEnabled;
    final scheduleLocked = YoutubeScheduleLockStore.isLockedNow();
    final limitOn = YoutubeWatchTimerStore.isEnabled;
    final limitReached = YoutubeWatchTimerStore.isLimitReached;
    final remainMin = YoutubeWatchTimerStore.secondsRemaining ~/ 60;

    return Material(
      color: scheduleLocked ? const Color(0xFFFFEBEE) : IsleColors.ocean100.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(compact ? 12 : 14),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  scheduleLocked ? Icons.lock : Icons.lock_clock,
                  color: scheduleLocked ? Colors.red.shade700 : IsleColors.ocean700,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scheduleLocked
                        ? 'Isle 앱 안 YouTube 차단 중'
                        : (limitReached ? '오늘 시청 한도 도달' : '집중 모드'),
                    style: IsleText.subtitle(color: IsleColors.ocean900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              scheduleLocked
                  ? '스케줄 편집 → 「Isle 앱 안에서 차단」을 끄면 WebView에서 다시 볼 수 있어요.'
                  : limitOn
                      ? '오늘 남음 $remainMin분 · 한도 ${IsleUserDefaults.youtubeDailyLimitMinutes}분/일'
                      : '일일 한도·요일 스케줄로 유튜브 사용을 조절할 수 있어요.',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            const SizedBox(height: 12),
            Text(
              '세 가지로 막을 수 있어요',
              style: IsleText.caption(color: IsleColors.ocean700).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (onLimitsScreen)
              _LinkTile(
                icon: Icons.lock_clock,
                title: '분 한도',
                subtitle: '↓ 아래 슬라이더에서 조절 (Isle 앱 안 시청 시간)',
                onTap: null,
                muted: true,
              )
            else
              _LinkTile(
                icon: Icons.lock_clock,
                title: '분 한도',
                subtitle: 'Isle 앱 안에서 하루/주기 시청 시간',
                onTap: () => context.push(IsleRoutes.youtubeLimits),
              ),
            const SizedBox(height: 6),
            _LinkTile(
              icon: Icons.event_repeat,
              title: '요일·시간 차단',
              subtitle: scheduleOn
                  ? (scheduleLocked ? '지금 스케줄로 막는 중' : '스케줄 켜짐 · 편집하기')
                  : '예: 밤 11시~아침 7시 자동 차단',
              highlight: scheduleLocked,
              onTap: () => context.push(IsleRoutes.blockSchedules),
            ),
            if (Platform.isIOS || Platform.isAndroid) ...[
              const SizedBox(height: 6),
              _LinkTile(
                icon: Icons.phonelink_lock,
                title: '유튜브 앱·Safari',
                subtitle: '${PlatformBlockCopy.systemSettingsName} — OS에서 앱 자체 차단',
                onTap: () => showScreenTimeGuideSheet(context),
              ),
            ],
            if (ScheduleActiveService.isYoutubeWebViewBlockedNow() && !compact) ...[
              const SizedBox(height: 8),
              Text(
                PlatformBlockCopy.focusPanelExternalHint,
                style: IsleText.caption(color: Colors.red.shade800),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
    this.muted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool highlight;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? Colors.red.shade800 : IsleColors.ocean900;
    final iconColor = muted
        ? IsleColors.muted
        : highlight
            ? Colors.red.shade700
            : IsleColors.ocean700;

    return Material(
      color: Colors.white.withValues(alpha: muted ? 0.5 : 0.92),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: IsleText.body(color: fg).copyWith(fontWeight: FontWeight.w600)),
                    Text(subtitle, style: IsleText.caption(color: IsleColors.muted), maxLines: 2),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: IsleColors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
