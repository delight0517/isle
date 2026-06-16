import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../insight/application/insight_crafter_provider.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/share/shared_playlist_cc_service.dart';
import '../../../../core/share/shared_playlist_store.dart';
import '../../../home/presentation/cc_article_view_screen.dart';
import '../../../insight/presentation/insight_compose_sheet.dart';
import '../../../../shared/widgets/isle_sheet.dart';

/// YouTube 미니 플레이어 · 중앙 Isle 길게 누르기 — 큐 영상 + CC 기사
Future<void> showIsleYoutubeLibrarySheet(BuildContext context) async {
  await SharedPlaylistStore.ensureOpen();
  if (!context.mounted) return;
  await showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => const _IsleYoutubeLibrarySheet(),
  );
}

class _IsleYoutubeLibrarySheet extends ConsumerStatefulWidget {
  const _IsleYoutubeLibrarySheet();

  @override
  ConsumerState<_IsleYoutubeLibrarySheet> createState() => _IsleYoutubeLibrarySheetState();
}

class _IsleYoutubeLibrarySheetState extends ConsumerState<_IsleYoutubeLibrarySheet> {
  bool _busy = false;
  List<SharedPlaylistItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _items = SharedPlaylistCcService.queueItems());
  }

  Future<void> _sync() async {
    setState(() => _busy = true);
    await SharedPlaylistCcService.syncNow();
    if (!mounted) return;
    setState(() => _busy = false);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, scroll) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Isle', style: IsleText.title()),
            const SizedBox(height: 4),
            Text(
              '공유 탭에 넣은 영상·플레이리스트 · CC로 기사화된 목록',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _sync,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync),
                    label: const Text('CC 새로고침'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '공유 탭에서 큐 관리',
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/home/share');
                  },
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Text(
                        '큐가 비어 있어요.\n공유 탭에서 플레이리스트·영상 URL을 추가하세요.',
                        textAlign: TextAlign.center,
                        style: IsleText.body(color: IsleColors.muted),
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final e = _items[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            minVerticalPadding: 10,
                            leading: e.thumbnailUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      e.thumbnailUrl,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(Icons.play_circle_outline, color: Color(0xFFFF0000)),
                            title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              [
                                if (e.channelName.isNotEmpty) e.channelName,
                                if (e.hasArticle) '기사 ✓',
                                if (e.hasTranscript) 'CC ✓',
                              ].join(' · '),
                              style: IsleText.caption(color: IsleColors.muted),
                            ),
                            isThreeLine: true,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.pop(context);
                              context.push(
                                '/viewer?url=${Uri.encodeComponent(e.url)}&title=${Uri.encodeComponent(e.title)}',
                              );
                            },
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'article' && e.hasArticle) {
                                  Navigator.pop(context);
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) => CcArticleViewScreen(item: e),
                                    ),
                                  );
                                } else if (v == 'sync') {
                                  unawaited(_sync());
                                } else if (v == 'insight') {
                                  final card = await ref
                                      .read(insightCrafterProvider.notifier)
                                      .craftInsight(e.url, '');
                                  if (!context.mounted || card == null) return;
                                  await showInsightComposeSheet(context, ref, card: card);
                                }
                              },
                              itemBuilder: (_) => [
                                if (e.hasArticle)
                                  const PopupMenuItem(value: 'article', child: Text('기사로 읽기')),
                                const PopupMenuItem(value: 'insight', child: Text('인사이트 카드')),
                                const PopupMenuItem(value: 'sync', child: Text('CC 동기화')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
