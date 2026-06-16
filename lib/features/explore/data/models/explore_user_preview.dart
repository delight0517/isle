import '../../../island/data/models/shelf.dart';

/// 탐색 탭용 공개 프로필 + 섬 미리보기
class ExploreUserPreview {
  final String id;
  final String displayName;
  final String username;
  final List<String> interests;
  final List<Shelf> shelves;

  const ExploreUserPreview({
    required this.id,
    required this.displayName,
    required this.username,
    required this.interests,
    required this.shelves,
  });
}
