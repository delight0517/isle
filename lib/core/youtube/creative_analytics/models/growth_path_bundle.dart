/// 쇼핑 추천처럼 제시하는 「맞춤 성장 코스」 Top 3
class GrowthPathPick {
  const GrowthPathPick({
    required this.rank,
    required this.channelId,
    required this.channelName,
    required this.profileUrl,
    required this.matchPercent,
    required this.hookStyle,
    required this.scriptStyle,
    required this.cameraEditing,
    required this.whyEasiest,
    required this.researchSteps,
    this.topVideoId,
    this.topVideoTitle,
    this.storyFormula,
  });

  final int rank;
  final String channelId;
  final String channelName;
  final String profileUrl;
  final int matchPercent;
  final String hookStyle;
  final String scriptStyle;
  final String cameraEditing;
  final String whyEasiest;
  final List<String> researchSteps;
  final String? topVideoId;
  final String? topVideoTitle;
  final String? storyFormula;

  factory GrowthPathPick.fromJson(Map<String, dynamic> j) => GrowthPathPick(
        rank: (j['rank'] as num?)?.toInt() ?? 1,
        channelId: j['channel_id'] as String? ?? '',
        channelName: j['channel_name'] as String? ?? '',
        profileUrl: j['profile_url'] as String? ?? '',
        matchPercent: (j['match_percent'] as num?)?.toInt() ?? 0,
        hookStyle: j['hook_style'] as String? ?? '',
        scriptStyle: j['script_style'] as String? ?? '',
        cameraEditing: j['camera_editing'] as String? ?? '',
        whyEasiest: j['why_easiest'] as String? ?? '',
        researchSteps: _strList(j['research_steps']),
        topVideoId: j['top_video_id'] as String?,
        topVideoTitle: j['top_video_title'] as String?,
        storyFormula: j['story_formula'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'rank': rank,
        'channel_id': channelId,
        'channel_name': channelName,
        'profile_url': profileUrl,
        'match_percent': matchPercent,
        'hook_style': hookStyle,
        'script_style': scriptStyle,
        'camera_editing': cameraEditing,
        'why_easiest': whyEasiest,
        'research_steps': researchSteps,
        if (topVideoId != null) 'top_video_id': topVideoId,
        if (topVideoTitle != null) 'top_video_title': topVideoTitle,
        if (storyFormula != null) 'story_formula': storyFormula,
      };

  static List<String> _strList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }
}

class GrowthPathBundle {
  const GrowthPathBundle({
    required this.greeting,
    required this.materialLine,
    required this.picks,
    required this.usedAi,
    required this.generatedAt,
  });

  final String greeting;
  final String materialLine;
  final List<GrowthPathPick> picks;
  final bool usedAi;
  final DateTime generatedAt;

  factory GrowthPathBundle.fromJson(Map<String, dynamic> j) {
    final picks = <GrowthPathPick>[];
    for (final raw in j['picks'] as List? ?? []) {
      if (raw is! Map) continue;
      picks.add(GrowthPathPick.fromJson(Map<String, dynamic>.from(raw)));
    }
    return GrowthPathBundle(
      greeting: j['greeting'] as String? ?? '안녕하세요, 주인님',
      materialLine: j['material_line'] as String? ?? '',
      picks: picks,
      usedAi: j['used_ai'] as bool? ?? false,
      generatedAt: DateTime.tryParse(j['generated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'greeting': greeting,
        'material_line': materialLine,
        'picks': picks.map((e) => e.toJson()).toList(),
        'used_ai': usedAi,
        'generated_at': generatedAt.toIso8601String(),
      };
}
