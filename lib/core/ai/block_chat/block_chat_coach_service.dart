import '../../intervention/external_app_shield_store.dart';
import '../../block/rule_removal_lock.dart';
import '../../library/platform_usage_stats.dart';
import '../../library/platform_watch_limit_store.dart';
import '../../platform/platform_block_intent.dart';
import '../../navigation/isle_routes.dart';
import 'block_chat_models.dart';
import 'block_chat_persona_scenarios.dart';

/// 적용 직후 — 활용법 + 사용량 기반 추가 추천
class BlockChatCoachService {
  BlockChatCoachService._();

  static Future<BlockChatCoachGuide> build({
    required BlockChatPlan plan,
    required BlockChatResult applied,
  }) async {
    if (applied.isFailure) return const BlockChatCoachGuide();

    final appliedActions = _collectAppliedActions(plan);
    final profile = await _loadUsageProfile();
    final howTo = _howToForActions(appliedActions, plan);
    final insight = _usageInsight(profile);
    await ExternalAppShieldStore.ensureOpen();
    final recs = _recommendations(
      profile: profile,
      actions: appliedActions,
      plan: plan,
    );

    return BlockChatCoachGuide(
      usageInsight: insight,
      howToUse: howTo,
      recommendations: recs.take(2).toList(),
    );
  }

  static Set<String> _collectAppliedActions(BlockChatPlan plan) {
    if (plan.action == 'persona_bundle' && plan.personaId != null) {
      final persona = BlockChatPersonaScenarios.byId(plan.personaId!);
      if (persona != null) {
        return persona.subPlans.map((p) => p.action).toSet();
      }
    }
    return {plan.action};
  }

  static Future<_UsageProfile> _loadUsageProfile() async {
    await PlatformWatchLimitStore.ensureOpen();

    final daily = await PlatformUsageStats.dailyByPlatform(days: 7);
    final avg = <String, int>{};
    for (final p in PlatformUsageStats.platforms) {
      var totalSec = 0;
      for (final e in daily.entries) {
        totalSec += e.value[p] ?? 0;
      }
      avg[p] = (totalSec / 7 / 60).round();
    }

    final todaySec = await PlatformUsageStats.todayByPlatform();
    final today = todaySec.map((k, v) => MapEntry(k, (v / 60).round()));

    final sorted = avg.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _UsageProfile(
      avgMinutesPerDay: avg,
      todayMinutes: today,
      topPlatform: sorted.isEmpty ? null : sorted.first.key,
      topPlatformAvg: sorted.isEmpty ? null : sorted.first.value,
    );
  }

  static String _usageInsight(_UsageProfile profile) {
    final parts = <String>[];
    for (final p in PlatformUsageStats.platforms) {
      final avg = profile.avgMinutesPerDay[p] ?? 0;
      if (avg >= 5) {
        parts.add(
          '${PlatformUsageStats.labelFor(p)} 하루 평균 ${avg}분',
        );
      }
    }
    if (parts.isEmpty) {
      return '아직 Isle 안 사용 기록이 많지 않아요. 며칠 쓰면 여기서 더 맞춤 추천이 나와요.';
    }
    final top = profile.topPlatform;
    final topAvg = profile.topPlatformAvg ?? 0;
    final todayTop = top != null ? (profile.todayMinutes[top] ?? 0) : 0;
    var line = '최근 7일 — ${parts.join(' · ')}.';
    if (top != null && topAvg >= 20) {
      line += '\n가장 많이 쓴 곳은 ${PlatformUsageStats.labelFor(top)}'
          ' (오늘 ${todayTop}분).';
    }
    return line;
  }

