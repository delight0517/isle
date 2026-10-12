import 'package:flutter/material.dart';

import '../../../../core/block_schedule/block_focus_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/platform/platform_block_intent.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';

/// 지금 차단이 켜져 있는지 한눈에
class BlockFocusStatusCard extends StatelessWidget {
  const BlockFocusStatusCard({
    super.key,
    required this.status,
    required this.onPrimaryAction,
    this.busy = false,
  });

  final BlockFocusStatus status;
  final VoidCallback onPrimaryAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final blocking = status.scheduleActiveNow && status.hasApps;
    final ready = status.isReady;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: blocking
              ? [const Color(0xFF2D6A5A), const Color(0xFF1B4332)]
              : ready
                  ? [const Color(0xFF4A6FA5), IsleColors.ocean700]
                  : [IsleColors.ocean500, IsleColors.ocean700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: IsleColors.ocean500.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                blocking ? Icons.shield : Icons.shield_outlined,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  blocking ? '지금 차단 중' : '앱 차단',
                  style: IsleText.title(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            status.headline,
            style: IsleText.body(color: Colors.white.withValues(alpha: 0.92)).copyWith(height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            PlatformBlockCopy.blockFocusExternalAppsHint,
            style: IsleText.caption(color: Colors.white.withValues(alpha: 0.78)).copyWith(height: 1.35),
          ),
          const SizedBox(height: 16),
          if (!ready)
            FilledButton.icon(
              onPressed: busy ? null : onPrimaryAction,
              icon: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: IsleColors.ocean700),
                    )
                  : const Icon(Icons.bolt),
              label: Text(busy ? '설정 중…' : 'Instagram·SNS 막기 (3분 설정)'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: IsleColors.ocean700,
                minimumSize: const Size.fromHeight(IsleSize.minTouchTarget),
              ),
            ),
          if (ready && !blocking)
            OutlinedButton.icon(
              onPressed: busy ? null : onPrimaryAction,
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              label: const Text('앱·시간 다시 고르기', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
        ],
      ),
    );
  }
}
