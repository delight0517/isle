class Shelf {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? interestTagId;
  final String iconEmoji;
  final bool isPublic;
  final int positionX;
  final int positionY;
  final String colorHex;
  final DateTime createdAt;

  const Shelf({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.interestTagId,
    this.iconEmoji = '📚',
    this.isPublic = true,
    this.positionX = 0,
    this.positionY = 0,
    this.colorHex = '#2B4A8C',
    required this.createdAt,
  });

  factory Shelf.fromJson(Map<String, dynamic> j) => Shelf(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        interestTagId: j['interest_tag_id'] as String?,
        iconEmoji: j['icon_emoji'] as String? ?? '📚',
        isPublic: j['is_public'] as bool? ?? true,
        positionX: j['position_x'] as int? ?? 0,
        positionY: j['position_y'] as int? ?? 0,
        colorHex: j['color_hex'] as String? ?? '#2B4A8C',
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'interest_tag_id': interestTagId,
        'icon_emoji': iconEmoji,
        'is_public': isPublic,
        'position_x': positionX,
        'position_y': positionY,
        'color_hex': colorHex,
        'created_at': createdAt.toIso8601String(),
      };
}
