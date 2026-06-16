import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_build_config.dart';
import '../../core/navigation/isle_navigation.dart';
import '../../core/constants/app_release_info.dart';
import '../../core/constants/app_typography.dart';
import '../../core/services/isle_app_log_service.dart';
import 'isle_crash_alert_banner.dart';
import 'youtube_resume_overlay.dart';
import 'youtube_podcast_resume_overlay.dart';
import 'youtube_podcast_session_host.dart';
import 'youtube_session_host.dart';

/// 화면 모서리 항상 표시 — 탭: 버전 복사 / 길게: 로그
class AppVersionBadge extends StatelessWidget {
  const AppVersionBadge({super.key});

  String get _label =>
      AppBuildConfig.isLightBuild ? AppReleaseInfo.lightLabel : AppReleaseInfo.label;

  Future<void> _copy(BuildContext context) async {
    final text = _label;
    await Clipboard.setData(ClipboardData(text: text));
    IsleAppLogService.log('Version copied: $text');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('복사됨: $text'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
  // 하단 탭(56) + FAB(56) + 여유 — SnackBar·FAB과 겹치지 않게 왼쪽 하단
    final badgeBottom = bottomInset + 128;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 8,
          bottom: badgeBottom,
          child: _BadgeChip(
            label: _label,
            onTap: () => _copy(context),
            onLongPress: () => _openLogOrBackup(context),
          ),
        ),
      ],
    );
  }

  void _openLogOrBackup(BuildContext context) {
    if (AppBuildConfig.isLightBuild) {
      IsleNavigation.push('/light/settings/backup', from: context);
    } else if (AppBuildConfig.isYoutubeFocusBuild) {
      IsleNavigation.push('/youtube-focus/more/debugger', from: context);
    } else {
      IsleNavigation.push('/settings/debugger', from: context);
    }
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.label,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cabin, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                label,
                style: IsleText.badge(color: Colors.white).copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// MaterialApp.builder — 버전 배지 + 유튜브 백그라운드 세션
class AppVersionOverlay extends StatelessWidget {
  const AppVersionOverlay({super.key, required this.child, this.lightMode = false});

  final Widget? child;
  final bool lightMode;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (child != null) child!,
        const YoutubeSessionHost(),
        const YoutubePodcastSessionHost(),
        const YoutubeResumeOverlay(),
        const YoutubePodcastResumeOverlay(),
        const IsleCrashAlertBanner(),
        const AppVersionBadge(),
      ],
    );
  }
}
