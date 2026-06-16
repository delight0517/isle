import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/youtube/channel_genre_ai_service.dart';
import '../../../youtube/presentation/widgets/block_channel_sheet.dart';
import '../../data/models/feed_item.dart';
import '../../providers/feed_provider.dart';

/// 오른쪽 스와이프 — 채널 차단 + 아카이브 (설정 기본값: both)
Future<bool> handleFeedSwipeRight(BuildContext context, WidgetRef ref, FeedItem item) async {
  final action = IsleUserDefaults.swipeRightAction;

  if (action == 'archive') {
    return ref.read(feedProvider.notifier).archiveItem(item);
  }

  if (action == 'block') {
    final result = await showBlockChannelSheet(
      context,
      channelId: item.channelId,
      channelName: item.channelName,
      pageUrl: item.url,
    );
    if (result?.channelBlocked == true) {
      await ref.read(feedProvider.notifier).removeBlockedFromFeed();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_blockSnackMessage(item.channelName, result?.genreApply))),
        );
      }
      return true;
    }
    return false;
  }

  // both — 액션 시트
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.block, color: IsleColors.danger),
            title: Text('채널 차단', style: IsleText.body()),
            subtitle: Text(item.channelName, style: IsleText.caption(color: IsleColors.muted)),
            onTap: () => Navigator.pop(ctx, 'block'),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_add_outlined, color: IsleColors.ocean500),
            title: Text('아카이브에 저장', style: IsleText.body()),
            subtitle: Text(item.title, style: IsleText.caption(color: IsleColors.muted), maxLines: 1),
            onTap: () => Navigator.pop(ctx, 'archive'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (choice == 'block') {
    if (!context.mounted) return false;
    final result = await showBlockChannelSheet(
      context,
      channelId: item.channelId,
      channelName: item.channelName,
      pageUrl: item.url,
    );
    if (result?.channelBlocked == true) {
      await ref.read(feedProvider.notifier).removeBlockedFromFeed();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_blockSnackMessage(item.channelName, result?.genreApply))),
        );
      }
      return true;
    }
    return false;
  }

  if (choice == 'archive') {
    if (!context.mounted) return false;
    final ok = await ref.read(feedProvider.notifier).archiveItem(item);
    if (context.mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아카이브에 저장했습니다.')),
      );
    }
    return ok;
  }

  return false;
}

String _blockSnackMessage(String channelName, GenreApplyResult? genre) {
  var msg = '$channelName 채널을 차단했습니다.';
  if (genre != null) {
    msg += ' 유형 「${genre.genreLabel}」 키워드 ${genre.keywordsAdded} · 채널 ${genre.channelsAdded}';
  }
  return msg;
}
