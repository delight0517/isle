import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/env.dart';
import '../../../core/insight/knowledge_visual_system.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/insight/living_identity_service.dart';
import '../../../core/social/isle_social_store.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../../shared/widgets/tag_badge.dart';
import 'insight_compose_sheet.dart';
import 'widgets/insight_typography_card.dart';
/// Living Knowledge Identity — 대시보드 + 타임라인
class LivingIdentityProfileScreen extends ConsumerWidget {
  const LivingIdentityProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = LivingIdentityService.build();
    final timeline = LivingIdentityService.recentTimeline();
    final profile = IsleSocialStore.loadProfile();
    final bio = profile.bio.trim().isNotEmpty
        ? profile.bio
        : '소비가 곧 포트폴리오 — 영상·CC·통찰을 한 줄의 지식 명함으로';

    return Scaffold(
      backgroundColor: KnowledgeVisual.paper,
      appBar: const IsleAppBar(title: '지식 명함'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            profile.displayName,
            style: KnowledgeVisual.editorialHeadline(
              color: KnowledgeVisual.ink,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            KnowledgeVisual.slogan,
            style: KnowledgeVisual.editorialMonoHint(color: KnowledgeVisual.intelligentBlue),
          ),
          const SizedBox(height: 12),
          Text(
            bio,
            style: KnowledgeVisual.editorialBody(color: KnowledgeVisual.caption),
          ),
          if (Env.isSupabaseConfigured) ...[
            const SizedBox(height: 12),
            const _InsightCloudToggle(),
          ],
          const SizedBox(height: 20),
          _StatsRow(
            insights: snap.totalInsights,
            published: snap.publishedCount,
            windowDays: 90,
          ),
          const SizedBox(height: 20),
          Text(
            '최근 3개월 집중 주제',
            style: KnowledgeVisual.editorialBody(
              color: KnowledgeVisual.ink,
              fontSize: 18,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (snap.topics.isEmpty)
            Text('인사이트를 쌓으면 주제 스파이크가 나타나요.', style: IsleText.caption(color: IsleColors.muted))
          else
            ...snap.topics.map((t) => _SpikeBar(topic: t)),
          const SizedBox(height: 16),
          if (snap.keywordCloud.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: snap.keywordCloud
                  .map((k) => TagBadge(label: '#$k', color: KnowledgeVisual.intelligentBlue))
                  .toList(),
            ),
          const Divider(height: 36),
          Row(
            children: [
              Expanded(child: Text('인사이트 타임라인', style: IsleText.subtitle())),
              TextButton(
                onPressed: () => context.push('/knowledge/swipe'),
                child: const Text('스와이프 읽기'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.push('/knowledge/depth'),
            child: const Text('깊이 맞는 사람 찾기 →'),
          ),
          const SizedBox(height: 12),
          if (timeline.isEmpty)
            Text('유튜브 공유 · 공유 탭 큐에서 CC 동기화 후 발행해 보세요.', style: IsleText.body(color: IsleColors.muted))
          else
            ...timeline.take(25).map(
                  (c) => InsightTypographyCard(
                    card: c,
                    onTap: () => showInsightComposeSheet(context, ref, card: c),
                  ),
                ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.insights,
    required this.published,
    required this.windowDays,
  });

  final int insights;
  final int published;
  final int windowDays;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip('$insights', '인사이트'),
        const SizedBox(width: 10),
        _chip('$published', '발행'),
        const SizedBox(width: 10),
        _chip('${windowDays}일', '분석'),
      ],
    );
  }

  Widget _chip(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: KnowledgeVisual.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KnowledgeVisual.hairline),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: KnowledgeVisual.editorialHeadline(
                color: KnowledgeVisual.intelligentBlue,
                fontSize: 22,
              ),
            ),
            Text(label, style: IsleText.caption(color: IsleColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _SpikeBar extends StatelessWidget {
  const _SpikeBar({required this.topic});
  final TopicSpike topic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(topic.label, style: IsleText.body())),
              Text('${topic.count}', style: IsleText.caption(color: IsleColors.muted)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: topic.weight.clamp(0.05, 1),
              minHeight: 8,
              backgroundColor: KnowledgeVisual.intelligentBlueSoft,
              color: KnowledgeVisual.intelligentBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCloudToggle extends StatefulWidget {
  const _InsightCloudToggle();

  @override
  State<_InsightCloudToggle> createState() => _InsightCloudToggleState();
}

class _InsightCloudToggleState extends State<_InsightCloudToggle> {
  late bool _on = IsleUserDefaults.insightCloudExtractionEnabled;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '클라우드 인사이트 추출',
        style: KnowledgeVisual.editorialBody(color: KnowledgeVisual.ink, fontSize: 15),
      ),
      subtitle: Text(
        '자막·LLM·DB는 Supabase Edge에서 처리 (로그인 필요)',
        style: KnowledgeVisual.editorialCaption(color: KnowledgeVisual.caption),
      ),
      value: _on,
      activeTrackColor: KnowledgeVisual.intelligentBlue.withValues(alpha: 0.35),
      activeThumbColor: KnowledgeVisual.intelligentBlue,
      onChanged: (v) async {
        await IsleUserDefaults.setInsightCloudExtractionEnabled(v);
        if (!mounted) return;
        setState(() => _on = v);
      },
    );
  }
}
