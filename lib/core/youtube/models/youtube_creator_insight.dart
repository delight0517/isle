/// 유튜브 영상 → 크리에이터 관점 분석 결과
class YoutubeCreatorInsight {
  final String videoId;
  final String sourceUrl;
  final String title;
  final String channelName;
  final String oneLiner;
  final List<String> differentiationPoints;
  final List<String> keyPoints;
  final List<CreatorApplication> applications;
  final bool usedCaptions;
  final bool usedAi;
  final DateTime analyzedAt;

  const YoutubeCreatorInsight({
    required this.videoId,
    required this.sourceUrl,
    required this.title,
    required this.channelName,
    required this.oneLiner,
    required this.differentiationPoints,
    required this.keyPoints,
    required this.applications,
    required this.usedCaptions,
    required this.usedAi,
    required this.analyzedAt,
  });

  factory YoutubeCreatorInsight.fromJson(Map<String, dynamic> j) {
    final apps = <CreatorApplication>[];
    for (final raw in j['applicable_to_creator'] as List? ?? []) {
      if (raw is! Map) continue;
      apps.add(CreatorApplication.fromJson(Map<String, dynamic>.from(raw)));
    }
    return YoutubeCreatorInsight(
      videoId: j['video_id'] as String? ?? '',
      sourceUrl: j['source_url'] as String? ?? '',
      title: j['title'] as String? ?? '',
      channelName: j['channel_name'] as String? ?? '',
      oneLiner: j['one_liner'] as String? ?? '',
      differentiationPoints: _strList(j['differentiation_points']),
      keyPoints: _strList(j['key_points']),
      applications: apps,
      usedCaptions: j['used_captions'] as bool? ?? false,
      usedAi: j['used_ai'] as bool? ?? false,
      analyzedAt: DateTime.tryParse(j['analyzed_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'video_id': videoId,
        'source_url': sourceUrl,
        'title': title,
        'channel_name': channelName,
        'one_liner': oneLiner,
        'differentiation_points': differentiationPoints,
        'key_points': keyPoints,
        'applicable_to_creator': applications.map((e) => e.toJson()).toList(),
        'used_captions': usedCaptions,
        'used_ai': usedAi,
        'analyzed_at': analyzedAt.toIso8601String(),
      };

  static List<String> _strList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }
}

class CreatorApplication {
  final String interest;
  final String application;
  final String actionIdea;

  const CreatorApplication({
    required this.interest,
    required this.application,
    required this.actionIdea,
  });

  factory CreatorApplication.fromJson(Map<String, dynamic> j) => CreatorApplication(
        interest: j['interest'] as String? ?? '',
        application: j['application'] as String? ?? '',
        actionIdea: j['action_idea'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'interest': interest,
        'application': application,
        'action_idea': actionIdea,
      };
}
