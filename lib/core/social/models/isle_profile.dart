class IsleProfile {
  const IsleProfile({
    required this.id,
    required this.displayName,
    this.bio = '',
    this.avatarPath = '',
    this.createdAt,
  });

  final String id;
  final String displayName;
  final String bio;
  final String avatarPath;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'bio': bio,
        'avatar_path': avatarPath,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory IsleProfile.fromJson(Map<String, dynamic> j) => IsleProfile(
        id: j['id'] as String? ?? '',
        displayName: j['display_name'] as String? ?? 'Isle',
        bio: j['bio'] as String? ?? '',
        avatarPath: j['avatar_path'] as String? ?? '',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      );

  IsleProfile copyWith({
    String? displayName,
    String? bio,
    String? avatarPath,
  }) =>
      IsleProfile(
        id: id,
        displayName: displayName ?? this.displayName,
        bio: bio ?? this.bio,
        avatarPath: avatarPath ?? this.avatarPath,
        createdAt: createdAt,
      );
}
