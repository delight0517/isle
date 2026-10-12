/// 차단 AI 챗 — 일상 15가지 시나리오 (예시 문장 · action 매핑)
class BlockChatDailyScenarios {
  const BlockChatDailyScenarios({
    required this.id,
    required this.title,
    required this.examplePrompt,
    required this.action,
    this.hint = '',
  });

  final String id;
  final String title;
  final String examplePrompt;
  final String action;
  final String hint;

  static const all = <BlockChatDailyScenarios>[
    BlockChatDailyScenarios(
      id: 'morning_isle_yt',
      title: '아침 앱 유튜브 차단',
      examplePrompt: '매일 10시30분까지 isle 유튜브 차단해줘',
      action: 'morning_schedule',
      hint: '0시~지정 시각까지 Isle 안 유튜브만',
    ),
    BlockChatDailyScenarios(
      id: 'morning_safari',
      title: '아침 Safari·웹 차단',
      examplePrompt: '매일 9시까지 Safari 막아줘 (Isle 웹도)',
      action: 'morning_schedule',
      hint: 'Safari·Isle 브라우저·인앱 탐색',
    ),
    BlockChatDailyScenarios(
      id: 'youtube_daily',
      title: '유튜브 일일 한도',
      examplePrompt: '유튜브 하루 20분 한도',
      action: 'youtube_limit',
    ),
    BlockChatDailyScenarios(
      id: 'hide_shorts',
      title: '숏츠 숨김',
      examplePrompt: '숏츠 숨겨줘',
      action: 'toggle_shorts',
    ),
    BlockChatDailyScenarios(
      id: 'hide_reels',
      title: '릴스 숨김',
      examplePrompt: '릴스 숨겨줘',
      action: 'toggle_reels',
    ),
    BlockChatDailyScenarios(
      id: 'insta_session',
      title: '인스타 세션·쿨다운',
      examplePrompt: '인스타 5분 쓰고 10분 쉬기, 하루 30분',
      action: 'usage_budget',
    ),
    BlockChatDailyScenarios(
      id: 'keyword_block',
      title: '키워드 숨김',
      examplePrompt: '로블록스 더 이상 안 보게',
      action: 'add_keyword',
    ),
    BlockChatDailyScenarios(
      id: 'morning_habit',
      title: '아침 습관 패키지',
      examplePrompt: '매일 아침 유튜브에서 자꾸 많이 보는데 해결책이 없을까?',
      action: 'morning_habit_pack',
    ),
    BlockChatDailyScenarios(
      id: 'yt_music_screen',
      title: 'YT Music 화면 한도',
      examplePrompt: '유튜브 뮤직 11시까지 1시간에 10분만 onscreen, 나머지 background',
      action: 'music_foreground_limit',
    ),
    BlockChatDailyScenarios(
      id: 'relax_youtube',
      title: '차단 풀기',
      examplePrompt: '아침에 유튜브 이제 보게 해줘',
      action: 'relax_block',
    ),
    BlockChatDailyScenarios(
      id: 'remove_schedule',
      title: '스케줄 끄기',
      examplePrompt: '사파리 차단 스케줄 끄기',
      action: 'remove_schedule',
    ),
    BlockChatDailyScenarios(
      id: 'night_sns',
      title: '야간 SNS 차단',
      examplePrompt: '밤 11시부터 아침 7시까지 인스타 막아줘',
      action: 'night_schedule',
    ),
    BlockChatDailyScenarios(
      id: 'reels_guard',
      title: '릴스 둠스크롤 멈춤',
      examplePrompt: '인스타 릴스 무한스크롤 멈춰줘',
      action: 'toggle_reels_guard',
    ),
    BlockChatDailyScenarios(
      id: 'safari_pause',
      title: 'Safari 잠깐 풀기',
      examplePrompt: 'Safari 10분만 풀어줘',
      action: 'safari_pause',
      hint: '항상-막기 쉴드가 켜져 있을 때',
    ),
    BlockChatDailyScenarios(
      id: 'block_website',
      title: '웹사이트 차단',
      examplePrompt: 'twitter.com 막아줘',
      action: 'block_website',
      hint: 'Safari Content Blocker (Isle WebView 무관)',
    ),
    // 아래 3개는 복합(compound) 명령 — 하루 안에 두 구간·두 방식이 겹치는
    // 실사용 요청. 단일 절 파서만으로는 절끼리 서로 덮어써서 하나만 남던
    // 문제를 2026-07-11(cage 제보)~07-13에 전용 함수로 고쳤다
    // (`_parseCompoundRationAndBlock`/`_parseCompoundBlockThenRation`).
    BlockChatDailyScenarios(
      id: 'compound_ration_then_block',
      title: '나눠쓰기 안에 완전차단 끼우기',
      examplePrompt: '매일 22:30부터 14:00까지 유튜브를 10분에 5분씩 허가해줘. 그리고 23:00부터 13:00까지는 유튜브를 아예 블락해줘.',
      action: 'explain',
      hint: '나눠쓰기 구간을 앞/뒤로 쪼개고 그 안에 완전차단 구간을 끼워 3구간으로 분리(예전엔 한쪽이 통째로 사라졌음)',
    ),
    BlockChatDailyScenarios(
      id: 'compound_block_then_ration',
      title: '앞 완전차단 + 뒤 나눠쓰기',
      examplePrompt: '11:30까지는 인터넷 브라우저 차단해주고 그 이후로 22:30까지는 20분쓰고 40분 쉬는 방식으로 해줘',
      action: 'explain',
      hint: '하루를 순서대로(안 겹치게) 앞부분 완전차단·뒷부분 나눠쓰기로 분리, 뒷 절은 앞 절의 대상(브라우저)을 이어받음',
    ),
    BlockChatDailyScenarios(
      id: 'compound_unsupported_combo',
      title: '(회귀 확인) 지원 밖 조합',
      examplePrompt: '인스타 릴스 무한스크롤 멈춰줘 그리고 숏츠도 숨겨줘',
      action: 'toggle_reels_guard',
      hint: '나눠쓰기+완전차단 조합 전용 함수 밖의 임의 조합 — 현재는 첫 절만 반영되고 둘째 절(숏츠 숨김)은 조용히 무시됨, 향후 일반 compound 지원 시 이 칩으로 회귀 확인',
    ),
  ];

  static BlockChatDailyScenarios? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  static List<BlockChatDailyScenarios> forAction(String action) =>
      all.where((s) => s.action == action).toList();
}
