import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/feed/feed_ingest_service.dart';
import '../../../../core/library/personal_library_store.dart';
import '../../../../core/services/setup_journey_service.dart';
import '../../providers/feed_provider.dart';
import '../../../../shared/widgets/isle_sheet.dart';

/// 피드 — YouTube·브런치·RSS 빠른 구독
Future<void> showAddFeedSubscriptionSheet(BuildContext context, WidgetRef ref) async {
  final urlCtrl = TextEditingController();
  var busy = false;

  await showIsleModalSheet<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('구독 추가', style: IsleText.subtitle()),
                const SizedBox(height: 8),
                Text(
                  'YouTube 채널·브런치 프로필·RSS 주소를 붙여넣으면 '
                  '앱이 직접 최신 글을 가져옵니다 (API 키 없음).',
                  style: IsleText.caption(color: IsleColors.muted),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: urlCtrl,
                  autofocus: true,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'youtube.com/@채널 · brunch.co.kr/@… · https://…/feed',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          setLocal(() => busy = true);
                          final result = await FeedIngestService.addSubscriptionFromUrl(urlCtrl.text);
                          await ref.read(connectedSourcesProvider.notifier).reload();
                          if (result.ok && result.itemCount > 0) {
                            await SetupJourneyService.markStepDone('import_content');
                            await SetupJourneyService.markStepDone('pick_interests');
                          }
                          ref.invalidate(feedProvider);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message)),
                            );
                          }
                        },
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.rss_feed),
                  label: Text(busy ? '가져오는 중…' : '추가하고 피드 갱신'),
                ),
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  urlCtrl.dispose();
}
