import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/youtube/youtube_clipboard_watch.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';

/// 피드 상단 — 유튜브 허브 바로가기 (iPhone)
class YoutubeHubBanner extends StatelessWidget {
  const YoutubeHubBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Material(
          color: const Color(0xFFFF0000).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push('/youtube/browser'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.ondemand_video, color: Color(0xFFFF0000), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('유튜브 바로 보기', style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
                        Text('시청 시간 기록 · Safari 차단은 설정에서', style: IsleText.caption(color: IsleColors.muted)),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => YoutubeClipboardWatch.pasteAndPlay(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF0000),
                      side: const BorderSide(color: Color(0xFFFF0000)),
                      minimumSize: const Size(0, IsleSize.minTouchTarget),
                    ),
                    child: const Text('복사한 URL'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => context.push('/youtube/browser'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0000),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: const Size(0, IsleSize.minTouchTarget),
                    ),
                    child: const Text('열기'),
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
      ),
    );
  }
}
