import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// 가이드용 미니 UI 목업 (사진 대신 단계별 그림)
class GuideStepIllustration extends StatelessWidget {
  final IconData icon;
  final String caption;
  final Color accent;
  final List<Widget>? overlays;

  const GuideStepIllustration({
    super.key,
    required this.icon,
    required this.caption,
    this.accent = IsleColors.ocean500,
    this.overlays,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: IsleColors.ocean100, width: 2),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 72, color: accent.withValues(alpha: 0.85))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1.05, 1.05),
                    duration: 1.2.seconds,
                    curve: Curves.easeInOut,
                  ),
              ...?overlays,
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0),
        const SizedBox(height: 16),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: IsleText.body(color: IsleColors.ocean900).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// 피드 카드 스와이프 목업
class SwipeGuideOverlay extends StatelessWidget {
  const SwipeGuideOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 24,
      top: 70,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: IsleColors.danger,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.block, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward, color: IsleColors.danger.withValues(alpha: 0.8), size: 28)
              .animate(onPlay: (c) => c.repeat())
              .moveX(begin: -4, end: 8, duration: 800.ms),
        ],
      ),
    );
  }
}
