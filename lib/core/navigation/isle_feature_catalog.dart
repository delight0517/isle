/// 설정·차단 기능 검색 카탈로그 (로컬 · API 없음)
class IsleFeatureEntry {
  const IsleFeatureEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.keywords,
    this.emoji = '✨',
  });

  final String id;
  final String title;
  final String subtitle;
  final String route;
  final List<String> keywords;
  final String emoji;
}

class IsleFeatureCatalog {
  IsleFeatureCatalog._();

  static const all = <IsleFeatureEntry>[
    IsleFeatureEntry(
      id: 'youtube_podcast',
      title: '유튜브 음성',
      subtitle: '썸네일 + 소리만 — 화면 없이 듣기',
      route: '/youtube/podcast',
      emoji: '🎧',
      keywords: [
        '음성',
        '팟캐스트',
        'podcast',
        '뮤직',
        'music',
        '썸네일',
        '오디오',
        '듣기',
        '백그라운드',
      ],
    ),
    IsleFeatureEntry(
      id: 'pomodoro',
      title: '포모도로 휴식',
      subtitle: '30분 보고 10분 쉬기 — 쇼츠·릴 사용 줄이기',
      route: '/home/block/pomodoro',
      emoji: '🍅',
      keywords: [
        '포모도로',
        'pomodoro',
        '휴식',
        '쉬기',
        '30분',
        '10분',
        '쇼츠',
        '숏츠',
        '릴',
        '릴스',
        '카카오',
        '카톡',
        '과소비',
        '습관',
        '짧은영상',
      ],
    ),
    IsleFeatureEntry(
      id: 'kakao_refill',
      title: '카카오 쇼츠 · 5분 리필',
      subtitle: '5분마다 3분만 허용 (스케줄)',
      route: '/home/block/pomodoro?tab=refill',
      emoji: '🔄',
      keywords: ['5분', '리필', '카카오톡', '쇼츠', '스케줄'],
    ),
    IsleFeatureEntry(
      id: 'always_block',
      title: '항상 막기',
      subtitle: '스케줄 없이 앱 즉시 잠금',
      route: '/home/block',
      emoji: '🔒',
      keywords: ['항상', '막기', 'instagram', '틱톡', '차단'],
    ),
    IsleFeatureEntry(
      id: 'schedules',
      title: '차단 스케줄',
      subtitle: '시간대별 앱·한도',
      route: '/settings/block-schedules',
      emoji: '📅',
      keywords: ['스케줄', '시간', '야간', '집중'],
    ),
    IsleFeatureEntry(
      id: 'block_chat',
      title: '차단 AI 챗',
      subtitle: '말로 Safari·인스타·키워드 차단 설정',
      route: '/settings/block-chat',
      emoji: '💬',
      keywords: [
        '챗',
        'chat',
        'ai',
        '사파리',
        'safari',
        '9시',
        '아침',
        '스타크래프트',
        '키워드',
        '블락',
        '차단',
        '인스타',
        '한도',
      ],
    ),
  ];

  static List<IsleFeatureEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [all.first];
    return all.where((e) {
      if (e.title.toLowerCase().contains(q)) return true;
      if (e.subtitle.toLowerCase().contains(q)) return true;
      for (final k in e.keywords) {
        if (k.toLowerCase().contains(q) || q.contains(k.toLowerCase())) return true;
      }
      return false;
    }).toList();
  }
}
