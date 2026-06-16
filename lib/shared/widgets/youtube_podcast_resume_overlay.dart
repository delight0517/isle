import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_typography.dart';
import '../../core/navigation/isle_navigation.dart';
import '../../core/youtube/youtube_podcast_session.dart';

/// 피드·다른 화면 — 음성 모드 「다시 듣기」
class YoutubePodcastResumeOverlay extends StatelessWidget {
  const YoutubePodcastResumeOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: YoutubePodcastSession.instance,
      builder: (_, __) {
        final s = YoutubePodcastSession.instance;
        if (!s.hasParkedSession) return const SizedBox.shrink();

        final title = s.meta.videoTitle.isNotEmpty
            ? s.meta.videoTitle
            : (s.displayTitle.isNotEmpty ? s.displayTitle : '유튜브 음성');

        final bottom = MediaQuery.paddingOf(context).bottom;

        return Positioned(
          left: 12,
          right: 12,
          bottom: bottom + 132,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF1A1A1A),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.mediumImpact();
                IsleNavigation.push('/youtube/podcast', from: context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.headphones,
                        color: Color(0xFF1DB954),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '음성 재생 중',
                            style: IsleText.caption(color: const Color(0xFF1DB954))
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            title,
                            style: IsleText.body(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 22),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        YoutubePodcastSession.instance.quit();
                      },
                      tooltip: '음성 끄기',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
