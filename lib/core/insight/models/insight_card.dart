/// 지식 포트폴리오 카드 — CC·AI 요약·사용자 메모·발행 상태
class InsightCard {
  const InsightCard({
    required this.id,
    required this.url,
    required this.title,
    required this.thumbnailUrl,
    required this.channelName,
    required this.keywords,
    required this.aiSummaryLines,
    required this.userNote,
    required this.articleBody,
    required this.createdAt,
    this.transcript,
    this.publishedAt,
    this.published = false,
  });

  final String id;
  final String url;
  final String title;
  final String thumbnailUrl;
  final String channelName;
  final List<String> keywords;
  final List<String> aiSummaryLines;
  final String userNote;
  final String articleBody;
  final String? transcript;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final bool published;

  String get oneLiner => userNote.trim().isNotEmpty
      ? userNote.trim()
      : (aiSummaryLines.isNotEmpty ? aiSummaryLines.first : title);

  bool get hasArticle => articleBody.trim().length >= 80;

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'thumbnail_url': thumbnailUrl,
        'channel_name': channelName,
        'keywords': keywords,
        'ai_summary_lines': aiSummaryLines,
        'user_note': userNote,
        'article_body': articleBody,
        if (transcript != null) 'transcript': transcript,
        'created_at': createdAt.toIso8601String(),
        if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
        'published': published,
      };

  factory InsightCard.fromJson(Map<String, dynamic> j) => InsightCard(
        id: j['id'] as String? ?? '',
        url: j['url'] as String? ?? '',
        title: j['title'] as String? ?? '',
        thumbnailUrl: j['thumbnail_url'] as String? ?? '',
        channelName: j['channel_name'] as String? ?? '',
        keywords: List<String>.from(j['keywords'] as List? ?? []),
        aiSummaryLines: List<String>.from(j['ai_summary_lines'] as List? ?? []),
        userNote: j['user_note'] as String? ?? '',
        articleBody: j['article_body'] as String? ?? '',
        transcript: j['transcript'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        publishedAt: DateTime.tryParse(j['published_at'] as String? ?? ''),
        published: j['published'] as bool? ?? false,
      );

  InsightCard copyWith({
    String? title,
    String? thumbnailUrl,
    String? channelName,
    List<String>? keywords,
    List<String>? aiSummaryLines,
    String? userNote,
    String? articleBody,
    String? transcript,
    DateTime? publishedAt,
    bool? published,
  }) =>
      InsightCard(
        id: id,
        url: url,
        title: title ?? this.title,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        channelName: channelName ?? this.channelName,
        keywords: keywords ?? this.keywords,
        aiSummaryLines: aiSummaryLines ?? this.aiSummaryLines,
        userNote: userNote ?? this.userNote,
        articleBody: articleBody ?? this.articleBody,
        transcript: transcript ?? this.transcript,
        createdAt: createdAt,
        publishedAt: publishedAt ?? this.publishedAt,
        published: published ?? this.published,
      );
}
