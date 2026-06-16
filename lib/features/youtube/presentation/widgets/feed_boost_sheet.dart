import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/feed/feed_boost_store.dart';
import '../../../../core/feed/models/feed_boost_preference.dart';
import '../../../../core/youtube/models/youtube_page_channel.dart';
import '../../../feed/providers/feed_provider.dart';

enum FeedBoostChoice { channel, genre }

/// 유튜브 시청 중 — 채널 vs 장르(스타일) 중 무엇을 피드에 반영할지 선택
Future<FeedBoostChoice?> showFeedBoostSheet(
  BuildContext context, {
  required YoutubePageChannel watch,
  required String pageUrl,
}) {
  final genrePreview = FeedBoostStore.inferGenre(
    videoTitle: watch.videoTitle,
    channelName: watch.channelName,
    videoUrl: pageUrl,
  );

  return showModalBottomSheet<FeedBoostChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) => _FeedBoostSheetBody(
      watch: watch,
      pageUrl: pageUrl,
      genrePreview: genrePreview,
    ),
  );
}

class _FeedBoostSheetBody extends ConsumerStatefulWidget {
  const _FeedBoostSheetBody({
    required this.watch,
    required this.pageUrl,
    required this.genrePreview,
  });

  final YoutubePageChannel watch;
  final String pageUrl;
  final FeedBoostGenre genrePreview;

  @override
  ConsumerState<_FeedBoostSheetBody> createState() => _FeedBoostSheetBodyState();
}

class _FeedBoostSheetBodyState extends ConsumerState<_FeedBoostSheetBody> {
  FeedBoostChoice? _selected = FeedBoostChoice.channel;
  bool _saving = false;

  String get _channelLabel =>
      widget.watch.channelName.isNotEmpty ? widget.watch.channelName : '이 채널';

  @override
  Widget build(BuildContext context) {
    final title = widget.watch.videoTitle.isNotEmpty
        ? widget.watch.videoTitle
        : '지금 보는 영상';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('피드에 더 보기', style: IsleText.subtitle(color: IsleColors.ocean900)),
            const SizedBox(height: 6),
            Text(
              title,
              style: IsleText.caption(color: IsleColors.muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Text(
              '무엇을 기억할까요? (이 기기에 저장 · 피드 순위에 반영)',
              style: IsleText.caption(color: IsleColors.ocean700),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              selected: _selected == FeedBoostChoice.channel,
              icon: Icons.subscriptions_outlined,
              color: IsleColors.ocean500,
              title: '이 채널',
              subtitle: '「$_channelLabel」의 새 영상·글을 피드에서 위로 올립니다.\n'
                  '지금 영상 1개만이 아니라 채널 전체예요.',
              onTap: () => setState(() => _selected = FeedBoostChoice.channel),
            ),
            const SizedBox(height: 10),
            _ChoiceCard(
              selected: _selected == FeedBoostChoice.genre,
              icon: Icons.category_outlined,
              color: IsleColors.gold500,
              title: '이 스타일 · 장르',
              subtitle: _genreSubtitle(),
              onTap: () => setState(() => _selected = FeedBoostChoice.genre),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving || _selected == null ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: IsleColors.ocean500,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.thumb_up_alt_outlined),
              label: Text(_selected == FeedBoostChoice.channel ? '채널로 저장' : '스타일로 저장'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          ],
        ),
      ),
    );
  }

  String _genreSubtitle() {
    final g = widget.genrePreview;
    final parts = <String>[];
    if (g.topics.isNotEmpty) parts.add('주제: ${g.topics.join(', ')}');
    if (g.keywords.isNotEmpty) parts.add('키워드: ${g.keywords.take(4).join(', ')}');
    if (parts.isEmpty) return '제목·채널에서 비슷한 톤의 콘텐츠를 피드에서 찾아 올립니다.';
    return '${parts.join('\n')}\n비슷한 제목·주제의 다른 채널도 포함될 수 있어요.';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final choice = _selected!;
    if (choice == FeedBoostChoice.channel) {
      await ref.read(feedBoostChannelsProvider.notifier).addFromWatch(
            channelId: widget.watch.channelId,
            channelName: widget.watch.channelName,
            videoUrl: widget.pageUrl,
            videoTitle: widget.watch.videoTitle,
          );
    } else {
      await ref.read(feedBoostGenresProvider.notifier).addGenre(widget.genrePreview);
    }
    ref.invalidate(feedProvider);
    if (!mounted) return;
    Navigator.pop(context, choice);
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : IsleColors.ocean100.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: IsleText.body(color: IsleColors.ocean900).copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 4),
                    Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? color : IsleColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
