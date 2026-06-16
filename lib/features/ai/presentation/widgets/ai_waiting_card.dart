import 'package:flutter/material.dart';

import '../../../../core/ai/ai_activity_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import 'ai_honeycomb_worker.dart';

/// 관심 파이프라인 등 — N일 대기 중 「살아 있는」 카드
class AiWaitingCard extends StatelessWidget {
  const AiWaitingCard({super.key, required this.item});

  final AiActivityItem item;

  @override
  Widget build(BuildContext context) {
    final waiting = item.kind == AiActivityKind.waiting;
    final processing = item.kind == AiActivityKind.processing;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: waiting
              ? IsleColors.gold500.withValues(alpha: 0.7)
              : (processing ? IsleColors.ocean500 : IsleColors.ocean100),
          width: waiting ? 2 : 1,
        ),
        gradient: LinearGradient(
          colors: waiting
              ? [
                  IsleColors.ocean900.withValues(alpha: 0.95),
                  const Color(0xFF3D2E6B),
                ]
              : [Colors.white, Colors.white],
        ),
        boxShadow: waiting
            ? [
                BoxShadow(
                  color: IsleColors.gold500.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (waiting || processing)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: AiHoneycombWorker(
                      size: 48,
                      active: true,
                      showOutbound: processing,
                    ),
                  )
                else
                  Icon(
                    _icon,
                    color: IsleColors.ocean500,
                    size: 22,
                  ),
                SizedBox(width: waiting || processing ? 0 : 10),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: IsleText.subtitle(color: waiting ? Colors.white : IsleColors.ocean900),
                  ),
                ),
                if (waiting)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: IsleColors.gold500.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('AI 대기', style: IsleText.badge(color: IsleColors.gold300)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.subtitle,
              style: IsleText.caption(color: waiting ? Colors.white70 : IsleColors.muted),
            ),
            if (waiting && item.progress > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.progress,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(IsleColors.gold500),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '데이터는 예정 시각에만 전송 · 지금은 기기 안에서만 대기',
                style: IsleText.caption(color: IsleColors.gold300),
              ),
            ],
            if (processing) ...[
              const SizedBox(height: 10),
              Text(
                '꿀벌집 → AI 서버로 요약·기사 전송 중 · 완료되면 피드 카드로 올라갑니다',
                style: IsleText.caption(
                  color: waiting ? Colors.white70 : IsleColors.ocean700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (item.kind) {
        AiActivityKind.waiting => Icons.hourglass_top_rounded,
        AiActivityKind.processing => Icons.sync,
        AiActivityKind.ready => Icons.check_circle_outline,
        AiActivityKind.idle => Icons.info_outline,
      };
}
