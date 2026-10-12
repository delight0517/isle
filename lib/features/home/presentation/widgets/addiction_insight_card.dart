import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/content/daily_addiction_insight_service.dart';

/// 고정 원칙 배너 — 절대 순환하지 않는 별도의 경고 문구.
/// 로테이션 콘텐츠(AddictionInsightCard)와 다른 컴포넌트로 분리해
/// 날짜가 바뀌어도 이 문구는 항상 동일하게 노출한다.
class PrincipleBannerWidget extends StatelessWidget {
  const PrincipleBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: IsleColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IsleColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: IsleColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '마약은 적당한 조절이 아니라 근절이 필요합니다. 명심하십시오.',
              style: IsleText.caption(color: IsleColors.danger)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// 날마다 바뀌는 미디어 과사용 경각심 콘텐츠 — 로컬 순환, API 미사용.
class AddictionInsightCard extends StatefulWidget {
  const AddictionInsightCard({super.key});

  @override
  State<AddictionInsightCard> createState() => _AddictionInsightCardState();
}

class _AddictionInsightCardState extends State<AddictionInsightCard> {
  AddictionInsight? _insight;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final insight = await DailyAddictionInsightService.todayInsight();
    if (mounted) setState(() => _insight = insight);
  }

  @override
  Widget build(BuildContext context) {
    final insight = _insight;
    if (insight == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: IsleColors.ocean100.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: IsleColors.ocean700, size: 16),
              const SizedBox(width: 6),
              Text(
                '오늘의 이야기',
                style: IsleText.caption(color: IsleColors.ocean700)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            insight.text,
            style: IsleText.body(color: IsleColors.ocean900),
          ),
        ],
      ),
    );
  }
}
