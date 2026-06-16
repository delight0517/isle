import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/youtube/blocked_channel_store.dart';
import '../../../core/youtube/content_filter_store.dart';
import '../../feed/presentation/widgets/block_from_link_sheet.dart';
import '../../feed/presentation/widgets/keyword_filter_sheet.dart';

/// Light — 차단 목록 허브 (AI 없음)
class LightBlocksHubScreen extends ConsumerWidget {
  const LightBlocksHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(blockedChannelsProvider);
    final videos = ref.watch(blockedVideosProvider);
    final keywords = ref.watch(blockedKeywordsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('차단', style: IsleText.subtitle(color: IsleColors.ocean900)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _summaryCard(
            channels.length,
            videos.length,
            keywords.length,
          ),
          const SizedBox(height: 20),
          _section('목록'),
          _tile(
            context,
            Icons.tv_off_outlined,
            '차단한 채널',
            '${channels.length}개',
            () => context.push('/light/settings/blocked'),
          ),
          _tile(
            context,
            Icons.movie_filter_outlined,
            '숨긴 영상',
            '${videos.length}개',
            () => context.push('/light/settings/blocked-videos'),
          ),
          _tile(
            context,
            Icons.tag_outlined,
            '숨길 키워드',
            '${keywords.length}개 · 추천·검색 결과 필터',
            () => showKeywordFilterSheet(context),
          ),
          const SizedBox(height: 16),
          _section('빠른 추가'),
          _tile(
            context,
            Icons.link,
            '링크로 차단',
            '채널 전체 또는 영상 하나',
            () => showBlockFromLinkSheet(context),
          ),
          const SizedBox(height: 12),
          Material(
            color: IsleColors.ocean100,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '유튜브 탭에서 시청 중 「차단」 버튼으로도 추가할 수 있어요. '
                '키워드는 제목·채널명에 포함되면 홈·추천에서 숨겨집니다.',
                style: IsleText.caption(color: IsleColors.ocean700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(int ch, int vid, int kw) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [IsleColors.ocean900, IsleColors.ocean500],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: IsleColors.gold500, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('내 차단 필터', style: IsleText.subtitle(color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  '채널 $ch · 영상 $vid · 키워드 $kw',
                  style: IsleText.caption(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          title,
          style: IsleText.caption(color: IsleColors.muted).copyWith(fontWeight: FontWeight.w600),
        ),
      );

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) =>
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: ListTile(
          leading: Icon(icon, color: IsleColors.ocean700),
          title: Text(title, style: IsleText.body()),
          subtitle: Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
          trailing: const Icon(Icons.chevron_right, color: IsleColors.muted),
          onTap: onTap,
        ),
      );
}
