import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/brunch/brunch_blocked_author_store.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// 브런치·블로그 — 숨긴 작가 관리
class BrunchBlockedAuthorsScreen extends ConsumerWidget {
  const BrunchBlockedAuthorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authors = ref.watch(brunchBlockedAuthorsProvider);
    final kws = ref.watch(brunchBlockKeywordsProvider);

    return Scaffold(
      appBar: const IsleAppBar(title: '숨긴 작가 · 키워드'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '브런치 탐색기에서 「이 작가 숨기기」로 저장한 목록이에요. '
            '키워드는 제목·목록 카드에서 숨깁니다.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 16),
          Text('작가', style: IsleText.subtitle(color: IsleColors.ocean900)),
          const SizedBox(height: 8),
          if (authors.isEmpty)
            Text('숨긴 작가 없음', style: IsleText.body(color: IsleColors.muted))
          else
            ...authors.map((a) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.person_off, color: IsleColors.ocean500),
                  title: Text(a.displayName.isNotEmpty ? a.displayName : '@${a.handle}'),
                  subtitle: a.handle.isNotEmpty
                      ? Text('@${a.handle}', style: IsleText.caption(color: IsleColors.muted))
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: IsleColors.danger),
                    onPressed: () => ref.read(brunchBlockedAuthorsProvider.notifier).unblock(a.handle),
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
          Text('숨김 키워드', style: IsleText.subtitle(color: IsleColors.ocean900)),
          const SizedBox(height: 8),
          if (kws.isEmpty)
            Text('키워드 없음', style: IsleText.body(color: IsleColors.muted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kws
                  .map(
                    (k) => Chip(
                      label: Text(k),
                      onDeleted: () async {
                        final next = kws.where((x) => x != k).toList();
                        await ref.read(brunchBlockKeywordsProvider.notifier).setAll(next);
                      },
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

final brunchBlockKeywordsProvider =
    StateNotifierProvider<BrunchBlockKeywordsNotifier, List<String>>((ref) {
  return BrunchBlockKeywordsNotifier();
});

class BrunchBlockKeywordsNotifier extends StateNotifier<List<String>> {
  BrunchBlockKeywordsNotifier() : super(IsleUserDefaults.brunchBlockKeywords);

  Future<void> setAll(List<String> list) async {
    await IsleUserDefaults.setBrunchBlockKeywords(list);
    state = list;
  }
}