  static List<BlockChatCoachTip> _howToForActions(
    Set<String> actions,
    BlockChatPlan plan,
  ) {
    final tips = <BlockChatCoachTip>[];
    void add(BlockChatCoachTip t) {
      if (tips.length >= 5) return;
      if (tips.any((x) => x.title == t.title)) return;
      tips.add(t);
    }

    if (actions.contains('morning_habit_pack') ||
        actions.contains('morning_schedule')) {
      add(
        BlockChatCoachTip(
          title: '스케줄이 켜졌는지 확인',
          body: '차단 탭 → 스케줄 목록에서 「활성」인지 봐 주세요. '
              '편집 화면 ③에서 ${PlatformBlockCopy.nativeInstalledAppLabel}을 고르면 OS 차단이 붙어요.',
          route: '/home/block',
          routeLabel: '차단 탭',
        ),
      );
    }
    if (actions.contains('morning_habit_pack')) {
      add(
        const BlockChatCoachTip(
          title: '타임락으로 설정 변경 어렵게',
          body: '유튜브 탭 → 「타임락」을 켜면 한도·스케줄을 바꾸려면 '
              '해제 대기 시간이 필요해요. 시험 기간에 특히 유용해요.',
          route: '/youtube',
          routeLabel: '유튜브 · 타임락',
        ),
      );
      add(
        const BlockChatCoachTip(
          title: '한도·숏츠는 여기서 조절',
          body: '내 콘텐츠 → 유튜브·SNS 관리에서 일일 한도·숏츠 토글을 '
              '언제든 확인할 수 있어요.',
          route: '/home/my-isle/manage',
          routeLabel: '관리 센터',
        ),
      );
    }
    if (actions.contains('night_schedule')) {
      add(
        BlockChatCoachTip(
          title: '야간 차단은 앱 아이콘까지',
          body: PlatformBlockCopy.nativeInstalledAppPickHint,
          route: IsleRoutes.blockSchedulesOutsideShell,
          routeLabel: '스케줄 목록',
        ),
      );
    }
    if (actions.contains('toggle_shorts')) {
      add(
        const BlockChatCoachTip(
          title: '숏츠가 어디서 숨겨지나요',
          body: 'Isle 유튜브·피드·검색에서 Shorts 선반이 사라져요. '
              '다시 보이게 하려면 관리 센터에서 끄면 됩니다.',
          route: '/home/my-isle/manage',
          routeLabel: '숏츠 토글',
        ),
      );
    }
    if (actions.contains('toggle_reels_guard')) {
      add(
        const BlockChatCoachTip(
          title: '릴스 멈춤은 피드 안에서',
          body: '인스타 WebView에서 스크롤로 영상을 넘기면 '
              '임계치마다 「그만 볼게요」 화면이 떠요. '
              '「조금만 더」를 누를수록 다음 알림이 빨라져요.',
          route: '/explore/browser?site=instagram',
          routeLabel: '인스타 열기',
        ),
      );
    }
    if (actions.contains('youtube_limit') ||
        actions.contains('platform_limit') ||
        actions.contains('youtube_budget') ||
        actions.contains('usage_budget')) {
      add(
        const BlockChatCoachTip(
          title: '한도는 재생할 때만 줄어요',
          body: 'Isle 안에서 해당 앱·WebView가 열려 있는 동안만 '
              '시간이 셉니다. 한도에 닿으면 오버레이가 뜨고 재생이 멈춰요.',
          route: '/settings/platform-usage',
          routeLabel: '사용 통계',
        ),
      );
    }
    if (actions.contains('youtube_budget') ||
        actions.contains('usage_budget')) {
      add(
        BlockChatCoachTip(
          title: '처음엔 거칠게, 나중에 미세 조절',
          body: '하루 총량·한 번 쓰는 시간·쉬는 시간을 한꺼번에 완벽히 말하지 않아도 돼요. '
              '오늘 써 보고 “조금 더 빡세게”처럼 다시 말하면 다음 단계로 조절해요.',
          route: IsleRoutes.youtubeLimits,
          routeLabel: '나눠 쓰기 확인',
        ),
      );
    }
    if (actions.contains('app_session_limit')) {
      add(
        const BlockChatCoachTip(
          title: '세션·쿨다운 리듬',
          body: '짧게 쓰고 → 강제 휴식 → 다시 열 수 있는 패턴이에요. '
              '앱별 한도 화면에서 분 수를 조절할 수 있어요.',
          route: '/settings/app-usage-limits',
          routeLabel: '앱별 한도',
        ),
      );
    }
    if (actions.contains('safari_pause')) {
      add(
        const BlockChatCoachTip(
          title: '잠깐 풀기 후엔 자동 재잠금',
          body: '카운트다운이 끝나면 항상-막기 쉴드가 다시 켜져요. '
              '급한 링크만 열고 싶을 때 쓰세요 — 차단 탭에서 즉시 재잠금도 가능해요.',
          route: '/home/block',
          routeLabel: '차단 탭',
        ),
      );
    }
    if (actions.contains('block_website')) {
      add(
        const BlockChatCoachTip(
          title: 'Safari 확장 프로그램 켜기',
          body: 'iOS 설정 → Safari → 확장 프로그램에서 Isle를 켜야 '
              'Safari에서만 도메인 차단이 먹혀요. Isle WebView는 별도예요.',
          route: '/home/block',
          routeLabel: '웹사이트 차단 안내',
        ),
      );
    }
    if (actions.contains('add_keyword')) {
      add(
        const BlockChatCoachTip(
          title: '키워드는 피드·유튜브 제목에',
          body: '제목·채널명에 해당 단어가 있으면 카드가 안 보여요. '
              '관리 센터에서 목록을 추가·삭제할 수 있어요.',
          route: '/home/my-isle/manage',
          routeLabel: '숨김 목록',
        ),
      );
    }
    if (actions.contains('music_foreground_limit')) {
      add(
        BlockChatCoachTip(
          title: 'YT Music은 화면만 셈',
          body: '잠금 화면·백그라운드 음악은 iOS가 한도 밖으로 셉니다. '
              '스케줄 편집에서 YouTube Music 앱만 고르세요.',
          route: IsleRoutes.blockSchedulesOutsideShell,
          routeLabel: '스케줄 편집',
        ),
      );
    }

    if (tips.isEmpty) {
      add(
        const BlockChatCoachTip(
          title: '적용 위치 다시 보기',
          body: '위 초록 카드의 「차단 탭」「스케줄 편집」을 누르면 '
              '방금 바뀐 설정으로 바로 이동해요.',
          route: '/home/block',
          routeLabel: '차단 탭',
        ),
      );
    }

    return tips;
  }

