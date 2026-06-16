import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/intervention/browser_youtube_tracking_prefs.dart';
import '../../../../core/platform/platform_block_intent.dart';

/// 피드 — Safari·Chrome 유튜브 차단 후 Isle 트래킹 유도
class BrowserYoutubeTrackingBanner extends StatefulWidget {
  const BrowserYoutubeTrackingBanner({super.key});

  @override
  State<BrowserYoutubeTrackingBanner> createState() => _BrowserYoutubeTrackingBannerState();
}

class _BrowserYoutubeTrackingBannerState extends State<BrowserYoutubeTrackingBanner> {
  @override
  Widget build(BuildContext context) {
    if (!BrowserYoutubeTrackingPrefs.shouldShowFeedBanner) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final browser = PlatformBlockCopy.externalBrowserName;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Material(
          color: IsleColors.ocean100.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 40, 12),
                child: Row(
                  children: [
                    Icon(Icons.track_changes, color: IsleColors.ocean700, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$browser 유튜브는 막고 Isle에서 보기',
                            style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '시청 시간·일일 한도가 제대로 잡혀요',
                            style: IsleText.caption(color: IsleColors.muted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/settings/browser-youtube-tracking'),
                      child: const Text('설정'),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 20, color: IsleColors.muted),
                  onPressed: () async {
                    await BrowserYoutubeTrackingPrefs.setFeedBannerDismissed(true);
                    if (mounted) setState(() {});
                  },
                  tooltip: '닫기',
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms),
      ),
    );
  }
}
