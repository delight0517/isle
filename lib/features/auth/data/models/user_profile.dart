class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String islandTheme;
  final bool isPublic;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.islandTheme = 'classic',
    this.isPublic = true,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        username: j['username'] as String,
        displayName: j['display_name'] as String,
        avatarUrl: j['avatar_url'] as String?,
        islandTheme: j['island_theme'] as String? ?? 'classic',
        isPublic: j['is_public'] as bool? ?? true,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'island_theme': islandTheme,
        'is_public': isPublic,
      };

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    String? islandTheme,
    bool? isPublic,
  }) =>
      UserProfile(
        id: id,
        username: username,
        createdAt: createdAt,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        islandTheme: islandTheme ?? this.islandTheme,
        isPublic: isPublic ?? this.isPublic,
      );
}