  static List<BlockChatCoachRecommendation> _recommendations({
    required _UsageProfile profile,
    required Set<String> actions,
    required BlockChatPlan plan,
  }) {
    final out = <BlockChatCoachRecommendation>[];
    final avg = profile.avgMinutesPerDay;

    void add(BlockChatCoachRecommendation r) {
      if (out.length >= 2) return;
      if (out.any((x) => x.title == r.title)) return;
      out.add(r);
    }

    final ytAvg = avg['youtube'] ?? 0;
    final igAvg = avg['instagram'] ?? 0;
    final brunchAvg = avg['brunch'] ?? 0;

    _nextStepFromAppliedAction(plan, actions, add);

    if (!actions.contains('toggle_shorts') &&
        !actions.contains('morning_habit_pack') &&
        ytAvg >= 25) {
      add(
        BlockChatCoachRecommendation(
          title: '숏츠 선반 숨기기',
          reason: 'YouTube 평균 ${ytAvg}분/일 — 숏츠가 많은 편이에요.',
          chatPrompt: '숏츠 숨겨줘',
        ),
      );
    }

    if (!actions.contains('youtube_limit') &&
        !actions.contains('morning_habit_pack') &&
        ytAvg >= 45) {
      final suggest = _suggestedDailyLimit(ytAvg);
      add(
        BlockChatCoachRecommendation(
          title: '유튜브 하루 $suggest분 한도',
          reason: '최근 평균 ${ytAvg}분/일이에요.',
          chatPrompt: '유튜브 하루 $suggest분 한도',
        ),
      );
    }

    if (!actions.contains('toggle_reels_guard') && igAvg >= 20) {
      add(
        BlockChatCoachRecommendation(
          title: '릴스 둠스크롤 멈춤',
          reason: 'Instagram 평균 ${igAvg}분/일 — 피드 스크롤이 길어지기 쉬워요.',
          chatPrompt: '인스타 릴스 무한스크롤 멈춰줘',
        ),
      );
    }

    if (!actions.contains('night_schedule') && igAvg >= 35) {
      add(
        BlockChatCoachRecommendation(
          title: '밤 11시~아침 7시 야간 차단',
          reason: 'Instagram ${igAvg}분/일 — 밤 사용이 많을 수 있어요.',
          chatPrompt: '밤 11시부터 아침 7시까지 인스타 막아줘',
        ),
      );
    }

    if (!actions.contains('app_session_limit') &&
        !actions.contains('platform_limit') &&
        igAvg >= 30 &&
        plan.personaId != 'jieun_night_insta') {
      add(
        BlockChatCoachRecommendation(
          title: '인스타 5분 쓰고 10분 쉬기',
          reason: '평균 ${igAvg}분/일 — 짧은 세션으로 끊어 보세요.',
          chatPrompt: '인스타 5분 쓰고 10분 쉬기, 하루 30분',
        ),
      );
    }

    if (!actions.contains('platform_limit') && brunchAvg >= 15) {
      add(
        BlockChatCoachRecommendation(
          title: '브런치 하루 30분',
          reason: '브런치 평균 ${brunchAvg}분/일 — 글 읽기가 길어지기 쉬워요.',
          chatPrompt: '브런치 하루 30분 한도',
        ),
      );
    }

    if (!actions.contains('block_website') && (igAvg >= 40 || ytAvg >= 60)) {
      add(
        BlockChatCoachRecommendation(
          title: 'Safari에서 X(트위터) 차단',
          reason: 'SNS 사용이 많을 때 Safari 우회를 막을 수 있어요.',
          chatPrompt: 'twitter.com 막아줘',
        ),
      );
    }

    if (!RuleRemovalLock.lockEnabled &&
        (actions.contains('morning_habit_pack') ||
            actions.contains('night_schedule'))) {
      add(
        const BlockChatCoachRecommendation(
          title: '제거 타임락 켜기',
          reason: '차단을 끄려면 대기 시간이 필요하게 해요.',
          route: '/home/block',
          routeLabel: '차단 탭 · 제거 잠금',
        ),
      );
    }

    if (!ExternalAppShieldStore.hasSelection &&
        (igAvg >= 30 || actions.contains('night_schedule'))) {
      add(
        BlockChatCoachRecommendation(
          title: '${PlatformBlockCopy.nativeInstalledAppLabel} 직접 막기',
          reason: PlatformBlockCopy.isAndroid
              ? 'Isle 밖 Instagram·Chrome도 막으려면 접근성 앱 선택이 필요해요.'
              : 'Isle 밖 Instagram·Safari도 막으려면 Screen Time 앱 선택이 필요해요.',
          route: '/home/block',
          routeLabel:
              PlatformBlockCopy.isAndroid ? 'Android 앱 선택' : 'Safari·앱 선택',
        ),
      );
    }

    if (profile.topPlatform == 'youtube' &&
        ytAvg >= 20 &&
        !actions.contains('morning_schedule') &&
        !actions.contains('morning_habit_pack')) {
      add(
        BlockChatCoachRecommendation(
          title: '아침 유튜브 시간대 차단',
          reason: '아침에 ${ytAvg}분 이상 쓰는 패턴이 보여요.',
          chatPrompt: '매일 10시30분까지 isle 유튜브 차단해줘',
        ),
      );
    }

    _personaFollowUps(plan.personaId, actions, profile, add);

    if (out.isEmpty && ytAvg < 10 && igAvg < 10) {
      add(
        const BlockChatCoachRecommendation(
          title: '하나만 더 정해 보기',
          reason: '처음엔 완벽한 규칙보다 “하루 총량” 하나만 정해도 충분해요.',
          chatPrompt: '유튜브 하루 30분만 보게 해줘',
        ),
      );
    }

    return out;
  }

