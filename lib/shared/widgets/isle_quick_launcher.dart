import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/focus/isle_product_focus.dart';
import '../../core/youtube/youtube_clipboard_watch.dart';
import '../../features/feed/presentation/widgets/block_from_link_sheet.dart';
import '../../features/youtube/presentation/widgets/youtube_creator_insight_sheet.dart';
import 'isle_feature_search_sheet.dart';
import 'isle_platform_picker_sheet.dart';

/// 「무엇을 할까요?」 — 기능 많을 때 직관적 진입
void showIsleQuickLauncher(BuildContext context, {WidgetRef? ref}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    builder: (ctx) => _QuickLauncherSheet(ref: ref),
  );
}

class _QuickLauncherSheet extends StatelessWidget {
  const _QuickLauncherSheet({this.ref});

  final WidgetRef? ref;

  @override
  Widget build(BuildContext context) {
    final focus = IsleProductFocus.enabled;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('무엇을 할까요?', style: IsleText.subtitle(color: IsleColors.ocean900)),
            const SizedBox(height: 4),
            Text(
              focus
                  ? '하단 탭: 차단 · 나의 Isle(길게 누르면 유튜브) · 받기'
                  : '자주 쓰는 기능만 모았어요. 나머지는 설정에서.',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Text('🔍', style: TextStyle(fontSize: 22)),
              title: Text('기능 찾기', style: IsleText.body()),
              subtitle: Text('포모도로 · 쇼츠 · 스케줄', style: IsleText.caption(color: IsleColors.muted)),
              onTap: () {
                Navigator.pop(context);
                showIsleFeatureSearch(context);
              },
            ),
            const SizedBox(height: 12),
            _section(context, '▶ 지금 보기', [
              _Action(
                icon: Icons.explore_outlined,
                color: Color(0xFF0A84FF),
                label: 'Safari',
                onTap: () {
                  Navigator.pop(context);
                  context.push(
                    '/explore/browser?site=custom&url=${Uri.encodeComponent('https://www.google.com')}',
                  );
                },
              ),
              _Action(
                icon: Icons.play_circle_filled,
                color: Color(0xFFFF0000),
                label: '유튜브 재생',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/home/my-isle');
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) context.push('/youtube/browser');
                  });
                },
              ),
              _Action(
                icon: Icons.content_paste,
                color: Color(0xFFFF0000),
                label: 'URL 붙여넣기',
                onTap: () {
                  Navigator.pop(context);
                  YoutubeClipboardWatch.pasteAndPlay(context);
                },
              ),
              _Action(
                icon: Icons.grid_view_rounded,
                color: IsleColors.ocean700,
                label: '다른 사이트',
                onTap: () {
                  Navigator.pop(context);
                  showBottomNavPlatformPickerSheet(context);
                },
              ),
            ]),
            _section(context, '🛡 차단·시간', [
              _Action(
                icon: Icons.shield,
                color: IsleColors.ocean700,
                label: '차단 허브',
                onTap: () => _go(context, '/home/block'),
              ),
              _Action(
                icon: Icons.schedule,
                color: Colors.red.shade700,
                label: '스케줄',
                onTap: () => _go(context, '/settings/block-schedules'),
              ),
              _Action(
                icon: Icons.timer_outlined,
                color: IsleColors.ocean500,
                label: '앱·시청 한도',
                onTap: () => _go(context, '/settings/app-usage-limits'),
              ),
            ]),
            _section(context, '🎨 크리에이터', [
              _Action(
                icon: Icons.route,
                color: const Color(0xFFFF0000),
                label: '맞춤 Top 3',
                onTap: () => _go(context, '/youtube/creative-analytics?tab=growth'),
              ),
              _Action(
                icon: Icons.analytics_outlined,
                color: IsleColors.ocean700,
                label: '크리에이티브 분석',
                onTap: () => _go(context, '/youtube/creative-analytics?tab=outlier'),
              ),
              if (ref != null)
                _Action(
                  icon: Icons.auto_awesome,
                  color: IsleColors.gold500,
                  label: '영상 1개 인사이트',
                  onTap: () {
                    Navigator.pop(context);
                    showYoutubeCreatorInsightSheet(context, ref!);
                  },
                ),
            ]),
            _section(context, '⋯ 더 보기', [
              _Action(
                icon: Icons.share_outlined,
                color: IsleColors.ocean500,
                label: '공유·저장',
                onTap: () => _go(context, '/home/share'),
              ),
              _Action(
                icon: Icons.block,
                color: IsleColors.danger,
                label: '채널·링크 차단',
                onTap: () {
                  Navigator.pop(context);
                  showBlockFromLinkSheet(context);
                },
              ),
              _Action(
                icon: Icons.settings_outlined,
                color: IsleColors.muted,
                label: '설정',
                onTap: () => _go(context, '/settings'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String path) {
    Navigator.pop(context);
    if (path.startsWith('/home/')) {
      context.go(path);
    } else {
      context.push(path);
    }
  }

  Widget _section(BuildContext context, String title, List<_Action> actions) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.92,
            children: actions.map((a) => _ActionTile(action: a)).toList(),
          ),
        ],
      ),
    );
  }
}

class _Action {
  const _Action({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final _Action action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IsleColors.sand100,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: action.color, size: 28),
              const SizedBox(height: 6),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: IsleText.caption().copyWith(height: 1.15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
