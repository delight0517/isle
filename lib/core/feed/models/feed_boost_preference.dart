/// 피드 가중치 — 「이런 콘텐츠 더 보기」
enum FeedBoostKind { channel, genre }

class FeedBoostChannel {
  const FeedBoostChannel({
    required this.channelId,
    required this.channelName,
    this.sourceVideoUrl = '',
    this.sourceVideoTitle = '',
    required this.savedAt,
    this.weight = 1,
  });

  final String channelId;
  final String channelName;
  final String sourceVideoUrl;
  final String sourceVideoTitle;
  final DateTime savedAt;
  final int weight;

  bool matches({required String id, required String name}) {
    final cid = channelId.trim().toLowerCase();
    final cname = channelName.trim().toLowerCase();
    final iid = id.trim().toLowerCase();
    final iname = name.trim().toLowerCase();
    if (cid.isNotEmpty && iid.isNotEmpty && cid == iid) return true;
    if (cname.isNotEmpty && iname.isNotEmpty && cname == iname) return true;
    return false;
  }

  Map<String, dynamic> toJson() => {
        'channel_id': channelId,
        'channel_name': channelName,
        'source_video_url': sourceVideoUrl,
        'source_video_title': sourceVideoTitle,
        'saved_at': savedAt.toIso8601String(),
        'weight': weight,
      };

  factory FeedBoostChannel.fromJson(Map<String, dynamic> j) => FeedBoostChannel(
        channelId: j['channel_id'] as String? ?? '',
        channelName: j['channel_name'] as String? ?? '',
        sourceVideoUrl: j['source_video_url'] as String? ?? '',
        sourceVideoTitle: j['source_video_title'] as String? ?? '',
        savedAt: DateTime.tryParse(j['saved_at'] as String? ?? '') ?? DateTime.now(),
        weight: (j['weight'] as num?)?.toInt().clamp(1, 5) ?? 1,
      );

  FeedBoostChannel copyWith({int? weight}) => FeedBoostChannel(
        channelId: channelId,
        channelName: channelName,
        sourceVideoUrl: sourceVideoUrl,
        sourceVideoTitle: sourceVideoTitle,
        savedAt: savedAt,
        weight: weight ?? this.weight,
      );
}

class FeedBoostGenre {
  const FeedBoostGenre({
    required this.id,
    required this.label,
    required this.topics,
    required this.keywords,
    this.sourceVideoUrl = '',
    this.sourceVideoTitle = '',
    required this.savedAt,
    this.weight = 1,
  });

  final String id;
  final String label;
  final List<String> topics;
  final List<String> keywords;
  final String sourceVideoUrl;
  final String sourceVideoTitle;
  final DateTime savedAt;
  final int weight;

  double scoreForItem({
    required String title,
    required String channelName,
    required List<String> detectedTopics,
  }) {
    final hay = '${title.toLowerCase()} ${channelName.toLowerCase()}';
    var hits = 0;
    var checks = 0;

    for (final t in topics) {
      checks++;
      if (detectedTopics.contains(t)) hits++;
      if (hay.contains(t.toLowerCase())) hits++;
    }
    for (final k in keywords) {
      if (k.length < 2) continue;
      checks++;
      if (hay.contains(k.toLowerCase())) hits++;
    }
    if (checks == 0) return 0;
    return (hits / checks).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'topics': topics,
        'keywords': keywords,
        'source_video_url': sourceVideoUrl,
        'source_video_title': sourceVideoTitle,
        'saved_at': savedAt.toIso8601String(),
        'weight': weight,
      };

  factory FeedBoostGenre.fromJson(Map<String, dynamic> j) => FeedBoostGenre(
        id: j['id'] as String? ?? '',
        label: j['label'] as String? ?? '',
        topics: List<String>.from(j['topics'] as List? ?? []),
        keywords: List<String>.from(j['keywords'] as List? ?? []),
        sourceVideoUrl: j['source_video_url'] as String? ?? '',
        sourceVideoTitle: j['source_video_title'] as String? ?? '',
        savedAt: DateTime.tryParse(j['saved_at'] as String? ?? '') ?? DateTime.now(),
        weight: (j['weight'] as num?)?.toInt().clamp(1, 5) ?? 1,
      );

  FeedBoostGenre copyWith({int? weight}) => FeedBoostGenre(
        id: id,
        label: label,
        topics: topics,
        keywords: keywords,
        sourceVideoUrl: sourceVideoUrl,
        sourceVideoTitle: sourceVideoTitle,
        savedAt: savedAt,
        weight: weight ?? this.weight,
      );
}
