import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/intervention/browser_youtube_tracking_prefs.dart';
import '../../../../core/platform/platform_block_intent.dart';
import 'youtube_isle_core_guide.dart';

/// 차단·피드 상단 — 핵심 기능(브라우저 유튜브 → Isle) 미완료 시 강조
class YoutubeSetupHomeCard extends StatelessWidget {
  const YoutubeSetupHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (BrowserYoutubeTrackingPrefs.hasCompletedEncouragementFlow) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF0000).withValues(alpha: 0.12),
            IsleColors.ocean100,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF0000).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFF0000), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Isle 핵심 — ${PlatformBlockCopy.externalBrowserName} 유튜브 막고 Isle로 보기',
                  style: IsleText.subtitle(color: IsleColors.ocean900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          YoutubeIsleCoreGuide(
            compact: true,
            onPrimaryAction: () => context.push(PlatformBlockCopy.settingsRoute),
            primaryLabel: '설정 마법사 열기',
            onSecondaryAction: () => context.push('/youtube/browser'),
            secondaryLabel: '일단 Isle 유튜브 열기',
          ),
        ],
      ),
    );
  }
}
