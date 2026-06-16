enum IslePostMediaType { text, image, video }

class IslePost {
  const IslePost({
    required this.id,
    required this.authorId,
    required this.caption,
    this.mediaType = IslePostMediaType.text,
    this.mediaPath = '',
    this.createdAt,
    this.likeCount = 0,
    this.likedByMe = false,
  });

  final String id;
  final String authorId;
  final String caption;
  final IslePostMediaType mediaType;
  final String mediaPath;
  final DateTime? createdAt;
  final int likeCount;
  final bool likedByMe;

  Map<String, dynamic> toJson() => {
        'id': id,
        'author_id': authorId,
        'caption': caption,
        'media_type': mediaType.name,
        'media_path': mediaPath,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        'like_count': likeCount,
        'liked_by_me': likedByMe,
      };

  factory IslePost.fromJson(Map<String, dynamic> j) {
    final mt = j['media_type'] as String? ?? 'text';
    return IslePost(
      id: j['id'] as String? ?? '',
      authorId: j['author_id'] as String? ?? '',
      caption: j['caption'] as String? ?? '',
      mediaType: IslePostMediaType.values.firstWhere(
        (e) => e.name == mt,
        orElse: () => IslePostMediaType.text,
      ),
      mediaPath: j['media_path'] as String? ?? '',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      likeCount: (j['like_count'] as num?)?.toInt() ?? 0,
      likedByMe: j['liked_by_me'] == true,
    );
  }

  IslePost copyWith({int? likeCount, bool? likedByMe}) => IslePost(
        id: id,
        authorId: authorId,
        caption: caption,
        mediaType: mediaType,
        mediaPath: mediaPath,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
      );
}
