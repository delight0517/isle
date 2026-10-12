import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';

void main() {
  group('new Korean user chat prompts', () {
    final cases = <({
      String prompt,
      String action,
      String? platform,
      String? appId,
      int? daily,
      int? session,
      int? window,
      int? cooldown,
      int? startHour,
      int? endHour,
      String? keyword,
      String? website,
      String? channel,
    })>[
      (
        prompt: '앱 처음 써보는데 유튜브 하루 한 시간만 보고 싶어. 한 번에 20분씩 보고 1시간 지나면 다시 열리게 해줘',
        action: 'youtube_budget',
        platform: 'youtube',
        appId: null,
        daily: 60,
        session: 20,
        window: 60,
        cooldown: 60,
        startHour: null,
        endHour: null,
        keyword: null,
        website: null,
        channel: null,
      ),
      (
        prompt: '인스타는 5분 쓰면 10분 쉬고 하루 30분만 쓰게 해줘',
        action: 'usage_budget',
        platform: 'instagram',
        appId: null,
        daily: 30,
        session: 5,
        window: 10,
        cooldown: 10,
        startHour: null,
        endHour: null,
        keyword: null,
        website: null,
        channel: null,
      ),
      (
        prompt: '밤 11시부터 아침 7시까지 인스타 안 되게 해줘',
        action: 'night_schedule',
        platform: null,
        appId: null,
        daily: null,
        session: null,
        window: null,
        cooldown: null,
        startHour: 23,
        endHour: 7,
        keyword: null,
        website: null,
        channel: null,
      ),
      (
        prompt: '아침 9시까지 사파리랑 웹 못 보게 해줘',
        action: 'morning_schedule',
        platform: null,
        appId: null,
        daily: null,
        session: null,
        window: null,
        cooldown: null,
        startHour: null,
        endHour: 9,
        keyword: null,
        website: null,
        channel: null,
      ),
      (
        prompt: '숏츠가 너무 많이 떠. 그냥 숨겨줘',
        action: 'toggle_shorts',
        platform: null,
        appId: null,
        daily: null,
        session: null,
        window: null,
        cooldown: null,
        startHour: null,
        endHour: null,
        keyword: null,
        website: null,
        channel: null,
      ),
      (
        prompt: '릴스 보다가 시간 다 가서 릴스 무한스크롤 좀 멈춰줘',
        action: 'toggle_reels_guard',
        platform: null,
        appId: null,
        daily: null,
        session: null,
        window: null,
        cooldown: null,
        startHour: null,
        endHour: null,
        keyword: null,
        website: null,
        channel: null,
      ),
      (
        prompt: '로블록스 영상은 이제 안 보이게 해줘',
        action: 'add_keyword',
        platform: null,
        appId: null,
        daily: null,
        session: null,
        window: null,
        cooldown: null,
        startHour: null,
        endHour: null,
        keyword: '로블록스',
        website: null,
        channel: null,
      ),
      (
        prompt: 'twitter.com 들어가면 계속 새니까 막아줘',
        action: 'block_website',
        platform: null,
        appId: null,
        daily: null,
        session: null,
        window: null,
        cooldown: null,
        startHour: null,
        endHour: null,
        keyword: null,
        website: 'x.com',
        channel: null,
      ),
      (
        prompt: '브런치는 하루 30분만 읽게 해줘',
        action: 'platform_limit',
        platform: 'brunch',
        appId: null,
        daily: 30,
        session: null,
        window: null,
        cooldown: null,
        startHour: null,
        endHour: null,
        keyword: null,
        website: null,
        channel: null,
      ),
      (
        prompt: '침착맨 채널 그만 보게 숨겨줘',
        action: 'block_channel',
        platform: null,
        appId: null,
        daily: null,
        session: null,
        window: null,
        cooldown: null,
        startHour: null,
        endHour: null,
        keyword: null,
        website: null,
        channel: '침착맨',
      ),
    ];

    for (final c in cases) {
      test(c.prompt, () async {
        final (plan, usedAi) = await BlockChatParser.parse(c.prompt);

        expect(usedAi, false);
        expect(plan.action, c.action);
        if (c.platform != null) expect(plan.limitPlatform, c.platform);
        if (c.appId != null) expect(plan.appId, c.appId);
        if (c.daily != null) expect(plan.dailyMinutes, c.daily);
        if (c.session != null) expect(plan.sessionMinutes, c.session);
        if (c.window != null) expect(plan.windowMinutes, c.window);
        if (c.cooldown != null) expect(plan.cooldownMinutes, c.cooldown);
        if (c.startHour != null) expect(plan.startHour, c.startHour);
        if (c.endHour != null) expect(plan.endHour, c.endHour);
        if (c.keyword != null) expect(plan.keyword, c.keyword);
        if (c.website != null) expect(plan.websiteDomain, c.website);
        if (c.channel != null) expect(plan.channelName, c.channel);
      });
    }
  });
}
