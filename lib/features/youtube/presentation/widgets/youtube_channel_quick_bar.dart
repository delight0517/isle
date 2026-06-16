import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_dimensions.dart';

/// 인앱 YouTube — 채널·시청 중 하단 퀵 액션 (홈 복귀 없이 차단·구독)
class YoutubeChannelQuickBar extends StatelessWidget {
  const YoutubeChannelQuickBar({
    super.key,
    required this.channelLabel,
    required this.bottomInset,
    required this.onBlock,
    required this.onSubscribe,
    this.onDismiss,
  });

  final String channelLabel;
  final double bottomInset;
  final VoidCallback onBlock;
  final VoidCallback onSubscribe;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final label = channelLabel.trim().isEmpty ? '이 채널' : channelLabel.trim();

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                onPressed: onDismiss,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: IsleSize.minTouchTarget,
                  minHeight: IsleSize.minTouchTarget,
                ),
              ),
            Expanded(
              child: Text(
                label,
                style: IsleText.caption(color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _ActionChip(
              icon: Icons.block,
              label: '숨기기',
              color: IsleColors.danger,
              onTap: () {
                HapticFeedback.mediumImpact();
                onBlock();
              },
            ),
            const SizedBox(width: 8),
            _ActionChip(
              icon: Icons.rss_feed,
              label: '피드 구독',
              color: IsleColors.gold500,
              onTap: () {
                HapticFeedback.lightImpact();
                onSubscribe();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: IsleText.caption(color: Colors.white).copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
