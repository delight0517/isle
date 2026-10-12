import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/guard/isle_bootstrap_state.dart';

/// Hive·Supabase 등 부트스트랩 일부 실패 — 앱은 뜨되 데이터 복구 안내
class BootstrapDegradedBanner extends StatelessWidget {
  const BootstrapDegradedBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!IsleBootstrapState.degraded) return child;
    return Stack(
      children: [
        child,
        Positioned(
          top: MediaQuery.paddingOf(context).top + 4,
          left: 12,
          right: 12,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFFFF3E0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: IsleColors.gold500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '일부 데이터를 불러오지 못했어요. 설정 → 백업에서 복구해 보세요.',
                      style: IsleText.caption(color: IsleColors.ocean900),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/settings/backup'),
                    child: const Text('백업'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
