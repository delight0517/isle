import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/youtube/blocked_channel_store.dart';
import '../../../../core/youtube/content_filter_store.dart';
import '../../../feed/presentation/widgets/keyword_filter_sheet.dart';

/// 유튜브 탭 — 채널·영상·키워드 숨기기 (설정 깊숙이 숨기지 않음)
class YoutubeBlockHubSection extends ConsumerWidget {
  const YoutubeBlockHubSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(blockedChannelsProvider).length;
    final videos = ref.watch(blockedVideosProvider).length;
    final keywords = ref.watch(blockedKeywordsProvider).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('숨기기 · 차단', style: IsleText.subtitle()),
        const SizedBox(height: 6),
        Text(
          '피드·앱 안 유튜브에서 해당 콘텐츠를 숨깁니다. '
          '영상 재생 중 ⋮ 메뉴에서도 「이 채널 차단」을 쓸 수 있어요.',
          style: IsleText.caption(color: IsleColors.muted),
        ),
        const SizedBox(height: 10),
        _BlockTile(
          icon: Icons.block,
          color: IsleColors.danger,
          title: '차단한 채널',
          subtitle: channels == 0 ? '채널 전체 숨기기' : '$channels개 채널',
          onTap: () => context.push('/settings/blocked'),
        ),
        const SizedBox(height: 8),
        _BlockTile(
          icon: Icons.movie_filter_outlined,
          color: IsleColors.ocean700,
          title: '숨긴 영상',
          subtitle: videos == 0 ? '특정 영상만 숨기기' : '$videos개 영상',
          onTap: () => context.push('/settings/blocked-videos'),
        ),
        const SizedBox(height: 8),
        _BlockTile(
          icon: Icons.tag,
          color: IsleColors.ocean500,
          title: '숨길 키워드',
          subtitle: keywords == 0 ? '제목·채널명에 포함 시 숨김' : '$keywords개 키워드',
          onTap: () => showKeywordFilterSheet(context),
        ),
        const SizedBox(height: 8),
        _BlockTile(
          icon: Icons.category_outlined,
          color: IsleColors.ocean700,
          title: '분야·유형 차단 (AI)',
          subtitle: '비슷한 채널 일괄',
          onTap: () => context.push('/settings/channel-genre'),
        ),
      ],
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
                    Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: IsleColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
