import 'dart:convert';

import '../../ai/ai_client.dart';
import '../youtube_caption_fetcher.dart';
import 'models/narrative_report.dart';
import 'video_narrative_remote_service.dart';

/// STT(자막) + AI → 훅·3막·스토리 공식 (요약이 아닌 구조 추출)
class NarrativeAnalysisService {
  NarrativeAnalysisService._();

  static Future<NarrativeReport> analyze({
    required String videoId,
    required String title,
    required String channelName,
    required int durationSeconds,
  }) async {
    if (VideoNarrativeRemoteService.canUse) {
      try {
        final remote = await VideoNarrativeRemoteService.analyze(
          videoId: videoId,
          title: title,
          channelName: channelName,
          durationSeconds: durationSeconds,
        );
        if (remote != null) return remote;
      } on StateError {
        rethrow;
      } catch (_) {
        /* Edge 실패 시 로컬 폴백 */
      }
    }

    final captions = await YoutubeCaptionFetcher.fetchTranscript(videoId);
    final usedCaptions = captions != null && captions.length >= 40;

    if (AiClient.isConfigured && usedCaptions) {
      final ai = await _withAi(
        videoId: videoId,
        title: title,
        channelName: channelName,
        durationSeconds: durationSeconds,
        captions: captions,
      );
      if (ai != null) return ai;
    }

    return _heuristic(
      videoId: videoId,
      title: title,
      channelName: channelName,
      durationSeconds: durationSeconds,
      captions: captions,
      usedCaptions: usedCaptions,
    );
  }

  static Future<NarrativeReport?> _withAi({
    required String videoId,
    required String title,
    required String channelName,
    required int durationSeconds,
    required String captions,
  }) async {
    final result = await AiClient.chat(
      feature: 'youtube_narrative_anatomy',
      systemPrompt:
          'You analyze WHY a YouTube video went viral structurally — not a summary. '
          'Output JSON only with keys: '
          'acts (array of {phase: hook|body|twist|cta, start_sec, end_sec, keywords[], emotion, summary}), '
          'story_formula (Korean, one line with arrows e.g. "문제(5초)→통계(15초)→해결 유도"), '
          'wpm (int words per minute estimate), '
          'rhythm_summary (Korean: pacing, cuts density guess, tone shifts), '
          'structural_insight (Korean: why this structure retains viewers — be specific), '
          'originality_prompts (array 2-4 Korean: avoid clone trap — add your soul), '
          'differentiation_checklist (array 3-5 Korean checklist items). '
          'Ground in captions. Hook should be under 15s if data supports.',
      userPrompt: '''
제목: $title
채널: $channelName
길이: ${durationSeconds}s
자막:
${captions.length > 12000 ? captions.substring(0, 12000) : captions}
''',
      maxTokens: 1100,
      temperature: 0.35,
      jsonObject: true,
    );

    if (!result.usedAi || result.content.isEmpty) return null;

    try {
      final map = Map<String, dynamic>.from(jsonDecode(result.content) as Map);
      final acts = <NarrativeAct>[];
      for (final raw in map['acts'] as List? ?? []) {
        if (raw is! Map) continue;
        acts.add(NarrativeAct.fromJson(Map<String, dynamic>.from(raw)));
      }
      return NarrativeReport(
        videoId: videoId,
        title: title,
        channelName: channelName,
        acts: acts,
        storyFormula: map['story_formula'] as String? ?? '',
        wordsPerMinute: (map['wpm'] as num?)?.toInt() ?? 0,
        rhythmSummary: map['rhythm_summary'] as String? ?? '',
        structuralInsight: map['structural_insight'] as String? ?? '',
        originalityPrompts: _strList(map['originality_prompts']),
        differentiationChecklist: _strList(map['differentiation_checklist']),
        usedAi: true,
        usedCaptions: true,
        analyzedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static NarrativeReport _heuristic({
    required String videoId,
    required String title,
    required String channelName,
    required int durationSeconds,
    required String? captions,
    required bool usedCaptions,
  }) {
    final dur = durationSeconds > 0 ? durationSeconds : 600;
    final hookEnd = (dur * 0.08).round().clamp(5, 20);
    final bodyEnd = (dur * 0.85).round();
    final text = captions ?? title;
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final wpm = dur > 0 ? (words / (dur / 60)).round() : 140;

    final hookWords = _topWords(text, 5);
    return NarrativeReport(
      videoId: videoId,
      title: title,
      channelName: channelName,
      acts: [
        NarrativeAct(
          phase: 'hook',
          startSec: 0,
          endSec: hookEnd,
          keywords: hookWords,
          emotionLabel: '호기심',
          summary: usedCaptions
              ? '초반 ${hookEnd}초 — 질문·충격 키워드로 이탈 방지 패턴 (로컬 추정)'
              : '제목 기반 훅 추정 — AI 연결 시 자막으로 정밀화',
        ),
        NarrativeAct(
          phase: 'body',
          startSec: hookEnd,
          endSec: bodyEnd,
          keywords: _topWords(text, 8),
          emotionLabel: '전개',
          summary: '본론 구간 — 정보 밀도·사례 나열',
        ),
        NarrativeAct(
          phase: 'cta',
          startSec: bodyEnd,
          endSec: dur,
          keywords: const ['구독', '다음', '링크'],
          emotionLabel: '행동 유도',
          summary: '마무리 CTA·다음 영상 유도',
        ),
      ],
      storyFormula: '훅(${hookEnd}초) → 본론 전개 → CTA',
      wordsPerMinute: wpm,
      rhythmSummary: wpm > 160
          ? '빠른 말속도 — 숏폼형 긴장감'
          : '중간 속도 — 설명형 내러티브',
      structuralInsight: usedCaptions
          ? '자막 기반 구조 추정입니다. AI 센터 연결 시 「왜 터졌는지」 공식을 더 정밀히 뽑아요.'
          : '자막이 없어 제목·길이만으로 추정했습니다. CC가 있는 영상을 분석하세요.',
      originalityPrompts: _defaultOriginalityTips(),
      differentiationChecklist: _defaultChecklist(),
      usedAi: false,
      usedCaptions: usedCaptions,
      analyzedAt: DateTime.now(),
    );
  }

  static List<String> _strList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }

  static List<String> _defaultOriginalityTips() => const [
        '구조만 가져가고 예시·경험·말투는 반드시 내 것으로 바꾸세요.',
        '벤치마킹 채널과 같은 썸네일 문구·톤을 그대로 쓰면 「양산형」으로 보입니다.',
        '훅 7초 안에 「나만의 한 줄」 약속을 넣어 차별화하세요.',
      ];

  static List<String> _defaultChecklist() => const [
        '□ 내 채널 시청자에게만 통하는 비유 1개 넣었나?',
        '□ 경쟁 채널과 다른 결론·관점이 있는가?',
        '□ 제목·훅이 나의 브랜드 톤과 맞는가?',
      ];

  static List<String> _topWords(String text, int n) {
    final freq = <String, int>{};
    for (final w in text.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))) {
      final t = w.trim().toLowerCase();
      if (t.length < 2) continue;
      freq[t] = (freq[t] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }
}
