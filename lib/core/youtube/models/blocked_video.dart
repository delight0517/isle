class BlockedVideo {
  final String videoId;
  final String? sourceUrl;
  final DateTime blockedAt;

  const BlockedVideo({
    required this.videoId,
    this.sourceUrl,
    required this.blockedAt,
  });

  Map<String, dynamic> toJson() => {
        'video_id': videoId,
        'source_url': sourceUrl,
        'blocked_at': blockedAt.toIso8601String(),
      };

  factory BlockedVideo.fromJson(Map<String, dynamic> j) => BlockedVideo(
        videoId: j['video_id'] as String? ?? '',
        sourceUrl: j['source_url'] as String?,
        blockedAt: DateTime.tryParse(j['blocked_at'] as String? ?? '') ?? DateTime.now(),
      );
}
