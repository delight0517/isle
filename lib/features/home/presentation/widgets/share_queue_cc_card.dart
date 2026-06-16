import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/share/shared_playlist_cc_service.dart';
import '../../../../core/share/shared_playlist_store.dart';
import '../../../../core/utils/url_parser.dart';
/// 받기 ② — URL 직접 붙여넣기 → CC·기사 (내부 큐, 「Isle 플랫폼」 아님)
class ShareQueueCcCard extends StatefulWidget {
  const ShareQueueCcCard({super.key});

  @override
  State<ShareQueueCcCard> createState() => _ShareQueueCcCardState();
}

class _ShareQueueCcCardState extends State<ShareQueueCcCard> {
  final _urlCtrl = TextEditingController();
  bool _busy = false;
  bool _auto = IsleUserDefaults.shareQueueAutoSync;
  bool _wl = IsleUserDefaults.shareQueueSyncWatchLater;
  String? _status;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _addUrl() async {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) return;
    setState(() => _busy = true);
    await SharedPlaylistStore.ensureOpen();
    await SharedPlaylistStore.ensureIsleQueue();
    await IsleUserDefaults.addShareQueueSourceUrl(raw);
    final vid = UrlParser.extractYouTubeVideoId(raw);
    if (vid != null) {
      await SharedPlaylistStore.addItem(
        playlistId: SharedPlaylistStore.isleQueuePlaylistId,
        item: SharedPlaylistItem(
          id: 'q_$vid',
          url: raw.contains('http') ? raw : 'https://www.youtube.com/watch?v=$vid',
          title: 'YouTube',
          thumbnailUrl: UrlParser.youTubeThumbnail(vid),
          sourceType: 'youtube',
          addedAt: DateTime.now(),
        ),
      );
    }
    _urlCtrl.clear();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = vid != null ? '영상 1개 큐에 추가 · 동기화를 눌러 CC를 받아오세요' : '플레이리스트 URL 저장 · 동기화 시 목록을 펼칩니다';
    });
  }

  Future<void> _sync() async {
    setState(() => _busy = true);
    final r = await SharedPlaylistCcService.syncNow();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = '가져옴 ${r.ingested} · CC ${r.ccFetched} · 기사 ${r.articlesBuilt}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = SharedPlaylistCcService.queueItems().length;
    return Card(
      color: IsleColors.ocean100.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.subtitles_outlined, color: IsleColors.ocean700),
                const SizedBox(width: 10),
                Expanded(child: Text('URL 붙여넣기 · 자막', style: IsleText.subtitle())),
                Text('$count개', style: IsleText.caption(color: IsleColors.muted)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '친구가 보낸 유튜브·나중에 볼 링크를 여기에 넣으면 자막·요약으로 '
              '지식 명함에 쌓을 수 있어요.',
              style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'YouTube 영상·플레이리스트 URL',
                hintText: 'playlist?list=… 또는 watch?v=…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _busy ? null : _addUrl(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _addUrl,
                    child: const Text('큐에 추가'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _sync,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('CC 동기화'),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('앱 열 때 자동 동기화 (6시간)', style: IsleText.body()),
              value: _auto,
              onChanged: _busy
                  ? null
                  : (v) async {
                      await IsleUserDefaults.setShareQueueAutoSync(v);
                      setState(() => _auto = v);
                    },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Google 로그인 시 나중에 볼도 가져오기', style: IsleText.body()),
              subtitle: Text(
                'Watch Later(WL)는 로그인·API 옵트인 필요',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              value: _wl,
              onChanged: _busy
                  ? null
                  : (v) async {
                      await IsleUserDefaults.setShareQueueSyncWatchLater(v);
                      setState(() => _wl = v);
                    },
            ),
            if (_status != null) ...[
              const SizedBox(height: 6),
              Text(_status!, style: IsleText.caption(color: IsleColors.ocean700)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/home/share/playlists/${SharedPlaylistStore.isleQueuePlaylistId}',
                    ),
                    icon: const Icon(Icons.list),
                    label: const Text('큐 목록'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/knowledge/profile'),
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('지식 명함'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
