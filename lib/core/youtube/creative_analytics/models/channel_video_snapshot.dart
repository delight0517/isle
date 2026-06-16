/// 채널 영상 스냅샷 (조회·길이·게시일)
class ChannelVideoSnapshot {
  const ChannelVideoSnapshot({
    required this.videoId,
    required this.title,
    required this.viewCount,
    required this.durationSeconds,
    required this.publishedAt,
    this.thumbnailUrl,
    this.channelName = '',
  });

  final String videoId;
  final String title;
  final int viewCount;
  final int durationSeconds;
  final DateTime publishedAt;
  final String? thumbnailUrl;
  final String channelName;

  factory ChannelVideoSnapshot.fromJson(Map<String, dynamic> j) => ChannelVideoSnapshot(
        videoId: j['video_id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        viewCount: (j['view_count'] as num?)?.toInt() ?? 0,
        durationSeconds: (j['duration_seconds'] as num?)?.toInt() ?? 0,
        publishedAt: DateTime.tryParse(j['published_at'] as String? ?? '') ?? DateTime.now(),
        thumbnailUrl: j['thumbnail_url'] as String?,
        channelName: j['channel_name'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'video_id': videoId,
        'title': title,
        'view_count': viewCount,
        'duration_seconds': durationSeconds,
        'published_at': publishedAt.toIso8601String(),
        if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
        'channel_name': channelName,
      };
}
