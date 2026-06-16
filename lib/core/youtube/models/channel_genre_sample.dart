/// 「이 유형도 차단」에 쌓이는 샘플 채널
class ChannelGenreSample {
  final String channelId;
  final String channelName;
  final String pageUrl;
  final String? reason;
  final DateTime recordedAt;

  const ChannelGenreSample({
    required this.channelId,
    required this.channelName,
    required this.pageUrl,
    this.reason,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
        'channel_id': channelId,
        'channel_name': channelName,
        'page_url': pageUrl,
        if (reason != null) 'reason': reason,
        'recorded_at': recordedAt.toIso8601String(),
      };

  factory ChannelGenreSample.fromJson(Map<String, dynamic> j) => ChannelGenreSample(
        channelId: j['channel_id'] as String? ?? '',
        channelName: j['channel_name'] as String? ?? '',
        pageUrl: j['page_url'] as String? ?? '',
        reason: j['reason'] as String?,
        recordedAt: DateTime.tryParse(j['recorded_at'] as String? ?? '') ?? DateTime.now(),
      );
}
