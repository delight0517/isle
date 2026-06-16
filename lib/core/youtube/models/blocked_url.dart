class BlockedUrl {
  final String canonicalUrl;
  final String? label;
  final String? youtubeVideoId;
  final DateTime blockedAt;

  const BlockedUrl({
    required this.canonicalUrl,
    this.label,
    this.youtubeVideoId,
    required this.blockedAt,
  });

  Map<String, dynamic> toJson() => {
        'canonical_url': canonicalUrl,
        'label': label,
        'youtube_video_id': youtubeVideoId,
        'blocked_at': blockedAt.toIso8601String(),
      };

  factory BlockedUrl.fromJson(Map<String, dynamic> j) => BlockedUrl(
        canonicalUrl: j['canonical_url'] as String? ?? '',
        label: j['label'] as String?,
        youtubeVideoId: j['youtube_video_id'] as String?,
        blockedAt:
            DateTime.tryParse(j['blocked_at'] as String? ?? '') ?? DateTime.now(),
      );
}
