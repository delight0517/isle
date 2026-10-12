import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/tag_badge.dart';
import '../../data/models/feed_item.dart';
import '../../providers/feed_provider.dart';
import '../../../../core/library/engagement_tracker.dart';
import '../../../../core/library/interest_pipeline_store.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/utils/topic_matcher.dart';
import '../../../../core/utils/url_parser.dart';
import '../../../../core/youtube/youtube_content_open_guard.dart';
import '../../../../core/youtube/youtube_url_redirect.dart';
import '../../../../core/youtube/blocked_channel_store.dart';
import '../../../../core/youtube/channel_genre_block_store.dart';
import '../../../../core/youtube/content_filter_store.dart';
import 'feed_swipe_actions.dart';

class FeedCard extends ConsumerWidget {
  final FeedItem item;
  final bool isDemo;

  const FeedCard({super.key, required this.item, this.isDemo = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(item.id),
      background: _buildSwipeBg(
        color: IsleColors.danger,
        icon: Icons.block,
        label: '채널',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _buildSwipeBg(
        color: IsleColors.muted,
        icon: Icons.close,
        label: '무시',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          return handleFeedSwipeRight(context, ref, item);
        }
        if (dir == DismissDirection.endToStart) {
          await ref.read(feedProvider.notifier).dismissItem(item);
          return true;
        }
        return false;
      },
      child: GestureDetector(
        onTap: isDemo
            ? () => _showDemoTapHint(context)
            : () async {
                await EngagementTracker.recordContentOpen(item.url, sourceType: item.sourceType);
                if (!context.mounted) return;
                if (!YoutubeContentOpenGuard.showDenialOrAllow(
                  context,
                  url: item.url,
                  channelId: item.channelId,
                  channelName: item.channelName,
                  videoTitle: item.title,
                )) {
                  return;
                }
                final ytRoute = YoutubeUrlRedirect.inAppRoute(item.url);
                if (ytRoute != null) {
                  context.push(ytRoute);
                  return;
                }
                final q = [
                  'url=${Uri.encodeComponent(item.url)}',
                  'title=${Uri.encodeComponent(item.title)}',
                  if (item.channelId.isNotEmpty)
                    'channelId=${Uri.encodeComponent(item.channelId)}',
                  if (item.channelName.isNotEmpty)
                    'channelName=${Uri.encodeComponent(item.channelName)}',
                ].join('&');
                context.push('/viewer?$q');
              },
        child: Opacity(
          opacity: isDemo ? 0.88 : 1,
          child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: IsleSize.screenPadding,
            vertical: IsleSize.cardGap,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(IsleSize.cardRadius),
            border: Border.all(color: Colors.black.withValues(alpha: 0.07), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(IsleSize.cardRadius)),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: item.thumbnailUrl,
                      height: IsleSize.thumbnailH,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        height: IsleSize.thumbnailH,
                        color: IsleColors.ocean100,
                        child: const Icon(Icons.image_not_supported, color: IsleColors.muted),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 10,
                      child: Row(children: [
                        CircleAvatar(
                          radius: IsleSize.avatarSm / 2,
                          backgroundImage:
                              item.channelAvatar.isNotEmpty ? NetworkImage(item.channelAvatar) : null,
                          child: item.channelAvatar.isEmpty
                              ? Text(item.channelName.isNotEmpty ? item.channelName[0] : 'C')
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.channelName,
                          style: IsleText.caption(color: Colors.white),
                          maxLines: 1,
                        ),
                      ]),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.sourceType == 'youtube'
                              ? Colors.red
                              : item.sourceType == 'brunch'
                                  ? const Color(0xFF00C6B3)
                                  : IsleColors.ocean500,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _sourceLabel(item.sourceType),
                          style: IsleText.badge(color: Colors.white),
                        ),
                      ),
                    ),
                    if (isDemo)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: IsleColors.gold500,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('샘플', style: IsleText.badge(color: IsleColors.ocean900)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(IsleSize.innerPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.recommendReason != null && !isDemo) ...[
                      _RecommendChip(reason: item.recommendReason!),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      item.title,
                      style: IsleText.body(color: IsleColors.ocean900).copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.summary != null && item.summary!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.summary!,
                        style: IsleText.caption(color: IsleColors.ocean700),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final days = IsleUserDefaults.interestArticleDays;
                          await ref.read(interestPipelineProvider.notifier).markInterested(
                                url: item.url,
                                title: item.title,
                                sourceType: item.sourceType,
                                channelName: item.channelName,
                                daysUntilArticle: days,
                              );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '관심 저장됨 · $days일 후 AI가 읽기 카드로 만들어 피드에 올려요',
                              ),
                              action: SnackBarAction(
                                label: '대기열',
                                onPressed: () => context.push('/settings/interest-pipeline'),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.auto_stories_outlined, size: 18),
                        label: const Text('관심 있어요'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: IsleColors.ocean700,
                          side: BorderSide(color: IsleColors.ocean500.withValues(alpha: 0.4)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _timeAgo(item.publishedAt),
                          style: IsleText.caption(color: IsleColors.muted),
                        ),
                        if (!isDemo)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: IsleSize.minTouchTarget,
                              minHeight: IsleSize.minTouchTarget,
                            ),
                            tooltip: '이런 거 그만',
                            icon: Icon(
                              Icons.thumb_down_alt_outlined,
                              size: 18,
                              color: IsleColors.danger.withValues(alpha: 0.85),
                            ),
                            onPressed: () => _showQuickBlockSheet(context, ref, item),
                          ),
                        TextButton.icon(
                          onPressed: () => Share.share(
                            '${item.title}\n${item.url}',
                            subject: item.title,
                          ),
                          icon: const Icon(Icons.ios_share, size: 18, color: IsleColors.ocean500),
                          label: Text(
                            '공유',
                            style: IsleText.caption(color: IsleColors.ocean500)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, IsleSize.minTouchTarget),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const Spacer(),
                        ...item.detectedTopics.take(2).map((t) => Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: TagBadge(label: t, color: IsleColors.ocean500),
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildSwipeBg({
    required Color color,
    required IconData icon,
    required String label,
    required Alignment alignment,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: IsleSize.screenPadding, vertical: IsleSize.cardGap),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 26),
        Text(label, style: IsleText.caption(color: Colors.white)),
      ]),
    );
  }

  void _showDemoTapHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('샘플 카드예요. 「내 콘텐츠」에서 가져오면 진짜 피드가 채워져요.'),
        action: SnackBarAction(
          label: '가져오기',
          onPressed: () => context.push('/library/sources'),
        ),
      ),
    );
  }

  String _sourceLabel(String type) {
    switch (type) {
      case 'youtube':
        return 'YT';
      case 'brunch':
        return 'Brunch';
      default:
        return '글';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}일 전';
    if (diff.inHours > 0) return '${diff.inHours}시간 전';
    return '${diff.inMinutes}분 전';
  }

  Future<void> _showQuickBlockSheet(
    BuildContext context,
    WidgetRef ref,
    FeedItem item,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('이런 거 그만 보기', style: IsleText.subtitle(color: IsleColors.ocean900)),
              const SizedBox(height: 4),
              Text(
                item.channelName.isNotEmpty ? item.channelName : item.title,
                style: IsleText.caption(color: IsleColors.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.block, color: IsleColors.danger),
                title: Text('이 채널만 차단', style: IsleText.body()),
                subtitle: Text(
                  '${_channelLabelFn(item)} 영상만 피드에서 숨김',
                  style: IsleText.caption(color: IsleColors.muted),
                ),
                onTap: () => Navigator.pop(ctx, 'channel'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.do_not_disturb_on_outlined, color: IsleColors.danger),
                title: Text('비슷한 유형 다시 안 봄', style: IsleText.body()),
                subtitle: Text(
                  '채널 차단 + 제목·토픽 키워드 숨김',
                  style: IsleText.caption(color: IsleColors.muted),
                ),
                onTap: () => Navigator.pop(ctx, 'genre'),
              ),
              if (item.sourceType == 'youtube')
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.visibility_off_outlined, color: IsleColors.muted),
                  title: Text('이 영상만 숨기기', style: IsleText.body()),
                  onTap: () => Navigator.pop(ctx, 'video'),
                ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final feedNotifier = ref.read(feedProvider.notifier);

    var blocked = false;
    if (choice == 'channel' || choice == 'genre') {
      if (item.channelId.isNotEmpty || item.channelName.isNotEmpty) {
        await ref.read(blockedChannelsProvider.notifier).blockChannel(
              channelId: item.channelId,
              channelName: item.channelName,
            );
        blocked = true;
      }
    }

    if (choice == 'genre') {
      // 제목 + 채널명에서 토픽 추출 → 키워드로 저장
      final topics = TopicMatcher.detectTopics('${item.title} ${item.channelName}');
      final kwNotifier = ref.read(blockedKeywordsProvider.notifier);
      for (final t in topics.take(3)) {
        await kwNotifier.add(t.toLowerCase());
      }
      // 유형 분석을 위해 샘플 누적 (이후 AI 정리 시 활용)
      if (item.channelId.isNotEmpty || item.channelName.isNotEmpty) {
        await ChannelGenreBlockStore.addSample(
          channelId: item.channelId,
          channelName: item.channelName,
          pageUrl: item.url,
          reason: 'feed_card_quick_block',
        );
      }
    }

    if (choice == 'video' && item.sourceType == 'youtube') {
      final vid = UrlParser.extractYouTubeVideoId(item.url);
      if (vid != null) {
        await ref.read(blockedVideosProvider.notifier).addVideo(vid, sourceUrl: item.url);
      }
    }

    await feedNotifier.removeBlockedFromFeed();
    if (!context.mounted) return;
    final msg = switch (choice) {
      'channel' when blocked =>
        '「${item.channelName.isNotEmpty ? item.channelName : item.title}」 채널을 차단했어요',
      'channel' => '채널 정보가 없어 차단하지 못했어요',
      'genre' when blocked => '비슷한 유형도 피드에서 숨길게요',
      'genre' => '채널 정보가 없어 유형 차단을 완료하지 못했어요',
      'video' => '이 영상을 숨겼어요',
      _ => '',
    };
    if (msg.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

String _channelLabelFn(FeedItem item) =>
    item.channelName.isNotEmpty ? '「${item.channelName}」' : '이 채널의';

class _RecommendChip extends StatelessWidget {
  const _RecommendChip({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: IsleColors.gold500.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: IsleColors.gold500.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 12, color: IsleColors.gold500),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '추천 ↑ · $reason',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: IsleText.caption(color: IsleColors.ocean900)
                  .copyWith(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
