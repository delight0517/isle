/// 유튜브·브런치 등 사용자가 연결한 콘텐츠 출처 (로컬 저장, 수동 동기화)
class ConnectedSource {
  final String id;
  final String type; // youtube | brunch | custom
  final String profileUrl;
  final String displayName;
  final DateTime addedAt;
  final DateTime? lastSyncedAt;

  const ConnectedSource({
    required this.id,
    required this.type,
    required this.profileUrl,
    required this.displayName,
    required this.addedAt,
    this.lastSyncedAt,
  });

  factory ConnectedSource.fromJson(Map<String, dynamic> j) => ConnectedSource(
        id: j['id'] as String,
        type: j['type'] as String? ?? 'custom',
        profileUrl: j['profile_url'] as String,
        displayName: j['display_name'] as String? ?? '',
        addedAt: DateTime.tryParse(j['added_at'] as String? ?? '') ?? DateTime.now(),
        lastSyncedAt: DateTime.tryParse(j['last_synced_at'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'profile_url': profileUrl,
        'display_name': displayName,
        'added_at': addedAt.toIso8601String(),
        if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt!.toIso8601String(),
      };

  ConnectedSource copyWith({
    String? id,
    String? type,
    String? profileUrl,
    String? displayName,
    DateTime? addedAt,
    DateTime? lastSyncedAt,
  }) =>
      ConnectedSource(
        id: id ?? this.id,
        type: type ?? this.type,
        profileUrl: profileUrl ?? this.profileUrl,
        displayName: displayName ?? this.displayName,
        addedAt: addedAt ?? this.addedAt,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      );
}
