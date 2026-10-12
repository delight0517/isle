import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_build_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/env.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/island/island_profile_service.dart';
import '../../../core/island/island_theme_palette.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/island/island_snapshot_store.dart';
import '../../../core/island/local_shelf_store.dart';
import '../data/models/island_snapshot.dart';
import '../data/island_repository.dart';
import '../data/models/shelf.dart';
import '../providers/island_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'other_islands_browser_screen.dart';
import 'widgets/archive_list_sheet.dart';
import 'widgets/island_cloud_transition.dart';
import 'widgets/isometric_island_painter.dart';

class IslandScreen extends ConsumerStatefulWidget {
  final String? userId;
  const IslandScreen({super.key, this.userId});

  @override
  ConsumerState<IslandScreen> createState() => _IslandScreenState();
}

class _IslandScreenState extends ConsumerState<IslandScreen> {
  List<Shelf> _shelves = [];
  IslandMonthlySnapshot? _snapshot;
  String? _tappedShelfId;
  bool _loading = true;
  String _lastResolvedUid = '';
  String _viewPeriod = 'live';

  String _resolveUid() => widget.userId ?? ref.read(authStateProvider).value?.id ?? 'local';

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadIsland);
  }

  @override
  void didUpdateWidget(covariant IslandScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      Future.microtask(_loadIsland);
    }
  }

  Future<void> _loadIsland({bool force = false}) async {
    final uid = _resolveUid();
    if (!force && uid == _lastResolvedUid && _shelves.isNotEmpty && !_loading) return;
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    try {
      await IslandSnapshotStore.ensureOpen();
      await LocalShelfStore.ensureOpen();
      IslandMonthlySnapshot profile;
      if (_viewPeriod == 'live') {
        profile = await IslandProfileService.refreshAndMaybeSave(userId: uid);
      } else {
        profile = await IslandProfileService.buildForPeriod(_viewPeriod, userId: uid);
      }

      var shelves = profile.shelves;
      if (Env.isSupabaseConfigured && uid.isNotEmpty && uid != 'local') {
        try {
          final remote = await ref.read(islandRepoProvider).getShelves(uid);
          if (remote.isNotEmpty && profile.shelves.length <= 1) {
            shelves = remote;
          }
        } catch (_) {}
      }

      final localShelves = LocalShelfStore.load(uid);
      if (localShelves.isNotEmpty) {
        final ids = shelves.map((s) => s.id).toSet();
        shelves = [...shelves, ...localShelves.where((s) => !ids.contains(s.id))];
      }

      if (shelves.isEmpty) {
        shelves = IslandRepository.dummyShelves();
      }

      final userProfile = ref.read(currentUserProvider).value;
      if (userProfile != null &&
          userProfile.islandTheme.isNotEmpty &&
          userProfile.islandTheme != IsleUserDefaults.islandThemeId) {
        await IsleUserDefaults.setIslandThemeId(userProfile.islandTheme);
      }

      if (!mounted) return;
      setState(() {
        _lastResolvedUid = uid;
        _snapshot = profile;
        _shelves = shelves;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastResolvedUid = uid;
        _shelves = IslandRepository.dummyShelves();
        _loading = false;
      });
    }
  }

  List<String> get _periodOptions {
    final keys = IslandSnapshotStore.listPeriodKeys();
    return ['live', ...keys.reversed];
  }

  String _periodLabel(String key) {
    if (key == 'live') return '이번 달';
    final parts = key.split('-');
    if (parts.length == 2) return '${parts[0]}년 ${int.parse(parts[1])}월';
    return key;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateProvider);
    final uid = _resolveUid();
    if (uid != _lastResolvedUid && !_loading) {
      Future.microtask(() => _loadIsland(force: true));
    }

    final summary = _snapshot?.summary ?? '';
    final theme = IslandThemePalette.byId(IsleUserDefaults.islandThemeId);

    return Scaffold(
      backgroundColor: theme.skyTop,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [theme.skyTop, theme.skyBottom],
              ),
            ),
          ),
          if (!_loading)
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                constrained: true,
                child: LayoutBuilder(
                  builder: (ctx, constraints) => GestureDetector(
                    onTapDown: (d) => _handleTap(
                      d.localPosition,
                      Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: IsometricIslandPainter(
                        shelves: _shelves,
                        tappedShelfId: _tappedShelfId,
                        palette: theme,
                      ),
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.3, 0.3),
                  duration: 800.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(duration: 400.ms),
          if (_loading) const Center(child: CircularProgressIndicator(color: IsleColors.gold500)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          backgroundColor: IsleColors.ocean500,
                          child: Icon(Icons.person, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.userId != null ? '친구의 섬' : '나의 섬',
                                style: IsleText.subtitle(color: Colors.white),
                              ),
                              Text(
                                summary.isNotEmpty ? summary : '책장 ${_shelves.length}개',
                                style: IsleText.caption(color: IsleColors.sand500),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '관심사로 다시 만들기',
                          onPressed: () => _loadIsland(force: true),
                          icon: const Icon(Icons.refresh, color: Colors.white70),
                        ),
                        if (widget.userId == null)
                          IconButton(
                            tooltip: '다른 사람 섬 보기',
                            onPressed: _openOtherIslands,
                            icon: const Icon(Icons.cloud_outlined, color: Colors.white),
                          ),
                        if (widget.userId == null && AppBuildConfig.enableSocialUgc)
                          IconButton(
                            tooltip: '내 게시물',
                            onPressed: () => context.push('/social/profile/preview'),
                            icon: const Icon(Icons.grid_on_outlined, color: Colors.white70),
                          ),
                        IconButton(
                          tooltip: 'AI 센터',
                          onPressed: () => context.push('/settings/ai-hub'),
                          icon: const Icon(Icons.auto_awesome, color: IsleColors.gold500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _periodOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final key = _periodOptions[i];
                          final selected = key == _viewPeriod;
                          return FilterChip(
                            label: Text(_periodLabel(key)),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _viewPeriod = key);
                              _loadIsland(force: true);
                            },
                            labelStyle: IsleText.caption(
                              color: selected ? IsleColors.ocean900 : Colors.white70,
                            ),
                            selectedColor: IsleColors.gold500,
                            backgroundColor: IsleColors.ocean700.withValues(alpha: 0.5),
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_viewPeriod != 'live')
            Positioned(
              left: 16,
              right: 16,
              bottom: 100,
              child: Material(
                color: IsleColors.ocean700.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    '과거 스냅샷 — ${_periodLabel(_viewPeriod)}에 저장된 섬 모습입니다.',
                    style: IsleText.caption(color: IsleColors.sand500),
                  ),
                ),
              ),
            ),
          if (widget.userId == null)
            Positioned(
              bottom: 32,
              right: 24,
              child: FloatingActionButton(
                backgroundColor: IsleColors.gold500,
                foregroundColor: IsleColors.ocean900,
                onPressed: _showAddShelfDialog,
                child: const Icon(Icons.add),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openOtherIslands() async {
    await runIslandCloudTransition(context, () async {
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const OtherIslandsBrowserScreen()),
      );
    });
  }

  void _handleTap(Offset localPos, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height * 0.45);
    const tileW = IsometricIslandPainter.tileW;
    const tileH = IsometricIslandPainter.tileH;

    for (final shelf in _shelves.reversed) {
      final isoX = center.dx + (shelf.positionX - shelf.positionY) * tileW / 2;
      final isoY = center.dy + (shelf.positionX + shelf.positionY) * tileH / 2;
      final hitRect = Rect.fromCenter(
        center: Offset(isoX, isoY - 40),
        width: tileW,
        height: 100,
      );
      if (hitRect.contains(localPos)) {
        setState(() => _tappedShelfId = shelf.id);
        _showArchiveSheet(shelf);
        return;
      }
    }
  }

  void _showArchiveSheet(Shelf shelf) {
    final local = _snapshot?.archivesByShelfId[shelf.id];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ArchiveListSheet(shelf: shelf, localArchives: local),
    ).then((_) {
      if (mounted) setState(() => _tappedShelfId = null);
    });
  }

  void _showAddShelfDialog() {
    final uid = _resolveUid();
    final user = ref.read(authStateProvider).value;
    final titleCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '📚');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('책장 추가', style: IsleText.subtitle()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emojiCtrl,
              decoration: const InputDecoration(labelText: '이모지 (1글자)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              var emoji = emojiCtrl.text.trim();
              if (emoji.isEmpty) emoji = '📚';
              if (emoji.characters.length > 1) {
                emoji = emoji.characters.first;
              }
              final int positionX;
              final int positionY;
              if (_shelves.isEmpty) {
                positionX = 0;
                positionY = 0;
              } else {
                final maxY = _shelves.map((s) => s.positionY).reduce((a, b) => a > b ? a : b);
                final maxX = _shelves.map((s) => s.positionX).reduce((a, b) => a > b ? a : b);
                positionX = (maxX + 1) % 4;
                positionY = maxY + 1;
              }
              try {
                if (Env.isSupabaseConfigured && user != null) {
                  final shelf = Shelf(
                    id: '',
                    userId: user.id,
                    title: title,
                    iconEmoji: emoji,
                    positionX: positionX,
                    positionY: positionY,
                    createdAt: DateTime.now(),
                  );
                  await ref.read(islandRepoProvider).createShelf(shelf);
                } else {
                  await LocalShelfStore.add(
                    userId: uid,
                    title: title,
                    iconEmoji: emoji,
                    positionX: positionX,
                    positionY: positionY,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadIsland(force: true);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('책장이 추가됐어요')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    ).then((_) {
      titleCtrl.dispose();
      emojiCtrl.dispose();
    });
  }
}
