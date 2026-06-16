import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// ③ 정리 결과 — 지식 명함 (보내기는 명함·피드, SNS 피드 아님)
class ShareKnowledgeOutboundCard extends StatelessWidget {
  const ShareKnowledgeOutboundCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: IsleColors.ocean100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/knowledge/profile'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: IsleColors.ocean900.withValues(alpha: 0.1),
                child: const Icon(Icons.badge_outlined, color: IsleColors.ocean900),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('내 지식 명함', style: IsleText.subtitle()),
                    Text(
                      '정리한 인사이트·타임라인 — 팔로워 피드가 아니라 나의 포트폴리오',
                      style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: IsleColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