  static void _nextStepFromAppliedAction(
    BlockChatPlan plan,
    Set<String> actions,
    void Function(BlockChatCoachRecommendation) add,
  ) {
    if (actions.contains('youtube_limit')) {
      add(
        const BlockChatCoachRecommendation(
          title: '다음엔 나눠 쓰기로 바꾸기',
          reason: '하루 총량이 익숙해지면 “한 번에 몇 분”까지 나눠서 더 자연스럽게 줄일 수 있어요.',
          chatPrompt: '유튜브 하루 1시간, 20분 보고 나면 한 시간 뒤에 열리게 해줘',
        ),
      );
      return;
    }

    if (actions.contains('youtube_budget') ||
        actions.contains('usage_budget')) {
      add(
        const BlockChatCoachRecommendation(
          title: '잘 맞는지 하루만 관찰',
          reason: '오늘은 이 리듬으로 써 보고, 답답하면 “조금 느슨하게”, 쉽게 뚫리면 “더 빡세게”라고 말해 주세요.',
          chatPrompt: '방금 규칙을 조금 더 빡세게 해줘',
        ),
      );
      return;
    }

    if (actions.contains('toggle_shorts')) {
      add(
        const BlockChatCoachRecommendation(
          title: '총 시청 시간도 정하기',
          reason: '숏츠를 숨긴 뒤에도 긴 영상이 길어질 수 있어요. 다음엔 하루 총량만 가볍게 정해 보세요.',
          chatPrompt: '유튜브 하루 30분만 보게 해줘',
        ),
      );
      return;
    }

    if (actions.contains('toggle_reels_guard')) {
      add(
        const BlockChatCoachRecommendation(
          title: '인스타도 짧게 끊기',
          reason: '릴스 멈춤 다음 단계는 한 번 열 때 몇 분 볼지 정하는 거예요.',
          chatPrompt: '인스타 10분 보고 나면 1시간 닫아줘. 하루 총 30분',
        ),
      );
      return;
    }

    if (actions.contains('add_keyword') ||
        actions.contains('block_channel') ||
        actions.contains('block_url')) {
      add(
        const BlockChatCoachRecommendation(
          title: '비슷한 유혹도 묶어서 숨기기',
          reason: '하나를 숨긴 뒤 비슷한 제목·채널이 계속 뜨면, 다음엔 키워드로 넓게 막으면 돼요.',
          chatPrompt: '비슷한 추천 영상도 안 뜨게 키워드로 막아줘',
        ),
      );
      return;
    }

    if (actions.contains('morning_schedule') ||
        actions.contains('night_schedule') ||
        actions.contains('morning_habit_pack')) {
      add(
        const BlockChatCoachRecommendation(
          title: '스케줄 후엔 앱 선택 확인',
          reason: '시간표가 저장된 뒤 실제 앱까지 막으려면 OS 권한·앱 선택이 이어져야 해요.',
          route: '/home/block',
          routeLabel: '차단 탭',
        ),
      );
    }
  }

