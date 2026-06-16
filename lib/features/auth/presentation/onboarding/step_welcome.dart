import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../guide/presentation/widgets/youtube_isle_core_guide.dart';

class StepWelcome extends StatelessWidget {
  const StepWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB71C1C), Color(0xFFFF0000)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.play_circle_filled, size: 56, color: Colors.white),
          ).animate().scale(duration: 450.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 20),
          Text('ISLE에 오신 것을\n환영합니다', style: IsleText.title(color: IsleColors.ocean900)),
          const SizedBox(height: 10),
          Text(
            'Isle의 핵심은 「밖의 브라우저 유튜브는 막고, 시청은 Isle에서만」이에요. '
            '다음 단계에서 바로 설정할 수 있어요.',
            style: IsleText.body(color: IsleColors.muted).copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          const YoutubeIsleCoreGuide(compact: true),
        ],
      ),
    );
  }
}
