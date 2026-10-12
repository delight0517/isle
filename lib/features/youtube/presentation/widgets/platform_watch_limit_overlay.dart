import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/library/platform_watch_limit_store.dart';
import '../../../../core/services/isle_app_log_service.dart';
import '../../../../core/navigation/isle_navigation.dart';
import '../../../../core/social/instagram_web_config.dart';
import 'youtube_watch_limit_overlay.dart';

/// instagram · brunch 일일 한도 (youtube는 [YoutubeWatchLimitOverlay])
class PlatformWatchLimitOverlay extends StatefulWidget {
  const PlatformWatchLimitOverlay({required this.platform, super.key});

  final PlatformWatchId platform;

  @override
  State<PlatformWatchLimitOverlay> createState() =>
      _PlatformWatchLimitOverlayState();
}

class _PlatformWatchLimitOverlayState extends State<PlatformWatchLimitOverlay> {
  bool _loggedDenial = false;

  @override
  Widget build(BuildContext context) {
    if (widget.platform == PlatformWatchId.youtube) {
      return const YoutubeWatchLimitOverlay();
    }
    if (!PlatformWatchLimitStore.isLimitReached(widget.platform)) {
      _loggedDenial = false;
      return const SizedBox.shrink();
    }

    if (!_loggedDenial) {
      _loggedDenial = true;
      final name = PlatformWatchLimitStore.label(widget.platform);
      IsleAppLogService.log(
        'Platform limit denial overlay: $name (${widget.platform.name})',
        level: IsleLogLevel.warn,
      );
    }

    final name = PlatformWatchLimitStore.label(widget.platform);
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_clock, size: 56, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  '오늘 $name 한도에 도달했어요',
                  style: IsleText.subtitle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  '한도 변경은 설정 화면에서만 가능해요',
                  style: IsleText.caption(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => IsleNavigation.pop(from: context),
                  child: const Text('나가기'),
                ),
                if (widget.platform == PlatformWatchId.instagram) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                      InstagramWebConfig.dmBrowserRoute(dmOnly: true),
                    ),
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text('DM은 한도 없음 — 열기'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
