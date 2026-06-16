/// 관심사 태그 매칭 알고리즘
/// 제목 텍스트와 사용자 관심사 태그를 비교하여 관련성 점수 반환
class TopicMatcher {
  /// 관심사 편집 UI 등에서 사용하는 표준 태그 키 목록
  static List<String> get presetInterestTags => _keywordMap.keys.toList();

  // 태그 → 키워드 맵 (확장 가능)
  static const Map<String, List<String>> _keywordMap = {
    '기술/IT': ['ai', 'flutter', '개발', '앱', '스타트업', 'react', '코드', '프로그래밍', 'gpt', '기술'],
    '재무/투자': ['주식', '투자', '경제', '부동산', '펀드', '비트코인', '재테크', '절세', '금리'],
    '디자인': ['ux', 'ui', '디자인', '브랜딩', '타이포', '색상', 'figma', '그래픽', '인터페이스'],
    '철학/인문': ['철학', '역사', '심리', '문학', '사유', '독서', '인문', '고전'],
    '자기계발': ['생산성', '습관', '목표', '루틴', '성장', '독서', '노션', '시간관리'],
    '라이프스타일': ['여행', '카페', '음식', '패션', '건강', '운동', '라이프'],
    '음악': ['음악', '플레이리스트', '재즈', '클래식', '힙합', '인디', '앨범'],
    '영화/콘텐츠': ['영화', '드라마', '넷플릭스', '리뷰', '시리즈', '콘텐츠', '유튜브'],
    '과학': ['과학', '물리', '생물', '우주', '연구', '논문', '의학'],
    '비즈니스': ['마케팅', '브랜드', '창업', '비즈니스', 'b2b', '세일즈', '전략'],
  };

  /// 텍스트에서 관련 태그 목록 추출
  static List<String> detectTopics(String text) {
    final lower = text.toLowerCase();
    final found = <String>[];
    for (final entry in _keywordMap.entries) {
      if (entry.value.any((kw) => lower.contains(kw))) {
        found.add(entry.key);
      }
    }
    return found;
  }

  /// 콘텐츠 태그 목록 vs 유저 관심사 → 관련성 점수 (0.0~1.0)
  static double score(List<String> contentTopics, List<String> userInterests) {
    if (contentTopics.isEmpty || userInterests.isEmpty) return 0.1;
    final matches = contentTopics.where((t) => userInterests.contains(t)).length;
    return (matches / userInterests.length).clamp(0.0, 1.0);
  }
}
