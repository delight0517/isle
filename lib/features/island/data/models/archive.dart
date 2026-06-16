class Archive {
  final String id;
  final String userId;
  final String? shelfId;
  final String url;
  final String title;
  final String? thumbnailUrl;
  final String sourceType;
  final bool isRead;
  final bool isPublic;
  final List<String> tags;
  final DateTime archivedAt;

  const Archive({
    required this.id,
    required this.userId,
    this.shelfId,
    required this.url,
    required this.title,
    this.thumbnailUrl,
    this.sourceType = 'article',
    this.isRead = false,
    this.isPublic = true,
    this.tags = const [],
    required this.archivedAt,
  });

  factory Archive.fromJson(Map<String, dynamic> j) => Archive(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        shelfId: j['shelf_id'] as String?,
        url: j['url'] as String,
        title: j['title'] as String,
        thumbnailUrl: j['thumbnail_url'] as String?,
        sourceType: j['source_type'] as String? ?? 'article',
        isRead: j['is_read'] as bool? ?? false,
        isPublic: j['is_public'] as bool? ?? true,
        tags: List<String>.from(j['tags'] as List? ?? []),
        archivedAt: DateTime.parse(j['archived_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'shelf_id': shelfId,
        'url': url,
        'title': title,
        'thumbnail_url': thumbnailUrl,
        'source_type': sourceType,
        'is_public': isPublic,
        'tags': tags,
        'is_read': isRead,
        'archived_at': archivedAt.toIso8601String(),
      };
}
