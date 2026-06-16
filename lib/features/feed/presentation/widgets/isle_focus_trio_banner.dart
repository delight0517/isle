import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/focus/isle_product_focus.dart';

/// 피드(고급) — 하단 3탭 안내
class IsleFocusTrioBanner extends StatelessWidget {
  const IsleFocusTrioBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!IsleProductFocus.hideSecondaryUi) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Material(
          color: IsleColors.ocean100.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.go('/home/block'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: IsleColors.ocean700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '메인은 하단 탭 — 차단 · 유튜브 · 공유',
                      style: IsleText.caption(color: IsleColors.ocean900),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/home/my-isle'),
                    child: const Text('유튜브'),
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms),
      ),
    );
  }
}
