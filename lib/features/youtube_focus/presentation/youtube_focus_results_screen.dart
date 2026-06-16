import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_typography.dart';
import '../../../core/youtube/models/youtube_focus_video.dart';
import '../../../core/youtube/youtube_focus_search_service.dart';
import '../../../core/youtube/youtube_limit_gate.dart';

/// Zero-algorithm — 검색 결과 리스트만
class YoutubeFocusResultsScreen extends StatefulWidget {
  const YoutubeFocusResultsScreen({super.key, required this.query});

  final String query;

  @override
  State<YoutubeFocusResultsScreen> createState() => _YoutubeFocusResultsScreenState();
}

class _YoutubeFocusResultsScreenState extends State<YoutubeFocusResultsScreen> {
  late Future<List<YoutubeFocusVideo>> _future;

  @override
  void initState() {
    super.initState();
    _future = YoutubeFocusSearchService.search(widget.query);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: fg,
        title: Text(
          '「${widget.query}」',
          style: IsleText.subtitle(color: fg),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/youtube-focus/more'),
          ),
        ],
      ),
      body: FutureBuilder<List<YoutubeFocusVideo>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snap.error.toString(), style: IsleText.body(color: fg)),
              ),
            );
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                '결과가 없어요.\n네트워크를 확인하거나 다른 검색어를 써 보세요.',
                textAlign: TextAlign.center,
                style: IsleText.body(color: fg.withValues(alpha: 0.6)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: fg.withValues(alpha: 0.08)),
            itemBuilder: (context, i) {
              final v = items[i];
              return _ResultTile(
                video: v,
                onTap: () {
                  if (!YoutubeLimitGate.guard(context)) return;
                  context.push(
                    '/youtube-focus/watch/${v.videoId}',
                    extra: v,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.video, required this.onTap});

  final YoutubeFocusVideo video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black87;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (video.thumbnailUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  video.thumbnailUrl!,
                  width: 120,
                  height: 68,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 120,
                    height: 68,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.play_circle_outline),
                  ),
                ),
              )
            else
              Container(
                width: 120,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.play_circle_outline),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: IsleText.subtitle(color: fg),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.channelName,
                    style: IsleText.caption(color: fg.withValues(alpha: 0.55)),
                  ),
                  if (video.durationLabel.isNotEmpty)
                    Text(
                      video.durationLabel,
                      style: IsleText.caption(color: fg.withValues(alpha: 0.45)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
