import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../explore/data/models/explore_user_preview.dart';
import '../../explore/presentation/widgets/friend_island_card.dart';
import '../../explore/providers/explore_provider.dart';
import '../../island/data/island_repository.dart';
import '../data/models/shelf.dart';
import 'widgets/isometric_island_painter.dart';

/// 설정·나의 섬 — 숫자·스와이프로 다른 사람 섬 둘러보기
class OtherIslandsBrowserScreen extends ConsumerStatefulWidget {
  const OtherIslandsBrowserScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<OtherIslandsBrowserScreen> createState() => _OtherIslandsBrowserScreenState();
}

class _OtherIslandsBrowserScreenState extends ConsumerState<OtherIslandsBrowserScreen> {
  late final PageController _pageCtrl;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  static List<ExploreUserPreview> _demoPreviews() => List.generate(
        6,
        (i) => ExploreUserPreview(
          id: 'demo_$i',
          displayName: ['지은', '민수', '준서', '아라', '현우', '소연'][i],
          username: 'isle_${['jieun', 'minsu', 'junseo', 'ara', 'hyunwoo', 'soyeon'][i]}',
          interests: [
            ['디자인', 'UX'],
            ['기술/IT'],
            ['재무'],
            ['음악', '영화'],
            ['과학'],
            ['자기계발'],
          ][i],
          shelves: IslandRepository.dummyShelves(),
        ),
      );

  void _openDetail(ExploreUserPreview preview) {
    if (preview.id.startsWith('demo_')) {
      _showDemoDetailSheet(preview);
      return;
    }
    context.push('/island/${preview.id}');
  }

  void _showDemoDetailSheet(ExploreUserPreview preview) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _IslandDetailSheet(preview: preview, onEnter: () {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('데모 섬입니다. 로그인·공개 프로필 연동 후 실제 섬을 볼 수 있어요.')),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewsAsync = ref.watch(exploreIslandPreviewsProvider);

    return Scaffold(
      backgroundColor: IsleColors.ocean900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('다른 사람 섬', style: IsleText.subtitle(color: Colors.white)),
        centerTitle: true,
      ),
      body: previewsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: IsleColors.gold500)),
        error: (_, __) => _buildBody(_demoPreviews()),
        data: (list) => _buildBody(list.isEmpty ? _demoPreviews() : list),
      ),
    );
  }

  Widget _buildBody(List<ExploreUserPreview> previews) {
    final total = previews.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${_index + 1} / $total',
            style: IsleText.subtitle(color: IsleColors.gold500),
          ),
        ),
        Text(
          '좌우로 스와이프 · 섬을 탭하면 상세',
          style: IsleText.caption(color: IsleColors.sand500),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: total,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final p = previews[i];
              final label = p.displayName.isNotEmpty ? p.displayName : p.username;
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  children: [
                    _ProfileStrip(preview: p),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Material(
                        color: IsleColors.ocean700.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(IsleSize.cardRadius),
                          onTap: () => _openIslandDetail(p),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(IsleSize.cardRadius),
                            child: CustomPaint(
                              painter: IsometricIslandPainter(shelves: p.shelves),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      children: p.interests.take(4).map((t) => TagChip(label: t)).toList(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: IsleSize.minTouchTarget,
                      child: FilledButton(
                        onPressed: () => _openIslandDetail(p),
                        style: FilledButton.styleFrom(backgroundColor: IsleColors.gold500),
                        child: Text(
                          '$label님 섬 들어가기',
                          style: IsleText.body(color: IsleColors.ocean900),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openIslandDetail(ExploreUserPreview preview) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _IslandDetailSheet(
        preview: preview,
        onEnter: () {
          Navigator.pop(ctx);
          _openDetail(preview);
        },
      ),
    );
  }
}

class _ProfileStrip extends StatelessWidget {
  const _ProfileStrip({required this.preview});

  final ExploreUserPreview preview;

  @override
  Widget build(BuildContext context) {
    final label = preview.displayName.isNotEmpty ? preview.displayName : preview.username;
    return Row(
      children: [
        CircleAvatar(
          radius: IsleSize.avatarSm / 2,
          backgroundColor: IsleColors.ocean500,
          child: Text(
            label.isNotEmpty ? label[0] : '?',
            style: IsleText.subtitle(color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: IsleText.subtitle(color: Colors.white)),
              Text(
                '@${preview.username}',
                style: IsleText.caption(color: IsleColors.sand500),
              ),
            ],
          ),
        ),
        Text(
          '책장 ${preview.shelves.length}',
          style: IsleText.caption(color: IsleColors.sand500),
        ),
      ],
    );
  }
}

class _IslandDetailSheet extends StatelessWidget {
  const _IslandDetailSheet({required this.preview, required this.onEnter});

  final ExploreUserPreview preview;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final label = preview.displayName.isNotEmpty ? preview.displayName : preview.username;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(IsleSize.sheetRadius)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: IsleColors.ocean100,
                  child: Text(label.isNotEmpty ? label[0] : '?', style: IsleText.title()),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: IsleText.subtitle()),
                      Text('@${preview.username}', style: IsleText.caption(color: IsleColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: IsometricIslandPainter(shelves: preview.shelves),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('관심사', style: IsleText.subtitle()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: preview.interests.map((t) => TagChip(label: t)).toList(),
            ),
            const SizedBox(height: 16),
            Text('책장', style: IsleText.subtitle()),
            const SizedBox(height: 8),
            ...preview.shelves.map(
              (Shelf s) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(s.iconEmoji, style: const TextStyle(fontSize: 22)),
                title: Text(s.title, style: IsleText.body()),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onEnter,
              child: Text('$label님 섬 전체 보기'),
            ),
          ],
        ),
      ),
    );
  }
}
