import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/isle_user_defaults.dart';

/// 피드 첫 방문 — 스와이프 제스처 안내 (전체 화면 회색 막 대신 다이얼로그)
class FeedSwipeCoachOverlay extends StatelessWidget {
  const FeedSwipeCoachOverlay({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  static Future<void> showIfNeeded(BuildContext context) async {
    if (IsleUserDefaults.hasSeenFeedSwipeCoach) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black38,
      builder: (ctx) => FeedSwipeCoachOverlay(
        onDismiss: () async {
          await IsleUserDefaults.setHasSeenFeedSwipeCoach(true);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swipe, size: 48, color: IsleColors.ocean500),
            const SizedBox(height: 16),
            Text('피드 카드 스와이프', style: IsleText.subtitle(color: IsleColors.ocean900)),
            const SizedBox(height: 12),
            const _SwipeHint(
              icon: Icons.arrow_back,
              color: IsleColors.danger,
              title: '왼쪽으로 밀기',
              subtitle: '채널 차단',
            ),
            const SizedBox(height: 10),
            const _SwipeHint(
              icon: Icons.arrow_forward,
              color: IsleColors.ocean700,
              title: '오른쪽으로 밀기',
              subtitle: '무시 · 또는 섬에 아카이브 (설정)',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onDismiss,
                style: FilledButton.styleFrom(
                  backgroundColor: IsleColors.ocean500,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('알겠어요'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: IsleText.body(color: IsleColors.ocean900)),
              Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}
