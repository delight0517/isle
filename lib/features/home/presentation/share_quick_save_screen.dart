import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../insight/application/insight_crafter_provider.dart';
import '../../../core/navigation/share_link_router.dart';
import '../../../core/services/isle_app_log_service.dart';
import '../../../core/share/shared_playlist_store.dart';
import '../../../core/utils/url_parser.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../../shared/widgets/link_absorb_hero.dart';
import '../../insight/presentation/insight_compose_sheet.dart';

class ShareQuickSaveScreen extends ConsumerStatefulWidget {
  const ShareQuickSaveScreen({super.key, required this.url});

  final String url;

  @override
  ConsumerState<ShareQuickSaveScreen> createState() => _ShareQuickSaveScreenState();
}

class _ShareQuickSaveScreenState extends ConsumerState<ShareQuickSaveScreen> {
  String _title = '링크';
  String _thumb = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    try {
      await SharedPlaylistStore.ensureOpen();
      final meta = await UrlParser.fetchMeta(widget.url);
      if (!mounted) return;
      setState(() {
        _title = meta.title.isEmpty ? '링크' : meta.title;
        _thumb = meta.thumbnailUrl ?? '';
        _loading = false;
      });
    } catch (e, st) {
      IsleAppLogService.log('ShareQuickSave meta failed: $e', level: IsleLogLevel.warn, stack: st);
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _saveToPlaylist() async {
    final list = SharedPlaylistStore.loadAll();
    String playlistId;
    if (list.isEmpty) {
      final p = await SharedPlaylistStore.create('공유받은 링크');
      playlistId = p.id;
    } else {
      playlistId = list.first.id;
    }

    final added = await SharedPlaylistStore.addItem(
      playlistId: playlistId,
      item: SharedPlaylistItem(
        id: 'pli_${DateTime.now().millisecondsSinceEpoch}',
        url: widget.url,
        title: _title,
        thumbnailUrl: _thumb,
        sourceType: UrlParser.detectSourceType(widget.url),
        addedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(added ? '플레이리스트에 저장했어요' : '이미 플레이리스트에 있어요')),
    );
    context.push('/home/share/playlists');
  }

  @override
  Widget build(BuildContext context) {
    final openRoute = ShareLinkRouter.inAppRouteForUrl(widget.url);
    return Scaffold(
      appBar: const IsleAppBar(title: '공유 링크 저장'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'KakaoTalk·YouTube에서 공유한 링크를 Isle에서 바로 열거나 저장하세요.',
            style: IsleText.body(color: IsleColors.muted),
          ),
          const SizedBox(height: 14),
          LinkAbsorbHero(
            url: widget.url,
            thumbnailUrl: _thumb.isEmpty ? null : _thumb,
            title: _title,
            loading: _loading,
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: openRoute == null ? null : () => context.push(openRoute),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Isle에서 지금 열기'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saveToPlaylist,
            icon: const Icon(Icons.playlist_add),
            label: const Text('플레이리스트에 저장'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () =>
                context.push('/settings/archive?url=${Uri.encodeComponent(widget.url)}'),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('아카이브에 저장'),
          ),
          if (UrlParser.extractYouTubeVideoId(widget.url) != null) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _loading
                  ? null
                  : () async {
                      final card = await ref.read(insightCrafterProvider.notifier).craftInsight(
                            widget.url,
                            '',
                          );
                      if (!context.mounted || card == null) return;
                      await showInsightComposeSheet(context, ref, card: card);
                    },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('인사이트 카드 만들기 (클라우드·CC)'),
            ),
          ],
        ],
      ),
    );
  }
}
