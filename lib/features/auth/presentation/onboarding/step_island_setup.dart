import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

class StepIslandSetup extends StatelessWidget {
  const StepIslandSetup({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('내 섬이\n기다리고 있어요', style: IsleText.title(color: IsleColors.ocean900)),
          const SizedBox(height: 12),
          Text(
            '피드에서 콘텐츠를 오른쪽으로 스와이프하면 주제별 책장에 쌓여요. '
            '하단 「내 섬」 탭에서 이소메트릭 서재를 볼 수 있어요.',
            style: IsleText.body(color: IsleColors.muted),
          ),
          const SizedBox(height: 24),
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [IsleColors.grass, IsleColors.grassDeep],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: IsleColors.woodMid, width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 48,
                        height: 64,
                        decoration: BoxDecoration(
                          color: IsleColors.woodLight,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2)),
                          ],
                        ),
                        child: Icon(Icons.menu_book, color: IsleColors.sand100.withValues(alpha: 0.9), size: 28),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  child: Row(
                    children: [
                      const Icon(Icons.cabin, color: Colors.white, size: 28),
                      const SizedBox(width: 8),
                      Text('내 섬 미리보기', style: IsleText.subtitle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _TipRow(text: '피드 카드 탭 → 원문 보기'),
          _TipRow(text: '왼쪽 스와이프 → 채널 차단'),
          _TipRow(text: '오른쪽 스와이프 → 섬에 아카이브'),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.touch_app_outlined, size: 18, color: IsleColors.ocean500),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: IsleText.body())),
        ],
      ),
    );
  }
}
