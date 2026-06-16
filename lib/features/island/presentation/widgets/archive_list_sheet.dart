import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../data/island_repository.dart';
import '../../data/models/archive.dart';
import '../../data/models/shelf.dart';
import '../../providers/island_provider.dart';

class ArchiveListSheet extends ConsumerStatefulWidget {
  final Shelf shelf;
  final List<Archive>? localArchives;

  const ArchiveListSheet({super.key, required this.shelf, this.localArchives});

  @override
  ConsumerState<ArchiveListSheet> createState() => _ArchiveListSheetState();
}

class _ArchiveListSheetState extends ConsumerState<ArchiveListSheet> {
  List<Archive> _archives = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final local = widget.localArchives;
    if (local != null) {
      if (mounted) {
        setState(() {
          _archives = local;
          _loading = false;
        });
      }
      return;
    }
    try {
      final list = await ref.read(islandRepoProvider).getArchives(widget.shelf.id);
      if (mounted) {
        setState(() {
          _archives = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _archives = IslandRepository.dummyArchives(widget.shelf.id);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.52,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(IsleSize.sheetRadius)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: IsleColors.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                Text(widget.shelf.iconEmoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.shelf.title, style: IsleText.subtitle()),
                  Text('${_archives.length}개의 아카이브', style: IsleText.caption(color: IsleColors.muted)),
                ]),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _archives.isEmpty
                      ? Center(child: Text('아직 저장된 콘텐츠가 없어요', style: IsleText.body(color: IsleColors.muted)))
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _archives.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                          itemBuilder: (_, i) => _ArchiveTile(archive: _archives[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  final Archive archive;
  const _ArchiveTile({required this.archive});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          archive.thumbnailUrl ?? '',
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 60,
            height: 60,
            color: IsleColors.ocean100,
            child: const Icon(Icons.image, color: IsleColors.muted),
          ),
        ),
      ),
      title: Text(archive.title, style: IsleText.caption(), maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Row(children: [
        Icon(
          archive.sourceType == 'youtube' ? Icons.play_circle_outline : Icons.article_outlined,
          size: 13,
          color: IsleColors.muted,
        ),
        const SizedBox(width: 3),
        Text(_timeAgo(archive.archivedAt), style: IsleText.caption(color: IsleColors.muted)),
        if (archive.isRead) ...[
          const SizedBox(width: 8),
          const Icon(Icons.check_circle, size: 13, color: IsleColors.success),
        ],
      ]),
      onTap: () {
        Navigator.pop(context);
        context.push(
          '/viewer?url=${Uri.encodeComponent(archive.url)}&title=${Uri.encodeComponent(archive.title)}',
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 0) return '${d.inDays}일 전';
    if (d.inHours > 0) return '${d.inHours}시간 전';
    return '방금';
  }
}
