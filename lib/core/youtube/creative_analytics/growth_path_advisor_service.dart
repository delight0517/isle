import 'dart:convert';

import '../../ai/ai_client.dart';
import '../../services/isle_user_defaults.dart';
import '../../utils/topic_matcher.dart';
import 'creative_analytics_store.dart';
import 'models/bench_channel.dart';
import 'models/growth_path_bundle.dart';
import 'models/outlier_hit.dart';

/// 관심 소재 + 스캔 데이터 → 「이 길이 가장 쉬워요」 Top 3
class GrowthPathAdvisorService {
  GrowthPathAdvisorService._();

  static Future<GrowthPathBundle> recommend() async {
    await CreativeAnalyticsStore.ensureOpen();
    final channels = CreativeAnalyticsStore.loadChannels();
    if (channels.isEmpty) {
      throw StateError('벤치마킹 채널을 1개 이상 등록하고 스캔한 뒤 다시 시도해 주세요.');
    }

    final interests = _userMaterials();
    final niche = IsleUserDefaults.creatorNicheNote.trim();
    final materialLine = niche.isNotEmpty
        ? '다루시는 소재: $niche · ${interests.join(', ')}'
        : '다루시는 소재: ${interests.join(', ')}';

    final scored = <_ChannelScore>[];
    for (final ch in channels) {
      final s = _scoreChannel(ch, interests);
      if (s != null) scored.add(s);
    }
    scored.sort((a, b) => b.total.compareTo(a.total));

    var picks = scored.take(3).toList().asMap().entries.map((e) {
      return _toPick(e.value, e.key + 1, interests);
    }).toList();

    if (picks.isEmpty) {
      throw StateError('스캔된 대박 영상이 있는 채널이 필요해요. 흥행 레이더에서 스캔해 주세요.');
    }

    var usedAi = false;
    if (AiClient.isConfigured && picks.length >= 2) {
      final polished = await _polishWithAi(
        materialLine: materialLine,
        interests: interests,
        picks: picks,
      );
      if (polished != null) {
        picks = polished;
        usedAi = true;
      }
    }

    final bundle = GrowthPathBundle(
      greeting: '안녕하세요, 주인님',
      materialLine: materialLine,
      picks: picks,
      usedAi: usedAi,
      generatedAt: DateTime.now(),
    );
    await CreativeAnalyticsStore.saveGrowthPathBundle(bundle);
    return bundle;
  }

  static List<String> _userMaterials() {
    final niche = IsleUserDefaults.creatorNicheNote.trim();
    final tags = IsleUserDefaults.onboardingInterestTags;
    if (tags.isNotEmpty) return tags;
    if (niche.isNotEmpty) return TopicMatcher.detectTopics(niche);
    return TopicMatcher.presetInterestTags.take(3).toList();
  }

  static _ChannelScore? _scoreChannel(BenchChannel ch, List<String> interests) {
    final outliers = CreativeAnalyticsStore.loadOutliers(ch.id);
    if (outliers.isEmpty) return null;

    final corpus = StringBuffer(ch.name);
    for (final h in outliers.take(5)) {
      corpus.write(' ${h.video.title}');
    }
    final topics = TopicMatcher.detectTopics(corpus.toString());
    final topicScore = TopicMatcher.score(topics, interests);
    final top = outliers.first;
    final perfScore = (top.ratioToMedian / 4).clamp(0.0, 1.0);

    final narrative = top.video.videoId.isNotEmpty
        ? CreativeAnalyticsStore.narrativeFor(top.video.videoId)
        : null;
    final dataBonus = narrative != null ? 0.15 : 0.0;

    return _ChannelScore(
      channel: ch,
      topHit: top,
      narrativeFormula: narrative?.storyFormula,
      hookSec: narrative?.acts.isNotEmpty == true
          ? narrative!.acts.first.endSec - narrative.acts.first.startSec
          : 8,
      wpm: narrative?.wordsPerMinute ?? 150,
      total: topicScore * 0.5 + perfScore * 0.35 + dataBonus,
      topicScore: topicScore,
    );
  }

