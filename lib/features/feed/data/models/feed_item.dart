class FeedItem {
  final String id;
  final String title;
  final String url;
  final String thumbnailUrl;
  final String sourceType;
  final String channelId;
  final String channelName;
  final String channelAvatar;
  final List<String> detectedTopics;
  final double relevanceScore;
  final DateTime publishedAt;
  final String? summary;
  // 시청 이력 기반 추천 여부 (저장하지 않고 런타임에만 계산)
  final String? recommendReason;
  bool isArchived;
  bool isDismissed;

  FeedItem({
    required this.id,
    required this.title,
    required this.url,
    required this.thumbnailUrl,
    required this.sourceType,
    required this.channelId,
    required this.channelName,
    required this.channelAvatar,
    required this.detectedTopics,
    required this.relevanceScore,
    required this.publishedAt,
    this.summary,
    this.recommendReason,
    this.isArchived = false,
    this.isDismissed = false,
  });

  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
        id: j['id'] as String,
        title: j['title'] as String,
        url: j['content_url'] as String,
        thumbnailUrl: j['thumbnail_url'] as String? ?? '',
        sourceType: j['source_type'] as String? ?? 'article',
        channelId: j['channel_id'] as String? ?? '',
        channelName: j['channel_name'] as String? ?? '',
        channelAvatar: j['channel_avatar'] as String? ?? '',
        detectedTopics: List<String>.from(j['detected_topics'] as List? ?? []),
        relevanceScore: (j['relevance_score'] as num?)?.toDouble() ?? 0,
        publishedAt: DateTime.tryParse(j['published_at'] as String? ?? '') ?? DateTime.now(),
        summary: j['summary'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content_url': url,
        'thumbnail_url': thumbnailUrl,
        'source_type': sourceType,
        'channel_id': channelId,
        'channel_name': channelName,
        'channel_avatar': channelAvatar,
        'detected_topics': detectedTopics,
        'relevance_score': relevanceScore,
        'published_at': publishedAt.toIso8601String(),
        if (summary != null) 'summary': summary,
      };

  FeedItem copyWith({
    String? id,
    String? title,
    String? url,
    String? thumbnailUrl,
    String? sourceType,
    String? channelId,
    String? channelName,
    String? channelAvatar,
    List<String>? detectedTopics,
    double? relevanceScore,
    DateTime? publishedAt,
    String? summary,
    String? recommendReason,
    bool? isArchived,
    bool? isDismissed,
  }) =>
      FeedItem(
        id: id ?? this.id,
        title: title ?? this.title,
        url: url ?? this.url,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        sourceType: sourceType ?? this.sourceType,
        channelId: channelId ?? this.channelId,
        channelName: channelName ?? this.channelName,
        channelAvatar: channelAvatar ?? this.channelAvatar,
        detectedTopics: detectedTopics ?? this.detectedTopics,
        relevanceScore: relevanceScore ?? this.relevanceScore,
        publishedAt: publishedAt ?? this.publishedAt,
        summary: summary ?? this.summary,
        recommendReason: recommendReason ?? this.recommendReason,
        isArchived: isArchived ?? this.isArchived,
        isDismissed: isDismissed ?? this.isDismissed,
      );
}
