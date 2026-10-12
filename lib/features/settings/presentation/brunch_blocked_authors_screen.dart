import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/brunch/brunch_blocked_author_store.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/library/platform_watch_limit_store.dart';
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
          Text('하루 이용 한도', style: IsleText.subtitle(color: IsleColors.ocean900)),
          const SizedBox(height: 8),
          const _BrunchDailyLimitCard(),
          const SizedBox(height: 20),
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

/// 브런치 하루 시간 한도 — 예전엔 챗 명령(`platform_limit`)으로만 켜고 바꿀 수
/// 있었고 설정 화면엔 편집 UI가 없었음(cage에서 07-11 발견·이식 — Instagram은
/// 이미 [InstagramLimitControls]로 커버돼 있었지만 브런치만 빠져 있었음).
class _BrunchDailyLimitCard extends StatefulWidget {
  const _BrunchDailyLimitCard();

  @override
  State<_BrunchDailyLimitCard> createState() => _BrunchDailyLimitCardState();
}

class _BrunchDailyLimitCardState extends State<_BrunchDailyLimitCard> {
  late bool _enabled;
  late double _minutes;

  @override
  void initState() {
    super.initState();
    _enabled = PlatformWatchLimitStore.isEnabled(PlatformWatchId.brunch);
    _minutes =
        PlatformWatchLimitStore.limitMinutes(PlatformWatchId.brunch).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final used = PlatformWatchLimitStore.secondsUsedToday(PlatformWatchId.brunch);
    final limit = PlatformWatchLimitStore.limitSeconds(PlatformWatchId.brunch);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _enabled
                  ? '오늘 ${used ~/ 60}분 / ${limit ~/ 60}분'
                  : '한도 꺼짐 — 무제한',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('일일 한도'),
              value: _enabled,
              onChanged: (v) async {
                await PlatformWatchLimitStore.setEnabled(
                    PlatformWatchId.brunch, v);
                if (!mounted) return;
                setState(() => _enabled = v);
              },
            ),
            Slider(
              min: 5,
              max: 180,
              divisions: 35,
              label: '${_minutes.round()}분',
              value: _minutes,
              onChanged: _enabled
                  ? (v) async {
                      setState(() => _minutes = v);
                      await PlatformWatchLimitStore.setLimitMinutes(
                          PlatformWatchId.brunch, v.round());
                    }
                  : null,
            ),
          ],
        ),
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
