/// AI가 추론한 차단 유형 프로필
class ChannelGenreProfile {
  final String id;
  final String genreLabel;
  final List<String> keywords;
  final List<String> searchQueries;
  final String explanation;
  final int sampleCount;
  final int channelsAutoBlocked;
  final DateTime analyzedAt;

  const ChannelGenreProfile({
    required this.id,
    required this.genreLabel,
    required this.keywords,
    required this.searchQueries,
    required this.explanation,
    required this.sampleCount,
    required this.channelsAutoBlocked,
    required this.analyzedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'genre_label': genreLabel,
        'keywords': keywords,
        'search_queries': searchQueries,
        'explanation': explanation,
        'sample_count': sampleCount,
        'channels_auto_blocked': channelsAutoBlocked,
        'analyzed_at': analyzedAt.toIso8601String(),
      };

  factory ChannelGenreProfile.fromJson(Map<String, dynamic> j) => ChannelGenreProfile(
        id: j['id'] as String? ?? '',
        genreLabel: j['genre_label'] as String? ?? '',
        keywords: List<String>.from(j['keywords'] as List? ?? []),
        searchQueries: List<String>.from(j['search_queries'] as List? ?? []),
        explanation: j['explanation'] as String? ?? '',
        sampleCount: (j['sample_count'] as num?)?.toInt() ?? 0,
        channelsAutoBlocked: (j['channels_auto_blocked'] as num?)?.toInt() ?? 0,
        analyzedAt: DateTime.tryParse(j['analyzed_at'] as String? ?? '') ?? DateTime.now(),
      );
}
