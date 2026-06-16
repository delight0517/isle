import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_build_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/utils/url_parser.dart';
import '../../../../core/youtube/blocked_channel_store.dart';
import '../../../../core/youtube/channel_genre_ai_service.dart';
import '../../../../core/youtube/channel_genre_block_store.dart';
import '../../../../core/youtube/content_filter_store.dart'; // blockedVideosProvider
import '../../../../core/youtube/models/youtube_page_channel.dart';
import '../../../feed/providers/feed_provider.dart';
import 'feed_boost_sheet.dart';

/// 유튜브 시청 중 👍 — 피드 부스트 + 숨기기(채널·장르·영상) 한 메뉴
Future<void> showYoutubeWatchPrefSheet(
  BuildContext context, {
  required YoutubePageChannel watch,
  required String pageUrl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) => _YoutubeWatchPrefBody(watch: watch, pageUrl: pageUrl),
  );
}

class _YoutubeWatchPrefBody extends ConsumerStatefulWidget {
  const _YoutubeWatchPrefBody({required this.watch, required this.pageUrl});

  final YoutubePageChannel watch;
  final String pageUrl;

  @override
  ConsumerState<_YoutubeWatchPrefBody> createState() => _YoutubeWatchPrefBodyState();
}

class _YoutubeWatchPrefBodyState extends ConsumerState<_YoutubeWatchPrefBody> {
  bool _busy = false;

  String get _title =>
      widget.watch.videoTitle.isNotEmpty ? widget.watch.videoTitle : '지금 보는 영상';

  String get _channelLabel => widget.watch.channelName.isNotEmpty
      ? widget.watch.channelName
      : (widget.watch.channelId.isNotEmpty ? widget.watch.channelId : '이 채널');

  String? get _videoId => UrlParser.extractYouTubeVideoId(widget.pageUrl);

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _boost() async {
    if (!mounted) return;
    Navigator.pop(context);
    final choice = await showFeedBoostSheet(
      context,
      watch: widget.watch,
      pageUrl: widget.pageUrl,
    );
    if (!mounted || choice == null) return;
    final msg = choice == FeedBoostChoice.channel
        ? '이 채널을 피드에서 더 자주 보여줄게요'
        : '비슷한 스타일을 피드에서 더 자주 보여줄게요';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _blockChannel() async {
    final id = widget.watch.channelId.trim();
    final name = widget.watch.channelName.trim();
    if (id.isEmpty && name.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 채널 추천 안 함'),
        content: Text(
          '「$_channelLabel」 채널을 피드·앱 안 유튜브에서 숨길까요?\n'
          '이 채널 영상은 더 이상 추천되지 않아요.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: IsleColors.danger),
            child: const Text('숨기기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await ref.read(blockedChannelsProvider.notifier).blockChannel(
          channelId: id.isNotEmpty ? id : name,
          channelName: name.isNotEmpty ? name : id,
        );
    ref.invalidate(feedProvider);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이 채널을 추천하지 않을게요')),
    );
  }

  Future<void> _blockGenre() async {
    if (!AppBuildConfig.enableGenreBlockAi) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장르 차단은 이 빌드에서 사용할 수 없어요')),
      );
      return;
    }

    final id = widget.watch.channelId.trim();
    final name = widget.watch.channelName.trim();
    if (id.isEmpty && name.isEmpty) return;

    await ChannelGenreBlockStore.addSample(
      channelId: id.isNotEmpty ? id : name,
      channelName: name.isNotEmpty ? name : id,
      pageUrl: widget.pageUrl,
    );

    GenreApplyResult? applied;
    if (IsleUserDefaults.genreBlockAutoAnalyze && ChannelGenreBlockStore.shouldRunAutoAnalyze) {
      final lang = ref.read(appLocaleProvider)?.languageCode ?? 'ko';
      applied = await ChannelGenreAiService.analyzeAndApply(ref, languageCode: lang);
    }
    ref.invalidate(feedProvider);
    if (!mounted) return;
    Navigator.pop(context);
    final extra = applied != null && applied.keywordsAdded > 0
        ? ' · 키워드 ${applied.keywordsAdded}개'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('비슷한 스타일·장르를 숨기기 시작했어요$extra')),
    );
  }

  Future<void> _blockVideoOnly() async {
    final vid = _videoId;
    if (vid == null || vid.length != 11) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영상 ID를 찾지 못했어요')),
      );
      return;
    }
    await ref.read(blockedVideosProvider.notifier).addVideo(vid, sourceUrl: widget.pageUrl);
    ref.invalidate(feedProvider);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이 영상만 숨겼어요')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final canGenre = AppBuildConfig.enableGenreBlockAi;
    final canVideo = _videoId != null && _videoId!.length == 11;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.thumb_up_alt_outlined, color: IsleColors.gold500, size: 26),
                const SizedBox(width: 10),
                Expanded(child: Text('콘텐츠 취향', style: IsleText.subtitle(color: IsleColors.ocean900))),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _title,
              style: IsleText.caption(color: IsleColors.muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Text('더 보고 싶어요', style: IsleText.caption(color: IsleColors.ocean700)),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.thumb_up_alt_outlined,
              iconColor: IsleColors.gold500,
              title: '피드에 더 보기',
              subtitle: '채널 또는 비슷한 스타일을 피드 순위에 올려요',
              onTap: _busy ? null : () => _run(_boost),
            ),
            const SizedBox(height: 14),
            Text('덜 보고 싶어요', style: IsleText.caption(color: IsleColors.ocean700)),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.block,
              iconColor: IsleColors.danger,
              title: '이 채널 추천 안 함',
              subtitle: '「$_channelLabel」 전체를 피드·유튜브에서 숨김',
              onTap: _busy ? null : () => _run(_blockChannel),
            ),
            if (canGenre) ...[
              const SizedBox(height: 6),
              _ActionTile(
                icon: Icons.category_outlined,
                iconColor: IsleColors.danger,
                title: '이 장르·스타일 막기',
                subtitle: '비슷한 주제·톤의 다른 채널도 함께 줄여요',
                onTap: _busy ? null : () => _run(_blockGenre),
              ),
            ],
            if (canVideo) ...[
              const SizedBox(height: 6),
              _ActionTile(
                icon: Icons.videocam_off_outlined,
                iconColor: IsleColors.danger,
                title: '이 영상만 숨기기',
                subtitle: '채널은 유지하고 지금 영상 1개만 제외',
                onTap: _busy ? null : () => _run(_blockVideoOnly),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IsleColors.sand100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: IsleText.body()),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.3),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: IsleColors.muted.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
