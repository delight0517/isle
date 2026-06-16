import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/feed/feed_boost_store.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../feed/providers/feed_provider.dart';

/// 피드에 더 보고 싶은 채널·스타일 관리
class FeedBoostSettingsScreen extends ConsumerWidget {
  const FeedBoostSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(feedBoostChannelsProvider);
    final genres = ref.watch(feedBoostGenresProvider);

    return Scaffold(
      appBar: const IsleAppBar(title: '피드 선호'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '유튜브에서 「피드에 더 보기」로 저장한 항목이에요. '
            '같은 채널·비슷한 스타일 콘텐츠가 홈 피드에서 위로 올라갑니다.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 20),
          Text('채널', style: IsleText.subtitle(color: IsleColors.ocean900)),
          const SizedBox(height: 8),
          if (channels.isEmpty)
            Text('저장된 채널 없음', style: IsleText.body(color: IsleColors.muted))
          else
            ...channels.asMap().entries.map((e) {
              final c = e.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.subscriptions, color: IsleColors.ocean500),
                  title: Text(c.channelName.isNotEmpty ? c.channelName : c.channelId),
                  subtitle: Text(
                    '가중치 ×${c.weight}'
                    '${c.sourceVideoTitle.isNotEmpty ? ' · ${c.sourceVideoTitle}' : ''}',
                    style: IsleText.caption(color: IsleColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: IsleColors.danger),
                    onPressed: () async {
                      await ref.read(feedBoostChannelsProvider.notifier).removeAt(e.key);
                      ref.invalidate(feedProvider);
                    },
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
          Text('스타일 · 장르', style: IsleText.subtitle(color: IsleColors.ocean900)),
          const SizedBox(height: 8),
          if (genres.isEmpty)
            Text('저장된 스타일 없음', style: IsleText.body(color: IsleColors.muted))
          else
            ...genres.asMap().entries.map((e) {
              final g = e.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.category, color: IsleColors.gold500),
                  title: Text(g.label),
                  subtitle: Text(
                    [
                      if (g.topics.isNotEmpty) g.topics.join(', '),
                      if (g.keywords.isNotEmpty) g.keywords.take(5).join(', '),
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: IsleText.caption(color: IsleColors.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: IsleColors.danger),
                    onPressed: () async {
                      await ref.read(feedBoostGenresProvider.notifier).removeAt(e.key);
                      ref.invalidate(feedProvider);
                    },
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
