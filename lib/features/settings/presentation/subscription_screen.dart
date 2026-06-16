import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/env.dart';
import '../../../core/feed/feed_ingest_service.dart';
import '../../../core/library/personal_library_store.dart';
import '../../../features/feed/presentation/widgets/add_feed_subscription_sheet.dart';
import '../../../features/feed/presentation/widgets/youtube_channel_search_sheet.dart';
import '../../../features/feed/providers/feed_provider.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../providers/settings_provider.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localSources = ref.watch(connectedSourcesProvider);
    final remoteAsync = ref.watch(userSubscriptionsProvider);

    return Scaffold(
      appBar: const IsleAppBar(title: '구독 관리'),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'yt_search',
            onPressed: () => showYoutubeChannelSearchSheet(context, ref),
            backgroundColor: const Color(0xFFFF0000),
            icon: const Icon(Icons.search, color: Colors.white),
            label: const Text('유튜버 검색', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'add_sub',
            onPressed: () => showAddFeedSubscriptionSheet(context, ref),
            backgroundColor: IsleColors.ocean500,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          Text(
            'YouTube 채널·브런치·RSS를 추가하면 앱이 직접 최신 글을 가져옵니다. '
            '3시간마다 자동 갱신 · 유료 API 없음.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 16),
          Text('내 구독 (${localSources.length})', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          if (localSources.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '아직 구독이 없어요.\n+ 버튼으로 채널 URL을 붙여넣으세요.',
                textAlign: TextAlign.center,
                style: IsleText.body(color: IsleColors.muted),
              ),
            )
          else
            ...localSources.map((s) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(_typeIcon(s.type), color: IsleColors.ocean500),
                  title: Text(s.displayName, style: IsleText.body()),
                  subtitle: Text(
                    '${s.type} · ${s.profileUrl}',
                    style: IsleText.caption(color: IsleColors.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: IsleColors.danger),
                    onPressed: () async {
                      await ref.read(connectedSourcesProvider.notifier).remove(s.id);
                      ref.invalidate(feedProvider);
                    },
                  ),
                ),
              );
            }),
          if (Env.isSupabaseConfigured) ...[
            const Divider(height: 32),
            Text('클라우드 동기화', style: IsleText.subtitle()),
            const SizedBox(height: 8),
            remoteAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(e.toString()),
              data: (rows) {
                if (rows.isEmpty) {
                  return Text(
                    'Google 로그인 후 서버에도 저장할 수 있어요.',
                    style: IsleText.caption(color: IsleColors.muted),
                  );
                }
                return Column(
                  children: rows.map((r) {
                    final name = r['channel_name'] as String? ?? '';
                    final platform = r['platform'] as String? ?? '';
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.cloud_outlined, size: 20),
                      title: Text(name, style: IsleText.caption()),
                      subtitle: Text(platform, style: IsleText.caption(color: IsleColors.muted)),
                    );
                  }).toList(),
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final r = await FeedIngestService.refreshNow();
              ref.invalidate(feedProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(r.message)),
                );
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('지금 피드 새로고침'),
          ),
        ],
      ),
    );
  }

  static IconData _typeIcon(String type) {
    switch (type) {
      case 'youtube':
        return Icons.ondemand_video;
      case 'brunch':
        return Icons.article_outlined;
      default:
        return Icons.rss_feed;
    }
  }
}
