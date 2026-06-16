import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/library/personal_library_store.dart';
import '../../../core/share/shared_playlist_store.dart';
import '../../../core/utils/url_parser.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import 'cc_article_view_screen.dart';

class SharePlaylistScreen extends StatefulWidget {
  const SharePlaylistScreen({super.key});

  @override
  State<SharePlaylistScreen> createState() => _SharePlaylistScreenState();
}

class _SharePlaylistScreenState extends State<SharePlaylistScreen> {
  List<SharedPlaylist> _playlists = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await SharedPlaylistStore.ensureOpen();
    if (!mounted) return;
    setState(() => _playlists = SharedPlaylistStore.loadAll());
  }

  Future<void> _create() async {
    await SharedPlaylistStore.create('새 플레이리스트');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IsleAppBar(title: '공유 플레이리스트'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '여러 유튜브·기사 링크를 묶어 공유하고, Isle에서 얼마나 봤는지 비율을 확인하세요.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('플레이리스트 만들기'),
          ),
          const SizedBox(height: 12),
          if (_playlists.isEmpty)
            Text('아직 플레이리스트가 없어요.', style: IsleText.body(color: IsleColors.muted)),
          ..._playlists.map((p) {
            final ratio = _watchedRatio(p);
            return Card(
              child: ListTile(
                title: Text(p.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p.items.length}개 · 시청 ${(ratio * 100).round()}%'),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: ratio.clamp(0, 1),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: IsleColors.ocean100,
                      color: IsleColors.grassDeep,
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/home/share/playlists/${p.id}'),
              ),
            );
          }),
        ],
      ),
    );
  }

  double _watchedRatio(SharedPlaylist p) {
    if (p.items.isEmpty) return 0;
    final entries = PersonalLibraryStore.loadEntries();
    var watched = 0;
    for (final item in p.items) {
      final vid = UrlParser.extractYouTubeVideoId(item.url);
      if (vid != null && entries.any((e) => e.id == 'yt_hist_$vid')) watched++;
    }
    return watched / p.items.length;
  }
}

class SharePlaylistDetailScreen extends StatefulWidget {
  const SharePlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  State<SharePlaylistDetailScreen> createState() => _SharePlaylistDetailScreenState();
}

class _SharePlaylistDetailScreenState extends State<SharePlaylistDetailScreen> {
  SharedPlaylist? _playlist;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await SharedPlaylistStore.ensureOpen();
    final p = SharedPlaylistStore.loadAll().where((e) => e.id == widget.playlistId).firstOrNull;
    if (!mounted) return;
    setState(() => _playlist = p);
  }

  Future<void> _sharePlaylist(SharedPlaylist p) async {
    final payload = jsonEncode({
      'name': p.name,
      'items': p.items.map((e) => e.toJson()).toList(),
    });
    final encoded = base64UrlEncode(utf8.encode(payload));
    final link = 'isle://playlist?data=$encoded';
    await Share.share(link, subject: 'Isle 플레이리스트');
  }

  @override
  Widget build(BuildContext context) {
    final p = _playlist;
    if (p == null) {
      return const Scaffold(body: Center(child: Text('플레이리스트를 찾을 수 없습니다')));
    }
    final history = PersonalLibraryStore.loadEntries();
    return Scaffold(
      appBar: IsleAppBar(
        title: p.name,
        actions: [
          IconButton(
            onPressed: () => _sharePlaylist(p),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('공유 링크로 같은 Isle 사용자에게 보낼 수 있어요.', style: IsleText.caption(color: IsleColors.muted)),
          const SizedBox(height: 10),
          ...p.items.map((e) {
            final vid = UrlParser.extractYouTubeVideoId(e.url);
            final watched = vid != null && history.any((x) => x.id == 'yt_hist_$vid');
            return Card(
              child: ListTile(
                leading: e.thumbnailUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(e.thumbnailUrl, width: 56, height: 56, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.link),
                title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    watched ? '시청 완료' : '미시청',
                    if (e.hasArticle) '기사 ✓',
                    if (e.hasTranscript) 'CC ✓',
                  ].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (e.hasArticle)
                      IconButton(
                        icon: const Icon(Icons.article_outlined, size: 22),
                        tooltip: '기사로 읽기',
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(builder: (_) => CcArticleViewScreen(item: e)),
                        ),
                      ),
                    Icon(
                      watched ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: watched ? IsleColors.grassDeep : IsleColors.muted,
                    ),
                  ],
                ),
                onTap: () {
                  if (e.hasArticle) {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(builder: (_) => CcArticleViewScreen(item: e)),
                    );
                    return;
                  }
                  final route = '/viewer?url=${Uri.encodeComponent(e.url)}&title=${Uri.encodeComponent(e.title)}';
                  context.push(route);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class SharePlaylistImportScreen extends StatefulWidget {
  const SharePlaylistImportScreen({super.key, required this.payload});
  final String payload;

  @override
  State<SharePlaylistImportScreen> createState() => _SharePlaylistImportScreenState();
}

class _SharePlaylistImportScreenState extends State<SharePlaylistImportScreen> {
  String _name = '공유 플레이리스트';
  List<SharedPlaylistItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _parse();
  }

  void _parse() {
    try {
      final raw = utf8.decode(base64Url.decode(widget.payload));
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _name = map['name'] as String? ?? _name;
      _items = (map['items'] as List? ?? [])
          .map((e) => SharedPlaylistItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      _items = const [];
    }
  }

  Future<void> _import() async {
    await SharedPlaylistStore.ensureOpen();
    final created = await SharedPlaylistStore.create('받은: $_name');
    for (final item in _items) {
      await SharedPlaylistStore.addItem(
        playlistId: created.id,
        item: SharedPlaylistItem(
          id: 'imp_${DateTime.now().microsecondsSinceEpoch}',
          url: item.url,
          title: item.title,
          thumbnailUrl: item.thumbnailUrl,
          sourceType: item.sourceType,
          addedAt: DateTime.now(),
        ),
      );
    }
    if (!mounted) return;
    context.go('/home/share/playlists/${created.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IsleAppBar(title: '플레이리스트 가져오기'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('$_name · ${_items.length}개', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          Text('가져오면 내 Isle에서 시청 여부를 추적할 수 있어요.', style: IsleText.caption(color: IsleColors.muted)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _items.isEmpty ? null : _import,
            child: const Text('내 플레이리스트로 가져오기'),
          ),
        ],
      ),
    );
  }
}
