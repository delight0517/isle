import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/ai/block_chat/block_chat_models.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/ai/block_chat/block_chat_preview.dart';

void main() {
  test(
      'colon-range extend command does not corrupt schedule name '
      '(실사용 치명적 버그, cage에서 07-08 진단·수정 후 이식)', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '현재 있는 유튜브 뮤직 블락을 23:00 - 11:00 으로 바꿔줘',
    );
    expect(usedAi, false);
    expect(plan.action, isNot('rename_schedule'));
    expect(plan.scheduleNewName, isNull);
  });

  test(
      'colon-range extend command picks the second (end) time, not the first '
      '(실사용 치명적 버그, cage에서 07-08 진단·수정 후 이식)', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '유튜브 뮤직 블락 23:00부터 11:00까지 늘려줘',
    );
    expect(usedAi, false);
    if (plan.action == 'explain') {
      expect(plan.reply, contains('11시'));
      expect(plan.reply, isNot(contains('23시까지')));
    } else {
      expect(plan.action, 'update_schedule_time');
      expect(plan.endHour, 11);
    }
  });

  test('isle youtube morning schedule not keyword', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '매일 아침 10시30분까지는 isle 유튜브 차단해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'morning_schedule');
    expect(plan.blockIsleYoutube, true);
    expect(plan.endHour, 10);
    expect(plan.endMinute, 30);
    expect(plan.reply, isNot(contains('진짜 유튜브 앱')));
  });

  test('plain youtube morning schedule warns it only blocks isle in-app view', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '매일 아침 11시까지 유튜브 차단해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'morning_schedule');
    expect(plan.blockIsleYoutube, true);
    expect(plan.endHour, 11);
    expect(plan.endMinute, 0);
    // "isle"·"브라우저"를 언급 안 했으니 실제 유튜브 앱은 안 막힌다는
    // 안내가 붙어야 한다 (07-07 실사용 제보 — Cage에서 먼저 진단·수정된
    // 버그를 같은 코드가 복붙된 여기에도 포팅).
    expect(plan.reply, contains('진짜 유튜브 앱'));
    expect(plan.reply, contains('iPhone 차단 기능'));
  });

  test('morning youtube block mentioning browser also blocks Safari', () async {
    final (plan, _) = await BlockChatParser.parse(
      '아침에는 유튜브 브라우저 등에 들어가지 못하도록 막아줘',
    );
    expect(plan.action, 'morning_schedule');
    expect(plan.blockIsleYoutube, true);
    expect(plan.blockSafariNote, true);
    expect(plan.reply, isNot(contains('별개')));
  });

  test('safari schedule still works', () async {
    final (plan, _) = await BlockChatParser.parse('매일 9시까지 Safari 막아줘');
    expect(plan.action, 'morning_schedule');
    expect(plan.blockSafariNote, true);
    expect(plan.endHour, 9);
  });

  test('starcraft keyword still works', () async {
    final (plan, _) = await BlockChatParser.parse('스타크래프트 블락해줘');
    expect(plan.action, 'add_keyword');
    expect(plan.keyword, '스타크래프트');
  });

  test('remove url local parse', () async {
    final (plan, _) = await BlockChatParser.parse(
      'https://example.com/foo 블락 없애줘',
    );
    expect(plan.action, 'remove_url');
    expect(plan.removeUrl, contains('example.com'));
  });

  test('fuzzy remove schedule without exact name', () async {
    final (plan, _) = await BlockChatParser.parse('사파리 차단 스케줄 끄기');
    expect(plan.action, 'remove_schedule');
    expect(plan.scheduleQuery, 'safari');
  });

  test('morning youtube relax not habit pack', () async {
    final (plan, _) = await BlockChatParser.parse('아침에 유튜브 이제 보게 해줘');
    expect(plan.action, 'relax_block');
    expect(plan.relaxTarget, 'youtube');
  });

  test('youtube morning schedule typo 차당 becomes schedule', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '매일 아침 7시까지 유튜브 차당해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'morning_schedule');
    expect(plan.blockIsleYoutube, true);
    expect(plan.endHour, 7);
  });

  test('morning habit pack preview shows visible actions', () {
    final bullets = BlockChatPreview.bullets(
      const BlockChatPlan(
        action: 'morning_habit_pack',
        endHour: 7,
        endMinute: 0,
        dailyMinutes: 20,
        sessionMinutes: 5,
      ),
    );

    expect(bullets, contains('매일 00:00–07:00 아침 차단'));
    expect(bullets, contains('Isle 유튜브 하루 20분'));
    expect(bullets, contains('YouTube 앱은 5분 단위로 끊기'));
    expect(bullets, contains('적용 후 카드에서 타임락 설정으로 이동 가능'));
  });

  test('kakaotalk night three minute refill request stays on kakao', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '카카오톡은 밤에는 3분만 볼수 있게 햐줘 11시부터!',
    );

    expect(usedAi, false);
    // usage_budget(UsageBudgetStore)은 Isle 인앱 웹뷰만 셀 수 있어 카카오톡 같은
    // 완전 외부 앱엔 실제 효과가 없다(2026-07-06 실사용 버그) — night_schedule
    // 리필 모드라야 진짜 네이티브 Screen Time 경로로 걸린다.
    expect(plan.action, 'night_schedule');
    expect(plan.limitPlatform, 'app');
    expect(plan.appId, 'kakao');
    expect(plan.sessionMinutes, 3);
    expect(plan.windowMinutes, 3);
    expect(plan.cooldownMinutes, 3);
    expect(plan.startHour, 23);
    expect(plan.endHour, 7);
  });

  test('kakaotalk refill follow-up keeps previous target and night window',
      () async {
    const previous = BlockChatPlan(
      action: 'night_schedule',
      startHour: 23,
      startMinute: 0,
      endHour: 7,
      endMinute: 0,
      dailyMinutes: 3,
      limitPlatform: 'kakaotalk',
    );

    final (plan, usedAi) = await BlockChatParser.parseWithContext(
      '차단말고 !! 3분 리필 방식',
      previousPlan: previous,
    );

    expect(usedAi, false);
    expect(plan.action, 'usage_budget');
    expect(plan.limitPlatform, 'app');
    expect(plan.appId, 'kakao');
    expect(plan.dailyMinutes, 3);
    expect(plan.sessionMinutes, 3);
    expect(plan.windowMinutes, 3);
    expect(plan.cooldownMinutes, 3);
    expect(plan.startHour, 23);
    expect(plan.endHour, 7);
  });

  test('youtube schedule conversion phrase becomes usage budget', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '유튜브 스케줄을 변환해줘! 이제는 시간 제한을 하루 1시간!으로 바꾸고 싶고, 20분 마다 스탑하게 만들고 싶어!',
    );
    expect(usedAi, false);
    expect(plan.action, 'youtube_budget');
    expect(plan.limitPlatform, 'youtube');
    expect(plan.dailyMinutes, 60);
    expect(plan.sessionMinutes, 20);
    expect(plan.windowMinutes, 60);
  });

  test('night schedule with one start time uses the spoken hour', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '밤 11시부터는 유튜브 안되게 막아줘!',
    );
    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.startHour, 23);
    expect(plan.startMinute, 0);
    expect(plan.endHour, 7);
  });

  test('short follow-up corrects previous night schedule without AI', () async {
    const previous = BlockChatPlan(
      action: 'night_schedule',
      scheduleName: 'SNS 야간 차단 (AI)',
      startHour: 21,
      startMinute: 0,
      endHour: 7,
      endMinute: 0,
      reply: '매일 21시~7시 야간 스케줄',
    );

    final (plan, usedAi) = await BlockChatParser.parseWithContext(
      '23시!!',
      previousPlan: previous,
    );

    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.startHour, 23);
    expect(plan.endHour, 7);
    expect(plan.reply, contains('23시~7시'));
  });

  test('follow-up with overnight range corrects both ends', () async {
    const previous = BlockChatPlan(
      action: 'night_schedule',
      scheduleName: 'SNS 야간 차단 (AI)',
      startHour: 21,
      startMinute: 0,
      endHour: 7,
      endMinute: 0,
      reply: '매일 21시~7시 야간 스케줄',
    );

    final (plan, usedAi) = await BlockChatParser.parseWithContext(
      '23시부터 다음날 7시까지!',
      previousPlan: previous,
    );

    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.startHour, 23);
    expect(plan.endHour, 7);
  });

  test('night schedule for youtube sets limitPlatform instead of defaulting'
      ' to Instagram', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '밤 11시부터 다음날 11시까지 유튜브 차단해줘!!',
    );
    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.limitPlatform, 'youtube');
    expect(plan.appId, null);
    expect(plan.reply, contains('유튜브'));
    expect(plan.reply, isNot(contains('SNS 앱')));
  });

  test('follow-up clarifying the app corrects night schedule target away'
      ' from the Instagram default', () async {
    const previous = BlockChatPlan(
      action: 'night_schedule',
      scheduleName: 'SNS 야간 차단 (AI)',
      startHour: 23,
      startMinute: 0,
      endHour: 11,
      endMinute: 0,
      reply: '매일 23시~11시 야간 스케줄 — iPhone SNS 앱 차단 (Screen Time 선택 필요)',
    );

    final (plan, usedAi) = await BlockChatParser.parseWithContext(
      '아니아니 이 sns 앱 자체의 유튜브 말이야',
      previousPlan: previous,
    );

    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.limitPlatform, 'youtube');
    expect(plan.appId, null);
    expect(plan.startHour, 23);
    expect(plan.endHour, 11);
    expect(plan.reply, contains('유튜브'));
  });

  test('follow-up overwrite question explains merge reset options', () async {
    const previous = BlockChatPlan(
      action: 'morning_schedule',
      scheduleName: '아침 Isle 유튜브',
      endHour: 7,
      endMinute: 0,
      blockIsleYoutube: true,
      reply: '매일 0시~7시 Isle 인앱 유튜브를 막는 스케줄을 만듭니다.',
    );

    final (plan, usedAi) = await BlockChatParser.parseWithContext(
      '덮어쓰기야??',
      previousPlan: previous,
    );

    expect(usedAi, false);
    expect(plan.action, 'explain');
    expect(plan.reply, contains('삭제 덮어쓰기'));
    expect(plan.reply, contains('기존 유지하고 새로 만들기'));
    expect(plan.reply, contains('기존 끄고 새로 리셋'));
    expect(plan.reply, contains('매일 0시~7시'));
  });

  group('usage budget schedule conversion variants', () {
    final cases = [
      (
        text: '유튜브 차단 스케줄 이제 하루 1시간에 20분씩 끊는 모드로 바꿔줘',
        action: 'youtube_budget',
        platform: 'youtube',
        appId: null,
        daily: 60,
        session: 20,
      ),
      (
        text: '쇼츠 제한을 총 1시간, 한 번에 20분 컷으로 전환해줘',
        action: 'youtube_budget',
        platform: 'youtube',
        appId: null,
        daily: 60,
        session: 20,
      ),
      (
        text: '인스타 차단 스케줄을 하루 45분, 15분마다 멈추게 바꿔줘',
        action: 'usage_budget',
        platform: 'instagram',
        appId: null,
        daily: 45,
        session: 15,
      ),
      (
        text: '릴스 이제 일일 40분 총량에 10분씩 스탑하는 세팅으로',
        action: 'usage_budget',
        platform: 'instagram',
        appId: null,
        daily: 40,
        session: 10,
      ),
      (
        text: '틱톡 스케줄 변환. 하루 40분, 10분마다 정지',
        action: 'usage_budget',
        platform: 'app',
        appId: 'tiktok',
        daily: 40,
        session: 10,
      ),
      (
        text: '카톡은 앞으로 하루 30분만, 5분씩 나눠 쓰게 바꿔줘',
        action: 'usage_budget',
        platform: 'app',
        appId: 'kakao',
        daily: 30,
        session: 5,
      ),
      (
        text: '사파리도 하루 50분 총량, 10분마다 컷으로 설정해줘',
        action: 'usage_budget',
        platform: 'app',
        appId: 'safari',
        daily: 50,
        session: 10,
      ),
      (
        text: '넷플릭스 하루 1시간 30분, 30분씩 보는 모드로 변경',
        action: 'usage_budget',
        platform: 'app',
        appId: 'netflix',
        daily: 90,
        session: 30,
      ),
      (
        text: '디스코드는 일일 45분, 한 타임 15분으로 쪼개줘',
        action: 'usage_budget',
        platform: 'app',
        appId: 'discord',
        daily: 45,
        session: 15,
      ),
      (
        text: '게임 앱들 하루 2시간, 30분마다 멈춰',
        action: 'usage_budget',
        platform: 'app',
        appId: 'games',
        daily: 120,
        session: 30,
      ),
    ];

    for (final c in cases) {
      test(c.text, () async {
        final (plan, usedAi) = await BlockChatParser.parse(c.text);
        expect(usedAi, false);
        expect(plan.action, c.action);
        expect(plan.limitPlatform, c.platform);
        expect(plan.appId, c.appId);
        expect(plan.dailyMinutes, c.daily);
        expect(plan.sessionMinutes, c.session);
      });
    }
  });

  group('ambiguous requests suggest presets before AI', () {
    final cases = [
      (
        text: '넷플릭스 막아줘',
        containsText: '넷플릭스 관리는 앱에서 가능해요',
      ),
      (
        text: '도박 사이트 다 막아줘',
        containsText: '사이트 차단은 앱에서 가능해요',
      ),
      (
        text: 'SNS 좀 줄이고 싶어',
        containsText: 'SNS 줄이기는 앱에서 가능해요',
      ),
    ];

    for (final c in cases) {
      test(c.text, () async {
        final (plan, usedAi) = await BlockChatParser.parse(c.text);
        expect(usedAi, false);
        expect(plan.action, 'explain');
        expect(plan.reply, contains(c.containsText));
        expect(plan.reply, contains('예:'));
      });
    }
  });

  group('new Korean user persona sentences — usage budget', () {
    final cases = [
      (
        text: '유튜브 너무 많이 봐요. 하루 1시간만, 20분 보고 1시간 쉬게 해주세요.',
        action: 'youtube_budget',
        platform: 'youtube',
        appId: null,
        daily: 60,
        session: 20,
        refill: 60,
      ),
      (
        text: '쇼츠는 스무 분씩 하루 한 시간만 보게 해줘요.',
        action: 'youtube_budget',
        platform: 'youtube',
        appId: null,
        daily: 60,
        session: 20,
        refill: 60,
      ),
      (
        text: '유튜브 20분씩 네 번만 보고 싶어요. 그 이상은 막아줘요.',
        action: 'youtube_budget',
        platform: 'youtube',
        appId: null,
        daily: 80,
        session: 20,
        refill: 80,
      ),
      (
        text: '인스타 릴스 하루 45분, 15분씩 보고 30분 쉬게 해주세요.',
        action: 'usage_budget',
        platform: 'instagram',
        appId: null,
        daily: 45,
        session: 15,
        refill: 30,
      ),
      (
        text: '릴스 10분씩 세 번만 열어줘요.',
        action: 'usage_budget',
        platform: 'instagram',
        appId: null,
        daily: 30,
        session: 10,
        refill: 30,
      ),
      (
        text: '브런치는 하루 30분인데 10분 보면 20분 쉬게 해줘.',
        action: 'usage_budget',
        platform: 'brunch',
        appId: null,
        daily: 30,
        session: 10,
        refill: 20,
      ),
      (
        text: '틱톡은 5분씩 네 번만, 볼 때마다 30분 쉬기.',
        action: 'usage_budget',
        platform: 'app',
        appId: 'tiktok',
        daily: 20,
        session: 5,
        refill: 30,
      ),
      (
        text: '카톡은 하루 40분, 10분 쓰면 1시간 잠가줘.',
        action: 'usage_budget',
        platform: 'app',
        appId: 'kakao',
        daily: 40,
        session: 10,
        refill: 60,
      ),
      (
        text: '유튜브는 총 45분만, 한 번에 15분 보고 30분 지나면 다시 열리게.',
        action: 'youtube_budget',
        platform: 'youtube',
        appId: null,
        daily: 45,
        session: 15,
        refill: 30,
      ),
      (
        text: '인스타 하루 한 시간까지 괜찮고, 열다섯 분씩 끊어서 보게 해줘.',
        action: 'usage_budget',
        platform: 'instagram',
        appId: null,
        daily: 60,
        session: 15,
        refill: 60,
      ),
    ];

    for (final c in cases) {
      test(c.text, () async {
        final (plan, usedAi) = await BlockChatParser.parse(c.text);
        expect(usedAi, false);
        expect(plan.action, c.action);
        expect(plan.limitPlatform, c.platform);
        expect(plan.appId, c.appId);
        expect(plan.dailyMinutes, c.daily);
        expect(plan.sessionMinutes, c.session);
        expect(plan.windowMinutes, c.refill);
      });
    }
  });

  group('fresh install vague Korean requests — usage budget', () {
    final cases = [
      (
        text: '처음 써보는데 유튜브를 하루 30분만, 10분씩 끊어서 보게 해줘.',
        action: 'youtube_budget',
        platform: 'youtube',
        appId: null,
        daily: 30,
        session: 10,
        refill: 30,
      ),
      (
        text: '인스타 켜면 5분만 보게 하고 25분은 쉬게 해줘. 하루는 20분이면 돼.',
        action: 'usage_budget',
        platform: 'instagram',
        appId: null,
        daily: 20,
        session: 5,
        refill: 25,
      ),
      (
        text: '틱톡 자꾸 열어서요. 7분 보고 40분 잠기게, 하루 21분만요.',
        action: 'usage_budget',
        platform: 'app',
        appId: 'tiktok',
        daily: 21,
        session: 7,
        refill: 40,
      ),
      (
        text: '카톡도 줄이고 싶어요. 한 번 열면 10분, 하루 40분까지만.',
        action: 'usage_budget',
        platform: 'app',
        appId: 'kakao',
        daily: 40,
        session: 10,
        refill: 40,
      ),
      (
        text: '브런치 글은 15분씩 두 번만 읽게 해줘요.',
        action: 'usage_budget',
        platform: 'brunch',
        appId: null,
        daily: 30,
        session: 15,
        refill: 30,
      ),
      (
        text: '쇼츠 열면 12분 보고 48분 쉬게 해줘. 하루는 36분만.',
        action: 'youtube_budget',
        platform: 'youtube',
        appId: null,
        daily: 36,
        session: 12,
        refill: 48,
      ),
      (
        text: '유튜브는 하루 50분, 한 번 보면 10분만 보고 나머지는 잠깐 막아줘.',
        action: 'youtube_budget',
        platform: 'youtube',
        appId: null,
        daily: 50,
        session: 10,
        refill: 50,
      ),
      (
        text: '릴스는 열다섯 분씩 네 번까지만 허용해줘.',
        action: 'usage_budget',
        platform: 'instagram',
        appId: null,
        daily: 60,
        session: 15,
        refill: 60,
      ),
      (
        text: '인스타를 10분 보고 나면 1시간 닫아줘. 하루 총 30분.',
        action: 'usage_budget',
        platform: 'instagram',
        appId: null,
        daily: 30,
        session: 10,
        refill: 60,
      ),
      (
        text: '유튜브랑 쇼츠 하루 1시간, 20분 보고 나면 다시 한 시간 뒤에 열리게.',
        action: 'youtube_budget',
        platform: 'youtube',
        appId: null,
        daily: 60,
        session: 20,
        refill: 60,
      ),
    ];

    for (final c in cases) {
      test(c.text, () async {
        final (plan, usedAi) = await BlockChatParser.parse(c.text);
        expect(usedAi, false);
        expect(plan.action, c.action);
        expect(plan.limitPlatform, c.platform);
        expect(plan.appId, c.appId);
        expect(plan.dailyMinutes, c.daily);
        expect(plan.sessionMinutes, c.session);
        expect(plan.windowMinutes, c.refill);
      });
    }
  });

  test('허락해줘 phrasing is recognized as usage budget (not dropped)', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '카카오톡 차단 10분에 3분만 허락해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'usage_budget');
    expect(plan.appId, 'kakao');
    expect(plan.sessionMinutes, 3);
  });

  test('overnight kakao interval budget honors the spoken next-day end time',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '카카오톡을 밤 11시부터 다음날 12시까지는 10분에 3분씩만 허락해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.appId, 'kakao');
    expect(plan.startHour, 23);
    expect(plan.endHour, 12);
    expect(plan.sessionMinutes, 3);
  });

  test(
      'pure HHMM night range ("2300부터 0700까지") honors the spoken window and '
      'does not fabricate a daily cap (실사용 버그 2026-07-06, cage에서 이식)',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '카카오톡은 앞으로 2300부터 0700까지 10분에 3분씩 허락해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.appId, 'kakao');
    expect(plan.sessionMinutes, 3);
    expect(plan.windowMinutes, 10);
    expect(plan.startHour, 23);
    expect(plan.startMinute, 0);
    expect(plan.endHour, 7);
    expect(plan.endMinute, 0);
  });

  test('status query for kakao settings does not mutate anything', () async {
    final (plan, usedAi) = await BlockChatParser.parse('카카오톡 차단 설정 알려줘');
    expect(usedAi, false);
    expect(plan.action, 'explain_status');
    expect(plan.appId, 'kakao');
  });

  test('status query for youtube music schedule targets youtube_music',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse('유튜브 뮤직 스케줄 알려줘');
    expect(usedAi, false);
    expect(plan.action, 'explain_status');
    expect(plan.limitPlatform, 'youtube_music');
  });

  test('status query "what is blocking youtube music" targets youtube_music',
      () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('유튜브 뮤직 뭐가 차단하고 있는거야?');
    expect(usedAi, false);
    expect(plan.action, 'explain_status');
    expect(plan.limitPlatform, 'youtube_music');
  });

  test(
      '"왜 지금 유튜브 뮤직이 차단되어 있어??" is recognized as a status query, '
      'not a new youtube_limit mutation (실사용 버그 2026-07-07)', () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('왜 지금 유튜브 뮤직이 차단되어 있어??');
    expect(usedAi, false);
    expect(plan.action, 'explain_status');
    expect(plan.limitPlatform, 'youtube_music');
  });

  test('"지금 유튜브 뮤직이 차단되어 있는 이유" is recognized as a status query',
      () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('지금 유튜브 뮤직이 차단되어 있는 이유');
    expect(usedAi, false);
    expect(plan.action, 'explain_status');
    expect(plan.limitPlatform, 'youtube_music');
  });

  test('"왜 유튜브 뮤직이 차단되어있는거야?" is recognized as a status query',
      () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('왜 유튜브 뮤직이 차단되어있는거야?');
    expect(usedAi, false);
    expect(plan.action, 'explain_status');
    expect(plan.limitPlatform, 'youtube_music');
  });

  test('"모든 음란물을 차단해줘" applies the combined adult premade pack',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse('모든 음란물을 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'apply_premade_pack');
    expect(plan.presetId, 'premade_adult_combined');
    expect(plan.suggestTimelock, true);
  });

  test('"성인 사이트 전부 막아줘" also applies the combined adult premade pack',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse('성인 사이트 전부 막아줘');
    expect(usedAi, false);
    expect(plan.action, 'apply_premade_pack');
    expect(plan.presetId, 'premade_adult_combined');
  });

  test('a single adult domain still goes through block_website, not the pack',
      () async {
    final (plan, _) = await BlockChatParser.parse('pornhub.com 막아줘');
    expect(plan.action, isNot('apply_premade_pack'));
  });

  test('"모든 게임 채널 차단해줘" routes to block_genre with topicLabel 게임',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse('모든 게임 채널 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'block_genre');
    expect(plan.topicLabel, '게임');
  });

  test('a single named channel still goes through block_channel, not genre',
      () async {
    final (plan, _) = await BlockChatParser.parse('침착맨 채널 차단해줘');
    expect(plan.action, isNot('block_genre'));
  });

  test('"매일 아침 주식 관련 앱들을 차단해주라" asks which app instead of guessing',
      () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('매일 아침 주식 관련 앱들을 차단해주라');
    expect(usedAi, false);
    expect(plan.action, 'finance_guidance');
  });

  test('"카카오톡 밤에 통째로 블락 말고, 10분마다 3분만 보기로 변형해줘" '
      'assigns session/window correctly (not swapped)', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '카카오톡 밤에 통째로 블락 말고, 10분마다 3분만 보기로 변형해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'convert_schedule_mode');
    expect(plan.appId, 'kakao');
    expect(plan.sessionMinutes, 3);
    expect(plan.windowMinutes, 10);
  });

  test('"유튜브 뮤직 블락 관련 스케줄 전부 초토화, 리셋 이후에 다시 아래 스케줄으로 '
      '덮어쓰기 해줘: 매일 밤 10시부터 아침 7시까지 차단" builds a 2-step reset_reapply plan',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '유튜브 뮤직 블락 관련 스케줄 전부 초토화, 리셋 이후에 다시 아래 스케줄으로 '
      '덮어쓰기 해줘: 매일 밤 10시부터 아침 7시까지 차단',
    );
    expect(usedAi, false);
    expect(plan.action, 'reset_reapply');
    expect(plan.subPlans, isNotNull);
    expect(plan.subPlans!.length, 2);
    expect(plan.subPlans!.first.action, 'remove_schedule');
    expect(plan.subPlans!.first.scheduleQuery, contains('유튜브 뮤직'));
  });

  // 하드코딩된 TLD 목록(com/net/org/io/kr)만 인식하던 예전 정규식은 .live 같은
  // 흔한 TLD를 놓쳐서 도메인이 아예 인식 안 되고 add_keyword로 잘못 새던
  // 실사용 버그(2026-07-10, Cage에서 먼저 발견 — "mingky05.live가 성인 사이트
  // 목록에 있는데 왜 차단이 안 되지").
  test('"mingky05.live 차단해줘" (uncommon .live TLD, bare domain) is '
      'recognized as a domain, not misfiled as a keyword', () async {
    final (plan, usedAi) = await BlockChatParser.parse('mingky05.live 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'block_website');
    expect(plan.websiteDomain, 'mingky05.live');
  });

  test(
      '"오늘 저녁 00:00까지 어떤 차단이 활성화돼?" is a status question, '
      'not misfiled as a new night_schedule (2026-07-10)', () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('오늘 저녁 00:00까지 어떤 차단이 활성화돼?');
    expect(usedAi, false);
    expect(plan.action, 'explain_status');
  });

  test(
      '"무슨 차단이 있어?" is a status question, not misfiled as '
      'add_keyword with keyword "무슨" (2026-07-11)', () async {
    final (plan, usedAi) = await BlockChatParser.parse('무슨 차단이 있어?');
    expect(usedAi, false);
    expect(plan.action, 'explain_status');
  });

  // cage 2026-07-11 이식 — "23:00-10:00, AI 코딩툴/브라우저/유튜브 차단해줘"가
  // (1) 시작시각 유실 (2) 유튜브 하나만 타깃팅 (3) 유튜브 뮤직 배제가 설계가
  // 아니라 우연이던 3중 버그. _parseMultiCategoryNightBlock으로 수정.
  test('"매일 아침 23:00 - 10:00까지, ai 코딩 제작툴, 브라우저, 유튜브 차단해줘" '
      'keeps the explicit start time and blocks all 3 categories '
      '(cage 2026-07-11 이식)', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '매일 아침 23:00 - 10:00까지, ai 코딩 제작툴, 브라우저, 유튜브 차단해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.startHour, 23);
    expect(plan.startMinute, 0);
    expect(plan.endHour, 10);
    expect(plan.endMinute, 0);
    expect(plan.extraTargetIds, contains('isle_youtube'));
    expect(plan.extraTargetIds, isNot(contains('ios_youtube_music')));
    expect(plan.blockSafariNote, true);
    expect(plan.unmappedCategoryLabels, contains('AI 코딩 툴'));
  });

  // 2026-07-12: 모아는 인앱(isle_*) 전용 제품 스코프로 확정 — 카카오톡·틱톡·
  // 유튜브뮤직은 모아 안에 대응하는 인앱 화면이 없어(외부 iOS 앱뿐) "완전
  // 차단" 대상에서 제외된다. 아래 두 테스트는 예전엔 ios_kakao/ios_tiktok로
  // Screen Time 외부 앱을 잡던 걸 검증했지만, 이제 그 경로 자체가 없다 —
  // 남은 카탈로그 타깃(Instagram/YouTube)만 단일 타깃으로 처리되는지 검증.
  test('"매일 22:30 - 09:00까지 카카오톡, 인스타 차단해줘" — 카카오톡은 모아 '
      '스코프 밖이라 조용히 빠지고 Instagram만 단일 타깃으로 처리됨', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '매일 22:30 - 09:00까지 카카오톡, 인스타 차단해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.startHour, 22);
    expect(plan.startMinute, 30);
    expect(plan.endHour, 9);
    expect(plan.limitPlatform, 'instagram');
    expect(plan.extraTargetIds, isNull);
  });

  test('"카카오톡 차단해줘" 단독 — 모아 스코프 밖이라 완전 차단 대신 '
      '스크린 타임 안내로 답함', () async {
    final (plan, usedAi) = await BlockChatParser.parse('밤 11시부터 새벽 6시까지 카카오톡 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'explain');
    expect(plan.reply, contains('스크린 타임'));
  });

  test('"매일 00:30-08:00까지 브라우저랑 코딩 툴 차단해줘" (browser + unmapped, '
      'no catalog app target at all)', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '매일 00:30-08:00까지 브라우저랑 코딩 툴 차단해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.startHour, 0);
    expect(plan.startMinute, 30);
    expect(plan.endHour, 8);
    expect(plan.blockSafariNote, true);
    expect(plan.unmappedCategoryLabels, contains('AI 코딩 툴'));
    expect(plan.extraTargetIds, isEmpty);
  });

  test('"매일 21:00-07:30까지 유튜브, 카카오톡, 크롬 다 막아줘" — 카카오톡은 '
      '모아 스코프 밖이라 빠지고 유튜브+브라우저(크롬 별칭)만 반영됨', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '매일 21:00-07:30까지 유튜브, 카카오톡, 크롬 다 막아줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.startHour, 21);
    expect(plan.endHour, 7);
    expect(plan.endMinute, 30);
    expect(plan.extraTargetIds, contains('isle_youtube'));
    expect(plan.extraTargetIds, isNot(contains('ios_kakao')));
    expect(plan.blockSafariNote, true);
  });

  test('"매일 오후 11시부터 오전 9시까지 인스타, 코딩 제작툴 차단" (Korean '
      'AM/PM start phrasing + unmapped category)', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '매일 오후 11시부터 오전 9시까지 인스타, 코딩 제작툴 차단',
    );
    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.startHour, 23);
    expect(plan.endHour, 9);
    expect(plan.extraTargetIds, contains('isle_instagram'));
    expect(plan.unmappedCategoryLabels, contains('AI 코딩 툴'));
  });

  test('"11:30까지는 인터넷 브라우저 차단해주고 그 이후로 22:30까지는 20분쓰고 40분 '
      '쉬는 방식으로 해줘" builds a block-then-ration compound plan (2026-07-13: '
      'previously fell through every parser to the generic AI-less explain '
      'fallback — colon single-sided "까지" end time was unsupported in '
      '_parseNightEndTime, "쓰고/쉬게" wasn\'t in the ration allow-cue list, and '
      'no compound parser handled two sequential non-overlapping clauses)',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '11:30까지는 인터넷 브라우저 차단해주고 그 이후로 22:30까지는 20분쓰고 40분 '
      '쉬는 방식으로 해줘',
    );
    expect(usedAi, false);
    expect(plan.pendingConfirmAction, 'reset_reapply');
    expect(plan.subPlans, isNotNull);
    expect(plan.subPlans!.length, 2);

    final block = plan.subPlans!.first;
    expect(block.action, 'night_schedule');
    expect(block.appId, 'safari');
    expect(block.startHour, 0);
    expect(block.startMinute, 0);
    expect(block.endHour, 11);
    expect(block.endMinute, 30);

    final ration = plan.subPlans!.last;
    expect(ration.action, 'usage_budget');
    expect(ration.appId, 'safari');
    expect(ration.startHour, 11);
    expect(ration.startMinute, 30);
    expect(ration.endHour, 22);
    expect(ration.endMinute, 30);
    expect(ration.sessionMinutes, 20);
    expect(ration.cooldownMinutes, 40);
  });

  test('colon single end time "11:30까지" is recognized standalone for a '
      'full-day-morning block (previously only "시" format and 4-digit HHMM '
      'were supported, not colon)', () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('11:30까지는 인터넷 브라우저 차단해줘');
    expect(usedAi, false);
    expect(plan.action, isNot('explain'));
  });

  test('"N분 쓰고 M분 쉬게 해줘" ration phrasing is recognized within an explicit '
      'time window (previously "쉬"/"쉬게" was missing from the allow-cue list '
      'in _parseNightRefillUsageBudget, so this fell through to explain even '
      'with a valid target and time window)', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '브라우저 11:30부터 22:30까지 20분 쓰고 40분 쉬게 해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'usage_budget');
    expect(plan.startHour, 11);
    expect(plan.startMinute, 30);
    expect(plan.endHour, 22);
    expect(plan.endMinute, 30);
    expect(plan.sessionMinutes, 20);
    expect(plan.cooldownMinutes, 40);
  });

  test('"아침에는 인터넷 브라우저 못보도록 차단해줘" (no explicit hour, browser-only, '
      'no "유튜브"/"사파리" literal) is recognized as a morning_schedule with a '
      'default 09:00 end time (2026-07-13: previously the bare-Safari-morning '
      'branch only matched literal "사파리"/"safari" and required an explicit '
      'hour, so this fell through to explain)', () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('아침에는 인터넷 브라우저 못보도록 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'morning_schedule');
    expect(plan.blockSafariNote, true);
    expect(plan.blockIsleYoutube, false);
    expect(plan.endHour, 9);
    expect(plan.endMinute, 0);
    expect(plan.reply, contains('오전 9시까지로 잡았어요'));
  });

  test('explicit hour still overrides the 09:00 default for browser-only '
      'morning block', () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('아침에 인터넷 브라우저 11시까지 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'morning_schedule');
    expect(plan.endHour, 11);
    expect(plan.reply, isNot(contains('잡았어요')));
  });

  test('"인터넷 브라우저 4시간 동안 차단해줘" (duration without literal "지금부터") '
      'is a quick_block_now, not misread as "매일 0~4시" absolute-hour '
      'schedule (2026-07-13: after broadening the bare-Safari-morning branch '
      'to accept "브라우저"/"인터넷", it started intercepting duration phrasing '
      'too — "4시간" was misparsed as "4시" because _parseQuickBlockNow only '
      'triggered on literal "지금부터", which this sentence never says)',
      () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('인터넷 브라우저 4시간 동안 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'quick_block_now');
    expect(plan.windowMinutes, 240);
    expect(plan.appId, 'safari');
  });

  test('"인터넷은 아침 09:30까지 차단해줘" still builds a proper morning_schedule '
      'with the explicit colon end time (regression check alongside the '
      'quick_block_now duration fix above)', () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('인터넷은 아침 09:30까지 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'morning_schedule');
    expect(plan.endHour, 9);
    expect(plan.endMinute, 30);
    expect(plan.blockSafariNote, true);
  });

  // 2026-07-12: 사용자 관점 유사 멘트 테스트 중 발견한 실사용 버그 3건.
  test('"인스타 릴스 그만 보고싶어" toggles reels off, not misfiled as '
      'relax_block (existence-gate에 "그만" 빠져있던 버그)', () async {
    final (plan, usedAi) = await BlockChatParser.parse('인스타 릴스 그만 보고싶어');
    expect(usedAi, false);
    expect(plan.action, 'toggle_reels');
    expect(plan.toggleOn, true);
  });

  test('"유튜브 쇼츠 없애줘" toggles shorts off, not misfiled as '
      'remove_schedule ("쇼츠" 표기가 "숏츠"만 걸려있던 gate 버그)', () async {
    final (plan, usedAi) = await BlockChatParser.parse('유튜브 쇼츠 없애줘');
    expect(usedAi, false);
    expect(plan.action, 'toggle_shorts');
    expect(plan.toggleOn, true);
  });

  test('"인터넷은 오후 1시까지 막아줘" (browser-only isle target) does not '
      'get a false "Screen Time으로 선택하세요" permission-gap warning', () async {
    final (plan, usedAi) = await BlockChatParser.parse('인터넷은 오후 1시까지 막아줘');
    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.appId, 'safari');
  });

  test('"아침에는 유튜브 못키게 막아줘!! 8시반까지" keeps the half-hour (30분), not '
      'just the hour (2026-07-13: "N시반" clock phrasing was unsupported by '
      'every time-extraction regex, so "8시반까지" silently dropped the 30 '
      'minutes and became "8시까지")', () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('아침에는 유튜브 못키게 막아줘!! 8시반까지');
    expect(usedAi, false);
    expect(plan.action, 'morning_schedule');
    expect(plan.blockIsleYoutube, true);
    expect(plan.endHour, 8);
    expect(plan.endMinute, 30);
  });

  test('"밤 11시반부터 유튜브 차단해줘" — half-hour clock also works for the start '
      'time in raw-text-based parsers like _parseNightSchedule (regression '
      'check: the half-hour fix must normalize both `t` and `raw`, not just '
      '`t`, since night-schedule start/end extraction reads `raw` directly)',
      () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('밤 11시반부터 유튜브 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.startHour, 23);
    expect(plan.startMinute, 30);
  });

  test('"내일 아침부터 유튜브 뮤직에 들어가는 것을 09:30부터 볼수 있게 차단해줘!" is '
      'honestly declined instead of silently applying today (2026-07-13: '
      'ported from Cage — this parser has no future-activation concept at '
      'all, so "내일부터" used to be dropped and the schedule applied '
      'immediately today)', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '내일 아침부터 유튜브 뮤직에 들어가는 것을 09:30부터 볼수 있게 차단해줘!',
    );
    expect(usedAi, false);
    expect(plan.reply, contains('나중에 시작하는 예약은 지원 안'));
  });

  test('"유튜브 차단해줘" (no future-start words) still works — regression check',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse('유튜브 차단해줘');
    expect(usedAi, false);
    expect(plan.reply, isNot(contains('나중에 시작하는 예약')));
  });

  // "스타"만으로 매칭하던 하드코딩된 스타크래프트 키워드 감지가 "인스타(그램)"의
  // 부분 문자열과 겹쳐서 "인스타 3일간 차단해줘"가 완전히 무관한 스타크래프트
  // 키워드 차단으로 새던 실사용 버그(2026-07-13, 사용자 대화로그에서 발견).
  test('"인스타 3일간 차단해줘" is NOT misfiled as a "스타크래프트" keyword block',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse('인스타 3일간 차단해줘');
    expect(usedAi, false);
    expect(plan.keyword, isNot('스타크래프트'));
    expect(plan.reply, isNot(contains('스타크래프트')));
  });

  test('"인스타그램 3일간 차단해줘" is NOT misfiled as a "스타크래프트" keyword block',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse('인스타그램 3일간 차단해줘');
    expect(usedAi, false);
    expect(plan.keyword, isNot('스타크래프트'));
    expect(plan.reply, isNot(contains('스타크래프트')));
  });

  test('"스타크래프트 차단해줘" (bare, no 인스타 prefix) still correctly '
      'triggers the keyword block', () async {
    final (plan, usedAi) = await BlockChatParser.parse('스타크래프트 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'add_keyword');
    expect(plan.keyword, '스타크래프트');
  });

  // quick_block_now(지금부터 N시간 차단)는 QuickBlockService→Screen Time
  // 경유로만 동작하고 Isle 인앱 전용 임시차단 경로가 없는데, 사용자가
  // "인앱"이라고 명시해도 이 사실을 안 알려주고 일반 요청과 똑같이 응답해서
  // 매번 시스템 전체(Screen Time) 적용을 인앱 전용으로 오해하게 만들던
  // 실사용 버그(2026-07-13 사용자 대화로그).
  test('"인앱 유튜브 5시간 동안 차단해줘" honestly discloses this applies via '
      'Screen Time, not an isle-only path', () async {
    final (plan, usedAi) = await BlockChatParser.parse('인앱 유튜브 5시간 동안 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'quick_block_now');
    expect(plan.reply, contains('Screen Time'));
    expect(plan.reply, contains('인앱 전용'));
  });

  test('"오늘 유튜브 5시간 동안 차단해줘" (no 인앱 cue) keeps the plain reply — '
      'regression check', () async {
    final (plan, usedAi) = await BlockChatParser.parse('오늘 유튜브 5시간 동안 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'quick_block_now');
    expect(plan.reply, isNot(contains('Screen Time')));
  });

  // "N시간"이 "동안"·"지금부터" 없이 단독으로 쓰이면 _parseEndTime의 bare
  // "N시" fallback이 "2시간"의 "2시"를 절대 종료시각으로 잘못 집어
  // "매일 0시~2시"라는 전혀 다른 스케줄이 되던 실사용 버그(2026-07-13
  // 사용자 제보 — "인터넷 2시간간 차단해둬").
  test('"인터넷 2시간간 차단해둬" (bare hour, no 동안/지금부터/까지) is a '
      '2-hour quick_block_now, not "매일 0시~2시"', () async {
    final (plan, usedAi) = await BlockChatParser.parse('인터넷 2시간간 차단해둬');
    expect(usedAi, false);
    expect(plan.action, 'quick_block_now');
    expect(plan.windowMinutes, 120);
  });

  test('"밤 9시까지 차단해줘" (bare hour WITH "까지") still builds an absolute '
      'end-time schedule, not a duration block — regression check',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse('밤 9시까지 유튜브 차단해줘');
    expect(usedAi, false);
    expect(plan.action, isNot('quick_block_now'));
  });

  // bare-hour 트리거를 너무 넓게 잡으면 "하루 1시간에 20분씩 끊는 모드로
  // 바꿔줘" 같은 반복 예산(usage budget) 전환 요청까지 quick_block_now로
  // 가로채는 회귀가 생겼다(2026-07-13, 위 fix 직후 자체 발견) — "하루"가
  // 있으면 bare-hour 트리거를 켜지 않아야 한다.
  test('"유튜브 차단 스케줄 이제 하루 1시간에 20분씩 끊는 모드로 바꿔줘" '
      'still converts to youtube_budget, not misfiled as quick_block_now '
      '(regression check for the bare-hour-duration fix above)', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '유튜브 차단 스케줄 이제 하루 1시간에 20분씩 끊는 모드로 바꿔줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'youtube_budget');
  });

  // youtube_budget 확인카드가 뜬 직후 "나눠"/"모드" 같은 전환 신호어 없이
  // "20분쓰고 40분 쉬게해줘"라고만 정정하면 _parseRefillModeCorrection의
  // wantsRefill 게이트를 못 넘어 explain으로 떨어지던 실사용 버그
  // (2026-07-13 실기기 대화로그). 이미 나눠쓰기 모드(youtube_budget/
  // usage_budget)에서는 "나눠쓰기로 바꿔줘"를 또 말할 이유가 없으므로,
  // 세션·휴식 표현 + 숫자 2개만으로도 정정으로 인정해야 한다.
  test('follow-up "아니 20분쓰고 40분 쉬게해줘" after a youtube_budget card '
      'corrects session/window without needing 나눠/모드 keywords', () async {
    const previous = BlockChatPlan(
      action: 'youtube_budget',
      reply: '유튜브은 차단 대신 23시~7시에 60분 쓰고 20분 뒤 다시 충전되는 나눠쓰기 방식으로 바꿀게요.',
      startHour: 23,
      startMinute: 0,
      endHour: 7,
      endMinute: 0,
      dailyMinutes: 60,
      sessionMinutes: 60,
      cooldownMinutes: 20,
      limitPlatform: 'youtube',
      windowMinutes: 20,
    );
    final (plan, usedAi) = await BlockChatParser.parseWithContext(
      '아니 20분쓰고 40분 쉬게해줘',
      previousPlan: previous,
    );
    expect(usedAi, false);
    expect(plan.action, 'youtube_budget');
    expect(plan.sessionMinutes, 20);
    expect(plan.windowMinutes, 40);
  });

  // "previousPlan 없으면 오매칭 안 함" 음성 케이스는 로컬 파서가 이 문장에
  // 매칭되는 게 하나도 없어 결국 AI 폴백까지 가는데, 이 테스트 파일엔
  // AiConfigStore가 초기화돼 있지 않아(다른 모든 테스트가 로컬에서 매칭되는
  // 문장만 씀) 무관한 예외가 난다 — `_parseFollowUpCorrection`이 private라
  // AI를 안 타고 직접 단위테스트할 방법이 없어 생략. 대신 위 양성 테스트가
  // `previous.action == 'youtube_budget'` 가드를 실제로 타는 걸 확인하므로,
  // 그 가드 자체가 previousPlan 없이는 절대 통과 못 한다는 코드 리뷰로 대체.

  group('scheduled_reservation (예약 스케줄, 2026-07-20 신설)', () {
    test('relative start + N일간 parses to scheduled_reservation', () async {
      final (plan, usedAi) = await BlockChatParser.parse(
        '내일부터 3일간 유튜브 차단해줘',
      );
      expect(usedAi, false);
      expect(plan.action, 'scheduled_reservation');
      expect(plan.reservationLocked, true);
      expect(plan.scheduledActivationAtMs, isNotNull);
      expect(plan.scheduledDeactivationAtMs, isNotNull);
      final start = DateTime.fromMillisecondsSinceEpoch(
        plan.scheduledActivationAtMs!,
      );
      final end = DateTime.fromMillisecondsSinceEpoch(
        plan.scheduledDeactivationAtMs!,
      );
      expect(end.difference(start).inDays, 3);
      expect(plan.reply, contains('타임락'));
    });

    test('absolute date range (M월 D일부터 ~ 까지) parses correctly', () async {
      final (plan, usedAi) = await BlockChatParser.parse(
        '7월 25일부터 7월 30일까지 인스타그램 차단해줘',
      );
      expect(usedAi, false);
      expect(plan.action, 'scheduled_reservation');
      final start = DateTime.fromMillisecondsSinceEpoch(
        plan.scheduledActivationAtMs!,
      );
      final end = DateTime.fromMillisecondsSinceEpoch(
        plan.scheduledDeactivationAtMs!,
      );
      expect(start.month, 7);
      expect(start.day, 25);
      // 종료일까지 "포함"이라 다음날 00:00까지를 종료 시각으로 잡는다.
      expect(end.month, 7);
      expect(end.day, 31);
    });

    test('no date range keeps old night-block parsing (no false positive)', () async {
      final (plan, _) = await BlockChatParser.parse(
        '유튜브 차단해줘',
      );
      expect(plan.action, isNot('scheduled_reservation'));
    });

    test('해제 요청은 예약 파서를 안 탄다', () async {
      final (plan, _) = await BlockChatParser.parse(
        '내일부터 3일간 유튜브 차단 풀어줘',
      );
      expect(plan.action, isNot('scheduled_reservation'));
    });
  });

  group('app_open_block_trigger (앱 켠 지 N분, 2026-07-20 신설)', () {
    test('원문 그대로: "아침에 모아 앱에 들어가서 킨지 30분 동안은 유튜브에 못들어가게 해줘"',
        () async {
      final (plan, usedAi) = await BlockChatParser.parse(
        '아침에 모아 앱에 들어가서 킨지 30분 동안은 유튜브에 못들어가게 해줘',
      );
      expect(usedAi, false);
      expect(plan.action, 'app_open_block_trigger');
      expect(plan.appOpenTriggerMinutes, 30);
      expect(plan.appOpenTriggerMorningOnly, true);
      expect(plan.extraTargetIds, isNotNull);
      expect(plan.extraTargetIds, isNotEmpty);
    });

    test('"아침" 없이 "앱 켠 지 N분"만 말하면 morningOnly=false', () async {
      final (plan, _) = await BlockChatParser.parse(
        '앱 켠 지 20분 동안 유튜브 차단해줘',
      );
      expect(plan.action, 'app_open_block_trigger');
      expect(plan.appOpenTriggerMinutes, 20);
      expect(plan.appOpenTriggerMorningOnly, false);
    });

    test('분 단위 없으면 매칭 안 함 (quick_block_now 등 다른 파서로 폴백)', () async {
      final (plan, _) = await BlockChatParser.parse(
        '앱 켠 지 유튜브 차단해줘',
      );
      expect(plan.action, isNot('app_open_block_trigger'));
    });

    test('해제 요청은 이 파서를 안 탄다', () async {
      final (plan, _) = await BlockChatParser.parse(
        '앱 켠 지 30분 유튜브 차단 풀어줘',
      );
      expect(plan.action, isNot('app_open_block_trigger'));
    });
  });
}