  static GrowthPathPick _toPick(_ChannelScore s, int rank, List<String> interests) {
    final hook = s.hookSec <= 8
        ? '초반 ${s.hookSec}초 질문·약속형 훅'
        : '초반 ${s.hookSec}초 스토리·사례형 훅';
    final script = s.wpm > 165
        ? '빠른 대본·정보 밀도 (${s.wpm} WPM)'
        : '차분한 설명형 대본 (${s.wpm} WPM)';
    final camera = s.narrativeFormula != null && s.narrativeFormula!.contains('→')
        ? '컷 전환·자막 리듬이 공식과 맞춰진 편집'
        : '대화형 A-roll + 자막 강조';

    final why = s.topicScore >= 0.4
        ? '주인님 관심(${interests.take(2).join(', ')})과 채널 주제가 겹치고, '
            '대박 영상이 채널 평균 대비 +${s.topHit.boostPercent}%라 벤치마킹 효율이 높아요.'
        : '이 채널의 대박 구조가 검증됐어요(평균 대비 +${s.topHit.boostPercent}%). '
            '훅·대본 템포를 가져오고 예시만 바꾸면 가장 빠른 길이에요.';

    return GrowthPathPick(
      rank: rank,
      channelId: s.channel.id,
      channelName: s.channel.name,
      profileUrl: s.channel.profileUrl,
      matchPercent: (s.total * 100).round().clamp(40, 98),
      hookStyle: hook,
      scriptStyle: script,
      cameraEditing: camera,
      whyEasiest: why,
      researchSteps: [
        '① 「${s.topHit.video.title}」 시나리오 해부 (훅·본론 공식)',
        '② 같은 채널 대박 2개 더 — 반복 패턴만 메모',
        '③ 내 영상 1개에 훅 1개·CTA 1개만 이식 (전체 복제 금지)',
      ],
      topVideoId: s.topHit.video.videoId,
      topVideoTitle: s.topHit.video.title,
      storyFormula: s.narrativeFormula,
    );
  }

  static Future<List<GrowthPathPick>?> _polishWithAi({
    required String materialLine,
    required List<String> interests,
    required List<GrowthPathPick> picks,
  }) async {
    final brief = picks
        .map(
          (p) =>
              '#${p.rank} ${p.channelName} match=${p.matchPercent}% hook=${p.hookStyle}',
        )
        .join('\n');

    final result = await AiClient.chat(
      feature: 'growth_path_top3',
      systemPrompt:
          'You are Isle, a warm Korean YouTube growth advisor. Speak to "주인님". '
          'Output JSON only: { picks: array of exactly ${picks.length} items with '
          'rank, why_easiest (2 sentences Korean), research_steps (array 3 Korean strings) }. '
          'Emphasize: steal structure, not soul. Shopping-recommendation tone.',
      userPrompt: '''
$materialLine
관심: ${interests.join(', ')}

후보:
$brief
''',
      maxTokens: 900,
      temperature: 0.4,
      jsonObject: true,
    );

    if (!result.usedAi || result.content.isEmpty) return null;

    try {
      final map = Map<String, dynamic>.from(jsonDecode(result.content) as Map);
      final rawList = map['picks'] as List? ?? [];
      final out = <GrowthPathPick>[];
      for (var i = 0; i < picks.length && i < rawList.length; i++) {
        final p = picks[i];
        final patch = rawList[i] as Map?;
        if (patch == null) {
          out.add(p);
          continue;
        }
        final stepsRaw = patch['research_steps'];
        final steps = stepsRaw is List
            ? stepsRaw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList()
            : p.researchSteps;
        out.add(
          GrowthPathPick(
            rank: p.rank,
            channelId: p.channelId,
            channelName: p.channelName,
            profileUrl: p.profileUrl,
            matchPercent: p.matchPercent,
            hookStyle: p.hookStyle,
            scriptStyle: p.scriptStyle,
            cameraEditing: p.cameraEditing,
            whyEasiest: patch['why_easiest'] as String? ?? p.whyEasiest,
            researchSteps: steps.isNotEmpty ? steps : p.researchSteps,
            topVideoId: p.topVideoId,
            topVideoTitle: p.topVideoTitle,
            storyFormula: p.storyFormula,
          ),
        );
      }
      return out;
    } catch (_) {
      return null;
    }
  }
}

class _ChannelScore {
  _ChannelScore({
    required this.channel,
    required this.topHit,
    required this.total,
    required this.topicScore,
    this.narrativeFormula,
    required this.hookSec,
    required this.wpm,
  });

  final BenchChannel channel;
  final OutlierHit topHit;
  final double total;
  final double topicScore;
  final String? narrativeFormula;
  final int hookSec;
  final int wpm;
}
