/// 「관심 있어요」→ N일 후 기사화 파이프라인
class InterestItem {
  final String id;
  final String url;
  final String title;
  final String sourceType;
  final String channelName;
  final DateTime markedAt;
  final DateTime publishArticleAt;
  final String status; // queued | processing | article_ready | merged
  final String? articleText;
  final String? mergeGroupId;
  final List<String> processLog;

  const InterestItem({
    required this.id,
    required this.url,
    required this.title,
    required this.sourceType,
    required this.channelName,
    required this.markedAt,
    required this.publishArticleAt,
    required this.status,
    this.articleText,
    this.mergeGroupId,
    this.processLog = const [],
  });

  factory InterestItem.fromJson(Map<String, dynamic> j) => InterestItem(
        id: j['id'] as String,
        url: j['url'] as String,
        title: j['title'] as String,
        sourceType: j['source_type'] as String? ?? 'youtube',
        channelName: j['channel_name'] as String? ?? '',
        markedAt: DateTime.tryParse(j['marked_at'] as String? ?? '') ?? DateTime.now(),
        publishArticleAt:
            DateTime.tryParse(j['publish_article_at'] as String? ?? '') ?? DateTime.now(),
        status: j['status'] as String? ?? 'queued',
        articleText: j['article_text'] as String?,
        mergeGroupId: j['merge_group_id'] as String?,
        processLog: List<String>.from(j['process_log'] as List? ?? []),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'source_type': sourceType,
        'channel_name': channelName,
        'marked_at': markedAt.toIso8601String(),
        'publish_article_at': publishArticleAt.toIso8601String(),
        'status': status,
        if (articleText != null) 'article_text': articleText,
        if (mergeGroupId != null) 'merge_group_id': mergeGroupId,
        'process_log': processLog,
      };

  InterestItem copyWith({
    String? status,
    String? articleText,
    String? mergeGroupId,
    bool clearMergeGroupId = false,
    List<String>? processLog,
    DateTime? publishArticleAt,
  }) =>
      InterestItem(
        id: id,
        url: url,
        title: title,
        sourceType: sourceType,
        channelName: channelName,
        markedAt: markedAt,
        publishArticleAt: publishArticleAt ?? this.publishArticleAt,
        status: status ?? this.status,
        articleText: articleText ?? this.articleText,
        mergeGroupId: clearMergeGroupId ? null : (mergeGroupId ?? this.mergeGroupId),
        processLog: processLog ?? this.processLog,
      );
}