  static void _personaFollowUps(
    String? personaId,
    Set<String> actions,
    _UsageProfile profile,
    void Function(BlockChatCoachRecommendation) add,
  ) {
    if (personaId == null) return;
    switch (personaId) {
      case 'minsu_exam_morning':
        if (!actions.contains('toggle_shorts')) {
          add(
            const BlockChatCoachRecommendation(
              title: '피드에서도 숏츠 숨기기',
              reason: '시험 기간엔 피드 숏츠도 같이 끄는 게 좋아요.',
              chatPrompt: '숏츠 숨겨줘',
            ),
          );
        }
      case 'jieun_night_insta':
        if ((profile.avgMinutesPerDay['youtube'] ?? 0) >= 20) {
          add(
            BlockChatCoachRecommendation(
              title: '밤엔 유튜브도 한도',
              reason:
                  '인스타 말고 YouTube도 평균 ${profile.avgMinutesPerDay['youtube']}분이에요.',
              chatPrompt: '유튜브 하루 20분 한도',
            ),
          );
        }
      case 'taeyoung_safari_stuck':
        add(
          const BlockChatCoachRecommendation(
            title: '항상-막기 + 잠깐 풀기 조합',
            reason: '평소엔 막고, 급할 때만 챗으로 10분 풀기를 쓰세요.',
            route: '/home/block',
            routeLabel: '차단 탭 안내',
          ),
        );
      case 'jungwoo_brunch_study':
        if ((profile.avgMinutesPerDay['youtube'] ?? 0) >= 25) {
          add(
            const BlockChatCoachRecommendation(
              title: '공부 시간 유튜브도',
              reason: '브런치 다음으로 유튜브가 길어지는 경우가 많아요.',
              chatPrompt: '공부하겠다고 앉았는데 숏츠 추천만 계속 나와요',
            ),
          );
        }
      default:
        break;
    }
  }

  static int _suggestedDailyLimit(int avgMinutes) {
    if (avgMinutes >= 120) return 60;
    if (avgMinutes >= 60) return 45;
    if (avgMinutes >= 45) return 30;
    return 25;
  }
}

class _UsageProfile {
  const _UsageProfile({
    required this.avgMinutesPerDay,
    required this.todayMinutes,
    this.topPlatform,
    this.topPlatformAvg,
  });

  final Map<String, int> avgMinutesPerDay;
  final Map<String, int> todayMinutes;
  final String? topPlatform;
  final int? topPlatformAvg;
}
