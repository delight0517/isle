/// 벤치마킹 등록 채널
class BenchChannel {
  const BenchChannel({
    required this.id,
    required this.channelId,
    required this.name,
    required this.profileUrl,
    required this.addedAt,
    this.handle,
    this.lastScannedAt,
  });

  final String id;
  final String channelId;
  final String? handle;
  final String name;
  final String profileUrl;
  final DateTime addedAt;
  final DateTime? lastScannedAt;

  factory BenchChannel.fromJson(Map<String, dynamic> j) => BenchChannel(
        id: j['id'] as String? ?? '',
        channelId: j['channel_id'] as String? ?? '',
        handle: j['handle'] as String?,
        name: j['name'] as String? ?? '',
        profileUrl: j['profile_url'] as String? ?? '',
        addedAt: DateTime.tryParse(j['added_at'] as String? ?? '') ?? DateTime.now(),
        lastScannedAt: DateTime.tryParse(j['last_scanned_at'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'channel_id': channelId,
        if (handle != null) 'handle': handle,
        'name': name,
        'profile_url': profileUrl,
        'added_at': addedAt.toIso8601String(),
        if (lastScannedAt != null) 'last_scanned_at': lastScannedAt!.toIso8601String(),
      };

  BenchChannel copyWith({
    String? name,
    DateTime? lastScannedAt,
  }) =>
      BenchChannel(
        id: id,
        channelId: channelId,
        handle: handle,
        name: name ?? this.name,
        profileUrl: profileUrl,
        addedAt: addedAt,
        lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      );
}
