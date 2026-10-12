import 'block_chat_models.dart';

/// 진솔한 고민 톤 — 인물이 자신의 상황을 털어놓는 15가지
class BlockChatPersonaScenario {
  const BlockChatPersonaScenario({
    required this.id,
    required this.persona,
    required this.concern,
    required this.empathy,
    required this.matchAny,
    this.matchMin = 2,
    this.exclude = const [],
    required this.subPlans,
  });

  final String id;
  final String persona;
  final String concern;
  final String empathy;
  final List<String> matchAny;
  final int matchMin;
  final List<String> exclude;
  final List<BlockChatPlan> subPlans;

  BlockChatPlan toBundlePlan() => BlockChatPlan(
        action: 'persona_bundle',
        personaId: id,
        reply: empathy,
      );

  int score(String t) {
    for (final ex in exclude) {
      if (t.contains(ex)) return 0;
    }
    var n = 0;
    for (final m in matchAny) {
      if (t.contains(m)) n++;
    }
    return n;
  }

  bool matches(String t) => score(t) >= matchMin;
}

class BlockChatPersonaScenarios {
  BlockChatPersonaScenarios._();

  static const all = <BlockChatPersonaScenario>[
    BlockChatPersonaScenario(
      id: 'minsu_exam_morning',
      persona: '민수 · 대학생',
      concern: '시험 기간인데 알람 끄고 숏츠만 보다가 또 지각했어요. 어떡하죠',
      empathy: '시험 기간 아침은 특히 미끄러워요. 아침 유튜브 습관 패키지로 '
          '숏츠·아침 시간대·일일 한도를 한 번에 맞출게요.',
      matchAny: ['시험', '알람', '숏츠', '지각', '아침', '어떡'],
      subPlans: [
        BlockChatPlan(
          action: 'morning_habit_pack',
          scheduleName: '시험 기간 아침 (AI)',
          endHour: 10,
          dailyMinutes: 20,
          sessionMinutes: 5,
          blockIsleYoutube: true,
          suggestTimelock: true,
        ),
      ],
    ),
    BlockChatPersonaScenario(
      id: 'jieun_night_insta',
      persona: '지은 · 직장인',
      concern: '잠들기 전에 인스타만 스크롤하다 새벽 세 시가 됐어요. 나 진짜 왜 이러는 걸까요',
      empathy: '잠들기 전 릴스·피드가 제일 강해요. 밤 스케줄이랑 스크롤 멈춤을 같이 켤게요.',
      matchAny: ['잠들', '잠들기', '인스타', '새벽', '스크롤', '밤', '왜 이러'],
      matchMin: 2,
      subPlans: [
        BlockChatPlan(
          action: 'night_schedule',
          scheduleName: '잠들기 전 SNS (AI)',
          startHour: 23,
          endHour: 7,
        ),
        const BlockChatPlan(
          action: 'toggle_reels_guard',
          toggleOn: true,
        ),
      ],
    ),
    BlockChatPersonaScenario(
      id: 'hyunwoo_tiktok_commute',
      persona: '현우 · 사회초년생',
      concern: '출근길 지하철에서 틱톡 보다가 내릴 역을 또 놓쳤어요',
      empathy: '짧은 구간이라도 틱톡은 금방 새요. 5분 보고 10분 쉬기로 리듬을 만들게요.',
      matchAny: ['지하철', '틱톡', '놓쳤', '출근', '역'],
      subPlans: [
        BlockChatPlan(
          action: 'app_session_limit',
          appId: 'tiktok',
          dailyMinutes: 25,
          sessionMinutes: 5,
          cooldownMinutes: 10,
          scheduleName: '출근길 틱톡 (AI)',
        ),
      ],
    ),
    BlockChatPersonaScenario(
      id: 'sua_homework_yt',
      persona: '수아 · 고3',
      concern: '숙제 해야 하는데 유튜브 추천만 계속 눌러요. 집중이 안 돼요',
      empathy: '추천 알고리즘이 숙제보다 세요. 하루 한도부터 짧게 잡아볼게요.',
      matchAny: ['숙제', '추천', '유튜브', '집중'],
      subPlans: [
        const BlockChatPlan(
          action: 'youtube_limit',
          dailyMinutes: 25,
          limitPlatform: 'youtube',
        ),
      ],
    ),
    BlockChatPersonaScenario(
      id: 'taeho_safari_rabbit',
      persona: '태호 · 대학원생',
      concern: '뉴스 보려고 사파리 켰는데 엉뚱한 링크 따라가다 두 시간이 없어졌어요',
      empathy: '한 링크가 또 링크를 부르죠. 저녁까지 Safari·웹 탐색을 잠깐 막아볼게요.',
      matchAny: ['사파리', '뉴스', '링크', '시간', '없어졌', '따라가'],
      subPlans: [
        BlockChatPlan(
          action: 'morning_schedule',
          scheduleName: '웹 산만 방지 (AI)',
          endHour: 20,
          blockSafariNote: true,
        ),
      ],
    ),
    BlockChatPersonaScenario(
      id: 'junhyuk_lol_weekend',
      persona: '준혁 · 취준생',
      concern: '주말인데 롤 방송만 보다가 하루가 다 갔어요. 일요일이 무서워요',
      empathy: '주말 방송은 하루 종일 이어져요. 「롤」 키워드를 피드·유튜브에서 숨길게요.',
      matchAny: ['롤', '방송', '주말', '하루', '일요일', '무서워'],
      subPlans: [
        const BlockChatPlan(
          action: 'add_keyword',
          keyword: '롤',
        ),
      ],
    ),
    BlockChatPersonaScenario(
      id: 'yerin_shorts_study',
      persona: '예린 · 수험생',
      concern: '공부하겠다고 앉았는데 숏츠 추천만 계속 나와요',
      empathy: '숏츠 선반부터 없애고, 유튜브는 하루 20분만 쓰게 맞출게요.',
      matchAny: ['공부', '숏츠', '추천', '앉았'],
      subPlans: [
        const BlockChatPlan(
          action: 'toggle_shorts',
          toggleOn: true,
        ),
        const BlockChatPlan(
          action: 'youtube_limit',
          dailyMinutes: 20,
        ),
      ],
    ),
    BlockChatPersonaScenario(
      id: 'soyeon_reels_lunch',
      persona: '소연 · 대학생',
      concern: '릴스 보다 정신 차려보니 점심시간이 끝났어요',
      empathy: '점심 한 타임이 통째로 가요. 릴스 멈춤 + 인스타 하루 25분으로 막아볼게요.',
      matchAny: ['릴스', '점심', '정신', '끝났'],
      subPlans: [
        const BlockChatPlan(
          action: 'toggle_reels_guard',
          toggleOn: true,
        ),
        const BlockChatPlan(
          action: 'platform_limit',
          limitPlatform: 'instagram',
          dailyMinutes: 25,
        ),
      ],
    ),
    BlockChatPersonaScenario(
      id: 'doyoon_twitter_trap',
      persona: '도윤 · 프리랜서',
      concern: '집중해야 할 때 트위터 들어가면 나올 수가 없어요',
      empathy: 'X(트위터)는 한 번 열면 끝이 없죠. Safari에서 막아볼게요.',
      matchAny: ['트위터', '집중', '나올', 'twitter', 'x.com'],
      subPlans: [
        const BlockChatPlan(
          action: 'block_website',
          websiteDomain: 'x.com',
        ),
      ],
    ),
    BlockChatPersonaScenario(
      id: 'minjae_post_exam_binge',
      persona: '민재 · 고2',
      concern: '시험 끝났다고 보상한다고 유튜브만 여섯 시간 봤어요',
      empathy: '보상 심리가 제일 길게 끌고 가요. 하루 60분 한도로 다시 맞춰볼게요.',
      matchAny: ['시험', '보상', '유튜브', '여섯', '6시간', '시간', '봤어'],
      exclude: ['숙제', '기간'],
      subPlans: [
        const BlockChatPlan(
          action: 'youtube_limit',
          dailyMinutes: 60,
        ),
      ],
    ),
    BlockChatPersonaScenario(
      id: 'haeun_mom_night',
      persona: '하은 · 고1',
      concern: '엄마한테 혼났는데 또 밤새 폰 했어요. 정말 그만하고 싶어요',
      empathy: '혼나고 나면 더 미끄러울 때가 있어요. 밤 11시~아침 7시 야간 차단을 켤게요.',
      matchAny: ['엄마', '혼났', '밤새', '그만하고', '폰'],
      subPlans: [
        BlockChatPlan(
          action: 'night_schedule',
          scheduleName: '밤새 폰 그만 (AI)',
          startHour: 23,
          endHour: 7,
        ),
      ],
    ),
    BlockChatPersonaScenario(
      id: 'seojun_morning_clips',
      persona: '서준 · 대학생',
      concern: '아침에 일어나자마자 유튜브 뮤직 클립만 서른 개 넘게 봤어요',
      empathy: '아침 클립은 하나가 또 하나를 부르죠. 아침 습관 패키지로 맞출게요.',
      matchAny: ['아침', '뮤직', '클립', '일어나', '서른'],
      subPlans: [
        BlockChatPlan(
          action: 'morning_habit_pack',
          scheduleName: '아침 뮤직 클립 (AI)',
          endHour: 10,
          dailyMinutes: 20,
          sessionMinutes: 5,
          blockIsleYoutube: true,
          suggestTimelock: true,
        ),
      ],
    ),
    BlockChatPersonaScenario(
      id: 'yuna_date_shorts',
      persona: '유나 · 20대',
      concern: '친구 약속 시간인데 숏츠만 보고 있었어요. 미안해요',
      empathy: '약속 직전 숏츠가 제일 위험해요. 숏츠 숨김 + 하루 15분으로 짧게 맞출게요.',
      matchAny: ['친구', '약속', '숏츠', '미안'],
      subPlans: [
        const BlockChatPlan(
          action: 'toggle_shorts',
          toggleOn: true,
        ),
        const BlockChatPlan(
          action: 'youtube_limit',
          dailyMinutes: 15,
        ),
      ],
    ),
    BlockChatPersonaScenario(
      id: 'jungwoo_brunch_study',
      persona: '정우 · 취준생',
      concern: '공부하겠다고 폰 켰는데 브런치 글 읽다가 세 시간이에요',
      empathy: '긴 글은 읽는 척 하다가 금방 새요. 브런치는 하루 30분만 쓰게 할게요.',
      matchAny: ['브런치', '공부', '세 시간', '3시간', '글'],
      subPlans: [
        const BlockChatPlan(
          action: 'platform_limit',
          limitPlatform: 'brunch',
          dailyMinutes: 30,
        ),
      ],
    ),
    BlockChatPersonaScenario(
      id: 'taeyoung_safari_stuck',
      persona: '태영 · 직장인',
      concern: '차단해 놨는데 급하게 링크 열어야 할 때 사파리가 다 막혀서 답답해요',
      empathy: '막아 둔 건 잘했어요. 급할 땐 10분만 잠깐 풀었다가 자동으로 다시 잠글게요.',
      matchAny: ['차단', '급', '링크', '답답', '사파리', '막혀'],
      matchMin: 2,
      exclude: ['없애', '해제', '끄'],
      subPlans: [
        const BlockChatPlan(
          action: 'safari_pause',
          pauseMinutes: 10,
        ),
      ],
    ),
  ];

  static BlockChatPersonaScenario? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 고민 톤(명령형이 아닌 털어놓기)인지
  static bool looksLikeConcern(String t) {
    if (_hasAny(t, ['막아줘', '차단해', '설정해', '한도로', '블락해', 'block '])) {
      return false;
    }
    return _hasAny(t, [
      '어떡',
      '미안',
      '왜 이러',
      '그만하고',
      '집중이 안',
      '정신 차려',
      '없어졌',
      '답답',
      '무서워',
      '또 ',
      '자꾸',
      '진짜',
      '나 ',
      '했어요',
      '됐어요',
      '갔어요',
      '놓쳤',
      '혼났',
    ]);
  }

  static bool _hasAny(String t, List<String> needles) {
    for (final n in needles) {
      if (t.contains(n)) return true;
    }
    return false;
  }
}
