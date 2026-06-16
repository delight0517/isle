import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ai/ai_activity_service.dart';
import '../../../../core/ai/ai_config_store.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import 'ai_honeycomb_worker.dart';

/// 피드·설정 상단 — 꿀벌집 + 남색: AI 대기/전송/기사화 진행
class AiActivityStrip extends StatelessWidget {
  const AiActivityStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final activities = AiActivityService.currentActivities()
        .where((a) => a.kind != AiActivityKind.idle)
        .toList();
    final hasWork = activities.isNotEmpty;
    final processing = activities.any((a) => a.kind == AiActivityKind.processing);
    final waiting = activities.any((a) => a.kind == AiActivityKind.waiting);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/settings/ai-hub'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: hasWork
                  ? const [Color(0xFF0B1538), Color(0xFF243B7A)]
                  : [IsleColors.ocean100, IsleColors.ocean100],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasWork ? IsleColors.gold500.withValues(alpha: 0.55) : IsleColors.ocean300,
              width: hasWork ? 1.5 : 1,
            ),
            boxShadow: hasWork
                ? [
                    BoxShadow(
                      color: IsleColors.gold500.withValues(alpha: 0.2),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (hasWork)
                AiHoneycombWorker(
                  size: 56,
                  active: true,
                  showOutbound: processing || waiting,
                )
              else
                Icon(
                  AiConfigStore.isConfigured ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                  color: IsleColors.ocean500,
                  size: 28,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasWork ? 'AI 작업 진행 중' : 'AI · 무엇이 나오는지',
                      style: IsleText.subtitle(
                        color: hasWork ? Colors.white : IsleColors.ocean900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasWork
                          ? _workDetail(activities)
                          : AiActivityService.statusHeadline,
                      style: IsleText.caption(
                        color: hasWork ? Colors.white70 : IsleColors.muted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: hasWork ? Colors.white70 : IsleColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _workDetail(List<AiActivityItem> items) {
    final proc = items.where((a) => a.kind == AiActivityKind.processing).length;
    final wait = items.where((a) => a.kind == AiActivityKind.waiting).length;
    final ready = items.where((a) => a.kind == AiActivityKind.ready).length;
    final parts = <String>[];
    if (proc > 0) parts.add('전송·기사 작성 $proc');
    if (wait > 0) parts.add('대기 $wait');
    if (ready > 0) parts.add('완료 대기 $ready');
    return parts.isEmpty ? AiActivityService.statusHeadline : parts.join(' · ');
  }
}
