import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/feed/feed_ingest_service.dart';
import '../../../../core/library/personal_library_store.dart';
import '../../../../core/library/youtube_library_service.dart';
import '../../../../core/services/setup_journey_service.dart';
import '../../providers/feed_provider.dart';
import '../../../../shared/widgets/isle_sheet.dart';

/// 유튜브 구독 추가 — 앱 안에서 유튜버 검색
Future<void> showYoutubeChannelSearchSheet(BuildContext context, WidgetRef ref) async {
  final queryCtrl = TextEditingController();
  var busy = false;
  var searching = false;
  List<({String channelId, String channelName})> results = [];

  await showIsleModalSheet<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('여러 유튜버들 검색하기!', style: IsleText.subtitle()),
                const SizedBox(height: 6),
                Text(
                  '아는 유튜버 이름·채널명을 검색해 구독에 추가하면 피드에 새 영상이 올라와요.',
                  style: IsleText.caption(color: IsleColors.muted),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final q = queryCtrl.text.trim();
                    final url = q.isEmpty
                        ? 'https://m.youtube.com/results?search_query='
                        : 'https://m.youtube.com/results?search_query=${Uri.encodeComponent(q)}';
                    ctx.push('/youtube/browser?url=${Uri.encodeComponent(url)}');
                  },
                  icon: const Icon(Icons.play_circle_outline, color: Color(0xFFFF0000)),
                  label: const Text('영상 검색 (앱 안 · 빠름)'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: queryCtrl,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '예: 침착맨, 오마이걸, 디자인 유튜버…',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: searching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      onPressed: searching || queryCtrl.text.trim().isEmpty
                          ? null
                          : () async {
                              setLocal(() => searching = true);
                              try {
                                results = await YoutubeLibraryService.searchChannels(
                                  queryCtrl.text.trim(),
                                );
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                                results = [];
                              }
                              setLocal(() => searching = false);
                            },
                    ),
                  ),
                  onSubmitted: (_) async {
                    if (queryCtrl.text.trim().isEmpty) return;
                    setLocal(() => searching = true);
                    try {
                      results = await YoutubeLibraryService.searchChannels(queryCtrl.text.trim());
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                      results = [];
                    }
                    setLocal(() => searching = false);
                  },
                ),
                if (results.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.35,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final ch = results[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          minVerticalPadding: 8,
                          leading: const Icon(Icons.ondemand_video, color: Color(0xFFFF0000)),
                          title: Text(ch.channelName, style: IsleText.body()),
                          trailing: busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : TextButton(
                                  child: const Text('추가'),
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          setLocal(() => busy = true);
                                          final url = 'https://www.youtube.com/channel/${ch.channelId}';
                                          final result = await FeedIngestService.addSubscriptionFromUrl(url);
                                          await ref.read(connectedSourcesProvider.notifier).reload();
                                          if (result.ok) {
                                            await SetupJourneyService.markStepDone('import_content');
                                          }
                                          ref.invalidate(feedProvider);
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(result.message)),
                                            );
                                          }
                                          setLocal(() => busy = false);
                                        },
                                ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(ctx),
                  child: const Text('닫기'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  queryCtrl.dispose();
}
