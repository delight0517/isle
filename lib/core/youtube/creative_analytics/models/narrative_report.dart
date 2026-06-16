/// 3막 구조 · 스토리 공식 · 리듬 분석
class NarrativeAct {
  const NarrativeAct({
    required this.phase,
    required this.startSec,
    required this.endSec,
    required this.keywords,
    required this.emotionLabel,
    required this.summary,
  });

  final String phase;
  final int startSec;
  final int endSec;
  final List<String> keywords;
  final String emotionLabel;
  final String summary;

  factory NarrativeAct.fromJson(Map<String, dynamic> j) => NarrativeAct(
        phase: j['phase'] as String? ?? 'body',
        startSec: (j['start_sec'] as num?)?.toInt() ?? 0,
        endSec: (j['end_sec'] as num?)?.toInt() ?? 0,
        keywords: _strList(j['keywords']),
        emotionLabel: j['emotion'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'phase': phase,
        'start_sec': startSec,
        'end_sec': endSec,
        'keywords': keywords,
        'emotion': emotionLabel,
        'summary': summary,
      };

  static List<String> _strList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }
}

class NarrativeReport {
  const NarrativeReport({
    required this.videoId,
    required this.title,
    required this.channelName,
    required this.acts,
    required this.storyFormula,
    required this.wordsPerMinute,
    required this.rhythmSummary,
    required this.structuralInsight,
    required this.usedAi,
    required this.usedCaptions,
    required this.analyzedAt,
    this.originalityPrompts = const [],
    this.differentiationChecklist = const [],
    this.fromCache = false,
    this.analyzedViaEdge = false,
  });

  final String videoId;
  final String title;
  final String channelName;
  final List<NarrativeAct> acts;
  final String storyFormula;
  final int wordsPerMinute;
  final String rhythmSummary;
  final String structuralInsight;
  final bool usedAi;
  final bool usedCaptions;
  final DateTime analyzedAt;
  /// 구조는 벤치마킹, 알맹이는 내 것 — 복제 덫 방지 팁
  final List<String> originalityPrompts;
  final List<String> differentiationChecklist;
  final bool fromCache;
  final bool analyzedViaEdge;

  factory NarrativeReport.fromJson(Map<String, dynamic> j) {
    final acts = <NarrativeAct>[];
    for (final raw in j['acts'] as List? ?? []) {
      if (raw is! Map) continue;
      acts.add(NarrativeAct.fromJson(Map<String, dynamic>.from(raw)));
    }
    return NarrativeReport(
      videoId: j['video_id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      channelName: j['channel_name'] as String? ?? '',
      acts: acts,
      storyFormula: j['story_formula'] as String? ?? '',
      wordsPerMinute: (j['wpm'] as num?)?.toInt() ?? 0,
      rhythmSummary: j['rhythm_summary'] as String? ?? '',
      structuralInsight: j['structural_insight'] as String? ?? '',
      usedAi: j['used_ai'] as bool? ?? false,
      usedCaptions: j['used_captions'] as bool? ?? false,
      analyzedAt: DateTime.tryParse(j['analyzed_at'] as String? ?? '') ?? DateTime.now(),
      originalityPrompts: _strList(j['originality_prompts']),
      differentiationChecklist: _strList(j['differentiation_checklist']),
      fromCache: j['from_cache'] as bool? ?? false,
      analyzedViaEdge: j['analyzed_via_edge'] as bool? ?? false,
    );
  }

  static List<String> _strList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }

  Map<String, dynamic> toJson() => {
        'video_id': videoId,
        'title': title,
        'channel_name': channelName,
        'acts': acts.map((e) => e.toJson()).toList(),
        'story_formula': storyFormula,
        'wpm': wordsPerMinute,
        'rhythm_summary': rhythmSummary,
        'structural_insight': structuralInsight,
        'used_ai': usedAi,
        'used_captions': usedCaptions,
        'analyzed_at': analyzedAt.toIso8601String(),
        'originality_prompts': originalityPrompts,
        'differentiation_checklist': differentiationChecklist,
        'from_cache': fromCache,
        'analyzed_via_edge': analyzedViaEdge,
      };
}
