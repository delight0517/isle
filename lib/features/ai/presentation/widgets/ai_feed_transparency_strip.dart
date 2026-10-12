import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ai/ai_activity_service.dart';
import '../../../../core/ai/ai_config_store.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/library/interest_pipeline_service.dart';
import '../../../../core/library/interest_pipeline_store.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../feed/providers/feed_provider.dart';
import 'ai_honeycomb_worker.dart';

/// 피드 — 기사화가 무엇을 만드는지 + 사용자가 켤 수 있음을 표시
class AiFeedTransparencyStrip extends ConsumerStatefulWidget {
  const AiFeedTransparencyStrip({super.key});

  @override
  ConsumerState<AiFeedTransparencyStrip> createState() => _AiFeedTransparencyStripState();
}

class _AiFeedTransparencyStripState extends ConsumerState<AiFeedTransparencyStrip> {
  @override
  Widget build(BuildContext context) {
    final pipeline = ref.watch(interestPipelineProvider);
    final days = IsleUserDefaults.interestArticleDays;
    final aiOn = AiConfigStore.isConfigured;
    final working = AiActivityService.hasActiveWork;
    final queued = pipeline.where((e) => e.status == 'queued').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: _ArticlePanel(
        days: days,
        aiOn: aiOn,
        queued: queued,
        working: working,
        onProcess: () => _runPipeline(context),
        onSettings: () => context.push('/settings/interest-pipeline'),
      ),
    );
  }

  Future<void> _runPipeline(BuildContext context) async {
    final n = await InterestPipelineService.processDueItems();
    ref.invalidate(feedProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(n > 0 ? '기사 $n건 생성 · 피드에 반영됨' : '아직 기사화할 항목이 없어요')),
    );
    setState(() {});
  }
}

class _ArticlePanel extends StatelessWidget {
  const _ArticlePanel({
    required this.days,
    required this.aiOn,
    required this.queued,
    required this.working,
    required this.onProcess,
    required this.onSettings,
  });

  final int days;
  final bool aiOn;
  final int queued;
  final bool working;
  final VoidCallback onProcess;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1538), Color(0xFF1E3A7A)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IsleColors.gold500.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiHoneycombWorker(size: 64, active: working, showOutbound: working),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('관심 → 읽기 카드', style: IsleText.subtitle(color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  '피드에서 「관심 있어요」 → $days일 후 '
                  '${aiOn ? 'AI가 3~5문단 기사' : '기기 안 로컬 요약'} → '
                  '피드·내 콘텐츠에 카드로 올라옵니다.',
                  style: IsleText.caption(color: Colors.white70).copyWith(height: 1.4),
                ),
                const SizedBox(height: 8),
                _stepRow('1', '관심 저장', '지금은 전송 없음'),
                _stepRow('2', '$days일 대기', queued > 0 ? '대기 $queued건' : '대기열 비어 있음'),
                _stepRow('3', '기사 생성', aiOn ? '예정일에 API 1회' : '로컬 요약'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSettings,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: IsleColors.gold300,
                          side: BorderSide(color: IsleColors.gold500.withValues(alpha: 0.5)),
                        ),
                        child: const Text('기간·대기열'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: onProcess,
                        style: FilledButton.styleFrom(
                          backgroundColor: IsleColors.gold500,
                          foregroundColor: IsleColors.ocean900,
                        ),
                        child: const Text('지금 기사화'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(String n, String title, String sub) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Text(n, style: IsleText.badge(color: IsleColors.gold500)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$title · $sub',
                style: IsleText.caption(color: Colors.white60),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}
