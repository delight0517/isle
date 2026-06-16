import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import 'isle_quick_launcher.dart';

/// 차단 홈 상단 — 4개 직관 바로가기
class IsleHomeQuickStrip extends StatelessWidget {
  const IsleHomeQuickStrip({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      _QuickItem(Icons.landscape_outlined, '나의 Isle', IsleColors.ocean700, '/home/my-isle'),
      _QuickItem(Icons.shield, '차단', IsleColors.ocean700, '/home/block'),
      _QuickItem(Icons.route, 'Top 3', IsleColors.gold500, '/youtube/creative-analytics?tab=growth'),
      _QuickItem(Icons.apps, '전체', IsleColors.muted, null, isLauncher: true),
    ];

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final item = items[i];
          return _QuickChip(
            item: item,
            onTap: () {
              if (item.isLauncher) {
                showIsleQuickLauncher(context);
                return;
              }
              if (item.route != null) {
                final r = item.route!;
                if (r.startsWith('/home/')) {
                  context.go(r);
                } else {
                  context.push(r);
                }
              }
            },
          );
        },
      ),
    );
  }
}

class _QuickItem {
  const _QuickItem(this.icon, this.label, this.color, this.route, {this.isLauncher = false});

  final IconData icon;
  final String label;
  final Color color;
  final String? route;
  final bool isLauncher;
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.item, required this.onTap});

  final _QuickItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 76,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: IsleColors.ocean100),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: item.color, size: 26),
              const SizedBox(height: 6),
              Text(
                item.label,
                style: IsleText.caption().copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
