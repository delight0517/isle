import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/feed/feed_ingest_service.dart';
import '../../../../core/feed/feed_ingest_store.dart';
import '../../../../core/library/personal_library_store.dart';
import 'add_feed_subscription_sheet.dart';

/// 마지막 갱신·3시간 주기 안내
class FeedRefreshStatusStrip extends ConsumerWidget {
  const FeedRefreshStatusStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(connectedSourcesProvider);
    final last = FeedIngestStore.lastRefreshAt;
    final status = FeedIngestStore.lastStatus;
    final next = FeedIngestService.nextRefreshLabel();

    if (sources.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Material(
            color: IsleColors.gold500.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showAddFeedSubscriptionSheet(context, ref),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline, color: IsleColors.ocean700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '구독할 채널·블로그를 추가하면 피드가 채워져요',
                        style: IsleText.body(color: IsleColors.ocean900),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: IsleColors.muted),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final lastLabel = last == null
        ? '아직 갱신 안 함'
        : '${last.toLocal().month}/${last.toLocal().day} '
            '${last.toLocal().hour.toString().padLeft(2, '0')}:'
            '${last.toLocal().minute.toString().padLeft(2, '0')} 갱신';

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Text(
          '${sources.length}개 구독 · $lastLabel'
          '${status != null ? ' · $status' : ''}'
          '${next != null ? ' · $next' : ''}',
          style: IsleText.caption(color: IsleColors.muted),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
