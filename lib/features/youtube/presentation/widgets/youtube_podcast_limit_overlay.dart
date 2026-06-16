import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/youtube/youtube_podcast_listen_store.dart';

/// 음성 모드 전용 일일 한도 오버레이
class YoutubePodcastLimitOverlay extends StatelessWidget {
  const YoutubePodcastLimitOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    if (!YoutubePodcastListenStore.isLimitReached) {
      return const SizedBox.shrink();
    }
    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.headset_off, size: 56, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  '오늘 음성 한도에 도달했어요',
                  style: IsleText.subtitle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  '음성 모드 한도는 영상 시청 한도와 따로 계산돼요.\n'
                  '설정에서 분을 조절할 수 있어요.',
                  style: IsleText.caption(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('나가기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
