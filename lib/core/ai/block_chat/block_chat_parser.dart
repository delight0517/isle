import 'dart:async';
import 'dart:convert';

import '../../block/premade_block_pack_service.dart';
import '../../block_schedule/block_schedule_store.dart';
import '../../block_schedule/models/block_schedule.dart';
import '../../block_schedule/schedule_display_helper.dart';
import '../../block_schedule/url_rules/url_rule_detector.dart';
import '../../intervention/website_block_store.dart';
import '../../services/trusted_time_guard.dart';
import '../ai_client.dart';
import '../ai_usage_log_store.dart';
import 'block_audit_log_store.dart';
import 'block_chat_daily_scenarios.dart';
import 'block_chat_models.dart';
import 'block_chat_persona_parser.dart';
import 'block_chat_ration_tag.dart';
import 'block_chat_persona_scenarios.dart';

/// 자연어 → 차단 설정 계획 (AI + 로컬 폴백)
class BlockChatParser {
  BlockChatParser._();

  static final _system = '''
당신은 Isle 앱의 차단·한도 설정 도우미입니다. 사용자 요청을 JSON 하나로만 답하세요.

action 목록:
- add_keyword: 유튜브·피드 키워드 숨김 (keyword 필수) — 스케줄·시간 표현은 키워드로 쓰지 마세요
- remove_keyword: 키워드 제거 (remove_keyword)
- remove_url: URL·링크 차단 해제 (remove_url) — 제거 타임락 ON이면 N분 후 자동 해제
- morning_schedule: 매일 0시~지정 시각까지 차단 (schedule_name, end_hour, end_minute)
  - block_safari:true → Safari·Isle 웹 전체
  - block_isle_youtube:true → Isle 인앱 유튜브만 (「isle 유튜브」「앱 유튜브」)
- app_session_limit: 앱 일일 한도 + 세션·쿨다운 (app_id: instagram|tiktok|youtube_app, daily_minutes, session_minutes, cooldown_minutes)
- remove_schedule: 스케줄 해제·끄기 (schedule_query) — **같은 유튜브·Safari 차단이 여러 스케줄에 겹치면 전부 완화**
- relax_block: 차단 풀기·보게 해줘 (relax_target: youtube|safari|instagram) — 겹친 스케줄 일괄 완화
- rename_schedule: 스케줄 이름 변경 (schedule_query, schedule_new_name)
- update_schedule_time: 종료 시각 변경 (schedule_query, end_hour, end_minute, days 선택)
- add_schedule_days: 요일 추가 (schedule_query, days)
- remove_schedule_days: 요일 제거 (schedule_query, days)
- toggle_shorts / toggle_reels
- youtube_limit: Isle 유튜브 일일 한도 분 (daily_minutes)
- usage_budget / youtube_budget: 앱·플랫폼 나눠 쓰기 한도 (limit_platform 또는 app_id, daily_minutes=하루 총량, session_minutes=한 번 보기, window_minutes=충전 대기, cooldown_minutes=잠금)
- morning_habit_pack: 아침·습관 고민 → 스케줄(limitInSlot)+앱 한도+Isle 일일 한도 일괄 (schedule_name, end_hour, end_minute, daily_minutes, session_minutes, suggest_timelock:true)
- study_mode: 공부 모드 프리셋 — 브라우저 차단/유튜브 제한/포모도로 동기화/지속시간 조합
- music_foreground_limit: iPhone YouTube Music 앱 — 화면(on-screen) 시간당 N분 + 백그라운드 음악은 iOS 한도 밖 (end_hour, end_minute, session_minutes, window_minutes)
  - Isle 앱이 아니라 **iPhone의 YouTube Music 앱** 대상. Screen Time DeviceActivity로 슬롯 안 매시간 한도.
- night_schedule: 야간 SNS·인스타 차단 (start_hour, start_minute, end_hour, end_minute) — overnight 슬롯. 기본 21:00–07:00
- toggle_reels_guard: 인스타 피드 릴스 둠스크롤 멈춤 오버레이 (toggle_on)
- safari_pause: 항상-막기 Safari·앱 쉴드 N분 임시 해제 (pause_minutes: 5|10|15)
- block_website: Safari Content Blocker 도메인 추가 (website_domain) — Isle WebView 무관
- block_url: URL·영상 링크 차단 (remove_url 필드에 URL 저장)
- block_channel: 유튜브 채널 숨김 (channel_name)
- platform_limit: 인스타·브런치 일일 한도 (limit_platform: instagram|brunch, daily_minutes)
- persona_bundle: 고민 톤 일괄 적용 (persona_id) — reply에 공감 먼저, subPlans 순차 실행
- apply_premade_pack: 프리셋 팩 통째 적용 (preset_id) — "모든 음란물/성인물 차단해줘" 같은 포괄 요청. 단일 사이트/URL이면 block_website·block_url 사용
- block_genre: 특정 채널명이 아니라 장르/주제 전체 채널 차단 (topic_label, language_code 기본 ko) — "모든 게임 채널 차단해줘" 류. 특정 채널명이면 block_channel 사용
- finance_guidance: "주식/증권 앱 차단해줘" 류 — 실제 앱을 특정하기 전에 어떤 앱/URL인지 되묻는다(주식앱 종류가 다양해 임의로 하나만 고르지 않음)
- convert_schedule_mode: 기존 스케줄을 전체차단→구간제한(N분마다 M분)으로 변형 (schedule_query, app_id, session_minutes=한 번 보기, window_minutes=주기) — "OO 밤에 통째로 블락 말고 10분마다 3분만" 류
- reset_reapply: "OO 관련 스케줄 전부 초토화 후 콜론(:) 뒤 내용으로 덮어쓰기" 복합명령 — 로컬 파서 전용(콜론 분리+재귀 파싱), AI JSON으로 요청하지 마세요
- reset_all_blocks: "모든/전부/전체 차단·설정을 초기화·리셋해줘" — 앱의 모든 스케줄·차단·한도를 통째로 지우는 파괴적 명령. 특정 앱 하나만 지칭하면 remove_schedule/relax_block을 쓰고, 이건 "모든/전부/전체"처럼 범위가 전체일 때만
- explain_status: 설정 변경 없이 현재 상태만 조회 (limit_platform 또는 app_id) — "OO 차단 설정 알려줘"「OO 스케줄 알려줘」「OO 뭐가 차단하고 있어?」류. YouTube Music이면 limit_platform: "youtube_music"
- explain: 설정 불가·추가 질문

JSON: action, reply, keyword, schedule_name, end_hour, end_minute, start_hour, start_minute, days,
block_safari, block_isle_youtube, app_id, daily_minutes, session_minutes, cooldown_minutes,
remove_schedule_query, schedule_query, schedule_new_name, remove_keyword, remove_url, toggle_on,
suggest_timelock, window_minutes, channel_name, website_domain, pause_minutes, limit_platform, persona_id,
preset_id, topic_label, language_code

schedule_query: 아침·유튜브·Safari·인스타·AI·방금 만든·지금 켜진 등 — 비우면 활성/최근 스케줄 자동 선택

예: "아침에 유튜브 이제 보게 해줘" → relax_block, relax_target: youtube
예: "아침 유튜브 스케줄 끄기" → remove_schedule, schedule_query: "아침 유튜브"
예: "10시까지로 바꿔줘" → update_schedule_time, schedule_query: "", end_hour:10
예: "이름을 저녁 집중으로 바꿔" → rename_schedule, schedule_new_name: "저녁 집중"
예: "토요일도 추가" → add_schedule_days, days: [5]

예: "매일 10시30분까지 isle 유튜브 차단" → morning_schedule, end_hour:10, end_minute:30, block_isle_youtube:true
예: "매일 9시까지 Safari 막아줘" → morning_schedule, end_hour:9, block_safari:true
예: "아침에 유튜브 뮤직 영상 많이 보는데 해결책?" → morning_habit_pack, end_hour:10, daily_minutes:20, session_minutes:5, suggest_timelock:true
예: "유튜브 뮤직 11시까지 1시간에 10분 onscreen 나머지 background" → music_foreground_limit, end_hour:11, session_minutes:10, window_minutes:60
예: "밤 11시부터 아침 7시까지 인스타 막아줘" → night_schedule, start_hour:23, end_hour:7
예: "Safari 10분만 풀어줘" → safari_pause, pause_minutes:10
예: "모든 음란물을 차단해줘" → apply_premade_pack, preset_id:"premade_adult_combined", suggest_timelock:true
예: "모든 게임 채널 차단해줘" → block_genre, topic_label:"게임"
예: "매일 아침 주식 관련 앱들을 차단해주라" → finance_guidance
예: "카카오톡 밤에 통째로 블락 말고, 10분마다 3분만 보기로 변형해줘" → convert_schedule_mode, schedule_query:"카카오톡 밤", app_id:"kakao", session_minutes:3, window_minutes:10
예: "카카오톡 차단 설정 알려줘" → explain_status, app_id: "kakao"
예: "유튜브 뮤직 스케줄 알려줘" → explain_status, limit_platform: "youtube_music"
예: "twitter.com 막아줘" → block_website, website_domain: "x.com"
예: "인스타 릴스 무한스크롤 멈춰줘" → toggle_reels_guard, toggle_on:true
예: "인스타 하루 30분" → platform_limit, limit_platform:instagram, daily_minutes:30
예: "유튜브 하루 1시간인데 20분씩 보고 1시간마다 충전" → youtube_budget, daily_minutes:60, session_minutes:20, window_minutes:60, cooldown_minutes:60
예: "유튜브 스케줄을 하루 1시간, 20분마다 스탑으로 변환" → youtube_budget, daily_minutes:60, session_minutes:20
예: "인스타 하루 45분, 15분씩 30분 쉬게" → usage_budget, limit_platform:instagram, daily_minutes:45, session_minutes:15, window_minutes:30, cooldown_minutes:30
예: "틱톡 차단 스케줄 이제 하루 40분에 10분씩으로 바꿔줘" → usage_budget, limit_platform:app, app_id:tiktok, daily_minutes:40, session_minutes:10

일상 명령형 15가지:
${BlockChatDailyScenarios.all.map((s) => '- ${s.title}: 「${s.examplePrompt}」').join('\n')}

진솔한 고민 톤 15가지 (공감 reply + persona_bundle):
${BlockChatPersonaScenarios.all.map((p) => '- ${p.persona}: 「${p.concern}」').join('\n')}
''';

  static Future<(BlockChatPlan plan, bool usedAi)> parseWithContext(
    String userText, {
    BlockChatPlan? previousPlan,
  }) async {
    final correction = _parseFollowUpCorrection(userText, previousPlan);
    if (correction != null) return (correction, false);
    return parse(userText, previousPlan: previousPlan);
  }

  static Future<(BlockChatPlan plan, bool usedAi)> parse(
    String userText, {
    BlockChatPlan? previousPlan,
  }) async {
    final local = _parseLocal(userText);
    if (local != null) {
      if (!_shouldEscalateLocalToAi(userText, local) ||
          !_wantsAiEscalation(userText) ||
          !AiClient.isConfigured) {
        return (local, false);
      }
      final ai = await _parseWithAi(userText, previousPlan: previousPlan);
      if (ai != null && ai.$1.action != 'explain') return ai;
      return (local, false);
    }

    final recommendation = _parseCapabilityRecommendation(userText);
    if (recommendation != null && !_wantsAiEscalation(userText)) {
      return (recommendation, false);
    }

    final ai = await _parseWithAi(userText, previousPlan: previousPlan);
    if (ai != null) {
      if (ai.$1.action != 'explain' || recommendation == null) return ai;
    }
    if (recommendation != null) return (recommendation, false);

    return (
      BlockChatPlan(
        action: 'explain',
        reply: '요청을 이해하지 못했어요. 예: 「시험 기간인데 알람 끄고 숏츠만 보다가 또 지각했어요」, '
            '「매일 10시30분까지 isle 유튜브 차단」'
            '${AiClient.isConfigured ? '' : '\n\n애매한 문장도 알아듣게 하려면 AI 센터에서 키를 등록해 보세요(선택 사항).'}',
      ),
      false,
    );
  }

  static int _maxDailyMinutesForAction(String action) {
    switch (action) {
      case 'app_session_limit':
        return 180;
      case 'usage_budget':
      case 'youtube_budget':
      case 'platform_limit':
      case 'youtube_limit':
      default:
        return 480;
    }
  }

  /// 「하루 총량은 30분으로 해줘」처럼 명시적 스코프 단어(하루/총량 또는
  /// 한번에/세션)와 함께 숫자 하나만 고치는 후속 정정 — 스코프 단어가 있어야만
  /// dailyMinutes/sessionMinutes 중 어느 쪽인지 확정할 수 있으므로 로컬에서
  /// 안전하게 처리한다. Cage에서 먼저 발견·수정된 클래스의 버그를 이식
  /// (2026-07-21 사용자 제보 — 모아에선 이 함수 자체가 없어서 "하루 총량은
  /// 30분으로 해줘"가 로컬 정정 체인에 안 걸리고 AI 폴백으로 새는데, AI엔
  /// previousPlan이 아예 전달되지 않아 맥락(직전이 유튜브 나눠쓰기였다는 것)을
  /// 통째로 잃고 엉뚱하게 Instagram으로 바뀌는 실사용 버그로 이어졌음).
  static BlockChatPlan? _parseScopedBudgetNumberCorrection(
    String t,
    BlockChatPlan previous,
  ) {
    const budgetActions = {
      'usage_budget',
      'youtube_budget',
      'platform_limit',
      'app_session_limit',
      'youtube_limit',
    };
    if (!budgetActions.contains(previous.action)) return null;

    final mentionsDaily = _hasAny(t, ['하루', '일일', '총량', 'daily']);
    final mentionsSession = _hasAny(t, ['한번에', '한 번에', '세션', 'session', '한 번']);
    if (mentionsDaily == mentionsSession) return null;

    if (_hasAny(t, ['제한 없', '제한없', '무제한', '한도 없', '한도없', '제한 안'])) {
      return null;
    }
    if (_hasAny(t, ['리필', '충전', '나눠', '나누', '쪼개', '방식', '모드'])) {
      return null;
    }
    if (_hasAny(t, ['해제', '풀', '삭제', '끄', '취소'])) return null;

    final mins = _parseAllMinutes(t);
    if (mins.length != 1) return null;
    final value = mins.first;

    final maxDaily = _maxDailyMinutesForAction(previous.action);
    final target = _platformLabel(previous);

    if (mentionsDaily) {
      final daily = value.clamp(previous.sessionMinutes ?? 1, maxDaily).toInt();
      return previous.copyWith(
        dailyMinutes: daily,
        reply: '$target 하루 총량을 $daily분으로 고칠게요.',
      );
    }

    final session = value.clamp(1, previous.dailyMinutes ?? 480).toInt();
    return previous.copyWith(
      sessionMinutes: session,
      reply: '$target 한 번에 쓸 수 있는 시간을 $session분으로 고칠게요.',
    );
  }

  static BlockChatPlan? _parseFollowUpCorrection(
    String raw,
    BlockChatPlan? previousPlan,
  ) {
    if (previousPlan == null) return null;
    final t =
        _applySelfCorrection(_normalizeCommonTypos(raw.toLowerCase().trim()));
    if (t.isEmpty) return null;

    final ambiguousDurationReply =
        _parseAmbiguousDurationReply(t, previousPlan);
    if (ambiguousDurationReply != null) return ambiguousDurationReply;

    final multiApplyReply = _parseMultiApplyConfirmReply(t, previousPlan);
    if (multiApplyReply != null) return multiApplyReply;

    final overwriteReply = _parseOverwriteConfirmReply(t, previousPlan);
    if (overwriteReply != null) return overwriteReply;

    final modeQuestion = _parseApplyModeQuestion(t, previousPlan);
    if (modeQuestion != null) return modeQuestion;

    final scopedNumberCorrection =
        _parseScopedBudgetNumberCorrection(t, previousPlan);
    if (scopedNumberCorrection != null) return scopedNumberCorrection;

    final refillCorrection = _parseRefillModeCorrection(raw, t, previousPlan);
    if (refillCorrection != null) return refillCorrection;

    if (previousPlan.action == 'night_schedule') {
      // "분리해줘" — 병합된 여러 시간대를 시간대별 별개 스케줄로 나눠 달라는
      // 후속 요청(cage 2026-07-13 이식). 시간 정정 파서보다 먼저 잡아야 한다
      // — 안 그러면 시간 토큰이 없는 "분리해줘"가 그냥 무시된다.
      final splitRequest = _parseScheduleSplitRequest(t, previousPlan);
      if (splitRequest != null) return splitRequest;
      final targetCorrection =
          _parseNightScheduleTargetCorrection(t, previousPlan);
      if (targetCorrection != null) return targetCorrection;
      final nightCorrection = _parseNightScheduleCorrection(raw, t, previousPlan);
      if (nightCorrection != null) return nightCorrection;
    }

    final genericCancel = _parseGenericQuestionCancel(t, previousPlan);
    if (genericCancel != null) return genericCancel;

    if (previousPlan.action == 'focus_mode_ask') {
      return _parseFocusModeAnswer(t);
    }

    return null;
  }

  /// 「아니아니 이 sns 앱 자체의 유튜브 말이야」— 시간이 아니라 "어떤 앱"을 정정하는 후속 메시지.
  /// executor가 appId/limitPlatform 없으면 Instagram으로 기본 처리하므로, 여기서 못 잡으면
  /// 사용자가 지목한 앱과 무관하게 계속 Instagram이 막힌다.
  /// 「분리해줘」— 병합돼 여러 시간대를 가진 야간 스케줄을 시간대별 별개
  /// 스케줄로 나눠 달라는 후속 요청(cage 2026-07-13 이식). 새 시간이나 앱
  /// 정정이 아니라 순수하게 "나눠줘"만 말하는 짧은 답장이라 시간 토큰이
  /// 없어도 통과시킨다.
  static BlockChatPlan? _parseScheduleSplitRequest(
    String t,
    BlockChatPlan previous,
  ) {
    final wantsSplit = _hasAny(t, ['분리', '나눠', '따로']) &&
        _hasAny(t, ['스케줄', '나눠', '분리', '따로']);
    if (!wantsSplit) return null;
    // "10분마다 3분만 나눠 쓰기"처럼 리필 설정을 말하는 문장과 헷갈리지
    // 않게 — 시간·분 숫자가 같이 나오면 그건 새 리필 정정이지 분리 요청이 아니다.
    if (_hasTimeToken(t) || RegExp(r'\d+\s*분').hasMatch(t)) return null;

    return BlockChatPlan(
      action: 'split_night_schedule',
      scheduleName: previous.scheduleName,
      appId: previous.appId,
      limitPlatform: previous.limitPlatform,
      blockSafariNote: previous.blockSafariNote,
      extraTargetIds: previous.extraTargetIds,
      reply: '스케줄을 시간대별로 나눌게요.',
    );
  }

  static BlockChatPlan? _parseNightScheduleTargetCorrection(
    String t,
    BlockChatPlan previous,
  ) {
    if (_hasAny(t, ['해제', '풀', '삭제', '끄', '취소'])) return null;
    final target = _parseUsageBudgetTarget(t);
    if (target == null) return null;

    final appId = target.$1 == 'app' ? target.$2 : null;
    final limitPlatform = target.$1 != 'app' ? target.$1 : null;
    final startH = previous.startHour ?? 21;
    final startM = previous.startMinute ?? 0;
    final label = target.$3;

    return BlockChatPlan(
      action: 'night_schedule',
      scheduleName: '야간 $label 차단 (AI)',
      startHour: startH,
      startMinute: startM,
      endHour: previous.endHour,
      endMinute: previous.endMinute,
      days: previous.days,
      blockSafariNote: previous.blockSafariNote,
      appId: appId,
      limitPlatform: limitPlatform,
      sessionMinutes: previous.sessionMinutes,
      dailyMinutes: previous.dailyMinutes,
      cooldownMinutes: previous.cooldownMinutes,
      windowMinutes: previous.windowMinutes,
      reply: '$label로 대상을 바꿔서 다시 보여드릴게요. '
          '매일 ${_fmt(startH, startM)}~${_fmt(previous.endHour, previous.endMinute)} '
          '야간 스케줄 — iPhone $label 앱 차단 (Screen Time 선택 필요)',
    );
  }

  static BlockChatPlan? _parseApplyModeQuestion(
    String t,
    BlockChatPlan previous,
  ) {
    final asksMode = _hasAny(t, [
      '덮어',
      'overwrite',
      '기존',
      '새로',
      '리셋',
      'reset',
      '초기화',
      '유지',
      '대체',
      '바꾸는',
      '바뀌는',
    ]);
    final asksQuestion = _hasAny(t, ['?', '야', '이야', '임', '맞', '어떻게', '혹시']);
    if (!asksMode || !asksQuestion) return null;

    final target = _planTargetLabel(previous);
    final window = _planWindowLabel(previous);
    final defaultMode = _defaultApplyModeLabel(previous);

    return BlockChatPlan(
      action: 'explain',
      reply: '$target 설정은 기본적으로 “삭제 덮어쓰기”가 아니라 $defaultMode 방식이에요.\n\n'
          '현재 카드: $window\n\n'
          '선택지는 이렇게 말하면 돼요.\n'
          '1. 「이대로 적용」: 기존 같은 스케줄이 있으면 시간·대상만 갱신해요.\n'
          '2. 「기존 유지하고 새로 만들기」: 기존 스케줄은 두고 별도 스케줄로 만들어요.\n'
          '3. 「기존 끄고 새로 리셋」: 기존 관련 스케줄을 끈 뒤 새 설정으로 다시 시작해요.\n\n'
          '적용 전에는 항상 확인 카드가 먼저 나오고, 확인 적용을 눌러야 실제로 바뀌어요.',
    );
  }

  static String _defaultApplyModeLabel(BlockChatPlan plan) {
    switch (plan.action) {
      case 'morning_schedule':
      case 'night_schedule':
      case 'allow_window':
        return '같은 목적의 스케줄이 있으면 지우지 않고 갱신하고, 없으면 새로 만드는';
      case 'youtube_budget':
      case 'usage_budget':
      case 'youtube_limit':
      case 'platform_limit':
      case 'app_session_limit':
        return '기존 한도 정책을 새 값으로 갱신하는';
      default:
        return '기존 설정과 충돌하지 않는 범위에서 추가·갱신하는';
    }
  }

  static String _planTargetLabel(BlockChatPlan plan) {
    switch (plan.action) {
      case 'morning_schedule':
        if (plan.blockSafariNote) return '아침 Safari·유튜브 차단';
        return '아침 유튜브 차단';
      case 'night_schedule':
        return '야간 차단';
      case 'youtube_budget':
      case 'youtube_limit':
        return '유튜브 한도';
      case 'usage_budget':
      case 'platform_limit':
      case 'app_session_limit':
        return '${_platformLabel(plan)} 한도';
      default:
        return '방금 제안한';
    }
  }

  static String _platformLabel(BlockChatPlan plan) {
    final app = (plan.appId ?? plan.limitPlatform ?? '').toLowerCase();
    switch (app) {
      case 'instagram':
        return '인스타';
      case 'tiktok':
        return '틱톡';
      case 'kakao':
      case 'kakaotalk':
        return '카카오톡';
      case 'safari':
        return 'Safari';
      case 'youtube':
      case 'youtube_app':
        return '유튜브';
      case 'brunch':
        return '브런치';
      default:
        return '앱';
    }
  }

  static String _planWindowLabel(BlockChatPlan plan) {
    switch (plan.action) {
      case 'morning_schedule':
        return '매일 0시~${_fmt(plan.endHour, plan.endMinute)}';
      case 'night_schedule':
        return '매일 ${_fmt(plan.startHour ?? 21, plan.startMinute ?? 0)}~'
            '${_fmt(plan.endHour, plan.endMinute)}';
      case 'youtube_budget':
      case 'usage_budget':
        final daily =
            plan.dailyMinutes != null ? '하루 ${plan.dailyMinutes}분' : '하루 총량';
        final session =
            plan.sessionMinutes != null ? ', 한 번에 ${plan.sessionMinutes}분' : '';
        return '$daily$session';
      case 'youtube_limit':
      case 'platform_limit':
        return plan.dailyMinutes != null ? '하루 ${plan.dailyMinutes}분' : '하루 한도';
      default:
        return plan.reply.isNotEmpty ? plan.reply : '방금 만든 확인 카드';
    }
  }

  static BlockChatPlan? _parseRefillModeCorrection(
    String raw,
    String t,
    BlockChatPlan previous,
  ) {
    // "같은 조건에서 10분에 5분씩만 허락해줘" 류 — 완전 차단이 아니라 창(10분)마다
    // 세션(5분)만 여는 나눠쓰기 전환 요청인데, '허락'/'허용'/'풀어'만으로는
    // "그냥 임시로 다 풀어줘"(allow_window)와 구분이 안 되므로, 이 단어들은
    // "N분에 M분" 류 구간 패턴이 같이 있을 때만 나눠쓰기 신호로 인정한다.
    final interval = _matchIntervalThenSession(t);
    // 직전 계획이 이미 나눠쓰기(youtube_budget/usage_budget)라면, "나눠"/"모드"
    // 같은 전환 신호어 없이 "20분쓰고 40분 쉬게해줘"처럼 숫자만 바꾸는 후속
    // 정정도 같은 의도다 — 이미 나눠쓰기 모드인데 또 "나눠쓰기로 바꿔줘"라고
    // 말할 사용자는 없다. "쓰고"/"쉬"/"분만" 같은 세션·휴식 표현 + 숫자 2개
    // 이상이면 정정으로 인정한다(2026-07-13 실사용 확인 — youtube_budget
    // 확인카드 뜬 직후 "아니 20분쓰고 40분 쉬게해줘"가 explain으로 떨어짐).
    final alreadyInRefillMode =
        previous.action == 'youtube_budget' || previous.action == 'usage_budget';
    final looksLikeBareSessionRestCorrection = alreadyInRefillMode &&
        _hasAny(t, ['쓰고', '쉬', '분만']) &&
        _parseAllMinutes(t).length >= 2;
    final wantsRefill = _hasAny(t, [
          '리필',
          '충전',
          '나눠',
          '나누',
          '쪼개',
          '방식',
          '모드',
          '차단말고',
          '차단 말고',
        ]) ||
        (interval != null &&
            _hasAny(t, ['허락', '허용', '허가', '풀어', '보게'])) ||
        looksLikeBareSessionRestCorrection;
    if (!wantsRefill) return null;

    final target =
        _usageBudgetTargetFromPlan(previous) ?? _parseUsageBudgetTarget(t);
    if (target == null) return null;

    final mins = _parseAllMinutes(t);
    final previousSession = previous.sessionMinutes ?? previous.dailyMinutes;
    // "N분에 M분"은 창(N)이 세션(M)보다 먼저 오는 어순이므로, 단순히 파싱된
    // 순서대로 첫 숫자를 세션으로 쓰면 창·세션이 뒤바뀐다 — interval 매칭이
    // 있으면 그걸 우선한다.
    final session = (interval?.$2 ?? (mins.isNotEmpty ? mins.first : previousSession ?? 3))
        .clamp(1, 60)
        .toInt();
    final rest = _parseRestMinutes(t);
    final refill = (interval?.$1 ?? rest ?? (mins.length >= 2 ? mins.last : session))
        .clamp(1, 480)
        .toInt();
    final daily = (_parseDailyCapMinutes(t) ??
            previous.dailyMinutes ??
            (mins.length >= 2 ? mins.reduce((a, b) => a > b ? a : b) : 30))
        .clamp(session, 480)
        .toInt();
    final startH = previous.startHour ?? _parseNightStartTime(raw, t)?.$1 ?? 23;
    final startM =
        previous.startMinute ?? _parseNightStartTime(raw, t)?.$2 ?? 0;
    final endH = previous.endHour == 9 ? 7 : previous.endHour;
    final endM = previous.endMinute;
    final label = target.$3;

    return BlockChatPlan(
      action: target.$1 == 'youtube' ? 'youtube_budget' : 'usage_budget',
      limitPlatform: target.$1,
      appId: target.$2,
      dailyMinutes: daily,
      sessionMinutes: session,
      windowMinutes: refill,
      cooldownMinutes: refill,
      startHour: startH,
      startMinute: startM,
      endHour: endH,
      endMinute: endM,
      reply: '$label은 차단 대신 ${_fmt(startH, startM)}~${_fmt(endH, endM)}에 '
          '$session분 쓰고 $refill분 뒤 다시 충전되는 나눠쓰기 방식으로 바꿀게요.',
    );
  }

  static Future<(BlockChatPlan plan, bool usedAi)?> _parseWithAi(
    String userText, {
    BlockChatPlan? previousPlan,
  }) async {
    // AI 미설정 상태를 곧장 "API 키 사서 예산 채우세요" 안내로 보여주면, 로컬
    // 파서가 이해 못 한 애매한 문장(예: "인터넷, 사파리를!!")마다 유료 결제
    // 유도만 하고 정작 더 친절한 "이렇게 말해보세요" 안내(parse()의 최종
    // fallback)는 영영 안 나온다 — AI는 옵트인이 기본(§6.1)인데 거꾸로
    // AI 없이는 아무것도 못 하는 것처럼 보이던 문제(2026-07-10, cage 제보).
    // null을 반환해 호출부가 recommendation·일반 안내로 자연스럽게 이어지게 한다.
    if (!AiClient.isConfigured) return null;

    // previousPlan을 안 실어 보내면 AI가 직전 확인 카드의 맥락(예: 직전이
    // 유튜브 나눠쓰기였다는 것)을 전혀 모른 채 이번 메시지만 보고 판단한다 —
    // "하루 총량은 30분으로 해줘"처럼 대상 앱을 다시 말하지 않는 후속
    // 정정에서 엉뚱한 앱(Instagram)으로 새는 실사용 버그(2026-07-21 제보,
    // Cage에는 이미 있던 컨텍스트 전달을 모아에 이식).
    final contextNote = previousPlan == null
        ? ''
        : '\n\n[직전 확인 카드 — 아래는 참고용 컨텍스트다. 먼저 판단하라: 이번 메시지가 '
            '정말로 이 계획의 시간·앱·모드 등 구체적인 값을 고치는 요청인가?\n'
            '· 맞다면 — 명시적으로 언급된 필드만 바꾸고, 나머지(특히 action/'
            'limit_platform/app_id)는 사용자가 다른 앱·플랫폼을 직접 말하지 않는 한 '
            '유지하세요.\n'
            '· 아니라면(예: "아니라고"/"그게 아니라"/"취소해" 같은 부정·거부 표현, '
            '또는 이 계획과 무관한 새 질문·명령) — 이 컨텍스트는 완전히 무시하고 '
            '이번 메시지만 보고 처음부터 새로 판단하세요. 절대 직전 계획을 그대로 '
            '반복해서 반환하지 마세요.]\n'
            '${jsonEncode(_planToContextJson(previousPlan))}';

    final ai = await AiClient.chat(
      feature: 'block_chat',
      systemPrompt: _system,
      userPrompt: '$userText$contextNote',
      maxTokens: 400,
      temperature: 0.2,
      jsonObject: true,
    );

    if (ai.error == 'budget') {
      return (
        const BlockChatPlan(
          action: 'explain',
          reply: '월 예산이 0이거나 한도를 넘었어요. AI 센터 → 예산 슬라이더를 \$1 이상으로 올려 주세요.',
        ),
        false,
      );
    }

    if (ai.usedAi && ai.content.isNotEmpty) {
      try {
        final j = jsonDecode(ai.content) as Map<String, dynamic>;
        return (BlockChatPlan.fromJson(j), true);
      } catch (e) {
        // 응답은 왔지만 JSON으로 못 바꿨다 — 원인을 로그에 남겨야 나중에
        // "AI가 왜 이렇게 답했는지" 디버깅이 가능하다(2026-[REDACTED] 사용자 요청).
        // 여기서 실패해도 호출 자체는 계속 진행(아래 폴백들로 이어짐).
        if (ai.logId != null) {
          unawaited(AiUsageLogStore.attachParseError(ai.logId!, e.toString()));
        }
      }
    }

    if (ai.error != null && ai.error!.isNotEmpty) {
      return (
        BlockChatPlan(
          action: 'explain',
          reply: 'AI 연결 실패: ${ai.error}\n키·모델·Base URL을 AI 센터에서 확인해 주세요.',
        ),
        false,
      );
    }
    return null;
  }

  static Map<String, dynamic> _planToContextJson(BlockChatPlan p) {
    final j = <String, dynamic>{'action': p.action};
    if (p.limitPlatform != null) j['limit_platform'] = p.limitPlatform;
    if (p.appId != null) j['app_id'] = p.appId;
    if (p.dailyMinutes != null) j['daily_minutes'] = p.dailyMinutes;
    if (p.sessionMinutes != null) j['session_minutes'] = p.sessionMinutes;
    if (p.cooldownMinutes != null) j['cooldown_minutes'] = p.cooldownMinutes;
    if (p.windowMinutes != null) j['window_minutes'] = p.windowMinutes;
    if (p.startHour != null) j['start_hour'] = p.startHour;
    if (p.startMinute != null) j['start_minute'] = p.startMinute;
    j['end_hour'] = p.endHour;
    j['end_minute'] = p.endMinute;
    return j;
  }

  static bool _shouldEscalateLocalToAi(String raw, BlockChatPlan local) {
    final t = raw.toLowerCase().trim();
    if (t.length < 12) return false;

    final hasComplexCue = _hasAny(t, [
      '정확히',
      '알아서',
      '자동으로',
      '복잡',
      '애매',
      '모르겠',
      '추천',
      '상황',
      '대신',
      '조절',
      '변환',
      '전환',
      '바꿔',
      '바꾸',
      '변경',
      '스케줄',
      '한도',
      '제한',
      '총량',
      '충전',
      '리필',
      '쿨다운',
    ]);
    if (!hasComplexCue) return false;

    if (local.action == 'add_keyword' || local.action == 'explain') return true;
    if (local.action == 'platform_limit' &&
        _hasAny(t, ['씩', '마다', '쉬', '충전', '리필', '스탑', '멈춰', '끊'])) {
      return true;
    }
    if ((local.action == 'morning_schedule' ||
            local.action == 'update_schedule_time' ||
            local.action == 'rename_schedule') &&
        _looksLikeUsageBudgetIntent(t)) {
      return true;
    }
    return false;
  }

  static bool _wantsAiEscalation(String raw) {
    final t = raw.toLowerCase();
    return _hasAny(t, [
      'ai',
      '인공지능',
      '더 정교',
      '정교하게',
      '정확하게',
      '내 말 그대로',
      '그대로 해석',
      '프리셋 말고',
      '추천 말고',
      '거기서 더',
      '그 이상',
      '맞춤으로',
      '나한테 맞게',
      '알아서 판단',
      '의도 추론',
      '니가 해줘',
      '네가 해줘',
      '니가 해',
      '네가 해',
      '알아서 해줘',
      '알아서 해',
    ]);
  }

  static BlockChatPlan? _parseCapabilityRecommendation(String raw) {
    final t = raw.toLowerCase().trim();
    if (t.isEmpty) return null;

    final target = _parseUsageBudgetTarget(t);
    if (target != null &&
        _hasAny(t, ['막', '차단', '제한', '줄이', '관리', '못 쓰', '못쓰'])) {
      final label = target.$3;
      final example = target.$1 == 'youtube'
          ? '$label 하루 1시간, 20분씩 보고 1시간 쉬게 해줘'
          : '$label 하루 40분, 10분씩 쓰고 30분 쉬게 해줘';
      return BlockChatPlan(
        action: 'explain',
        reply: '$label 관리는 앱에서 가능해요.\n'
            '바로 쓸 수 있는 방식은 ① 하루 총량 한도 ② 몇 분씩 나눠 쓰기 ③ 특정 시간대 차단이에요.\n'
            '예: 「$example」\n'
            '더 복잡한 조건이면 「AI로 내 말 그대로 맞춰줘」라고 이어서 말해 주세요.',
      );
    }

    if (_hasAny(t, ['사이트', '웹사이트', '성인', '도박', '카지노', '토토', '불법'])) {
      return const BlockChatPlan(
        action: 'explain',
        reply: '사이트 차단은 앱에서 가능해요.\n'
            '바로 쓸 수 있는 방식은 ① 도메인 직접 차단 ② 성인/도박류 프리셋 적용 ③ 스케줄에 웹 차단 묶기예요.\n'
            '예: 「도박 사이트 프리셋 켜줘」 또는 「example.com 막아줘」\n'
            '더 넓게 추론해야 하면 「AI로 관련 사이트까지 추론해줘」라고 이어서 말해 주세요.',
      );
    }

    if (_hasAny(t, ['sns', '릴스', '쇼츠', '무한스크롤', '둠스크롤'])) {
      return const BlockChatPlan(
        action: 'explain',
        reply: 'SNS 줄이기는 앱에서 가능해요.\n'
            '추천 프리셋은 ① 릴스/쇼츠 숨김 ② 하루 한도 ③ 10분 쓰고 쉬기 ④ 야간 SNS 차단이에요.\n'
            '예: 「인스타 하루 45분, 15분씩 쉬게」 또는 「밤 11시부터 SNS 막아줘」',
      );
    }

    return null;
  }

  /// "모든 음란물을 차단해줘" 같은 포괄 요청 — category=adult 메타데이터가 아니라
  /// PremadeBlockPackService 의 실제 통합 팩(사이트+유튜브+게시판 수백 개)을 적용한다.
  static BlockChatPlan? _parseApplyPremadePack(String t) {
    final mentionsAdult = _hasAny(t, ['음란물', '성인물', '야동']) ||
        (_hasAny(t, ['성인']) && _hasAny(t, ['사이트', '컨텐츠', '콘텐츠']));
    if (!mentionsAdult) return null;
    if (!_hasAny(t, ['모든', '전부', '전체', '싹', '다'])) return null;
    if (!_hasAny(t, ['차단', '막', '블락', '블록', 'block'])) return null;

    return const BlockChatPlan(
      action: 'apply_premade_pack',
      presetId: PremadeBlockPackService.adultCombinedPackId,
      suggestTimelock: true,
      reply: '음란물 통합 차단 팩을 적용할게요. 사이트·유튜브 채널·게시판까지 한 번에 막습니다.',
    );
  }

  /// "모든 게임 채널 차단해줘" — 특정 채널명이 아니라 장르/주제 전체를 AI로 잡는 요청.
  /// ChannelGenreAiService.applyTopicLabel 로 라우팅 (topicLabel 필요).
  static BlockChatPlan? _parseBlockGenre(String t) {
    if (!_hasAny(t, ['채널'])) return null;
    if (!_hasAny(t, ['차단', '막', '블락', '블록', 'block'])) return null;
    // 따옴표로 특정 채널명을 콕 집었으면 장르가 아니라 그 채널 하나를 말하는
    // 거라 block_channel에 양보한다.
    if (t.contains('"') || t.contains('“') || t.contains('”') || t.contains("'")) {
      return null;
    }

    // "모든/전부/전체/싹" 없이 "게임 채널을 차단해줘"처럼 그냥 말해도 장르로
    // 인식해야 하는데, 예전엔 이 수식어가 꼭 있어야만 잡혀서 "게임"을 진짜
    // 채널 이름으로 오인해 아무 효과 없는 block_channel로 새던 버그였다
    // (2026-07-11 cage 제보 — "게임 채널을 차단해줘!"가 효과 없이 처리됨).
    const genreMap = {
      '게임': ['게임'],
      '뉴스': ['뉴스'],
      '먹방': ['먹방'],
      '음악': ['음악'],
      '뷰티': ['뷰티', '메이크업'],
      '스포츠': ['스포츠'],
    };
    for (final entry in genreMap.entries) {
      if (_hasAny(t, entry.value)) {
        return BlockChatPlan(
          action: 'block_genre',
          topicLabel: entry.key,
          reply: '「${entry.key}」 관련 채널을 찾아 한꺼번에 차단할게요.',
        );
      }
    }
    return null;
  }

  /// "주식 관련 앱들을 차단해주라" — 증권앱은 종류가 다양하고 실제 패키지ID를 지어낼 수 없어서,
  /// 바로 차단하는 대신 어떤 앱/URL인지 되물어 사용자가 지정하면 기존 block_website·add_keyword로
  /// 처리한다. finance_guidance 액션은 CHAT_SPEC target.category=finance 에 대응.
  static BlockChatPlan? _parseFinanceGuidance(String t) {
    if (!_hasAny(t, ['주식', '증권'])) return null;
    if (!_hasAny(t, ['앱', '차단', '막'])) return null;
    return const BlockChatPlan(
      action: 'finance_guidance',
      reply: '주식·증권 앱은 종류가 많아서, 어떤 앱을 막을지 말씀해 주시면 바로 차단해드려요.\n'
          '예: "토스증권 막아줘", "삼성증권 앱 차단해줘" — 앱 이름이나 URL을 알려주세요.',
    );
  }

  /// "카카오톡 밤에 통째로 블락 말고, 10분마다 3분만 보기로 변형해줘" — 기존 스케줄의 모드를
  /// 전체차단→구간제한으로 바꾼다(SCHEDULE_CONVERT). "N분마다"=window, "M분만"=session 을
  /// 명확한 정규식으로 구분 — 순서로 추측하면 실사용 버그(잠금/락 오파싱)처럼 뒤바뀔 수 있다.
  static BlockChatPlan? _parseConvertScheduleMode(String t) {
    if (!_hasAny(t, ['말고', '아니라', '대신'])) return null;
    if (!_hasAny(t, ['변형', '바꿔', '바꾸', '전환'])) return null;

    final windowMatch = RegExp(r'(\d+)\s*분\s*마다').firstMatch(t);
    final sessionMatch = RegExp(r'(\d+)\s*분\s*만').firstMatch(t);
    if (windowMatch == null || sessionMatch == null) return null;
    final window = int.tryParse(windowMatch.group(1)!);
    final session = int.tryParse(sessionMatch.group(1)!);
    if (window == null || session == null) return null;

    String? appId;
    String label;
    if (_hasAny(t, ['카카오', '카톡', 'kakao'])) {
      appId = 'kakao';
      label = '카카오톡';
    } else if (_hasAny(t, ['틱톡', 'tiktok'])) {
      appId = 'tiktok';
      label = 'TikTok';
    } else if (_hasAny(t, ['유튜브', 'youtube'])) {
      appId = 'youtube_app';
      label = 'YouTube';
    } else if (_hasAny(t, ['인스타', 'instagram'])) {
      appId = 'instagram';
      label = 'Instagram';
    } else {
      return null;
    }

    return BlockChatPlan(
      action: 'convert_schedule_mode',
      scheduleQuery: '$label 밤',
      appId: appId,
      sessionMinutes: session,
      windowMinutes: window,
      reply: '$label 밤 스케줄을 전체차단 대신 $window분마다 $session분만 보는 방식으로 바꿀게요.',
    );
  }

  /// "카카오톡 추가해줘"/"~에서 하나 더 추가할래"/"틱톡 빼줘"류 — 이미 있는
  /// 스케줄에 앱 하나를 더 걸거나 빼는 요청. 앱 이름이 카탈로그에서 인식되면
  /// (카카오·틱톡·유튜브·인스타·크롬·브런치·사파리) 바로 실행 계획을 만들고,
  /// 카탈로그 밖 앱이면 executor가 Screen Time 추가 선택으로 안내한다
  /// (2026-[REDACTED] 사용자 요청 — 전엔 이 패턴이 로컬 파서에 아예 없어서 매번
  /// AI로 새고, AI도 앱 이름을 app_id에 자유 텍스트로만 담아 explain으로
  /// 죽는 실사용 버그가 있었다: "게임 pc방 인증 앱에서 하나 더 추가할래!!").
  /// 스케줄을 어떤 것으로 볼지는 raw 문장 전체를 [BlockChatScheduleResolver]에
  /// 넘겨 fuzzy 매칭에 맡긴다 — 여기서 이름을 잘라내려 하면 오히려 신호를
  /// 잃는다(그 리졸버는 원래 자유 문장을 받게 설계됨).
  static BlockChatPlan? _parseModifyScheduleApps(String raw, String t) {
    final isAdd = _hasAny(t, ['추가', '더 넣', '더할래', '하나 더']);
    final isRemove = !isAdd &&
        _hasAny(t, ['빼줘', '빼줄래', '빼줄게', '제거해', '제거할래', '삭제해', '삭제할래', '지워줘']);
    if (!isAdd && !isRemove) return null;

    final target = _parseUsageBudgetTarget(t);
    if (target == null) return null; // 앱 이름이 없으면 기존 explain/AI 흐름에 맡긴다.

    final label = target.$3;
    return BlockChatPlan(
      action: 'modify_schedule_apps',
      appId: target.$2 ?? target.$1,
      limitPlatform: target.$1,
      scheduleQuery: raw,
      toggleOn: isAdd,
      reply: isAdd
          ? '$label을(를) 스케줄에 추가할게요.'
          : '$label을(를) 스케줄에서 뺄게요.',
    );
  }

  /// "모든 차단 초기화해줘"/"차단 전부 리셋" 류 — 앱 전체 차단 설정을 통째로
  /// 지우는 파괴적 커맨드(07-09 사용자 요청, cage에서 먼저 구현 후 이식).
  /// "OO 관련"처럼 특정 앱을 좁혀 말하는 [_parseResetReapply] 류와 구분하기
  /// 위해 "모든/전부/전체" 같은 전체-지시어를 반드시 요구한다.
  static BlockChatPlan? _parseResetAllBlocks(String t) {
    if (!_hasAny(t, ['모든', '전부', '전체'])) return null;
    if (!_hasAny(t, ['차단', '블락', '설정'])) return null;
    if (!_hasAny(t, ['초기화', '리셋', 'reset'])) return null;
    return const BlockChatPlan(
      action: 'reset_all_blocks',
      reply: '지금 만든 모든 스케줄·차단·한도 설정을 전부 초기화합니다. 되돌릴 수 없어요.',
    );
  }

  /// "유튜브 뮤직 블락 관련 스케줄 전부 초토화, 리셋 이후에 다시 아래 스케줄으로
  /// 덮어쓰기 해줘: 매일 밤 10시부터 아침 7시까지 차단" — RESET_REAPPLY 복합명령.
  /// persona_bundle 의 순차 subPlans 패턴을 그대로 재사용(신규 엔진 아님):
  /// [remove_schedule(대상), <콜론 뒤 새 명령을 재귀 파싱한 plan>].
  static BlockChatPlan? _parseResetReapply(String raw, String t) {
    if (!_hasAny(t, ['초토화', '리셋'])) return null;
    if (!_hasAny(t, ['덮어쓰기', '다시'])) return null;

    final colonIdx = raw.indexOf(':');
    if (colonIdx < 0) return null;
    final beforeColon = raw.substring(0, colonIdx);
    final afterColon = raw.substring(colonIdx + 1).trim();
    if (afterColon.isEmpty) return null;

    final targetMatch =
        RegExp(r'^(.*?)\s*(관련|블락|차단)').firstMatch(beforeColon.trim());
    final scheduleQuery = targetMatch?.group(1)?.trim();
    if (scheduleQuery == null || scheduleQuery.isEmpty) return null;

    final newPlan = _parseLocal(afterColon);
    if (newPlan == null) return null;

    return BlockChatPlan(
      action: 'reset_reapply',
      reply: '「$scheduleQuery」 관련 스케줄을 정리하고 새 스케줄로 다시 적용할게요.',
      subPlans: [
        BlockChatPlan(
          action: 'remove_schedule',
          scheduleQuery: scheduleQuery,
          reply: '',
        ),
        newPlan,
      ],
    );
  }

  // "나눠쓰기" 계열뿐 아니라 완전 차단(night_schedule) 생성도 포함 — 다른
  // 이름의 기존 스케줄이 이미 같은 대상을 겹치게 막고 있으면 조용히 하나 더
  // 만들지 않고 "덮어쓸까요?"부터 물어본다(2026-07-11 cage 제보: 겹치는
  // 야간 스케줄이 병합 없이 중복 생성됨).
  static const _rationActions = {
    'music_foreground_limit',
    'youtube_budget',
    'usage_budget',
    'night_schedule',
  };

  /// 사용자가 이미 특정 스케줄을 답한 게 아니면(scheduleQuery 없음), 나눠쓰기
  /// 요청이 적용될 대상과 겹치는 "다른" 활성 스케줄이 2개 이상 있는지 확인한다.
  /// 있으면 바로 적용하지 않고 "전부 덮어쓸까요, 하나만 고를까요?"를 먼저 물어서
  /// 사용자가 모르는 사이 다른 스케줄이 그대로 남아 충돌하는 걸 막는다
  /// (2026-07-11 cage 요청).
  static BlockChatPlan _withOverwriteConfirmIfNeeded(BlockChatPlan plan) {
    if (plan.scheduleQuery != null) return plan;
    if (!_rationActions.contains(plan.action)) return plan;
    // 파서는 원래 순수 함수(부작용·스토어 읽기 없음)였는데, 이 확인 흐름만
    // BlockScheduleStore를 읽는다 — 앱에서는 항상 열려 있지만, 파서를 단독으로
    // 부르는 기존 테스트들은 이 박스를 안 열어서 예외가 났다(2026-07-11). 안 열려
    // 있으면 확인 없이 그냥 진행(기존 동작 유지)한다.
    if (!BlockScheduleStore.isOpen) return plan;

    final tag = plan.action == 'music_foreground_limit'
        ? 'youtube_music'
        : (plan.action == 'youtube_budget'
            ? 'youtube'
            : (plan.appId ?? plan.limitPlatform ?? ''));
    if (tag.isEmpty) return plan;

    final ownName = plan.scheduleName;
    final conflicts = BlockScheduleStore.loadAll()
        .where((s) => s.enabled)
        .where((s) => ownName == null || s.name != ownName)
        .where((s) => BlockChatRationTag.matches(s, tag))
        .map((s) => s.name)
        .toSet()
        .toList();
    // 다른 스케줄이 1개만 있어도 조용히 방치하면 그 스케줄이 계속 완전 차단을
    // 걸어 새 나눠쓰기와 충돌할 수 있으므로, 1개 이상이면 항상 먼저 물어본다.
    if (conflicts.isEmpty) return plan;

    final label = BlockChatRationTag.label(tag);
    final question = conflicts.length == 1
        ? '지금 「$label」 관련 스케줄이 하나 더 있어요: ${conflicts.first}\n\n'
            '이것도 덮어쓸까요, 아니면 그대로 둘까요? 아래에서 골라주세요.'
        : '지금 「$label」 관련 스케줄이 ${conflicts.length}개 있어요: '
            '${conflicts.join(' · ')}\n\n'
            '전부 덮어쓸까요, 아니면 하나만 골라서 바꿀까요? 아래에서 골라주세요.';
    return plan.copyWith(
      action: 'explain',
      pendingConfirmAction: plan.action,
      overwriteCandidates: conflicts,
      reply: question,
      // 이름을 타이핑하지 않아도 되게 — 후보 스케줄마다 탭 한 번으로 고를 수
      // 있는 칩을 준다. value는 _parseOverwriteConfirmReply가 그대로 받아
      // 매칭하는 문자열과 동일해야 한다("전부" 또는 스케줄 이름 포함 텍스트).
      quickReplies: [
        for (final name in conflicts)
          BlockChatQuickReplyOption(label: name, value: name),
        const BlockChatQuickReplyOption(label: '전부 덮어쓰기', value: '전부'),
      ],
    );
  }

  /// 위 질문 이후 후속 답변("전부"/스케줄 이름)을 실제 실행 계획으로 복원한다.
  static BlockChatPlan? _parseOverwriteConfirmReply(
    String t,
    BlockChatPlan previous,
  ) {
    if (previous.action != 'explain' || previous.pendingConfirmAction == null) {
      return null;
    }
    final realAction = previous.pendingConfirmAction!;
    if (_hasAny(t, ['전부', '모두', '다 ', '전체', '다덮어', '다 덮어'])) {
      final actionLabel =
          realAction == 'night_schedule' ? '차단' : '나눠쓰기 설정';
      return previous.copyWith(
        action: realAction,
        pendingConfirmAction: '',
        overwriteCandidates: const [],
        scheduleQuery: '__ALL__',
        reply:
            '${BlockChatRationTag.label(_tagFromAction(realAction, previous))} 관련 '
            '기존 스케줄을 전부 정리하고 새 $actionLabel을 적용할게요.',
      );
    }
    final candidates = previous.overwriteCandidates ?? const [];
    for (final name in candidates) {
      if (t.contains(name.toLowerCase())) {
        return previous.copyWith(
          action: realAction,
          pendingConfirmAction: '',
          overwriteCandidates: const [],
          scheduleQuery: name,
          reply: '「$name」만 정리하고 새 나눠쓰기 설정을 적용할게요.',
        );
      }
    }
    return null;
  }

  /// "둘 다 적용" / "아니요, 괜찮습니다" — 멀티 타깃 야간 차단 확인.
  static BlockChatPlan? _parseMultiApplyConfirmReply(
    String t,
    BlockChatPlan previous,
  ) {
    if (previous.pendingConfirmAction != 'reset_reapply') return null;
    final subs = previous.subPlans;
    if (subs == null || subs.isEmpty) return null;

    final no = _hasAny(t, ['아니요', '아니오', '괜찮', '싫', '취소', '안 할래', 'no']);
    if (no) {
      return previous.copyWith(
        action: 'explain',
        pendingConfirmAction: '',
        subPlans: const [],
        quickReplies: const [],
        reply: '적용하지 않았어요.',
      );
    }
    final yes =
        _hasAny(t, ['둘 다', '전부', '적용', '네', '예', '응', '좋아', '오케이', 'ok', 'yes']);
    if (yes) {
      return previous.copyWith(
        action: 'reset_reapply',
        pendingConfirmAction: '',
        quickReplies: const [],
        reply: '둘 다 같은 조건으로 적용할게요.',
      );
    }
    return null;
  }

  /// "방금 그거 취소" — 어떤 종류의 확인 질문(멀티 타깃/덮어쓰기/모호한 시간 등)이든
  /// 상관없이, 아직 아무것도 적용 안 된 질문 단계를 그냥 접는 공통 처리.
  /// 각 질문의 전용 "아니요" 처리보다 뒤에서 최후 수단으로만 동작한다.
  static BlockChatPlan? _parseGenericQuestionCancel(
    String t,
    BlockChatPlan previous,
  ) {
    if (previous.action != 'explain') return null;
    final hasPendingQuestion =
        (previous.pendingConfirmAction?.isNotEmpty ?? false) ||
            (previous.quickReplies?.isNotEmpty ?? false);
    if (!hasPendingQuestion) return null;
    if (!_hasAny(t, ['취소', '안 할래', '그만할래', '됐어', '됐다', '아니 됐', '넘어가'])) {
      return null;
    }
    return previous.copyWith(
      action: 'explain',
      pendingConfirmAction: '',
      quickReplies: const [],
      subPlans: const [],
      reply: '취소했어요.',
    );
  }

  static String _tagFromAction(String action, BlockChatPlan plan) {
    if (action == 'music_foreground_limit') return 'youtube_music';
    if (action == 'youtube_budget') return 'youtube';
    return plan.appId ?? plan.limitPlatform ?? '';
  }

  /// "어제처럼 해줘" — 실제로 재적용하지 않고, 어제 있었던 성공한 명령 이력을
  /// 버튼으로 보여준다. 사용자가 그중 하나를 고르면 그 원문 명령을 그대로
  /// 다시 보낸 것처럼 재파싱해 확인 카드부터 다시 거친다(2026-07-11 cage 요청).
  static BlockChatPlan? _parseYesterdayLikeQuestion(String t) {
    if (!_hasAny(t, ['어제처럼', '어제랑 같이', '어제 한 거', '어제 한거', '어제 했던', '어제같이', '어제 그거', '어제 그대로'])) {
      return null;
    }
    if (!BlockAuditLogStore.isOpen) {
      return const BlockChatPlan(
        action: 'explain',
        reply: '어제 기록을 아직 못 불러와요. 잠시 후 다시 시도해 주세요.',
      );
    }
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final entries = BlockAuditLogStore.loadRecent()
        .where((e) => e.success)
        .where(
          (e) =>
              e.at.year == yesterday.year &&
              e.at.month == yesterday.month &&
              e.at.day == yesterday.day,
        )
        .toList();
    if (entries.isEmpty) {
      return const BlockChatPlan(
        action: 'explain',
        reply: '어제 있었던 차단·임시 허용 기록이 없어요.',
      );
    }

    final chips = entries.take(8).map((e) {
      final hh = e.at.hour.toString().padLeft(2, '0');
      final mm = e.at.minute.toString().padLeft(2, '0');
      final firstLine = e.summary.split('\n').first;
      final short =
          firstLine.length > 20 ? '${firstLine.substring(0, 20)}…' : firstLine;
      return BlockChatQuickReplyOption(label: '$short ($hh:$mm)', value: e.command);
    }).toList();

    return BlockChatPlan(
      action: 'explain',
      reply: '어제 있었던 차단·임시 허용 기록이에요. 그대로 다시 적용하려면 아래에서 골라주세요.',
      quickReplies: chips,
    );
  }

  /// "타임락 기본을 20분으로 해줘" — 새로 만드는 스케줄에 기본으로 걸리는
  /// 설정 잠금(타임락) 분을 바꾼다. 최소 15분(즉시 해제로 의지가 약해지는 걸
  /// 막기 위한 방침, 2026-07-11) — 그 밑으로는 못 내려간다.
  static BlockChatPlan? _parseDefaultLockCooldown(String t) {
    if (!_hasAny(t, [
      '타임락 기본',
      '기본 타임락',
      '기본 잠금',
      '잠금 기본',
      '설정 잠금 기본',
      '기본 설정 잠금',
    ])) {
      return null;
    }
    final mins = _parseAllMinutes(t);
    if (mins.isEmpty) return null;
    final n = mins.first.clamp(15, 180).toInt();
    final note = mins.first < 15 ? ' (최소 15분이라 15분으로 맞췄어요)' : '';
    return BlockChatPlan(
      action: 'set_default_lock_cooldown',
      dailyMinutes: n,
      reply: '앞으로 새로 만드는 스케줄은 기본으로 $n분 설정 잠금이 걸려요.$note',
    );
  }

  /// "아침 알림을 9시로 바꿔줘" — 매일 뜨는 요약 알림 시각 변경.
  static BlockChatPlan? _parseMorningNotificationTime(String raw, String t) {
    if (!_hasAny(t, ['아침 알림', '모닝 알림'])) return null;
    final time = _parseEndTime(t);
    if (time == null) return null;
    return BlockChatPlan(
      action: 'set_morning_notification_time',
      startHour: time.$1,
      startMinute: time.$2,
      reply: '아침 알림을 매일 ${_fmt(time.$1, time.$2)}에 보낼게요.',
    );
  }

  /// "지금부터 3시간동안 유튜브 차단해줘" — 매일 반복 스케줄이 아니라 지금
  /// 이 순간부터 N시간만 한 번 막는 일회성 요청. `QuickBlockService`(구 6VPN
  /// "빠른 차단" — 세션 타이머, 이미 존재하던 시스템)를 그대로 재사용한다.
  /// 예전엔 이 문구가 night_schedule/morning_schedule로 잘못 흡수돼 "지금부터"가
  /// 무시되고 엉뚱한 매일-반복 스케줄이 생겼다(2026-07-11 cage 제보).
  static BlockChatPlan? _parseQuickBlockNow(String t) {
    // "지금부터"가 없어도 "N시간 동안 차단해줘"는 이미 "지금부터 N시간"이란
    // 뜻이다 — 원래 "지금부터"를 리터럴로 요구해서 "인터넷 브라우저 4시간
    // 동안 차단해줘"가 여기서 안 걸리고, 뒤에 있는 (절대 시각 전용)
    // 아침/야간 차단 파서로 잘못 새서 "4시간"의 "시간"을 "4시"로 오인식해
    // "매일 0시~4시"라는 전혀 다른 스케줄이 됐다(2026-07-13 실사용 확인).
    final hasNowCue = _hasAny(t, ['지금부터', '지금 부터', '이제부터']);
    final hasDurationCue = t.contains('동안');
    // "동안"·"지금부터" 둘 다 없이 "N시간"만 쓴 경우("인터넷 2시간간 차단해둬")도
    // — "까지"(절대 종료시각을 뜻하는 명시적 단어)가 없으면 여전히 "지금부터
    // N시간"이란 뜻으로 읽는 게 자연스럽다. "까지"가 있으면(예: "밤 9시까지
    // 차단해줘") 절대 시각 스케줄이므로 제외한다(2026-07-13 실사용 확인).
    // "하루"·"마다"·"씩"이 같이 있으면 "하루 1시간에 20분씩 끊는 모드로
    // 바꿔줘" 같은 반복 예산(usage budget) 전환 요청이지 "지금부터 1시간만
    // 차단"이 아니다 — 이 신호가 있으면 bare-hour 트리거를 켜지 않는다
    // (2026-07-13 회귀 발견: "유튜브 차단 스케줄 이제 하루 1시간에 20분씩
    // 끊는 모드로 바꿔줘"가 youtube_budget 대신 quick_block_now로 샘).
    // "1시간에 10분 허락해줘"/"완전 차단 제외 시간에는 ... 허락" 같은 리필·
    // 예외 요청도 quick_block_now(전체 즉시차단)로 잘못 흡수되던 실사용 버그
    // (2026-07-21 제보 — "유튜브 완전 차단 제외 시간에는 1시간에 10분
    // 허락해줘"가 "완전 **차단**"의 "차단" 키워드에 걸려 엉뚱하게 70분
    // 전체차단이 됨). "N시간에 M분" 인터벌 패턴이나 "허락/허용/제외" 같은
    // 예외·리필 신호가 있으면 quick_block_now를 켜지 않고 뒤쪽 usage_budget류
    // 파서가 처리하게 둔다.
    final hasIntervalRefillCue =
        RegExp(r'\d+\s*(?:시간|분)\s*(?:마다|에)\s*\d+\s*분').hasMatch(t);
    final looksLikeRecurringBudget =
        _hasAny(t, ['하루', '마다', '씩', '허락', '허용', '제외']) ||
            hasIntervalRefillCue;
    // "24시간 차단해줘"/"온종일"/"항상"/"계속" 같은 "하루 종일·영구" 신호가 있으면
    // "24시간"의 "시간"이 상대적 지속시간(quick_block_now)이 아니라 "하루 전체를
    // 매일 차단"이라는 뜻이다 — 이 신호가 있으면 bare-hour 트리거를 켜지 않고
    // 뒤쪽의 always-on(morning_schedule/night_schedule) 파서가 처리하게 둔다
    // (2026-07-14 회귀 발견: "사파리랑 유튜브는 24시간 차단해줘"가 영구 스케줄
    // 대신 24시간짜리 일회성 quick_block_now로 잘못 흡수됨).
    final looksLikeAllDayPermanent = _hasAny(t, [
      '24시간',
      '24 시간',
      '하루종일',
      '하루 종일',
      '온종일',
      '종일',
      '항상',
      '계속',
    ]);
    // "3일간 차단해줘"처럼 일(日) 단위 기간은 "지금부터"/"동안"/"시간" 문구가
    // 전혀 없어도 그 자체로 상대 기간 신호다 — 이걸 못 읽으면 다른 함수(대상
    // 앱의 "영구" 매일 차단)로 새서 "3일"이 통째로 사라지는 실사용 버그
    // (2026-07-13, cage에서 발견한 것과 같은 클래스 — "유튜브 뮤직 3일간
    // 차단해줘"가 매일 00:00–23:59 영구 스케줄이 됨).
    final daysMatch = RegExp(r'(\d+)\s*일\s*(?:간|동안)?').firstMatch(t);
    final hasBareHourDuration = RegExp(r'\d+\s*시간').hasMatch(t) &&
        !t.contains('까지') &&
        !looksLikeRecurringBudget &&
        !looksLikeAllDayPermanent;
    // "유튜브 뮤직 1분간 차단해줘"처럼 "간" 접미사가 붙은 순수 분 단위 기간은
    // 위 hasBareHourDuration("시간"만 체크)도, hasDurationCue("동안"만 체크)도
    // 못 잡아서 아래 게이트를 전부 통과 못 하고 조용히 null로 새 — 결국 이
    // 함수 밖의 "시간대 언급 없음" 폴백이 하루 종일 영구 차단으로 잘못 처리하던
    // 실사용 버그(2026-07-21, Cage에서 먼저 발견·수정된 것과 동일 클래스: 거긴
    // "1시간동안"은 되는데 "1분간"은 안 되는 비대칭이었음). 숫자+시간/분 바로
    // 뒤에 차단 동사가 붙는 패턴을 추가로 인정해서 "간"/"동안" 여부와 무관하게
    // 잡는다.
    final bareDurationBeforeBlockVerb = RegExp(
          r'\d+\s*(?:시간|분)\s*(?:동안|간)?\s*(?:은|는)?\s*(?:막|차단|블락|블록|금지)',
        ).hasMatch(t) &&
        !looksLikeRecurringBudget &&
        !looksLikeAllDayPermanent;
    if (!hasNowCue &&
        !hasDurationCue &&
        !hasBareHourDuration &&
        !bareDurationBeforeBlockVerb &&
        daysMatch == null) {
      return null;
    }
    if (!_hasAny(t, ['차단', '막', '블락', '블록', 'block'])) return null;

    // 시(hour) 단위만 받아서 "30분 동안 차단해줘"처럼 분 단위 요청이 그냥
    // null로 새 최후수단 add_keyword로 문장 전체가 키워드 등록되던 문제
    // (Cage에서 2026-07-13 발견한 것과 같은 클래스 — 분 단위도 받게 확장).
    final hourMatch = RegExp(r'(\d+)\s*시간').firstMatch(t);
    final minuteMatch = RegExp(r'(\d+)\s*분').firstMatch(t);
    if (daysMatch == null && hourMatch == null && minuteMatch == null) {
      return null;
    }
    final days = daysMatch != null ? int.tryParse(daysMatch.group(1)!) ?? 0 : 0;
    final hours = hourMatch != null ? int.tryParse(hourMatch.group(1)!) ?? 0 : 0;
    final minutes =
        minuteMatch != null ? int.tryParse(minuteMatch.group(1)!) ?? 0 : 0;
    // 최대 30일 — QuickBlockService 세션은 절대시각(endsAt) 기준으로
    // 스스로 만료되니 상한을 넉넉히 둬도 안전하다.
    final totalMinutes =
        (days * 24 * 60 + hours * 60 + minutes).clamp(1, 30 * 24 * 60);

    // "유튜브 뮤직 3일간 차단해줘"가 _parseUsageBudgetTarget의 "유튜브"
    // 키워드 매칭에 뭉뚱그려져 일반 유튜브로 오분류되던 갭 — 다른
    // night_schedule류 함수들엔 이미 있던 isMusic 분기가 이 함수엔 없었다
    // (2026-07-13).
    final isMusic = _hasAny(t, ['뮤직', 'music', 'ytm']);
    final isBrowser = !isMusic && _hasAny(t, ['브라우저', 'browser', '크롬', 'chrome']);
    final target = _parseUsageBudgetTarget(t);
    final appId = !isMusic && target?.$1 == 'app' ? target?.$2 : null;
    final limitPlatform = isMusic
        ? 'youtube_music'
        : target != null && target.$1 != 'app'
            ? target.$1
            : null;
    final label = isMusic
        ? 'YouTube Music'
        : (isBrowser ? '브라우저' : (target?.$3 ?? '선택한 앱'));
    final durationLabel = totalMinutes % (24 * 60) == 0
        ? '${totalMinutes ~/ (24 * 60)}일'
        : totalMinutes % 60 == 0
            ? '${totalMinutes ~/ 60}시간'
            : '$totalMinutes분';

    // 이 액션(quick_block_now)은 QuickBlockService → Screen Time 경유로만
    // 동작한다 — Isle 인앱 웹뷰만 즉시·일시적으로 막는 별도 경로가 없다.
    // 그런데 사용자가 "인앱"/"isle"이라고 명시해도 이 사실을 안 알려주고
    // 똑같이 "차단합니다"라고만 답해서, 매번 Screen Time 기준으로 조용히
    // 적용되는 걸 인앱 전용으로 오해하게 만들던 실사용 버그(2026-07-13
    // 사용자 대화로그에서 확인 — "인앱 유튜브 5시간 차단해줘"가 "오늘 유튜브
    // 5시간 차단해줘"와 완전히 동일하게 처리됨). 인앱 전용 임시차단 자체를
    // 새로 구현하는 대신, 최소한 뭘 어떻게 적용했는지 정직하게 알려준다.
    final wantsIsleOnly = _hasAny(t, ['인앱', 'isle', '이슬', '이젤']);
    final reply = wantsIsleOnly
        ? '지금부터 $durationLabel 동안 $label을 차단합니다(Screen Time 기준 — 인앱 전용 '
            '임시차단은 아직 지원하지 않아 시스템 전체에 적용돼요). 시간이 지나면 자동으로 풀려요.'
        : '지금부터 $durationLabel 동안 $label을 차단합니다. 시간이 지나면 자동으로 풀려요.';

    return BlockChatPlan(
      action: 'quick_block_now',
      windowMinutes: totalMinutes,
      appId: appId,
      limitPlatform: isBrowser ? 'safari' : limitPlatform,
      reply: reply,
    );
  }

  /// "매일 22:30-14:00은 유튜브를 10분에 5분씩 허가해줘. 그리고 23:00부터
  /// 13:00까지는 유튜브를 아예 블락해줘." — 한 문장(정확히는 "그리고"로 이어진
  /// 두 문장)에 나눠쓰기 구간과 완전 차단 구간이 겹쳐 있는 요청. 예전엔 각
  /// 절이 서로 덮어써서 완전히 엉뚱한 스케줄 하나만 남았다(2026-07-11 cage
  /// 제보). 차단 구간이 나눠쓰기 구간에 완전히 포함될 때만 지원 — 나눠쓰기
  /// 구간을 앞/뒤 두 조각으로 쪼개 같은 세션·창으로 다시 걸고, 차단 구간은
  /// 별도 완전 차단 스케줄로 만든다.
  static BlockChatPlan? _parseCompoundRationAndBlock(String raw) {
    if (!raw.contains('그리고')) return null;
    final idx = raw.indexOf('그리고');
    final clauseA = raw.substring(0, idx).trim();
    final clauseB = raw.substring(idx + '그리고'.length).trim();
    if (clauseA.isEmpty || clauseB.isEmpty) return null;

    BlockChatPlan? parseClause(String clause) {
      final ct =
          _applySelfCorrection(_normalizeCommonTypos(clause.toLowerCase().trim()));
      if (ct.isEmpty) return null;
      return _parseNightRefillUsageBudget(clause, ct) ??
          _parseNightSchedule(clause, ct);
    }

    final planA = parseClause(clauseA);
    final planB = parseClause(clauseB);
    if (planA == null || planB == null) return null;

    bool isRation(BlockChatPlan p) =>
        p.action == 'youtube_budget' || p.action == 'usage_budget';
    bool isBlock(BlockChatPlan p) => p.action == 'night_schedule';

    BlockChatPlan ration;
    BlockChatPlan block;
    if (isRation(planA) && isBlock(planB)) {
      ration = planA;
      block = planB;
    } else if (isRation(planB) && isBlock(planA)) {
      ration = planB;
      block = planA;
    } else {
      return null;
    }

    if (ration.startHour == null || ration.startMinute == null) return null;
    if (block.startHour == null) return null;

    final rationTag = ration.appId ?? ration.limitPlatform ?? '';
    final blockTag = block.appId ?? block.limitPlatform ?? '';
    if (rationTag.isEmpty || rationTag != blockTag) return null;

    int mod(int x) => ((x % 1440) + 1440) % 1440;
    final rStart = ration.startHour! * 60 + ration.startMinute!;
    final rEndAbs = ration.endHour * 60 + ration.endMinute;
    final rLen = mod(rEndAbs - rStart) == 0 ? 1440 : mod(rEndAbs - rStart);
    final bStart = block.startHour! * 60 + (block.startMinute ?? 0);
    final bEndAbs = block.endHour * 60 + block.endMinute;
    final bLen = mod(bEndAbs - bStart) == 0 ? 1440 : mod(bEndAbs - bStart);

    final bStartRel = mod(bStart - rStart);
    final bEndRel = bStartRel + bLen;
    // 차단 구간이 나눠쓰기 구간 안에 완전히 들어있을 때만 분할 지원 —
    // 그 외(부분 겹침·분리) 조합은 안전하게 지원 범위 밖으로 남겨둔다.
    if (bStartRel < 0 || bEndRel > rLen) return null;

    final label = _rationTagLabelForCompound(rationTag);
    final segLines = <String>[];
    final extra = <int>[];

    final seg1Start = rStart;
    final seg1End = bStart;
    if (seg1Start != seg1End) {
      segLines.add(
        '${_fmtMinuteOfDay(seg1Start)}~${_fmtMinuteOfDay(seg1End)} $label 나눠쓰기 '
        '(${ration.sessionMinutes}분/${ration.windowMinutes}분)',
      );
    }
    segLines.add(
      '${_fmtMinuteOfDay(bStart)}~${_fmtMinuteOfDay(bEndAbs)} $label 완전 차단',
    );
    final seg3Start = bEndAbs;
    final seg3End = rEndAbs;
    if (seg3Start != seg3End) {
      extra
        ..add(seg3Start)
        ..add(seg3End);
      segLines.add(
        '${_fmtMinuteOfDay(seg3Start)}~${_fmtMinuteOfDay(seg3End)} $label 나눠쓰기 '
        '(${ration.sessionMinutes}분/${ration.windowMinutes}분)',
      );
    }

    final rationPlan = ration.copyWith(
      action: 'night_schedule',
      scheduleName: '야간 $label 나눠쓰기 (AI)',
      startHour: seg1Start ~/ 60,
      startMinute: seg1Start % 60,
      endHour: seg1End ~/ 60,
      endMinute: seg1End % 60,
      extraSlotMinutes: extra.isEmpty ? null : extra,
      disableFuzzyDedup: true,
    );
    final blockPlan = block.copyWith(
      scheduleName: '야간 $label 완전 차단 (AI)',
      disableFuzzyDedup: true,
    );

    return BlockChatPlan(
      action: 'explain',
      pendingConfirmAction: 'reset_reapply',
      subPlans: [rationPlan, blockPlan],
      reply: '$label 하루 흐름을 이렇게 만들까요?\n\n${segLines.join('\n')}',
      quickReplies: const [
        BlockChatQuickReplyOption(label: '적용', value: '적용'),
        BlockChatQuickReplyOption(label: '아니요, 괜찮습니다', value: '아니요, 괜찮습니다'),
      ],
    );
  }

  /// "11:30까지는 인터넷 브라우저 차단해주고 그 이후로 22:30까지는 20분쓰고
  /// 40분 쉬는 방식으로 해줘" — 하루를 "앞부분 완전 차단 + 뒷부분 나눠쓰기"로
  /// 순서대로(안 겹치게) 나누는 요청. `_parseCompoundRationAndBlock`은
  /// "그리고"로만 잇고 차단 구간이 나눠쓰기 구간 "안에 포함"될 때만 지원해서,
  /// 이렇게 시간이 순서대로 이어지는 두 구간엔 안 걸렸다. 뒷 절엔 대상(브라우저
  /// 등) 언급이 없는 게 자연스러운 화법이라 앞 절의 대상을 이어받는다
  /// (2026-07-13 실사용 확인 — 원래 아무 파서에도 안 걸리고 explain 폴백으로 샜음).
  static BlockChatPlan? _parseCompoundBlockThenRation(String raw) {
    const connectors = [
      '그 이후로',
      '그이후로',
      '이후로는',
      '이후에는',
      '그 다음은',
      '그다음은',
      '그 이후엔',
      '이후엔',
    ];
    var idx = -1;
    var usedConnector = '';
    for (final c in connectors) {
      final i = raw.indexOf(c);
      if (i > 0 && (idx == -1 || i < idx)) {
        idx = i;
        usedConnector = c;
      }
    }
    if (idx <= 0) return null;
    final clauseA = raw.substring(0, idx).trim();
    final clauseB = raw.substring(idx + usedConnector.length).trim();
    if (clauseA.isEmpty || clauseB.isEmpty) return null;

    final ctA =
        _applySelfCorrection(_normalizeCommonTypos(clauseA.toLowerCase().trim()));
    if (!_hasAny(ctA, ['막', '차단', '블락', '블록', 'block'])) return null;

    final target = _parseUsageBudgetTarget(ctA);
    if (target == null) return null;
    final blockEnd = _parseNightEndTime(clauseA, ctA);
    if (blockEnd == null) return null;

    // 뒤 절은 대상(타깃) 단어만 이어받고, 시작 시각도 "차단이 끝나는 시각"으로
    // 명시해 합성한다 — 콜론(HH:MM) 표기라 _parseNightStartTime의 "9~11시는
    // 밤으로 추정" 오전/오후 어림짐작 분기를 안 타서 안전하다. 앞 절의 원문을
    // 통째로 붙이면 앞 절 자신의 "~까지" 시각이 뒤 절 종료 시각으로 잘못
    // 재매칭돼 뒷부분이 통째로 사라지는 버그가 있었다(2026-07-13 확인) — 그래서
    // 타깃 키워드 하나만 뽑아 붙인다.
    final targetKeyword = _appAliasCatalog
        .firstWhere((e) => e.$1 == target.$1 && e.$2 == target.$2)
        .$4
        .firstWhere((k) => ctA.contains(k.toLowerCase()), orElse: () => target.$3);
    final synthStart = _fmtMinuteOfDay(blockEnd.$1 * 60 + blockEnd.$2);
    final synthClauseB = '$targetKeyword $synthStart부터 $clauseB';
    final ctB = _applySelfCorrection(
        _normalizeCommonTypos(synthClauseB.toLowerCase().trim()));
    final rationPlan = _parseNightRefillUsageBudget(synthClauseB, ctB);
    if (rationPlan == null) return null;
    if (rationPlan.action != 'usage_budget' &&
        rationPlan.action != 'youtube_budget') {
      return null;
    }

    final label = target.$3;
    final appId = target.$1 == 'app' ? target.$2 : null;
    final limitPlatform = target.$1 != 'app' ? target.$1 : null;

    final blockPlan = BlockChatPlan(
      action: 'night_schedule',
      scheduleName: '$label 아침 차단 (AI)',
      startHour: 0,
      startMinute: 0,
      endHour: blockEnd.$1,
      endMinute: blockEnd.$2,
      appId: appId,
      limitPlatform: limitPlatform,
      disableFuzzyDedup: true,
    );
    final rationPlanTagged = rationPlan.copyWith(
      scheduleName: '$label 나눠쓰기 (AI)',
      disableFuzzyDedup: true,
    );

    final blockLabel =
        '${_fmtMinuteOfDay(0)}~${_fmtMinuteOfDay(blockEnd.$1 * 60 + blockEnd.$2)}';
    final rationStart =
        (rationPlan.startHour ?? blockEnd.$1) * 60 + (rationPlan.startMinute ?? blockEnd.$2);
    final rationEnd = rationPlan.endHour * 60 + rationPlan.endMinute;
    final rationLabel = '${_fmtMinuteOfDay(rationStart)}~${_fmtMinuteOfDay(rationEnd)}';

    return BlockChatPlan(
      action: 'explain',
      pendingConfirmAction: 'reset_reapply',
      subPlans: [blockPlan, rationPlanTagged],
      reply: '$label 하루 흐름을 이렇게 만들까요?\n\n'
          '$blockLabel $label 완전 차단\n'
          '$rationLabel $label ${rationPlan.sessionMinutes}분 쓰고 ${rationPlan.cooldownMinutes}분 쉬기',
      quickReplies: const [
        BlockChatQuickReplyOption(label: '적용', value: '적용'),
        BlockChatQuickReplyOption(label: '아니요, 괜찮습니다', value: '아니요, 괜찮습니다'),
      ],
    );
  }

  static String _fmtMinuteOfDay(int minuteOfDay) {
    final m = ((minuteOfDay % 1440) + 1440) % 1440;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  static String _rationTagLabelForCompound(String tag) =>
      BlockChatRationTag.label(tag);

  static BlockChatPlan? _parseLocal(String rawInput) {
    // 아래 많은 파서(_parseNightSchedule 등)가 `t`(정규화·소문자)가 아니라
    // 대소문자 보존이 필요한 `raw`를 직접 정규식에 쓴다 — "N시반"→"N시 30분"
    // 정규화를 `t`에만 적용하면 그 파서들엔 "반"이 그대로 남아 분(分)이
    // 사라진다(2026-07-13 실사용 확인: "밤 11시반부터 유튜브 차단해줘"가 11시
    // 30분이 아니라 기본값 21시로 새어나감). `raw`도 같은 정규화를 거치게 한다.
    final raw = _normalizeHalfHourClockWords(rawInput);
    final t =
        _applySelfCorrection(_normalizeCommonTypos(raw.toLowerCase().trim()));
    if (t.isEmpty) return null;

    // 날짜 구간 예약("내일부터 3일간"/"7월25일부터 7월30일까지")은 아래
    // "미래 시작 미지원" 안내(_mentionsFutureStart)나 quick_block_now 등
    // 다른 파서보다 먼저 잡아야 한다 — 2026-07-20부터 미래 시작 자체를
    // 정식 지원하므로, 이 문장들이 "미지원" 안내로 새거나 즉시 적용으로
    // 오해되면 안 된다.
    final scheduledReservation = _parseScheduledReservation(raw, t);
    if (scheduledReservation != null) return scheduledReservation;

    // "앱 켠 지 30분"류 앱 실행 트리거도 같은 이유로 quick_block_now(같은
    // "동안"/"N분" 신호를 씀)보다 먼저 잡아야 한다.
    final appOpenTrigger = _parseAppOpenBlockTrigger(raw, t);
    if (appOpenTrigger != null) return appOpenTrigger;

    // "내일부터"/"다음주부터"/"모레부터"처럼 나중에 시작하는 예약 표현인데
    // 위 예약 파서가 못 잡은 경우(기간·대상 불명확 등) — 이 앱엔 원래
    // "미래 시작" 개념 자체가 없어서, 예전엔 이 말을 그냥 무시하고
    // 스케줄을 오늘 즉시 적용해버렸다(2026-07-13 실사용 확인 — "내일
    // 아침부터 유튜브 뮤직을... 차단해줘"가 조용히 오늘부터 적용됨,
    // Cage에서 먼저 발견해 이식). 정직하게 미지원을 안내한다.
    if (_mentionsFutureStart(t) &&
        _hasAny(t, ['막', '차단', '블락', '블록', 'block'])) {
      return const BlockChatPlan(
        action: 'explain',
        reply: '아직 "내일부터"·"다음주부터"처럼 나중에 시작하는 예약은 지원 안 해요 '
            '— 지금은 말하는 즉시 적용돼요. 지금 바로 적용해도 괜찮으면 '
            '"내일부터" 없이 다시 말해 주세요.',
      );
    }

    final studyMode = _parseStudyMode(raw, t);
    if (studyMode != null) return studyMode;

    final focusModeTrigger = _parseFocusModeTrigger(t);
    if (focusModeTrigger != null) return focusModeTrigger;

    final yesterdayLike = _parseYesterdayLikeQuestion(t);
    if (yesterdayLike != null) return yesterdayLike;

    final defaultLockCooldown = _parseDefaultLockCooldown(t);
    if (defaultLockCooldown != null) return defaultLockCooldown;

    final morningNotifTime = _parseMorningNotificationTime(raw, t);
    if (morningNotifTime != null) return morningNotifTime;

    final quickBlockNow = _parseQuickBlockNow(t);
    if (quickBlockNow != null) return quickBlockNow;

    final compound = _parseCompoundRationAndBlock(raw);
    if (compound != null) return compound;

    final compoundBlockThenRation = _parseCompoundBlockThenRation(raw);
    if (compoundBlockThenRation != null) return compoundBlockThenRation;

    final premadePack = _parseApplyPremadePack(t);
    if (premadePack != null) return premadePack;

    // reset_reapply(콜론 뒤 덮어쓰기 지정)가 더 구체적인 패턴이라 먼저 검사—
    // 안 그러면 "전부 초토화, 리셋..." 같은 문장이 아래 reset_all_blocks에
    // 잘못 가로채인다.
    final resetReapply = _parseResetReapply(raw, t);
    if (resetReapply != null) return resetReapply;

    final resetAll = _parseResetAllBlocks(t);
    if (resetAll != null) return resetAll;

    final convertMode = _parseConvertScheduleMode(t);
    if (convertMode != null) return convertMode;

    final modifyScheduleApps = _parseModifyScheduleApps(raw, t);
    if (modifyScheduleApps != null) return modifyScheduleApps;

    final genre = _parseBlockGenre(t);
    if (genre != null) return genre;

    final financeGuidance = _parseFinanceGuidance(t);
    if (financeGuidance != null) return financeGuidance;

    final statusQuery = _parseStatusQuery(t);
    if (statusQuery != null) return statusQuery;

    final safariPause = _parseSafariPause(raw, t);
    if (safariPause != null) return safariPause;

    final nightRefillBudget = _parseNightRefillUsageBudget(raw, t);
    if (nightRefillBudget != null) {
      return _withOverwriteConfirmIfNeeded(nightRefillBudget);
    }

    // 요일별/주간 총량 요청은 다른 "늘려/줄여" 파서(나눠쓰기 연장 등)보다
    // 먼저 잡아야 한다 — 안 그러면 "일요일엔...", "이번주..." 같은 한정어가
    // 무시되고 "몇 시를 의미하신 건가요?" 같은 엉뚱한 되묻기로 샌다.
    final ytWeekdayLimit = _parseYoutubeWeekdayLimit(t);
    if (ytWeekdayLimit != null) return ytWeekdayLimit;

    final ytWeeklyLimit = _parseYoutubeWeeklyLimit(t);
    if (ytWeeklyLimit != null) return ytWeeklyLimit;

    // 이미 켜져 있는 나눠쓰기 스케줄을 "늘려/연장/줄여"만 하는 의도는 새로 만드는
    // 일반 경로(_parseUsageBudget)보다 먼저 체크해야 한다 — 그 경로는 언급 안 된
    // 필드까지 하드코딩 기본값으로 재작성해버린다.
    final usageBudgetExtend = _parseUsageBudgetExtend(raw, t);
    if (usageBudgetExtend != null) return usageBudgetExtend;

    final usageBudget = _parseUsageBudget(t);
    if (usageBudget != null) return _withOverwriteConfirmIfNeeded(usageBudget);

    final reelsGuard = _parseReelsGuardToggle(t);
    if (reelsGuard != null) return reelsGuard;

    final allDayBlock = _parseAllDayBlockSchedule(raw, t);
    if (allDayBlock != null) return allDayBlock;

    final multiCategoryNightBlock = _parseMultiCategoryNightBlock(raw, t);
    if (multiCategoryNightBlock != null) {
      return _withOverwriteConfirmIfNeeded(multiCategoryNightBlock);
    }

    // "브라우저는 10시부터 쓸 수 있게 해줘"처럼 "차단"이란 말 없이 시작 경계
    // 하나만 말하는 문장 — _parseNightSchedule보다 먼저 잡아야 한다(아래는
    // "허용/열어/풀"을 보면 무조건 relaxOnly로 판단해 그냥 버리기 때문).
    final allowFromMorning = _parseAllowFromMorningBlock(raw, t);
    if (allowFromMorning != null) {
      return _withOverwriteConfirmIfNeeded(allowFromMorning);
    }

    final night = _parseNightSchedule(raw, t);
    if (night != null) return _withOverwriteConfirmIfNeeded(night);

    final removeUrlEarly = _parseRemoveUrl(raw, t);
    if (removeUrlEarly != null) return removeUrlEarly;

    final persona = BlockChatPersonaParser.parse(raw, t);
    if (persona != null) return persona;

    final website = _parseBlockWebsite(raw, t);
    if (website != null) return website;

    final blockUrl = _parseBlockUrl(raw, t);
    if (blockUrl != null) return blockUrl;

    final channel = _parseBlockChannel(raw, t);
    if (channel != null) return channel;

    final platformLimit = _parsePlatformLimit(t);
    if (platformLimit != null) return platformLimit;

    final shorts = _parseShortsToggle(t);
    if (shorts != null) return shorts;

    final reels = _parseReelsToggle(t);
    if (reels != null) return reels;

    final musicFg = _parseMusicForegroundBackground(raw, t);
    if (musicFg != null) return _withOverwriteConfirmIfNeeded(musicFg);

    final scheduleMut = _parseScheduleMutation(raw, t);
    if (scheduleMut != null) return scheduleMut;

    final allowWindow = _parseAllowWindow(raw, t);
    if (allowWindow != null) return allowWindow;

    final isleYt = _parseIsleYoutubeSchedule(raw, t);
    if (isleYt != null) return isleYt;

    final relax = _parseRelaxBlock(raw, t);
    if (relax != null) return relax;

    final habit = _parseMorningHabitConcern(raw, t);
    if (habit != null) return habit;

    final ytLimit = _parseYoutubeLimit(t);
    if (ytLimit != null) return ytLimit;

    // "브라우저"·"웹"·"인터넷"도 사용자가 Safari를 부르는 일상 표현이다 —
    // 원래 "사파리"/"safari" 리터럴만 잡아서 "아침에는 인터넷 브라우저
    // 못보도록 차단해줘" 같은 문장은 유튜브도 안 나오고 "사파리"도 안 나와
    // 아무 파서에도 안 걸리고 explain 폴백으로 샜다. 시각도 명시 안 하면
    // (`time == null`) 그냥 조용히 통과시켜서 같은 문장이 또 새는 원인이었다
    // (2026-07-13 실사용 확인) — 명시 안 하면 기상 시간 기준 오전 9시 기본값.
    if (_hasAny(t, ['사파리', 'safari', '브라우저', '웹', '인터넷']) &&
        _hasAny(t, [
          '막',
          '차단',
          '블락',
          '블록',
          'block',
          '못 보',
          '못보',
          '보지 못',
          '못하게',
          '안 되',
          '안되',
        ])) {
      final time = _parseEndTime(t);
      final hour = time?.$1 ?? 9;
      final minute = time?.$2 ?? 0;
      final noExplicitTimeNote = time == null
          ? ' 몇 시까지인지 말씀 안 하셔서 기상 시간 기준 오전 9시까지로 잡았어요.'
          : '';
      return BlockChatPlan(
        action: 'morning_schedule',
        scheduleName: '아침 Safari 차단',
        endHour: hour,
        endMinute: minute,
        blockSafariNote: true,
        reply:
            '매일 0시~${_fmt(hour, minute)} 스케줄 — Isle 웹·Safari 차단.$noExplicitTimeNote',
        // 기본값(9시)을 조용히 골라줬을 때, 채팅으로 다시 시간을 안 쳐도
        // 바로 탭 한 번으로 흔한 기상 시각으로 바꿀 수 있게 — 각 값은
        // "N시까지"만이 아니라 완결된 문장이라 _parseLocal이 컨텍스트 없이도
        // 바로 다시 파싱한다(2026-07-13, UI에 시각 선택지 노출 요청).
        quickReplies: time == null
            ? const [
                BlockChatQuickReplyOption(label: '7시까지', value: '아침에 인터넷 브라우저 7시까지 차단해줘'),
                BlockChatQuickReplyOption(label: '9시까지', value: '아침에 인터넷 브라우저 9시까지 차단해줘'),
                BlockChatQuickReplyOption(label: '11시까지', value: '아침에 인터넷 브라우저 11시까지 차단해줘'),
              ]
            : null,
      );
    }

    // "인스타/SNS N시까지 못 보게/차단" → morning_schedule (아침 차단)
    if (_hasAny(t, ['인스타', 'instagram', 'sns']) &&
        _hasAny(t, ['막', '차단', '블락', '블록', 'block', '못 보', '보지 못', '못하게'])) {
      final time = _parseEndTime(t);
      if (time != null && _hasAny(t, ['까지', '아침', '오전', '매일'])) {
        return BlockChatPlan(
          action: 'morning_schedule',
          scheduleName: '아침 Instagram 차단',
          endHour: time.$1,
          endMinute: time.$2,
          reply: '매일 0시~${_fmt(time.$1, time.$2)} 스케줄 — Instagram 앱 차단',
        );
      }
    }

    // "숏츠/릴스 N시까지 막아줘" → morning_schedule (아침 숏츠 차단)
    if (_hasAny(t, ['숏츠', 'shorts', '숏폼']) &&
        _hasAny(t, ['막', '차단', '블락', '블록', 'block', '못 보', '못하게'])) {
      final time = _parseEndTime(t);
      if (time != null) {
        return BlockChatPlan(
          action: 'morning_schedule',
          scheduleName: '아침 Shorts 차단',
          endHour: time.$1,
          endMinute: time.$2,
          blockIsleYoutube: true,
          reply: '매일 0시~${_fmt(time.$1, time.$2)} 스케줄 — Isle 유튜브(숏츠 포함) 차단',
        );
      }
    }

    // '스타'만으로 매칭하면 "인스타(그램)"의 부분 문자열과 겹쳐서
    // "인스타 3일간 차단해줘" 같은 요청이 엉뚱하게 '스타크래프트' 키워드
    // 차단으로 새는 실사용 버그(2026-07-13)가 있었다 — "인스타"를 포함하면
    // 제외한다.
    final mentionsStarcraft = _hasAny(t, ['스타크래프트', 'starcraft']) ||
        (t.contains('스타') && !t.contains('인스타'));
    if (mentionsStarcraft &&
        _hasAny(t, ['블락', '블록', '차단', '숨김', '안 보', 'block', '그만'])) {
      return const BlockChatPlan(
        action: 'add_keyword',
        keyword: '스타크래프트',
        reply: '유튜브·피드에서 「스타크래프트」 키워드를 숨깁니다.',
      );
    }

    final explicitKw = _extractExplicitKeyword(raw, t);
    if (explicitKw != null) {
      return BlockChatPlan(
        action: 'add_keyword',
        keyword: explicitKw,
        reply: '유튜브·피드에서 「$explicitKw」 키워드를 숨깁니다.',
      );
    }

    final noMore = _extractNoMoreKeyword(raw, t);
    if (noMore != null &&
        _hasAny(t, ['블락', '블록', '차단', '숨김', '그만', '안 보', 'block'])) {
      return BlockChatPlan(
        action: 'add_keyword',
        keyword: noMore,
        reply: '키워드 「$noMore」를 숨깁니다.',
      );
    }

    final ytKw = _extractYoutubeKeyword(raw, t);
    if (ytKw != null) {
      return BlockChatPlan(
        action: 'add_keyword',
        keyword: ytKw,
        reply: '키워드 「$ytKw」를 숨깁니다.',
      );
    }

    final session = _parseAppSessionLimit(t);
    if (session != null) return session;

    if (_hasAny(t, ['키워드', 'keyword']) &&
        _hasAny(t, ['제거', '해제', '풀어', '삭제', 'remove'])) {
      final kw = _extractQuoted(raw) ?? _extractBeforeBlock(t);
      if (kw != null) {
        return BlockChatPlan(
          action: 'remove_keyword',
          removeKeyword: kw,
          reply: '키워드 「$kw」 제거 — 제거 타임락이 켜져 있으면 대기 후 자동으로 해제돼요.',
        );
      }
    }

    final removeUrl = _parseRemoveUrl(raw, t);
    if (removeUrl != null) return removeUrl;

    final ambiguousDuration = _parseAmbiguousDurationQuestion(raw, t);
    if (ambiguousDuration != null) return ambiguousDuration;

    if (_looksLikeSchedule(t)) return null;

    final quoted = _extractQuoted(raw);
    if (quoted != null &&
        _hasAny(t, ['블락', '블록', '차단', '숨김', '키워드', 'block'])) {
      return BlockChatPlan(
        action: 'add_keyword',
        keyword: quoted,
        reply: '키워드 「$quoted」를 숨깁니다.',
      );
    }

    final beforeBlock = _extractBeforeBlock(t);
    if (beforeBlock != null && _hasAny(t, ['블락', '블록', '차단', '숨김', 'block'])) {
      return BlockChatPlan(
        action: 'add_keyword',
        keyword: beforeBlock,
        reply: '키워드 「$beforeBlock」를 숨깁니다.',
      );
    }

    return null;
  }

  /// "틱톡 30분만" 류 — 하루 총량인지, 시간당 세션인지 구분할 단서가 전혀 없는
  /// 순수 "N분만" 요청. 마음대로 추측해서 잘못 적용하느니 세 가지 선택지를
  /// 버튼으로 물어본다(2026-07-11 cage 요청).
  static BlockChatPlan? _parseAmbiguousDurationQuestion(String raw, String t) {
    if (_hasAny(t, ['뮤직', 'music', 'ytm'])) return null; // YTM은 전용 경로
    if (_hasAny(t, ['차단', '막', '금지', '블록', 'block', '해제', '취소', '삭제'])) {
      return null; // 완전 차단·해제 의도는 다른 파서가 맡는다
    }
    final hasDailyCue = _hasAny(t, ['하루', '총', '일일', '전체', '총량']);
    final hasIntervalCue = _hasAny(t, ['마다', '시간에', '1시간', '시간당', '매시간']) ||
        _matchIntervalThenSession(t) != null;
    if (hasDailyCue || hasIntervalCue) return null;

    final m =
        RegExp(r'(\d+)\s*분\s*만').firstMatch(_normalizeKoreanDurationWords(t));
    if (m == null) return null;
    final n = int.tryParse(m.group(1)!);
    if (n == null || n <= 0 || n > 300) return null;

    final target = _parseUsageBudgetTarget(t);
    if (target == null) return null;
    final label = target.$3;
    final appId = target.$1 == 'app' ? target.$2 : null;
    final limitPlatform = target.$1 != 'app' ? target.$1 : null;

    // n(모호했던 분)을 dailyMinutes에 잠깐 실어 보낸다 — 이 plan은 action이
    // 'explain'이라 그 자체로는 실행 안 되고, 사용자가 버튼을 누른 뒤
    // _parseAmbiguousDurationReply가 pendingConfirmAction으로 이 값을 찾아
    // 실제 계획을 만든다.
    return BlockChatPlan(
      action: 'explain',
      appId: appId,
      limitPlatform: limitPlatform,
      dailyMinutes: n,
      pendingConfirmAction: 'ambiguous_duration',
      reply: '「$label」을 하루 $n분만 쓰게 할지, $n분씩 나눠 쓰게 할지 헷갈려서 여쭤봐요.',
      quickReplies: [
        BlockChatQuickReplyOption(label: '하루 $n분', value: '$label 하루 $n분'),
        BlockChatQuickReplyOption(
          label: '1시간에 $n분씩',
          value: '$label 1시간에 $n분씩',
        ),
        const BlockChatQuickReplyOption(
          label: '조금 더 세부적으로…',
          value: '__info__:예를 들어 이렇게 말해보세요.\n'
              '"하루 40분, 10분씩 나눠 써"(하루 총량 + 한 번에 쓰는 시간)\n'
              '"1시간마다 10분만"(한 번 + 충전 주기)\n'
              '"밤 11시부터 아침 7시까지 10분씩만"(시간대 + 한 번에 쓰는 시간)',
        ),
      ],
    );
  }

  /// 위 질문의 버튼 응답("하루 N분" / "1시간에 N분씩") — usage_budget 엔진(카운터가
  /// 있는 시스템은 이거 하나뿐)으로 직접 계획을 만든다. 자유 텍스트 재파싱에
  /// 기대지 않고 여기서 확정하는 이유는, 일반 앱(틱톡 등)의 "그냥 하루 총량만"은
  /// 세션·리필 개념이 없는 별도 한도 시스템이 없어 재파싱이 실패하기 때문
  /// (2026-07-11 확인).
  static BlockChatPlan? _parseAmbiguousDurationReply(
    String t,
    BlockChatPlan previous,
  ) {
    if (previous.pendingConfirmAction != 'ambiguous_duration') return null;
    final n = previous.dailyMinutes;
    if (n == null) return null;
    final appId = previous.appId;
    final limitPlatform = previous.limitPlatform;
    final tag = appId ?? limitPlatform ?? '';
    final label = BlockChatRationTag.label(tag);
    final action = limitPlatform == 'youtube' ? 'youtube_budget' : 'usage_budget';

    if (t.contains('하루')) {
      return BlockChatPlan(
        action: action,
        appId: appId,
        limitPlatform: limitPlatform,
        dailyMinutes: n,
        sessionMinutes: n,
        windowMinutes: 1440,
        cooldownMinutes: 1440,
        reply: '$label을 하루 $n분만 쓰도록 설정할게요. 다 쓰면 다음 날까지 잠겨요.',
      );
    }
    if (t.contains('시간')) {
      return BlockChatPlan(
        action: action,
        appId: appId,
        limitPlatform: limitPlatform,
        sessionMinutes: n,
        windowMinutes: 60,
        cooldownMinutes: 60,
        reply: '$label을 1시간마다 $n분씩 쓰도록 설정할게요.',
      );
    }
    return null;
  }

  /// "8시반"(= 8시 30분)처럼 시각에 "반"(半)을 쓰는 표기가 흔한데, 어느 시간
  /// 추출 정규식도 "반"을 몰라서 30분이 통째로 사라졌다(2026-07-13 실사용
  /// 확인: "아침에는 유튜브 못키게 막아줘!! 8시반까지"가 8시 30분이 아니라
  /// 8시로 잘림) — "N시 30분"으로 미리 풀어써서 기존 "시/분" 정규식이 그대로
  /// 잡게 한다.
  static String _normalizeHalfHourClockWords(String t) {
    return t.replaceAllMapped(
      RegExp(r'(\d{1,2})\s*시\s*반'),
      (m) => '${m.group(1)}시 30분',
    );
  }

  static final RegExp _futureStartRe =
      RegExp(r'(내일|모레|다음\s*주|다음\s*달)\s*[가-힣]{0,4}\s*부터');

  static bool _mentionsFutureStart(String t) => _futureStartRe.hasMatch(t);

  static String _normalizeCommonTypos(String t) {
    return t
        .replaceAll('차당', '차단')
        .replaceAll('차댱', '차단')
        .replaceAll('차잔', '차단')
        .replaceAll('햐줘', '해줘')
        .replaceAll('블락', '블록');
  }

  /// "인스타 10분마다 3분, 아니 5분" — 한 문장 안에서 스스로 정정한 숫자.
  /// 정정 전 숫자(3)가 그대로 남아 있으면 뒤쪽 파서들이 "먼저 나온 숫자"를
  /// 세션·한도로 잘못 집어버린다(2026-07-11 확인) — 정정 대상 숫자를 아예
  /// 지우고 정정된 숫자만 남겨서, 뒤 파서들이 원래 하나만 있었던 것처럼 보게 한다.
  static String _applySelfCorrection(String t) {
    final re = RegExp(r'\d+\s*분(?:씩|만)?\s*[,，]?\s*(?:아니|아니라|말고|아니고)\s*(\d+)\s*분');
    final m = re.firstMatch(t);
    if (m == null) return t;
    return t.replaceRange(m.start, m.end, '${m.group(1)}분');
  }

  /// 기존 스케줄 수정·해제 — 정확한 이름 없이 키워드만으로
  static BlockChatPlan? _parseScheduleMutation(String raw, String t) {
    final creatingNew = _looksLikeSchedule(t) &&
        _hasAny(t, ['막', '차단', '만들', '설정', '추가해', 'block']) &&
        !_hasAny(t, [
          '바꿔',
          '변경',
          '이름',
          '연장',
          '확장',
          '줄여',
          '늘려',
          '빼',
          '제거',
          '해제',
          '끄',
          '없애',
          '삭제',
          '꺼',
        ]);
    if (creatingNew) return null;

    final q = _extractScheduleQueryHint(raw, t);
    final hasScheduleCue = _hasAny(t, ['스케줄', 'schedule']) ||
        (q != null &&
            _hasAny(t, [
              '바꿔',
              '변경',
              '이름',
              '연장',
              '확장',
              '줄여',
              '늘려',
              '끄',
              '없애',
              '제거',
              '해제',
              '삭제',
              '추가',
              '빼',
              '꺼',
            ])) ||
        (_hasAny(t, ['지금', '활성', '켜진', '방금', '아까', '최근']) &&
            _hasAny(t, ['끄', '꺼', '해제', '없애', '제거', '삭제']));

    if (!hasScheduleCue) return null;

    // "사파리/인스타/유튜브 차단 해제" without "스케줄" → relax_block이 처리
    if (t.contains('차단 해제') && !_hasAny(t, ['스케줄', 'schedule'])) return null;

    final query = q ?? '';

    // "23:00 - 11:00"처럼 콜론(HH:MM) 시각 범위만 쓰고 "까지"/"시각" 같은
    // 한국어 단서가 없는 문장도 시간 변경 의도로 인정 — 안 그러면 아래
    // rename_schedule 정규식에 잘못 걸려 스케줄 이름이 그 문자열로 깨짐
    // (실사용 치명적 버그, cage에서 07-08 진단·수정 후 이식).
    final hasClockTimeRange = RegExp(r'\d{1,2}:\d{2}').hasMatch(t);
    if ((_hasAny(t, ['까지', '종료', '시간', '시각']) || hasClockTimeRange) &&
        _hasAny(t, ['바꿔', '변경', '연장', '확장', '줄여', '늘려', '단축', '맞춰'])) {
      final time = _parseEndTime(t);
      if (time != null) {
        // usage_budget용 _isAmbiguousBareHour와 같은 판정 — bare "N시"는
        // 오전/오후 표기가 없으면 24시간제로 조용히 단정하지 않고 되묻는다.
        if (_isAmbiguousBareHour(t, time.$1)) {
          final altHour = time.$1 <= 12 ? time.$1 + 12 : time.$1 - 12;
          return BlockChatPlan(
            action: 'explain',
            reply: '${_fmt(time.$1, time.$2)}까지로 바꿀까요, 아니면 '
                '${_fmt(altHour, time.$2)}($altHour시)를 의미하신 건가요? '
                '오전/오후를 붙여서 다시 말씀해 주세요.\n'
                '예: "새벽 ${time.$1}시까지" 또는 "오후 ${time.$1}시까지"',
          );
        }
        return BlockChatPlan(
          action: 'update_schedule_time',
          scheduleQuery: query,
          endHour: time.$1,
          endMinute: time.$2,
          reply: '종료 시각을 ${_fmt(time.$1, time.$2)}까지로 바꿉니다.',
        );
      }
    }

    if (_hasAny(t, ['이름', '명칭', 'rename']) &&
        _hasAny(t, ['바꿔', '변경', '해줘', '해'])) {
      final newName = _extractNewScheduleName(raw, t);
      if (newName != null) {
        return BlockChatPlan(
          action: 'rename_schedule',
          scheduleQuery: query,
          scheduleNewName: newName,
          reply: '스케줄 이름을 「$newName」으로 바꿉니다.',
        );
      }
    }

    final renameTo = RegExp(
      r'(.+?)\s*로\s*(이름|명칭|스케줄명)?\s*(바꿔|변경|해)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (renameTo != null) {
      var newName = renameTo.group(1)!.trim();
      newName = newName.replaceAll(RegExp(r'^(스케줄|이름)\s*'), '').trim();
      if (newName.length >= 2 &&
          !_hasAny(t, ['까지', '시각', '종료']) &&
          !RegExp(r'\d+\s*시').hasMatch(newName) &&
          !RegExp(r'\d{1,2}:\d{2}').hasMatch(newName)) {
        return BlockChatPlan(
          action: 'rename_schedule',
          scheduleQuery: query,
          scheduleNewName: newName,
          reply: '스케줄 이름을 「$newName」으로 바꿉니다.',
        );
      }
    }

    if (_hasAny(t, ['추가', '넣어', '포함', '넣']) && _hasDayTokens(t)) {
      final days = _parseDays(t);
      return BlockChatPlan(
        action: 'add_schedule_days',
        scheduleQuery: query,
        days: days,
        reply:
            '스케줄에 ${ScheduleDisplayHelper.formatDaysPattern(days.toSet())} 요일을 추가합니다.',
      );
    }

    if (_hasAny(t, ['빼', '제외', '빼줘']) &&
        _hasDayTokens(t) &&
        !_hasAny(t, ['스케줄', '전부', '삭제', '해제', '없애'])) {
      final days = _parseDays(t);
      return BlockChatPlan(
        action: 'remove_schedule_days',
        scheduleQuery: query,
        days: days,
        reply:
            '스케줄에서 ${ScheduleDisplayHelper.formatDaysPattern(days.toSet())} 요일을 뺍니다.',
      );
    }

    if (_hasAny(t, ['제거', '해제', '풀어', '삭제', 'unblock', '끄', '없애', '꺼'])) {
      return BlockChatPlan(
        action: 'remove_schedule',
        scheduleQuery: query,
        removeScheduleQuery: query,
        reply: query.isNotEmpty
            ? '「$query」 스케줄 해제 — 타임락이 켜져 있으면 대기 후 자동으로 꺼져요.'
            : '스케줄 해제 — 타임락이 켜져 있으면 대기 후 자동으로 꺼져요.',
      );
    }

    return null;
  }

  static String? _extractScheduleQueryHint(String raw, String t) {
    final quoted = _extractQuoted(raw);
    if (quoted != null && _hasAny(t, ['스케줄', '이름', '바꿔', '변경', '끄', '해제'])) {
      return quoted;
    }
    if (t.contains('사파리') || t.contains('safari')) return 'safari';
    if (t.contains('인스타')) return '인스타';
    if (t.contains('유튜브') || t.contains('youtube')) return '유튜브';
    if (t.contains('틱톡') || t.contains('tiktok')) return '틱톡';
    if (t.contains('아침')) return '아침';
    if (t.contains('저녁') || t.contains('야간') || t.contains('밤')) return '야간';
    if (_hasAny(t, ['방금', '아까', '최근', '어제', '만든'])) return 'ai';
    if (_hasAny(t, ['지금', '활성', '켜진', '진행'])) return '';
    return null;
  }

  static String? _extractNewScheduleName(String raw, String t) {
    final quoted = RegExp(r'이름을?\s*[「『"]([^」』"]+)[」』"]').firstMatch(raw);
    if (quoted != null) return quoted.group(1)?.trim();

    final plain = RegExp(r'이름을?\s*(.+?)\s*으로?\s*(?:바꿔|변경|해)').firstMatch(raw);
    if (plain != null) {
      var name = plain.group(1)!.trim();
      if (name.endsWith('으')) name = name.substring(0, name.length - 1);
      if (name.length >= 2) return name;
    }

    final to = RegExp(
      r'(.+?)\s*로\s*(이름|명칭|스케줄명)?\s*(바꿔|변경|해)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (to != null) {
      var name = to.group(1)!.trim();
      name = name.replaceAll(RegExp(r'^(스케줄|이름)\s*'), '').trim();
      if (name.length >= 2) return name;
    }
    return null;
  }

  static bool _hasDayTokens(String t) {
    return _hasAny(t, [
          '월',
          '화',
          '수',
          '목',
          '금',
          '토',
          '일',
          '평일',
          '주말',
          '매일',
        ]) ||
        RegExp(r'[월화수목금토일]요일').hasMatch(t);
  }

  static BlockChatPlan? _parseAllDayBlockSchedule(String raw, String t) {
    final blockCue = _hasAny(t, [
      '막',
      '차단',
      '블락',
      '블록',
      'block',
      '금지',
      '안 되',
      '안되',
      '못 쓰',
      '못쓰',
      '못 보',
      '못보',
    ]);
    if (!blockCue) return null;
    final negativeViewCue = _hasAny(t, ['못 보게', '못보게', '안 보게', '안보게']);
    if (!negativeViewCue && _hasAny(t, ['풀', '해제', '허용', '보게', '열어', '다시'])) {
      return null;
    }

    final allDayCue = _hasAny(t, [
      '24시간',
      '24 시간',
      '하루종일',
      '하루 종일',
      '온종일',
      '종일',
      '항상',
      '계속',
      '전부',
      '완전',
      '완전히',
    ]);
    if (!allDayCue) return null;

    final hasSafari = _hasAny(t, ['사파리', 'safari', '웹', '브라우저']);
    final hasYoutube = _hasAny(t, ['유튜브', 'youtube', '쇼츠', 'shorts']);
    final hasInstagram = _hasAny(t, ['인스타', 'instagram', '릴스', 'reels', 'sns']);

    if (hasSafari || hasYoutube) {
      final targets = [
        if (hasSafari) 'Safari·웹',
        if (hasYoutube) 'Isle 유튜브',
      ].join(' + ');
      return BlockChatPlan(
        action: 'morning_schedule',
        scheduleName: '$targets 24시간 차단 (AI)',
        endHour: 23,
        endMinute: 59,
        blockSafariNote: hasSafari,
        blockIsleYoutube: hasYoutube,
        reply: '$targets를 매일 00:00–23:59 차단하는 스케줄로 만들게요.',
      );
    }

    if (hasInstagram) {
      return const BlockChatPlan(
        action: 'night_schedule',
        scheduleName: 'Instagram 24시간 차단 (AI)',
        startHour: 0,
        startMinute: 0,
        endHour: 23,
        endMinute: 59,
        reply: 'Instagram을 매일 00:00–23:59 차단하는 스케줄로 만들게요.',
      );
    }

    return null;
  }

  static List<int> _parseDays(String t) {
    final days = <int>{};
    if (_hasAny(t, ['평일'])) days.addAll([0, 1, 2, 3, 4]);
    if (_hasAny(t, ['주말'])) days.addAll([5, 6]);
    if (_hasAny(t, ['매일'])) return const [0, 1, 2, 3, 4, 5, 6];

    // 그룹 단어(평일·주말·매일)의 '일'·'월' 등이 개별 요일로 오인되지 않게 제거.
    final cleaned =
        t.replaceAll('평일', '').replaceAll('주말', '').replaceAll('매일', '');
    const map = {
      '월': 0,
      '화': 1,
      '수': 2,
      '목': 3,
      '금': 4,
      '토': 5,
      '일': 6,
    };
    for (final e in map.entries) {
      if (cleaned.contains(e.key)) days.add(e.value);
    }
    if (days.isEmpty) return const [0, 1, 2, 3, 4, 5, 6];
    return days.toList()..sort();
  }

  /// 「1시간에 10분 onscreen · 나머지 background」 유튜브 뮤직 화면/음성 분리
  static BlockChatPlan? _parseMusicForegroundBackground(String _, String t) {
    final musicCue = _hasAny(t, ['뮤직', 'music', 'ytm']);
    final ytCue = _hasAny(t, ['유튜브', 'youtube']);
    if (!musicCue && !ytCue) return null;

    final screenCue = _hasAny(t, [
      'onscreen',
      'on screen',
      'on-screen',
      '온스크린',
      '화면',
      '영상',
      '시청',
      '보게',
    ]);
    final bgCue = _hasAny(t, [
      'background',
      '백그라운드',
      '백 그라운드',
      '음성',
      '듣기',
      '배경',
    ]);
    final hourlyCue = (RegExp(r'(\d+)\s*시간').hasMatch(t) &&
            RegExp(r'(\d+)\s*분').hasMatch(t)) ||
        _hasAny(t, ['1시간에', '시간당', '매시간', '시간에']);
    // "10분에 5분씩만" 류 — 시간(hour) 단위가 아니라 분 단위 구간(창·세션)으로만
    // 말하는 나눠쓰기 요청. musicCue가 있을 때만 인정(순수 "10분에 5분"만으로는
    // 다른 의도와 겹칠 수 있음).
    final intervalMatch = _matchIntervalThenSession(t);
    final intervalCue = musicCue && intervalMatch != null;
    // "20분에 5분씩 쉬게"/"20분 보면 5분 쉬게"류 휴식형 cadence — 아래
    // intervalMatch 어순 추측(창이 항상 먼저)과 달리 뒤에 쉬(게/어/는)·휴식이
    // 오면 뜻이 반대다(2026-07-15, CAGE에서 먼저 발견·수정). 있으면 최우선.
    final restCadence = _matchWatchThenRestCadence(t);
    final restCadenceCue = musicCue && restCadence != null;

    if (!screenCue && !hourlyCue && !intervalCue && !restCadenceCue) {
      return null;
    }
    if (!bgCue && !hourlyCue && !musicCue) return null;

    final time = _parseEndTime(t);
    final endH = time?.$1 ?? 11;
    final endM = time?.$2 ?? 0;

    var windowMin = 60;
    var allowMin = 10;
    final hourMin = RegExp(r'(\d+)\s*시간[^0-9]*(\d+)\s*분').firstMatch(t);
    if (restCadence != null) {
      allowMin = restCadence.session;
      windowMin = restCadence.window;
    } else if (hourMin != null) {
      final hours = int.tryParse(hourMin.group(1)!) ?? 1;
      allowMin = int.tryParse(hourMin.group(2)!) ?? 10;
      windowMin = hours * 60;
    } else if (intervalMatch != null) {
      // "N분에 M분" = N분마다(창) M분만(세션) — 창이 세션보다 먼저 나오는 어순.
      windowMin = intervalMatch.$1;
      allowMin = intervalMatch.$2;
    } else {
      final mins = _parseAllMinutes(t);
      if (mins.length >= 2) {
        allowMin = mins.last;
        final first = mins.first;
        windowMin = first >= 30 ? first : 60;
        if (first < allowMin) allowMin = mins.first;
      } else if (mins.isNotEmpty) {
        allowMin = mins.first;
      }
    }

    final windowLabel = windowMin >= 60 && windowMin % 60 == 0
        ? '${windowMin ~/ 60}시간'
        : '${windowMin}분';

    // "N분에 M분" 어순(창이 세션보다 먼저)은 시간 단위(1시간에 10분 등)보다 훨씬
    // 짧은 창을 흔히 말하므로("10분에 5분"), 시간 단위 전제인 최소 30분 클램프를
    // 그대로 적용하면 창이 부풀려진다(2026-07-11 cage 제보 — 10분이 30분으로 바뀜).
    final windowMinClamp =
        intervalMatch != null || restCadence != null ? 1 : 30;
    return BlockChatPlan(
      action: 'music_foreground_limit',
      scheduleName: 'YouTube Music · 화면 한도 (AI)',
      endHour: endH,
      endMinute: endM,
      sessionMinutes: allowMin.clamp(1, 120),
      windowMinutes: windowMin.clamp(windowMinClamp, 720),
      reply:
          'iPhone YouTube Music — ${_fmt(endH, endM)}까지 화면(on-screen)은 $windowLabel당 ${allowMin}분. '
          '잠금 화면·백그라운드 음악은 iOS가 한도 밖으로 셉니다.',
    );
  }

  /// 「유튜브 차단을 평일 15시부터 19시까지 풀어줘」 — 반복 허용 창.
  /// 그 시간대만 허용하고 나머지는 차단하는 스케줄(=보완 슬롯)을 만든다.
  /// relax_block(즉시 일회성 해제)보다 먼저 검사한다.
  static BlockChatPlan? _parseAllowWindow(String raw, String t) {
    if (_hasAny(t, ['못 보게', '못보게', '안 보게', '안보게', '안 되게', '안되게'])) {
      return null;
    }
    // 풀기·허용 의도가 있어야 한다 (차단 생성 문장은 제외).
    final relaxCue = _hasAny(t, ['풀', '해제', '허용', '보게', '볼 수', '볼수', '열어']);
    if (!relaxCue) return null;
    // 유튜브 대상만 지원 (Isle 인앱 유튜브).
    if (!_hasAny(t, ['유튜브', 'youtube', '영상', '동영상'])) return null;
    // 시작·종료가 있는 시간 "범위"여야 한다 (부터~까지 / 두 개의 시각).
    final fromTo = RegExp(
      r'(?:오전|오후|저녁|밤|새벽|아침)?\s*(\d{1,2})\s*(?::|시)\s*(\d{1,2})?\s*분?\s*(?:부터|~|에서|-)\s*(?:오전|오후|저녁|밤|새벽|아침)?\s*(\d{1,2})\s*(?::|시)\s*(\d{1,2})?\s*분?\s*(?:까지)?',
      caseSensitive: false,
    ).firstMatch(raw);
    if (fromTo == null) return null;

    final rawSh = int.tryParse(fromTo.group(1)!);
    final sm = int.tryParse(fromTo.group(2) ?? '') ?? 0;
    final rawEh = int.tryParse(fromTo.group(3)!);
    final em = int.tryParse(fromTo.group(4) ?? '') ?? 0;
    if (rawSh == null || rawEh == null) return null;
    var sh = rawSh;
    var eh = rawEh;
    // 오전/오후를 시작·종료 문맥에 맞춰 각각 24시간제로 변환
    final sepIdx = raw.indexOf(RegExp(r'부터|~|에서'));
    final startCtx = sepIdx > 0 ? raw.substring(0, sepIdx) : raw;
    final endCtx = sepIdx > 0 ? raw.substring(sepIdx) : raw;
    bool isPm(String s) =>
        s.contains('오후') || s.contains('저녁') || s.contains('밤');
    bool isAm(String s) => s.contains('오전') || s.contains('새벽');
    if (isPm(startCtx) && sh >= 1 && sh <= 11) sh += 12;
    if (isPm(endCtx) && eh >= 1 && eh <= 11) eh += 12;
    // 종료에 오전/오후 표기 없으면 시작이 오후일 때 같은 오후로 추론 (예: "오후 2시~4시")
    if (!isPm(endCtx) &&
        !isAm(endCtx) &&
        sh >= 12 &&
        eh >= 1 &&
        eh <= 11 &&
        eh < sh) {
      eh += 12;
    }
    if (sh < 0 || sh > 23 || eh < 0 || eh > 23) return null;
    final startMin = sh * 60 + sm;
    final endMin = eh * 60 + em;
    // 자정 넘는 창은 night_schedule이 처리 — 허용 창은 같은 날 안에서만.
    if (endMin <= startMin) return null;

    final days = _parseDays(t);
    final daysKo = _hasAny(t, ['평일'])
        ? '평일'
        : (_hasAny(t, ['주말']) ? '주말' : (days.length >= 7 ? '매일' : '지정 요일'));

    return BlockChatPlan(
      action: 'allow_window',
      blockIsleYoutube: true,
      startHour: sh,
      startMinute: sm,
      endHour: eh,
      endMinute: em,
      days: days,
      scheduleName: '유튜브 허용 ${_fmt(sh, sm)}–${_fmt(eh, em)} (AI)',
      reply: '$daysKo ${_fmt(sh, sm)}–${_fmt(eh, em)}만 Isle 유튜브를 허용하고, '
          '그 외 시간엔 차단하는 스케줄을 만들어요.',
    );
  }

  /// 「아침에 유튜브 이제 보게 해줘」 — 차단 생성과 구분
  static BlockChatPlan? _parseRelaxBlock(String raw, String t) {
    if (_hasAny(t, ['못 보게', '못보게', '안 보게', '안보게', '안 되게', '안되게'])) {
      return null;
    }
    final blockCreate = _hasAny(t, ['막', '차단', '블락', '블록', '금지', 'block']) &&
        !_hasAny(
            t, ['풀', '해제', '허용', '보게', '이제', '다시', '끄', '없애', 'unblock', '막지']);
    if (blockCreate) return null;

    // "하루 N분/N시간만 보게" 류는 한도(limit) 의도 → relax(차단해제) 아님.
    // youtube_limit / platform_limit 이 처리하도록 넘긴다.
    if (_hasAny(t, ['하루', '일일', '한도', '제한', '이상', '넘으면']) &&
        RegExp(r'\d+\s*(?:분|시간)').hasMatch(t)) {
      return null;
    }

    final relaxCue = _hasAny(t, [
      '풀',
      '해제',
      '허용',
      '허가',
      '보게',
      '보자',
      '보여',
      '이제',
      '다시',
      '없애',
      '끄',
      'unblock',
      'off',
      '취소',
      '막지',
      '그만',
    ]);
    if (!relaxCue) return null;

    if (_hasAny(t, ['스케줄', 'schedule']) &&
        _hasAny(t, ['끄', '꺼', '해제', '제거', '삭제', '없애', 'unblock', '이름', '바꿔'])) {
      return null;
    }

    final hasMedia = _hasAny(t, [
      '유튜브',
      'youtube',
      '뮤직',
      'music',
      'ytm',
      '사파리',
      'safari',
      '인스타',
      '스케줄',
    ]);

    // "이제 좀 풀어줘"처럼 대상을 아예 안 말하는 짧은 문장 — 사람도 맥락 없인
    // 뭘 말하는지 확신 못 하는 수준이라, 아주 짧고 명확한 "그냥 풀어줘" 어투일
    // 때만 통과시키고 대상은 'all'로 남겨서 executor가 "지금 활성 중인 스케줄"
    // 우선으로 후보를 고르게 한다(BlockChatScheduleResolver, 2026-07-11 cage 요청).
    if (!hasMedia) {
      final bareRelax = _hasAny(t, ['이제 좀 풀어', '그만 막아', '다 풀어', '전부 풀어']) ||
          t.replaceAll(RegExp(r'[\s.,!?~]'), '') == '풀어줘' ||
          t.replaceAll(RegExp(r'[\s.,!?~]'), '') == '풀어주세요';
      if (!bareRelax) return null;
      return BlockChatPlan(
        action: 'relax_block',
        relaxTarget: 'all',
        reply: '지금 활성 중인 차단부터 찾아서 풀게요.',
      );
    }

    String? target;
    if (_hasAny(t, ['유튜브', 'youtube', '뮤직', 'music', 'ytm', '영상'])) {
      target = 'youtube';
    } else if (_hasAny(t, ['사파리', 'safari', '웹'])) {
      target = 'safari';
    } else if (_hasAny(t, ['인스타', 'instagram'])) {
      target = 'instagram';
    }

    final q = _extractScheduleQueryHint(raw, t) ?? '';
    return BlockChatPlan(
      action: 'relax_block',
      relaxTarget: target ?? 'youtube',
      scheduleQuery: q,
      removeScheduleQuery: q,
      reply: target == 'youtube' || target == null
          ? '유튜브 관련 차단을 찾아 **겹친 스케줄까지** 모두 풀게요.'
          : '요청한 차단을 찾아 겹친 스케줄까지 완화할게요.',
    );
  }

  /// 「아침에 유튜브 뮤직 많이 본다」 등 습관·고민 → 일괄 패키지
  static BlockChatPlan? _parseMorningHabitConcern(String _, String t) {
    if (_hasAny(t, [
      '보게',
      '풀',
      '해제',
      '허용',
      '이제',
      '다시',
      '막지',
      'unblock',
      '그만 막',
    ])) {
      return null;
    }
    if (_hasAny(t, ['막', '차단', '블락', '블록', 'block', '금지']) &&
        !_hasAny(t, ['해결', '없을까', '어떻게', '줄이', '습관'])) {
      return null;
    }
    if (_hasAny(t, ['안 되', '안되', '못 보', '못보', '못 쓰', '못쓰'])) {
      return null;
    }

    final mediaCue = _hasAny(t, [
      '유튜브',
      'youtube',
      '뮤직',
      'music',
      '영상',
      '동영상',
      '쇼츠',
      'shorts',
    ]);
    final worryCue = _hasAny(t, [
      '해결',
      '없을까',
      '어떻게',
      '습관',
      '중독',
      '줄이',
      '그만',
      '멈추',
      '끊',
      '많이',
      '자꾸',
      '보는데',
      '너무',
    ]);
    final morningCue = _hasAny(t, ['아침', '매일', 'morning', '기상', '출근', '아침에']);

    if (!mediaCue) return null;
    if (!worryCue && !morningCue) return null;

    final time = _parseEndTime(t);
    final endH = time?.$1 ?? 10;
    final endM = time?.$2 ?? 0;
    final mins = _parseAllMinutes(t);
    final daily = mins.isNotEmpty ? mins.last.clamp(10, 120) : 20;
    final session = mins.length >= 2 ? mins.first.clamp(3, 30) : 5;
    final isMusic = _hasAny(t, ['뮤직', 'music', 'ytm']);
    final label = isMusic ? '유튜브·뮤직' : '유튜브';

    return BlockChatPlan(
      action: 'morning_habit_pack',
      scheduleName: isMusic ? '아침 유튜브·뮤직 (AI)' : '아침 유튜브 습관 (AI)',
      endHour: endH,
      endMinute: endM,
      dailyMinutes: daily,
      sessionMinutes: session,
      blockIsleYoutube: true,
      suggestTimelock: true,
      reply: '아침 $label 습관 — 스케줄·앱 한도·Isle 일일 ${daily}분을 맞출게요. '
          '더 단단히 막으려면 적용 후 카드에서 「타임락」 설정으로 이동할 수 있어요.',
    );
  }

  static BlockChatPlan? _parseIsleYoutubeSchedule(String raw, String t) {
    if (!_hasAny(t, ['유튜브', 'youtube'])) return null;
    if (!_hasAny(t, ['막', '차단', '블락', '블록', 'block', '금지'])) return null;
    if (_hasAny(t, ['사파리', 'safari'])) return null;

    // "브라우저"·"웹"을 함께 말하면 Isle 인앱뿐 아니라 Safari 등 브라우저 경로도 막고 싶다는 뜻 —
    // 예전엔 이 단어를 무시하고 Isle 인앱만 막은 뒤 "Safari·브라우저와 별개"라고 안내해
    // 사용자 기대(브라우저 전체 차단)와 실제 적용 범위가 조용히 어긋났음.
    final wantsBrowserToo = _hasAny(t, ['브라우저', '웹']);

    final time = _parseEndTime(t);
    final hasScheduleCue =
        time != null || _hasAny(t, ['매일', '아침', '저녁', '까지', '스케줄', '시']);

    final hour = time?.$1 ?? 9;
    final minute = time?.$2 ?? 0;

    if (!hasScheduleCue &&
        !wantsBrowserToo &&
        !_hasAny(t, ['isle', '이슬', '이젤', '앱 안', '인앱', '앱'])) {
      return BlockChatPlan(
        action: 'youtube_limit',
        dailyMinutes: 20,
        limitPlatform: 'youtube',
        reply: '「유튜브 차단」만으로는 스케줄이 애매해요. Isle 유튜브 일일 20분 한도를 제안합니다. '
            '시간대 차단이면 「매일 9시까지 유튜브 차단」처럼 말해 주세요.',
      );
    }

    // "isle"을 직접 언급 안 한 "유튜브 차단"류는 아이폰의 진짜 유튜브 앱까지
    // 막힌다고 오해하기 쉽다 — 이 액션은 Isle 인앱 화면(+선택 시 브라우저)만
    // 막을 수 있어서, 말없이 그 범위로만 적용하면 "차단했다는데 실제 유튜브
    // 앱은 멀쩡하다"는 실사용 혼란으로 이어짐(Cage 쪽 동일 버그 07-07 진단,
    // 같은 코드가 복붙돼 있어 여기도 포팅). wantsBrowserToo면 이미 스코프를
    // 넓혀 달란 뜻이라 그대로 두고, 아무 표시도 없을 때만 안내를 붙인다.
    final mentionsIsle =
        wantsBrowserToo || _hasAny(t, ['isle', '이슬', '이젤', '앱 안', '인앱']);
    final reply = wantsBrowserToo
        ? '매일 0시~${_fmt(hour, minute)} Isle 인앱 유튜브뿐 아니라 Safari 등 브라우저로 접속하는 것도 함께 막는 스케줄을 만듭니다.'
        : mentionsIsle
            ? '매일 0시~${_fmt(hour, minute)} Isle 인앱 유튜브를 막는 스케줄을 만듭니다. (Safari·다른 브라우저는 별도 설정이 필요해요)'
            : '매일 0시~${_fmt(hour, minute)} Isle 앱 안의 유튜브 화면만 막는 스케줄을 만들었어요 — '
                '아이폰의 진짜 유튜브 앱은 이걸로는 안 막혀요. 유튜브 앱 자체를 막는 방법은 '
                '설정 → 「iPhone 차단 기능」에서 확인할 수 있어요.';

    return BlockChatPlan(
      action: 'morning_schedule',
      scheduleName: wantsBrowserToo ? '아침 Safari·유튜브 차단' : '아침 Isle 유튜브',
      endHour: hour,
      endMinute: minute,
      blockIsleYoutube: true,
      blockSafariNote: wantsBrowserToo,
      reply: reply,
    );
  }

  static bool _looksLikeSchedule(String t) {
    return _hasAny(t, [
          '매일',
          '아침',
          '저녁',
          '스케줄',
          '까지',
          '24시간',
          '하루종일',
          '하루 종일',
          '종일',
        ]) &&
        _hasAny(t, ['시', '분', ':', '시간', '종일']) &&
        (_hasAny(t, ['막', '차단', '블락', '블록', 'block']) ||
            _hasAny(t, ['못 보', '보지 못', '못하게']));
  }

  static String _fmt(int h, int m) => m > 0 ? '$h시 $m분' : '$h시';

  static BlockChatPlan? _parseShortsToggle(String t) {
    // '쇼츠'가 실제로 흔히 쓰는 표기(이 파일 다른 곳 _appAliasCatalog에서도
    // '쇼츠'를 씀) — '숏츠'만 걸려있어서 "유튜브 쇼츠 없애줘" 같은 흔한
    // 문장이 이 토글에 아예 안 걸리고 다른 파서(remove_schedule)로 새고
    // 있었다(2026-07-12 발견).
    if (!_hasAny(t, ['숏츠', '쇼츠', 'shorts', '숏폼'])) return null;
    // 시간 표현이 있는 스케줄(아침에 숏츠 N시까지 막아줘) → morning_schedule이 처리
    if (_looksLikeSchedule(t)) return null;
    if (!_hasAny(t, [
      '숨김',
      '숨기',
      '숨겨',
      '끄',
      '꺼',
      '막',
      '켜',
      '보이',
      '안 보이',
      '안보이',
      '안 뜨',
      '안뜨',
      '해제',
      '풀어',
      '그만',
      '싫',
      '없애',
    ])) {
      return null;
    }
    final hideExplicit = _hasAny(t, ['안 보이', '안보이', '안 뜨', '안뜨', '그만', '싫']);
    final show = !hideExplicit && _hasAny(t, ['켜', '보이', '해제', '풀어', '다시']);
    final hide = hideExplicit || _hasAny(t, ['숨김', '숨기', '숨겨', '끄', '꺼', '막', '없애']);
    final on = hide && !show ? true : (show && !hide ? false : true);
    return BlockChatPlan(
      action: 'toggle_shorts',
      toggleOn: on,
      reply: on ? 'YouTube Shorts 숨김을 켭니다.' : 'YouTube Shorts를 다시 보이게 합니다.',
    );
  }

  static BlockChatPlan? _parseReelsToggle(String t) {
    if (!_hasAny(t, ['릴', 'reels', '릴스'])) return null;
    if (!_hasAny(t, [
      '숨김',
      '숨기',
      '숨겨',
      '끄',
      '꺼',
      '막',
      '켜',
      '보이',
      '해제',
      '풀어',
      '다시',
      '그만',
      '싫',
      '없애',
    ])) {
      return null;
    }
    // 스크롤 멈춤 의도(무한스크롤/둠스크롤)는 toggle_reels_guard가 처리
    if (_hasAny(t, ['무한', '둠스크롤', '멈춰', '멈추', '스크롤'])) return null;
    final hideExplicit = _hasAny(t, ['안 보이', '안보이', '안 뜨', '안뜨', '그만', '싫']);
    final show = !hideExplicit && _hasAny(t, ['켜', '보이', '해제', '풀어', '다시']);
    final hide = hideExplicit || _hasAny(t, ['숨김', '숨기', '숨겨', '끄', '꺼', '막', '없애']);
    final on = hide && !show ? true : (show && !hide ? false : true);
    return BlockChatPlan(
      action: 'toggle_reels',
      toggleOn: on,
      reply: on ? 'Instagram Reels 숨김을 켭니다.' : 'Instagram Reels를 다시 보이게 합니다.',
    );
  }

  /// "일요일에는 하루 유튜브 총량 7시간으로 늘려줘/줄여줘" — 특정 요일만
  /// 다른 하루 총량을 쓰고 싶은 요청. `_parseDays`는 0=월~6=일이라
  /// `DateTime.weekday`(1=월~7=일) 규약으로 맞춰서 저장한다.
  static BlockChatPlan? _parseYoutubeWeekdayLimit(String t) {
    if (!_hasAny(t, ['유튜브', 'youtube'])) return null;
    if (!_hasAny(t, ['요일', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'])) {
      return null;
    }
    if (!_hasAny(t, ['하루', '일일', '총량', '한도', '제한'])) return null;
    final hourMatch = RegExp(r'(\d+)\s*시간').firstMatch(t);
    if (hourMatch == null) return null;
    final hours = int.tryParse(hourMatch.group(1)!) ?? 0;
    if (hours <= 0) return null;
    final minutes = (hours * 60).clamp(5, 1440);

    final days = _parseDays(t);
    if (days.length != 1) return null;
    final weekday = days.first + 1; // 0=월..6=일 -> DateTime.weekday 1=월..7=일
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final label = weekdayLabels[days.first];

    return BlockChatPlan(
      action: 'youtube_weekday_limit',
      dailyMinutes: minutes,
      startHour: weekday, // weekday를 담아 executor로 전달(전용 필드 없어 재사용)
      reply: '$label요일엔 하루 유튜브 총량을 $hours시간으로 설정할게요.',
    );
  }

  /// "이번주는(이번주만) 일주일 유튜브 시간 4시간으로 줄여줘" — 이번 주에만
  /// 적용되는 임시 주간 총량. "이번주 유튜브 총량은 10시간으로 제한해줘"처럼
  /// "만/는" 없이 그냥 "이번주"만 말하면 매주 반복되는 영구 주간 총량으로 본다.
  static BlockChatPlan? _parseYoutubeWeeklyLimit(String t) {
    if (!_hasAny(t, ['유튜브', 'youtube'])) return null;
    if (!_hasAny(t, ['이번주', '이번 주', '일주일', '주간'])) return null;
    if (!_hasAny(t, ['총량', '제한', '늘려', '줄여', '줄이'])) return null;
    final hourMatch = RegExp(r'(\d+)\s*시간').firstMatch(t);
    if (hourMatch == null) return null;
    final hours = int.tryParse(hourMatch.group(1)!) ?? 0;
    if (hours <= 0) return null;
    final minutes = (hours * 60).clamp(1, 10080);

    final isTemporary = _hasAny(t, ['이번주만', '이번 주만', '이번주는', '이번 주는']);

    return BlockChatPlan(
      action: 'youtube_weekly_limit',
      dailyMinutes: minutes,
      toggleOn: isTemporary,
      reply: isTemporary
          ? '이번 주만 유튜브 총량을 $hours시간으로 설정할게요. 다음 주부터는 원래 한도로 돌아가요.'
          : '매주 유튜브 총량을 $hours시간으로 설정할게요.',
    );
  }

  static BlockChatPlan? _parseYoutubeLimit(String t) {
    if (_looksLikeSchedule(t)) return null;
    if (!_hasAny(t, ['유튜브', 'youtube'])) return null;
    if (!_hasAny(t, ['한도', '제한', 'limit', '하루', '일일', '이상', '넘으면', '잠궈', '잠그'])) return null;
    final mins = _parseAllMinutes(t);
    if (mins.isEmpty) return null;
    final daily = mins.last;
    return BlockChatPlan(
      action: 'youtube_limit',
      dailyMinutes: daily,
      limitPlatform: 'youtube',
      reply: 'Isle 유튜브 일일 한도를 ${daily}분으로 설정합니다.',
    );
  }

  static BlockChatPlan? _parseNightRefillUsageBudget(String raw, String t) {
    // 유튜브 뮤직은 UsageBudgetStore가 아니라 music_foreground_limit 경로 —
    // _parseUsageBudget의 동일 가드 참고(2026-07-11).
    if (_hasAny(t, ['뮤직', 'music', 'ytm'])) return null;
    final target = _parseUsageBudgetTarget(t);
    if (target == null) return null;
    final nightStart = _parseNightStartTime(raw, t);
    final nightCue = nightStart != null ||
        _hasAny(t, ['밤', '야간', '저녁', '취침', '11시부터', '23시부터']);
    if (!nightCue) return null;

    final allowLimitCue = _hasAny(t, [
      '볼수',
      '볼 수',
      '볼 수 있게',
      '보게',
      '쓸수',
      '쓸 수',
      '쓰게',
      '쓰고',
      '사용',
      '열게',
      '만 볼',
      '만 쓰',
      '리필',
      '충전',
      '나눠',
      '나누',
      '쪼개',
      '허용',
      '허락',
      '허가',
      // "20분 쓰고 40분 쉬게 해줘"처럼 "쓰고 ~ 쉬게" 어순으로 세션/휴식을 말하는
      // 흔한 표현이 이 목록에 아예 없어서 nightCue·target·시간대까지 다 맞아도
      // 통째로 null 반환되던 실사용 버그(2026-07-13 확인).
      '쉬게',
      '쉬는',
      '쉬고',
    ]);
    if (!allowLimitCue) return null;

    final mins = _parseAllMinutes(t);
    if (mins.isEmpty) return null;

    // 「10분에 3분만」 = 10분마다(창) 3분만(세션) — 창이 세션보다 먼저 나오는 어순이라
    // mins.first를 세션으로 잘못 읽으면 창·세션이 뒤바뀐다. 이 어순을 먼저 감지한다.
    final intervalMatch = _matchIntervalThenSession(t);
    final explicitWindow = intervalMatch?.$1;
    final session = (intervalMatch != null ? intervalMatch.$2 : mins.first)
        .clamp(1, 60)
        .toInt();
    final rest = _parseRestMinutes(t);
    final refill = (rest ??
            explicitWindow ??
            (_hasAny(t, ['리필', '충전']) && mins.length >= 2
                ? mins.last
                : session))
        .clamp(1, 480)
        .toInt();
    // "10분에 3분씩"은 하루 총량을 말한 게 아니라 창·세션 어순일 뿐이다 —
    // 언급 안 된 daily_minutes를 30으로 지어내던 실사용 버그(2026-07-06, cage).
    final dailyCue = _parseDailyCapMinutes(t);
    final daily = dailyCue == null && intervalMatch != null
        ? null
        : (dailyCue ?? (mins.length >= 2 && mins.last > session ? mins.last : 30))
            .clamp(session, 480)
            .toInt();
    final startH = nightStart?.$1 ?? 23;
    final startM = nightStart?.$2 ?? 0;
    final nightEnd = _parseNightEndTime(raw, t);
    final endH = nightEnd?.$1 ?? 7;
    final endM = nightEnd?.$2 ?? 0;
    final label = target.$3;

    // usage_budget은 UsageBudgetStore(순수 Dart 카운터)로 처리되는데, 이건 Isle
    // 인앱 웹뷰(유튜브·인스타·브런치)에서만 초 단위를 셀 수 있다 — 카카오톡·틱톡처럼
    // 완전 외부 앱은 Isle이 사용 시간을 볼 방법이 없어 usage_budget으로 보내면
    // 확인 카드만 뜨고 기기에서 실제로는 아무것도 안 막히는 실사용 버그(2026-07-06,
    // cage). 카탈로그에 진짜 네이티브 Screen Time 경로가 있는 앱(kakao/tiktok)은
    // night_schedule의 리필 모드로 보내야 실제로 걸린다.
    final hasNativeAppTarget =
        target.$1 == 'app' && (target.$2 == 'kakao' || target.$2 == 'tiktok');

    return BlockChatPlan(
      action: target.$1 == 'youtube'
          ? 'youtube_budget'
          : hasNativeAppTarget
              ? 'night_schedule'
              : 'usage_budget',
      scheduleName: hasNativeAppTarget ? '$label 야간 리필 (AI)' : null,
      limitPlatform: target.$1,
      appId: target.$2,
      dailyMinutes: daily,
      sessionMinutes: session,
      windowMinutes: refill,
      cooldownMinutes: refill,
      startHour: startH,
      startMinute: startM,
      endHour: endH,
      endMinute: endM,
      reply: '$label은 차단하지 않고 ${_fmt(startH, startM)}~${_fmt(endH, endM)}에 '
          '$session분 쓰고 $refill분 뒤 다시 충전되는 방식으로 설정합니다.',
    );
  }

  static BlockChatPlan? _parseUsageBudget(String t) {
    // "유튜브 뮤직"은 UsageBudgetStore(인앱 충전식 카운터)가 아니라 iPhone YouTube
    // Music 앱의 Screen Time 기반 music_foreground_limit이 처리한다
    // (_parseMusicForegroundBackground) — 여기서 가로채면 그 경로가 죽고, 실사용
    // 버그처럼 "유튜브"(메인 앱) 버킷에 잘못 적용된다(2026-07-11 cage 제보:
    // "유튜브뮤직을 10분에 5분씩만 허락해줘"가 limitPlatform=youtube로 잘못 파싱됨).
    if (_hasAny(t, ['뮤직', 'music', 'ytm'])) return null;
    if (_looksLikeSchedule(t) && !_looksLikeUsageBudgetIntent(t)) return null;
    // 명시적 시작+종료 시각이 둘 다 있으면("11:30부터 22:30까지") 하루 총량이
    // 아니라 그 시간대 안에서의 나눠쓰기 요청이다 — 시간대를 살릴 수 있는
    // _parseNightRefillUsageBudget에 양보한다. 이 가드가 없으면 여기서 먼저
    // 잡아채 시간대를 통째로 버리고 하루 총량 모드로 잘못 만들었다(2026-07-13
    // 실사용 확인: "브라우저 11:30부터 22:30까지는 20분쓰고 40분 쉬게 해줘"가
    // 시간대 없이 "하루 40분"으로 새어나감).
    if (_parseNightStartTime(t, t) != null && _parseNightEndTime(t, t) != null) {
      return null;
    }
    final target = _parseUsageBudgetTarget(t);
    if (target == null) return null;
    if (!_hasAny(t, [
      '변환',
      '전환',
      '바꿔',
      '바꾸',
      '변경',
      '모드',
      '세팅',
      '설정',
      '한도',
      '제한',
      '총량',
      '나눠',
      '쪼개',
      '씩',
      '충전',
      '리필',
      'refill',
      '쿨다운',
      '잠금',
      '쉬',
      '쉰',
      '마다',
      '한 번',
      '한번',
      '번만',
      '회만',
      '쓰면',
      '보면',
      '나면',
      '잠가',
      '잠그',
      '잠기',
      '닫',
      '뒤',
      '열리',
      '끊',
      '멈춰',
      '멈추',
      '스탑',
      'stop',
      '정지',
      '컷',
      '한 타임',
      '타임',
      '세트',
      '허용',
      '허락',
      '허가',
    ])) {
      return null;
    }
    final mins = _parseAllMinutes(t);
    final repeatCount = _parseRepeatCount(t);
    if (mins.length < 2 && repeatCount == null) return null;

    // "10분에 3분씩"은 10분마다(창) 3분만(세션) 나눠 쓰는 어순일 뿐 하루 총량을
    // 말한 게 아니다. 아래 max(mins) 폴백으로 잘못 추론하면 사용자가 언급도
    // 안 한 daily_minutes가 생겨버린다(실사용 버그 — 2026-07-06 cage 카카오톡 제보).
    final dailyCue = _parseDailyCapMinutes(t);
    final intervalMatch = _matchIntervalThenSession(t);
    if (intervalMatch != null && dailyCue == null && repeatCount == null) {
      final window = intervalMatch.$1;
      final burst = intervalMatch.$2.clamp(1, 60).toInt();
      final rest = _parseRestMinutes(t);
      final refill = (rest ?? window).clamp(1, 480).toInt();
      return BlockChatPlan(
        action: target.$1 == 'youtube' ? 'youtube_budget' : 'usage_budget',
        sessionMinutes: burst,
        windowMinutes: refill,
        cooldownMinutes: refill,
        limitPlatform: target.$1,
        appId: target.$2,
        reply: '${target.$3}을 $burst분 쓰고 $refill분 뒤 다시 쓸 수 있게 '
            '설정합니다 (하루 총량 제한은 없음 — 언급 안 하셔서 안 걸었어요).',
      );
    }

    final inferredBurst = mins.isNotEmpty ? mins.first : 20;
    final inferredDaily = dailyCue != null
        ? dailyCue.clamp(10, 480)
        : repeatCount != null
            ? (inferredBurst * repeatCount).clamp(10, 480)
            : mins.reduce((a, b) => a > b ? a : b).clamp(10, 480);
    final daily = inferredDaily.toInt();
    final burst = mins.firstWhere(
      (m) => m < daily,
      orElse: () => (daily ~/ 3).clamp(5, 60).toInt(),
    );
    final rest = _parseRestMinutes(t);
    final refill = rest ??
        (mins.length >= 3
            ? mins.last.clamp(10, 480).toInt()
            : repeatCount != null && mins.length >= 2
                ? mins.last.clamp(10, 480).toInt()
                : (_hasAny(t, ['시간', 'hour']) ? 60 : daily));
    final cooldown =
        _hasAny(t, ['쿨다운', '잠금', '쉬', '쉰', 'freeze']) ? refill : refill;
    final label = target.$3;

    return BlockChatPlan(
      action: target.$1 == 'youtube' ? 'youtube_budget' : 'usage_budget',
      dailyMinutes: daily,
      sessionMinutes: burst.clamp(1, daily).toInt(),
      windowMinutes: refill,
      cooldownMinutes: cooldown,
      limitPlatform: target.$1,
      appId: target.$2,
      reply: '$label을 하루 $daily분 안에서 $burst분씩 나눠 쓰도록 설정합니다.',
    );
  }

  /// "10분마다 3분 한 유튜브 뮤직 스케줄을 1시까지 늘려줘"류 — 이미 켜져 있는
  /// 나눠쓰기(usage_budget/youtube_budget) 정책을 처음부터 새로 만드는 게 아니라
  /// 종료 시각만(또는 이번에 언급된 값만) 바꿔서 "연장"하는 의도.
  ///
  /// 실사용 버그(cage에서 먼저 발견, 2026-07-07): 이 의도를 잡아내지 못하면
  /// _parseUsageBudget의 일반 생성 경로로 떨어져서, 실제 저장된 daily/session/
  /// window/cooldown 값을 다 무시하고 하드코딩 기본값(daily 60, session 20 등)
  /// 또는 이번 메시지에 우연히 같이 언급된 숫자만으로 정책을 통째로 재작성해버린다.
  /// 여기서는 값 자체를 확정하지 않고, "기존 정책을 이어가라"는 신호
  /// (extendsExistingBudget:true)와 이번에 명시적으로 말한 필드만 세팅해서 넘긴다 —
  /// 실제 기존 값 조회·병합은 UsageBudgetStore를 들고 있는 executor 쪽 책임이다.
  static BlockChatPlan? _parseUsageBudgetExtend(String raw, String t) {
    // "유튜브 뮤직"은 UsageBudgetStore(인앱 충전식 카운터)가 아니라 iPhone YouTube
    // Music 앱의 Screen Time 기반 music_foreground_limit이 처리한다(_parseMusicForeground
    // BackGround, 아래에서 별도 호출됨) — 여기서 가로채면 그 경로가 죽는다.
    if (_hasAny(t, ['뮤직', 'music', 'ytm'])) return null;

    // (2026-07-14 시도했다 되돌림) "쪼개"/"나눠"를 extendCue에 넣으면 "카톡은
    // 앞으로 하루 30분만, 5분씩 나눠 쓰게 바꿔줘"·"디스코드는 일일 45분, 한
    // 타임 15분으로 쪼개줘" 같은 **새로 만드는** 요청까지 "기존 값 이어가기"
    // 파서로 잘못 새서, 숫자 순서 해석이 다른 이 함수의 로직(창→세션 어순
    // 가정)과 충돌해 daily/session이 뒤바뀌는 회귀가 났다(실제 테스트로 확인).
    // "기존 20분이 새 나눠쓰기로 사라지는" 문제의 진짜 근본원인은 여기가 아니라
    // executor의 daily 폴백 체인(PlatformWatchLimitStore 미조회)이었다 —
    // 그건 block_chat_executor.dart의 flatDailyFallback으로 해결. extendCue는
    // 명시적 동사만으로 제한해서 안전하게 유지한다.
    final extendCue = _hasAny(t, ['연장', '늘려', '늘리', '줄여', '줄이', '확장']);
    if (!extendCue) return null;

    final target = _parseUsageBudgetTarget(t);
    if (target == null) return null;

    // 나눠쓰기(충전식) 스케줄이라는 근거 없이 그냥 "늘려줘"만 있으면 다른 파서
    // (update_schedule_time 등 일반 스케줄 연장)가 처리하도록 양보한다.
    final budgetCue = _hasAny(t, [
      '마다',
      '씩',
      '나눠',
      '나누',
      '쪼개',
      '충전',
      '리필',
      'refill',
      '쿨다운',
      '스케줄',
      '한도',
    ]);
    if (!budgetCue) return null;

    final label = target.$3;
    final limitPlatform = target.$1;
    final appId = target.$1 == 'app' ? target.$2 : null;
    final action = target.$1 == 'youtube' ? 'youtube_budget' : 'usage_budget';

    // 종료 시각("까지") — 언급 안 됐으면 이번엔 시간 변경 없이 다른 필드만 조정.
    final hasEndCue = _hasAny(t, ['까지']);
    (int, int)? endTime;
    if (hasEndCue) {
      endTime = _parseEndTime(t);
      if (endTime == null) return null;
      final ambiguous = _isAmbiguousBareHour(t, endTime.$1);
      if (ambiguous) {
        final altHour = endTime.$1 <= 12 ? endTime.$1 + 12 : endTime.$1 - 12;
        return BlockChatPlan(
          action: 'explain',
          reply: '${_fmt(endTime.$1, endTime.$2)}까지로 늘릴까요, 아니면 '
              '${_fmt(altHour, endTime.$2)}(${altHour}시)를 의미하신 건가요? '
              '오전/오후를 붙여서 다시 말씀해 주세요.\n'
              '예: "새벽 ${endTime.$1}시까지" 또는 "오후 ${endTime.$1}시까지"',
        );
      }
    }

    // 이번 메시지에서 명시적으로 언급된 값만 세팅 — 나머지는 executor가 기존 정책값을
    // 이어가도록 null로 남긴다(생성 경로처럼 기본값을 지어내지 않는다).
    // "N분마다 M분"(마다=window) 어순을 먼저 확인 — mins[0]/mins[1] 순서로 잘못 읽으면
    // window·session이 뒤바뀐다(_parseConvertScheduleMode에서와 같은 실사용 버그 패턴).
    int? session;
    int? window;
    final everyMatch = RegExp(r'(\d+)\s*분\s*마다').firstMatch(t);
    if (everyMatch != null) {
      window = int.tryParse(everyMatch.group(1)!);
      final afterEvery = t.substring(everyMatch.end);
      final sessionAfter = RegExp(r'(\d+)\s*분').firstMatch(afterEvery);
      if (sessionAfter != null) session = int.tryParse(sessionAfter.group(1)!);
    }
    final intervalMatch = _matchIntervalThenSession(t);
    session ??= intervalMatch?.$2;
    window ??= intervalMatch?.$1;
    if (session == null || window == null) {
      final mins = _parseAllMinutes(t);
      if (mins.length >= 2) {
        session ??= mins.first;
        window ??= mins.length >= 2 ? mins[1] : null;
      } else if (mins.length == 1 && !hasEndCue) {
        // 숫자 하나만 있고 종료 시각도 없으면 뭘 바꾸라는 건지 불명확 — 다른 파서에 양보.
        return null;
      }
    }
    final rest = _parseRestMinutes(t);
    final cooldown = rest ?? window;
    final dailyCue = _parseDailyCapMinutes(t);

    final endLabel =
        endTime != null ? '${_fmt(endTime.$1, endTime.$2)}까지 ' : '';
    return BlockChatPlan(
      action: action,
      limitPlatform: limitPlatform,
      appId: appId,
      dailyMinutes: dailyCue,
      sessionMinutes: session,
      windowMinutes: window,
      cooldownMinutes: cooldown,
      budgetWindowEndMinuteOfDay:
          endTime != null ? (endTime.$1 * 60 + endTime.$2) : null,
      extendsExistingBudget: true,
      reply: '$label 나눠 쓰기 스케줄을 ${endLabel}이어서 연장합니다 (언급 안 하신 값은 '
          '기존 설정 그대로 유지).',
    );
  }

  /// bare "N시"(오전/오후 표기 없음)가 애매한지 판정. 문맥에 오전/오후/새벽/밤/낮/정오 같은
  /// 명시적 단서가 전혀 없고, 1~11시 범위라 24시간제로도 오전으로 읽힐 수 있고 +12시간
  /// (오후)으로도 자연스레 읽힐 수 있는 경우에만 애매하다고 본다.
  static bool _isAmbiguousBareHour(String t, int hour) {
    if (hour == 0 || hour == 12) return false; // 자정/정오는 표기 자체가 명확
    if (hour < 1 || hour > 11) return false; // 13~23은 이미 24시간제로 명확
    final hasMeridiemCue = _hasAny(t, [
      '오전',
      '오후',
      '새벽',
      '밤',
      '저녁',
      '낮',
      '정오',
      '자정',
      'am',
      'pm',
    ]);
    return !hasMeridiemCue;
  }

  static bool _looksLikeUsageBudgetIntent(String t) {
    final hasDailyCue = _hasAny(t, ['하루', '일일', '총', '전체', '최대', '한도', '제한']);
    final hasSessionCue = _hasAny(t, [
      '씩',
      '마다',
      '한 번',
      '한번',
      '1회',
      '회만',
      '번만',
      '나눠',
      '쪼개',
      '끊',
      '멈춰',
      '멈추',
      '스탑',
      'stop',
      '정지',
      '컷',
      '세트',
    ]);
    final hasChangeCue = _hasAny(t, [
      '변환',
      '전환',
      '바꿔',
      '바꾸',
      '변경',
      '이제',
      '앞으로',
      '모드',
      '세팅',
      '설정',
    ]);
    return hasDailyCue &&
        hasSessionCue &&
        (hasChangeCue || _parseAllMinutes(t).length >= 2);
  }

  /// 「카카오톡 차단 설정 알려줘」「유튜브 뮤직 스케줄 알려줘」「뭐가 차단하고 있는거야?」
  /// — 읽기 전용 조회. mutation 동사(해줘/바꿔/만들어 등)가 섞이면 여기서 빠진다.
  static BlockChatPlan? _parseStatusQuery(String t) {
    final queryCue = _hasAny(t, [
      '알려줘',
      '알려 줘',
      '뭐야',
      '뭔지',
      '뭐가',
      '뭐지',
      '몇 분',
      // 위 항목들은 전부 "뭐"/"몇"의 특정 조합만 나열한 것이라 "뭐뭐 켜놨지"
      // "몇 개 걸려있는거야"처럼 목록에 없는 변형은 그대로 새 add_keyword로
      // 질문 그 자체가 키워드 등록되는 문제(Cage에서 2026-07-13 발견한 것과
      // 같은 클래스). 의문 대명사 자체를 넓게 잡고, 실제 변경 요청이면
      // mutationCue 체크(아래)가 이미 걸러내므로 과잉 매칭 걱정 없다.
      '뭐',
      '뭔',
      '몇',
      '얼마나',
      '어떻게 돼',
      '어떻게돼',
      '현재',
      '왜',
      // "어떤 상황이야?"/"어떤 상태야?" — mutation cue(해줘/막아줘 등)가 없는
      // 순수 질문형인데 queryCue에 안 걸려 youtube_limit 신규 생성으로 오인됨
      // (2026-07-10, "오늘 유튜브 뮤직 블락은 어떤 상황이야? 어떤 상태야?" 제보).
      '어떤 상황',
      '어떤 상태',
      '무슨 상황',
      '무슨 상태',
      // "리스트/목록 보여줘"는 "차단해줘"류 변경 요청이 아니라 순수 조회인데
      // "보여줘"가 통째로 빠져 있어서 mutationCue 목록의 다른 "~해줘"들과
      // 안 겹치는데도 queryCue 자체가 안 걸려 엉뚱한 액션(add_keyword로
      // "지금"이 그대로 키워드 등록되거나, youtube_limit 신규 제안)으로
      // 새던 실사용 버그(2026-07-11, "지금 차단중인 리스트 보여줘"/
      // "유튜브 뮤직 차단 목록 보여줘").
      '보여줘',
      '보여 줘',
      '보여주라',
      '보여줄래',
      '보여줄 수',
      '출력해줘',
      // "내보내줘"("지금 진행 중인 차단 전부 내보내줘")도 "출력해줘"와 같은
      // 뜻의 순수 조회 요청인데 목록에 없어서 add_keyword로 "지금 진행
      // 중인"이 그대로 키워드 등록되던 문제(Cage 이식 작업 중 2026-07-13
      // 발견 — 당시엔 Cage 포팅 범위 밖이라 안 고치고 남겨뒀던 것).
      '내보내줘',
      '리스트',
      '목록',
    ]);
    // "차단되어 있어"/"막혀 있어"/"잠겨 있어"/"활성화돼" 류는 현재 상태를 서술하는
    // 질문형 어미이지 "차단해줘" 같은 변경 요청이 아니다 — queryCue에 없어도
    // 조회로 인식한다 (cage에서 먼저 발견·수정: "왜 지금 유튜브 뮤직이 차단되어
    // 있어??"가 youtube_limit 신규 생성으로 오인됨, 2026-07-07. "오늘 저녁
    // 00:00까지 어떤 차단이 활성화돼?"가 night_schedule 신규 생성으로 오인됨,
    // 2026-07-10).
    final statusDescriptionCue = _hasAny(t, [
      '차단되어',
      '차단돼',
      '막혀',
      '잠겨',
      '잠겨있',
      '막혀있',
      '활성화',
      '적용되',
      '켜져',
      '켜있',
      '켜 있',
      '어떤 차단',
      // "무슨 차단이 있어?" — '어떤 차단'과 동의어인데 짝이 빠져 있어서
      // add_keyword로 "무슨"이 그대로 키워드 등록되던 실사용 버그(2026-07-11).
      '무슨 차단',
    ]);
    if (!queryCue && !statusDescriptionCue) return null;

    // '블락'/'블록'은 다른 파서 함수들 전부 '차단'과 동의어로 취급하는데 여기만
    // 빠져 있어서 "오늘 블락은 뭐가 켜져있어?"가 조회로 안 잡히고 일반
    // explain(안내 멘트)로 새던 문제(2026-07-10).
    final askCue = _hasAny(
        t, ['설정', '스케줄', 'schedule', '상태', '차단', '블락', '블록', 'block', '한도', '제한']);
    // statusDescriptionCue("막혀있어"/"잠겨있"/"켜져" 등)는 그 자체로 이미
    // 차단 상태를 묻는 표현이라 별도 askCue가 없어도 조회로 인정한다 — "지금
    // 뭐가 막혀있어?"처럼 "차단"/"설정" 단어 없이 물어보면 explain_status로
    // 안 잡히고 AI 폴백(explain, "요청을 이해하지 못했어요")으로 새던 실사용
    // 버그(2026-07-20, 채팅 시뮬레이터로 발견).
    if (!askCue && !statusDescriptionCue) return null;

    // 예전엔 여기 바로 아래 '해줘'를 통째로 넣어뒀었다 — "출력해줘"/"제공해줘"
    // 처럼 순수 조회 요청도 전부 '해줘'를 포함하기 때문에, queryCue가
    // "출력해줘"로 잡아도 바로 이 mutationCue에 다시 걸려 죽어서 결국
    // add_keyword 최후수단으로 새 문장 앞부분이 그대로 키워드 등록되는
    // 자기모순 버그였다(2026-07-13, 사용자 제보 — "지금 현재 차단 중인
    // 목록 데이터 다 출력해줘"). 실제 변경 동사는 이미 아래 구체적인
    // '~해'/'~줘' 조합들이 다 커버하므로 포괄적인 '해줘' 하나는 없앤다.
    final mutationCue = _hasAny(t, [
      '바꿔',
      '변경',
      '만들어',
      '설정해',
      '켜줘',
      '꺼줘',
      '풀어줘',
      '막아줘',
      '차단해',
      '허용해',
      '허락해',
      '추가해',
      '삭제해',
      '제거해',
      '해제해',
    ]);
    if (mutationCue) return null;

    final isMusic = _hasAny(t, ['뮤직', 'music', 'ytm']);
    final target = _parseUsageBudgetTarget(t);
    final limitPlatform = isMusic ? 'youtube_music' : target?.$1;
    final appId = (!isMusic && target?.$1 == 'app') ? target?.$2 : null;
    final label = isMusic ? '유튜브 뮤직' : (target?.$3 ?? '전체');

    return BlockChatPlan(
      action: 'explain_status',
      limitPlatform: limitPlatform,
      appId: appId,
      reply: '$label 현재 차단·한도 설정을 확인할게요.',
    );
  }

  /// 사용자가 실제로 쓰는 앱 이름의 일상 표현 사전 — 한 곳에서만 관리한다.
  /// (구조 노트, 2026-07-12: 예전엔 이 파일 여러 곳(_parseUsageBudgetTarget,
  /// _parseAllUsageBudgetTargets, _parseMultiCategoryNightBlock 등)에 각자
  /// 조금씩 다른 키워드 목록이 흩어져 있어서, 새 일상 표현이 하나 나올 때마다
  /// 어떤 파서는 반영되고 어떤 파서는 빠지는 일이 반복됐다("인터넷 브라우저"가
  /// _parseUsageBudgetTarget엔 있었는데 다른 곳엔 없어서 문장에 따라 결과가
  /// 달라졌던 것도 같은 원인). 이 테이블이 진실의 원천이고, 개별 파서는 여기서
  /// 조회만 한다. 새 앱/표현을 추가할 땐 이 목록 한 줄만 늘리면 전체 파서에
  /// 자동 반영된다.)
  static const List<(String platform, String? appId, String label, List<String> keywords)>
      _appAliasCatalog = [
    ('youtube', null, '유튜브', ['유튜브', 'youtube', '유튭', '유튜브쇼츠', '쇼츠', 'shorts', '튜브']),
    (
      'instagram',
      null,
      'Instagram',
      ['인스타그램', '인스타', 'instagram', '릴스', 'reels', '인스타스토리', '스토리', '디엠', 'dm']
    ),
    ('brunch', null, 'Brunch', ['브런치', 'brunch']),
    ('app', 'tiktok', 'TikTok', ['틱톡', 'tiktok', '틱']),
    (
      'app',
      'kakao',
      '카카오톡',
      ['카카오톡', '카톡', '카카오', 'kakao', 'kakaotalk']
    ),
    // "인터넷"/"브라우저"는 사용자가 사파리를 부르는 일상 표현이다 — 이 목록에
    // 없어서 "인터넷 브라우저는 2300부터 0800까지 차단해줘" 같은 문장이 타깃을
    // 전혀 못 찾고 AI 폴백(키 없으면 explain)으로 새거나, 최악엔 문장 전체가
    // add_keyword로 잘못 등록되던 실사용 버그(2026-07-10).
    (
      'app',
      'safari',
      'Safari',
      ['사파리', 'safari', '인터넷', '브라우저', 'browser', '웹', '웹서핑', '인터넷창']
    ),
    ('app', 'chrome', 'Chrome', ['크롬', 'chrome']),
    ('app', 'whale', 'Whale', ['웨일', 'whale']),
    ('app', 'firefox', 'Firefox', ['파이어폭스', 'firefox', '파폭']),
    ('app', 'x', 'X', ['엑스', '트위터', 'twitter', 'x.com', 'x앱']),
    ('app', 'netflix', '넷플릭스', ['넷플릭스', 'netflix', '넷플']),
    ('app', 'discord', 'Discord', ['디스코드', 'discord', '디코']),
    ('app', 'facebook', 'Facebook', ['페이스북', 'facebook', '페북', 'fb']),
    ('app', 'threads', 'Threads', ['스레드', 'threads']),
    ('app', 'telegram', 'Telegram', ['텔레그램', 'telegram', '텔그']),
    ('app', 'line', 'LINE', ['라인', 'line']),
    ('app', 'whatsapp', 'WhatsApp', ['왓츠앱', 'whatsapp']),
    ('app', 'twitch', 'Twitch', ['트위치', 'twitch']),
    ('app', 'soop', '숲', ['아프리카', '아프리카tv', '숲', 'soop']),
    ('app', 'snapchat', 'Snapchat', ['스냅챗', 'snapchat']),
    ('app', 'pinterest', 'Pinterest', ['핀터레스트', 'pinterest', '핀터']),
    ('app', 'naver', '네이버', ['네이버', 'naver', '네이버앱']),
    ('app', 'naver_webtoon', '네이버웹툰', ['네이버웹툰', '웹툰', 'webtoon']),
    ('app', 'coupang', '쿠팡', ['쿠팡', 'coupang']),
    ('app', 'coupang_eats', '쿠팡이츠', ['쿠팡이츠']),
    ('app', 'baemin', '배달의민족', ['배달의민족', '배민', 'baemin']),
    ('app', 'yogiyo', '요기요', ['요기요', 'yogiyo']),
    ('app', 'melon', '멜론', ['멜론', 'melon']),
    ('app', 'genie', '지니뮤직', ['지니', '지니뮤직', 'genie']),
    ('app', 'bugs', '벅스', ['벅스', 'bugs']),
    ('app', 'ridi', '리디북스', ['리디', '리디북스', 'ridi']),
    ('app', 'pubg', '배틀그라운드', ['배그', 'pubg', '배틀그라운드']),
    ('app', 'lol', '리그오브레전드', ['롤', 'lol', '리그오브레전드']),
    ('app', 'overwatch', '오버워치', ['옵치', '오버워치', 'overwatch']),
    ('app', 'roblox', 'Roblox', ['로블록스', 'roblox']),
    ('app', 'minecraft', '마인크래프트', ['마크', '마인크래프트', 'minecraft']),
    ('app', 'brawlstars', '브롤스타즈', ['브롤', '브롤스타즈', 'brawlstars']),
    ('app', 'games', '게임', ['게임', '겜', 'game']),
  ];

  static (String platform, String? appId, String label)?
      _parseUsageBudgetTarget(
    String t,
  ) {
    for (final entry in _appAliasCatalog) {
      if (_hasAny(t, entry.$4)) return (entry.$1, entry.$2, entry.$3);
    }
    return _fuzzyAppAliasMatch(t);
  }

  /// 오타·변형 표현("유트브"/"카톡오"/"인스타그렘")은 정확한 alias 문자열
  /// 포함 매칭에 안 걸려서 대상 없이 add_keyword 최후수단으로 새 오타
  /// 자체가 키워드로 등록되던 문제(Cage에서 2026-07-13 발견한 것과 같은
  /// 클래스 — 유사도 매칭으로 이식). 편집거리(Levenshtein) 기반으로 카탈로그
  /// alias와 가장 가까운 항목을 찾는다. 2자 이하 토큰/alias는 "지금"↔"지니"
  /// (distance 1)처럼 거의 모든 문장에 나오는 흔한 기능어가 오매칭되는
  /// 사고가 나서(Cage 자체 회귀 테스트에서 발견) 3자 이상만 허용한다.
  static (String platform, String? appId, String label)? _fuzzyAppAliasMatch(
    String t,
  ) {
    final tokens = t
        .split(RegExp(r'[\s,.!?~/]+'))
        .map((w) => w.trim())
        .where((w) => w.length >= 3)
        .toList();
    if (tokens.isEmpty) return null;

    (String, String?, String)? best;
    var bestDistance = 1 << 30;

    for (final entry in _appAliasCatalog) {
      for (final alias in entry.$4) {
        if (alias.length <= 2) continue;
        final maxDistance = alias.length <= 4
            ? 1
            : (alias.length <= 7 ? 2 : 3);
        for (final token in tokens) {
          if ((token.length - alias.length).abs() > maxDistance) continue;
          final distance = _levenshteinDistance(token, alias);
          if (distance <= maxDistance && distance < bestDistance) {
            bestDistance = distance;
            best = (entry.$1, entry.$2, entry.$3);
          }
        }
      }
    }
    return best;
  }

  static int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          curr[j - 1] + 1,
          prev[j] + 1,
          prev[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[b.length];
  }

  static (String platform, String? appId, String label)?
      _usageBudgetTargetFromPlan(BlockChatPlan plan) {
    final app = (plan.appId ?? '').toLowerCase().trim();
    if (app.isNotEmpty) {
      switch (app) {
        case 'kakao':
        case 'kakaotalk':
          return ('app', 'kakao', '카카오톡');
        case 'tiktok':
          return ('app', 'tiktok', 'TikTok');
        case 'safari':
          return ('app', 'safari', 'Safari');
        case 'chrome':
          return ('app', 'chrome', 'Chrome');
        case 'netflix':
          return ('app', 'netflix', '넷플릭스');
        case 'discord':
          return ('app', 'discord', 'Discord');
        default:
          return ('app', app, app);
      }
    }

    final platform = (plan.limitPlatform ?? '').toLowerCase().trim();
    switch (platform) {
      case 'youtube':
        return ('youtube', null, '유튜브');
      case 'instagram':
        return ('instagram', null, 'Instagram');
      case 'brunch':
        return ('brunch', null, 'Brunch');
      case 'kakao':
      case 'kakaotalk':
        return ('app', 'kakao', '카카오톡');
      case 'app':
        return null;
      default:
        return platform.isEmpty ? null : ('app', platform, platform);
    }
  }

  static BlockChatPlan? _parseAppSessionLimit(String t) {
    if (!_hasAny(t, ['인스타', 'instagram', '틱톡', 'tiktok'])) return null;
    final mins = _parseAllMinutes(t);
    if (mins.length < 2) return null;

    final appId = _hasAny(t, ['틱톡', 'tiktok']) ? 'tiktok' : 'instagram';
    final session = mins[0];
    final cooldown = mins.length >= 2 ? mins[1] : 10;
    final daily = mins.length >= 3
        ? mins[2]
        : (_hasAny(t, ['하루', '총', '일일']) ? mins.last : session + cooldown);

    return BlockChatPlan(
      action: 'app_session_limit',
      appId: appId,
      dailyMinutes: daily,
      sessionMinutes: session,
      cooldownMinutes: cooldown,
      scheduleName: appId == 'tiktok' ? '틱톡 세션 (AI)' : '인스타 세션 (AI)',
      reply: '$appId — 하루 $daily분, ${session}분 쓰고 ${cooldown}분 쉬기',
    );
  }

  /// "X 키워드 숨겨줘" / "X 관련 글 안 뜨게" / "X 안 보이게 해줘" → 키워드 X
  static String? _extractExplicitKeyword(String raw, String t) {
    final hideCue =
        _hasAny(t, ['숨겨', '숨기', '숨김', '안 뜨', '안뜨', '안 보이', '안보이', '가려', '가림']);
    if (!hideCue) return null;
    // 시간/스케줄/URL/채널 문장은 키워드가 아니다.
    if (_looksLikeSchedule(t)) return null;
    if (raw.contains('://') ||
        _hasAny(t, [
          '.com',
          '.net',
          '.org',
          '채널',
          'channel',
          '사파리',
          'safari',
          '유튜브',
          'youtube',
          '인스타',
          'instagram',
          '틱톡',
          'tiktok',
          '브런치',
          'brunch',
        ])) {
      return null;
    }
    var kw = RegExp(r'(.+?)\s*(?:관련|키워드)').firstMatch(raw)?.group(1)?.trim();
    kw ??= RegExp(r'(.+?)\s*(?:안\s*뜨|안\s*보이|숨겨|숨기|가려)')
        .firstMatch(raw)
        ?.group(1)
        ?.trim();
    if (kw == null) return null;
    kw = kw
        .replaceAll(RegExp(r'^(유튜브|youtube|피드|feed|인스타|instagram)\s*'), '')
        .trim();
    kw = kw.replaceAll(RegExp(r'\s*(에서|에|의|글|영상|콘텐츠|컨텐츠)$'), '').trim();
    kw = kw
        .replaceAll(RegExp(r'\s*(글|영상|비디오|콘텐츠|컨텐츠)(은|는)?\s*(이제)?$'), '')
        .trim();
    kw = kw.replaceAll(RegExp(r'\s*(은|는)?\s*이제$'), '').trim();
    if (kw.length < 2 || kw.length > 24) return null;
    return kw;
  }

  static String? _extractNoMoreKeyword(String raw, String t) {
    if (!_hasAny(t, ['더이상', '더 이상', '그만', '안 보'])) return null;
    final m = RegExp(r'더\s*이상\s+(.+?)\s*(영상|비디오|콘텐츠|보고|블락|차단|숨김|안\s*보)')
        .firstMatch(raw);
    String? kw;
    if (m == null) {
      final plain = RegExp(r'(.+?)\s*더\s*이상').firstMatch(raw);
      kw = plain?.group(1)?.trim();
    } else {
      kw = m.group(1)?.trim();
    }
    if (kw == null || kw.length < 2) return null;
    kw = kw.replaceAll(RegExp(r'(유튜브|youtube)\s*$'), '').trim();
    return kw.length >= 2 ? kw : null;
  }

  static String? _extractYoutubeKeyword(String raw, String t) {
    if (_looksLikeSchedule(t)) return null;
    if (_hasAny(t, ['사파리', 'safari', '인스타', 'instagram', '틱톡', 'tiktok'])) {
      return null;
    }
    final m = RegExp(r'(.+?)\s*유튜브.*(블락|차단|숨김|숨기|block)', caseSensitive: false)
        .firstMatch(raw);
    final kw = m?.group(1)?.trim();
    if (kw == null || kw.length < 2 || kw.length > 24) return null;
    if (_hasAny(kw.toLowerCase(), ['내', 'isle', '이젤', '이슬', '매일', '아침']))
      return null;
    return kw;
  }

  /// 「10분에 3분만」 = 10분마다(창) 3분만(세션) — 창이 세션보다 먼저 나오는
  /// 어순 전용 감지. usage-budget류 함수 여러 곳에 각각 복붙돼 있던 걸
  /// 단일 헬퍼로 합쳤다(cage에서 먼저 정리, 여기로 역이식) — 이 패턴을 쓰는
  /// 곳은 반드시 이 함수를 거치게 할 것.
  static (int window, int session)? _matchIntervalThenSession(String t) {
    final normalized = _normalizeKoreanDurationWords(t);
    // "N시간에 M분씩"(창을 시간 단위로 말하는 흔한 어순)이 이 정규식에 아예
    // 안 걸려서 (기존엔 "N분에 M분"만 인식) intervalMatch가 null로 새고,
    // 아래 호출부들이 mins.first(=시간 단위 창을 분으로 환산한 값, 예:
    // "한시간"→60)를 세션으로 잘못 집어 "1시간에 5분씩만 허락해줘"가
    // session=60/cooldown=60/daily=60(입력한 5분은 완전히 무시)이 되던
    // 실사용 버그(2026-07-15, 사용자 제보). "분에"/"시간에" 둘 다 받고,
    // 시간 단위면 60을 곱해 분으로 환산한다.
    final m = RegExp(r'(\d+)\s*(분|시간)에\s*(\d+)\s*분').firstMatch(normalized);
    if (m == null) return null;
    final amount = int.tryParse(m.group(1)!);
    final session = int.tryParse(m.group(3)!);
    if (amount == null || session == null) return null;
    final window = m.group(2) == '시간' ? amount * 60 : amount;
    return (window, session);
  }

  /// "20분 보면 5분 쉬기"는 "20분마다 5분만 허용"이 아니라 session=20,
  /// cooldown=5다 — CAGE(11-1Isle_the_Blocker)에서 2026-07-15 사용자 실사용
  /// 제보로 먼저 발견·수정한 근본 원인(문구마다 window/session이 뒤바뀌던
  /// 버그)을 MOA에도 동일하게 이식한다. iOS DeviceActivity는 "고정 시간창
  /// 누적" 모델만 지원하고 idle-gap 리셋은 노출하지 않으므로, window은
  /// 명시적으로 "N시간 안에"가 있으면 그 값, 없으면 session+rest로 근사한다.
  static ({int session, int rest, int window})? _matchWatchThenRestCadence(
      String t) {
    final normalized = _normalizeKoreanDurationWords(t);

    final explicitHourWindow = RegExp(
      r'(\d+)\s*시간\s*안에[^0-9]{0,12}(\d+)\s*분[^0-9]{0,16}(\d+)\s*분\s*(?:쉬|휴식)',
    ).firstMatch(normalized);
    if (explicitHourWindow != null) {
      final hours = int.tryParse(explicitHourWindow.group(1)!) ?? 1;
      final session = int.tryParse(explicitHourWindow.group(2)!) ?? 0;
      final rest = int.tryParse(explicitHourWindow.group(3)!) ?? 0;
      if (session > 0 && rest > 0) {
        return (
          session: session.clamp(1, 60).toInt(),
          rest: rest.clamp(1, 480).toInt(),
          window: (hours * 60).clamp(1, 480).toInt(),
        );
      }
    }

    final watchThenRest = RegExp(
      r'(\d+)\s*분\s*(?:보면|보고|쓰면|쓰고|사용하면|사용하고|이용하면|이용하고)[^0-9]{0,12}(\d+)\s*분\s*(?:쉬|휴식)',
    ).firstMatch(normalized);
    if (watchThenRest != null) {
      final session = int.tryParse(watchThenRest.group(1)!) ?? 0;
      final rest = int.tryParse(watchThenRest.group(2)!) ?? 0;
      if (session > 0 && rest > 0) {
        return (
          session: session.clamp(1, 60).toInt(),
          rest: rest.clamp(1, 480).toInt(),
          window: (session + rest).clamp(1, 480).toInt(),
        );
      }
    }

    final intervalRest = RegExp(
      r'(\d+)\s*분\s*(?:마다|에)\s*(\d+)\s*분(?:씩)?\s*(?:쉬|휴식)',
    ).firstMatch(normalized);
    if (intervalRest != null) {
      final session = int.tryParse(intervalRest.group(1)!) ?? 0;
      final rest = int.tryParse(intervalRest.group(2)!) ?? 0;
      if (session > 0 && rest > 0) {
        return (
          session: session.clamp(1, 60).toInt(),
          rest: rest.clamp(1, 480).toInt(),
          window: (session + rest).clamp(1, 480).toInt(),
        );
      }
    }

    return null;
  }

  static List<int> _parseAllMinutes(String t) {
    final normalized = _normalizeKoreanDurationWords(t);
    // "N시간[ M분]"은 분으로 환산, 단독 "N분"도 처리 — 텍스트 순서 유지
    final out = <int>[];
    final re = RegExp(r'(\d+)\s*시간(?:\s*(\d+)\s*분)?|(\d+)\s*분');
    for (final m in re.allMatches(normalized)) {
      final int val;
      if (m.group(1) != null) {
        val = (int.tryParse(m.group(1)!) ?? 0) * 60 +
            (int.tryParse(m.group(2) ?? '') ?? 0);
      } else {
        val = int.tryParse(m.group(3)!) ?? 0;
      }
      if (val > 0 && val <= 480) out.add(val);
    }
    return out;
  }

  static int? _parseDailyCapMinutes(String t) {
    final normalized = _normalizeKoreanDurationWords(t);
    final cueBeforeHour = RegExp(
      r'(하루|일일|총|전체|최대)[^0-9]{0,10}(\d+)\s*시간(?:\s*(\d+)\s*분)?',
    ).firstMatch(normalized);
    if (cueBeforeHour != null) {
      final h = int.tryParse(cueBeforeHour.group(2) ?? '') ?? 0;
      final m = int.tryParse(cueBeforeHour.group(3) ?? '') ?? 0;
      return h * 60 + m;
    }

    final cueBeforeMinute = RegExp(
      r'(하루|일일|총|전체|최대)[^0-9]{0,10}(\d+)\s*분',
    ).firstMatch(normalized);
    if (cueBeforeMinute != null) {
      return int.tryParse(cueBeforeMinute.group(2) ?? '');
    }

    final cueAfterHour = RegExp(
      r'(\d+)\s*시간(?:\s*(\d+)\s*분)?[^가-힣a-zA-Z0-9]{0,6}(하루|일일|총|전체|최대)',
    ).firstMatch(normalized);
    if (cueAfterHour != null) {
      final h = int.tryParse(cueAfterHour.group(1) ?? '') ?? 0;
      final m = int.tryParse(cueAfterHour.group(2) ?? '') ?? 0;
      return h * 60 + m;
    }

    final cueAfterMinute = RegExp(
      r'(\d+)\s*분[^가-힣a-zA-Z0-9]{0,6}(하루|일일|총|전체|최대)',
    ).firstMatch(normalized);
    if (cueAfterMinute != null) {
      return int.tryParse(cueAfterMinute.group(1) ?? '');
    }
    return null;
  }

  static int? _parseRestMinutes(String t) {
    final normalized = _normalizeKoreanDurationWords(t);
    // 'lock' — "N분 lock" 처럼 영어로 쓰는 경우도 쿨다운 신호로 인식.
    final restWords = r'(쉬|쉰|잠기|잠가|잠금|닫|닫아|기다|뒤|후|지나|충전|리필|lock)';
    // "카카오톡 잠금이 아니라 3분" 처럼 부정어가 낀 매치는 "이렇게 하지 마라"는
    // 뜻이지 방금 언급한 숫자의 쿨다운이 아니다 — 매치 구간에 부정어가 있으면 건너뛴다.
    final negation = RegExp(r'아니|말고|아님');
    bool negated(RegExpMatch m) => negation.hasMatch(normalized.substring(m.start, m.end));

    final beforeHour = RegExp(
      r'(\d+)\s*시간(?:\s*(\d+)\s*분)?[^0-9.。!?]{0,14}' + restWords,
    );
    for (final m in beforeHour.allMatches(normalized)) {
      if (negated(m)) continue;
      final h = int.tryParse(m.group(1) ?? '') ?? 0;
      final mm = int.tryParse(m.group(2) ?? '') ?? 0;
      final total = h * 60 + mm;
      if (total > 0) return total;
    }

    final beforeMinute = RegExp(
      r'(\d+)\s*분[^0-9.。!?]{0,14}' + restWords,
    );
    for (final m in beforeMinute.allMatches(normalized)) {
      if (negated(m)) continue;
      final v = int.tryParse(m.group(1) ?? '');
      if (v != null) return v;
    }

    final afterHour = RegExp(
      restWords + r'[^0-9]{0,12}(\d+)\s*시간(?:\s*(\d+)\s*분)?',
    );
    for (final m in afterHour.allMatches(normalized)) {
      if (negated(m)) continue;
      final h = int.tryParse(m.group(2) ?? '') ?? 0;
      final mm = int.tryParse(m.group(3) ?? '') ?? 0;
      final total = h * 60 + mm;
      if (total > 0) return total;
    }

    final afterMinute = RegExp(
      restWords + r'[^0-9]{0,12}(\d+)\s*분',
    );
    for (final m in afterMinute.allMatches(normalized)) {
      if (negated(m)) continue;
      final v = int.tryParse(m.group(2) ?? '');
      if (v != null) return v;
    }

    return null;
  }

  static String _normalizeKoreanDurationWords(String t) {
    var out = t;
    const words = {
      '한': 1,
      '두': 2,
      '세': 3,
      '네': 4,
      '다섯': 5,
      '여섯': 6,
      '일곱': 7,
      '여덟': 8,
      '아홉': 9,
      '열': 10,
      '열다섯': 15,
      '스무': 20,
      '서른': 30,
      '마흔': 40,
      '쉰': 50,
      '한시간': 60,
    };
    final entries = words.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final e in entries) {
      if (e.key == '한시간') {
        out = out.replaceAll(e.key, '1시간');
        continue;
      }
      out = out.replaceAll(RegExp('${e.key}\\s*시간'), '${e.value}시간');
      out = out.replaceAll(RegExp('${e.key}\\s*분'), '${e.value}분');
    }
    return out;
  }

  static int? _parseRepeatCount(String t) {
    final digit = RegExp(r'(\d+)\s*(번|회)').firstMatch(t);
    if (digit != null) {
      final n = int.tryParse(digit.group(1)!);
      if (n != null && n >= 2 && n <= 24) return n;
    }

    const words = {
      '두': 2,
      '세': 3,
      '네': 4,
      '다섯': 5,
      '여섯': 6,
      '일곱': 7,
      '여덟': 8,
      '아홉': 9,
      '열': 10,
    };
    for (final e in words.entries) {
      if (RegExp('${e.key}\\s*(번|회)').hasMatch(t)) return e.value;
    }
    return null;
  }

  static bool _hasAny(String t, List<String> needles) {
    for (final n in needles) {
      if (t.contains(n.toLowerCase())) return true;
    }
    return false;
  }

  static BlockChatPlan? _parseRemoveUrl(String raw, String t) {
    if (!_hasAny(t, ['제거', '해제', '풀어', '삭제', '없애', 'remove', 'unblock'])) {
      return null;
    }
    final urlCue = _hasAny(t, ['url', '링크', '주소', 'http', 'www.']) ||
        raw.contains('://') ||
        raw.contains('www.');
    if (!urlCue && !_hasAny(t, ['블락', '블록', '차단', 'block'])) return null;

    final url = _extractUrl(raw);
    if (url == null || url.length < 8) return null;

    final short = url.length > 40 ? '${url.substring(0, 37)}…' : url;
    return BlockChatPlan(
      action: 'remove_url',
      removeUrl: url,
      reply: 'URL 「$short」 차단 해제 — 제거 타임락이 켜져 있으면 대기 후 자동으로 해제돼요.',
    );
  }

  static String? _extractUrl(String raw) {
    final m = RegExp(r'(https?://[^\s\)\]」』"]+)').firstMatch(raw);
    if (m != null) return m.group(1)?.trim();
    final www = RegExp(r'(www\.[^\s\)\]」』"]+)').firstMatch(raw);
    if (www != null) return 'https://${www.group(1)?.trim()}';
    return null;
  }

  static String? _extractQuoted(String raw) {
    // 「」 『』 "" '' 곡선따옴표(‘’ “”) 모두 인식
    final m = RegExp('[「『"\'‘“]([^」』"\'’”]+)[」』"\'’”]').firstMatch(raw);
    return m?.group(1)?.trim();
  }

  /// 「10시30분」「10:30」「10시」
  static (int, int)? _parseEndTime(String t) {
    // "23:00부터 11:00까지"·"23:00 - 11:00"처럼 시각이 두 개 나오면
    // firstMatch로는 시작 시각(23:00)을 종료 시각으로 잘못 집는다(실사용
    // 치명적 버그, cage에서 07-08 진단·수정 — 여기도 같은 코드가 복붙돼
    // 있어 이식). "까지" 바로 앞 시각 → 대시 범위의 뒤쪽 시각 순으로
    // 우선 시도하고, 없을 때만 아래 firstMatch 폴백.
    final hmBeforeUntil =
        RegExp(r'(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?\s*까지').firstMatch(t);
    if (hmBeforeUntil != null) {
      final h = int.tryParse(hmBeforeUntil.group(1)!);
      final m = int.tryParse(hmBeforeUntil.group(2) ?? '0') ?? 0;
      if (h != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        return (h, m);
      }
    }
    final colonBeforeUntil = RegExp(r'(\d{1,2}):(\d{2})\s*까지').firstMatch(t);
    if (colonBeforeUntil != null) {
      final h = int.tryParse(colonBeforeUntil.group(1)!);
      final m = int.tryParse(colonBeforeUntil.group(2)!);
      if (h != null && h >= 0 && h <= 23 && m != null && m >= 0 && m <= 59) {
        return (h, m);
      }
    }
    final colonRange =
        RegExp(r'(\d{1,2}):(\d{2})\s*[-~]\s*(\d{1,2}):(\d{2})').firstMatch(t);
    if (colonRange != null) {
      final h = int.tryParse(colonRange.group(3)!);
      final m = int.tryParse(colonRange.group(4)!);
      if (h != null && h >= 0 && h <= 23 && m != null && m >= 0 && m <= 59) {
        return (h, m);
      }
    }
    final hm = RegExp(r'(\d{1,2})\s*시\s*(\d{1,2})\s*분').firstMatch(t);
    if (hm != null) {
      final h = int.tryParse(hm.group(1)!);
      final m = int.tryParse(hm.group(2)!);
      if (h != null && h >= 0 && h <= 23 && m != null && m >= 0 && m <= 59) {
        return (h, m);
      }
    }
    final colon = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(t);
    if (colon != null) {
      final h = int.tryParse(colon.group(1)!);
      final m = int.tryParse(colon.group(2)!);
      if (h != null && h >= 0 && h <= 23 && m != null && m >= 0 && m <= 59) {
        return (h, m);
      }
    }
    // "2시간 차단해줘"의 "2시"를 절대 시각(오후 2시)으로 잘못 집던 버그
    // (2026-07-13 사용자 제보 — "인터넷 2시간간 차단해둬"가 "매일 0시~2시"로
    // 오해석됨). "시" 바로 뒤에 "간"이 오면(="시간"이라는 기간 단위 낱말)
    // 절대 시각이 아니므로 제외한다 — negative lookahead.
    final hOnly = RegExp(r'(\d{1,2})\s*시(?!간)').firstMatch(t);
    if (hOnly != null) {
      final h = int.tryParse(hOnly.group(1)!);
      if (h != null && h >= 1 && h <= 23) return (h, 0);
    }
    // "2200 - 0930까지"처럼 "시"·콜론 없이 순수 4자리(HHMM)만 쓴 경우 —
    // 위 케이스들이 전부 못 잡아서 기본값(11시)으로 조용히 대체되던 버그
    // (2026-07-11 cage 제보 — 유튜브 뮤직 종료 시각이 09:30 대신 11:00으로 나옴).
    final hhmmBeforeUntil = RegExp(r'(\d{4})\s*까지').firstMatch(t);
    if (hhmmBeforeUntil != null) {
      final token = _parseHHMMToken(hhmmBeforeUntil.group(1)!);
      if (token != null) return token;
    }
    final hhmmRange =
        RegExp(r'\d{4}\s*[-~]\s*(\d{4})').firstMatch(t);
    if (hhmmRange != null) {
      final token = _parseHHMMToken(hhmmRange.group(1)!);
      if (token != null) return token;
    }
    return null;
  }

  static String? _extractBeforeBlock(String t) {
    if (_looksLikeSchedule(t)) return null;
    if (_hasAny(t, [
      '사파리',
      'safari',
      '유튜브',
      'youtube',
      '인스타',
      'instagram',
      '틱톡',
      'tiktok',
      '브런치',
      'brunch',
      '웹',
      '브라우저',
      '24시간',
      '하루종일',
      '하루 종일',
      '종일',
    ])) {
      return null;
    }
    for (final sep in ['블락', '차단', '숨김', '숨기']) {
      final i = t.indexOf(sep);
      if (i > 0) {
        final before = t.substring(0, i).trim();
        if (before.length >= 2 && before.length <= 24) return before;
      }
    }
    return null;
  }

  /// Safari·항상-막기 N분 임시 해제 — relax_block과 구분
  static BlockChatPlan? _parseSafariPause(String raw, String t) {
    final hasUnlock = _hasAny(t, ['풀', '해제', '잠깐', '잠시', 'pause', 'unblock']);
    // "열어줘/열어" 단독은 분 지정 or 잠깐이 있을 때만 safari_pause; 없으면 persona가 처리
    final hasOpenOnly = !hasUnlock && t.contains('열어');
    if (!hasUnlock && !hasOpenOnly) return null;
    if (hasOpenOnly && !RegExp(r'\d+\s*분').hasMatch(t) && !_hasAny(t, ['잠깐', '잠시', 'pause'])) return null;
    if (!_hasAny(t, ['safari', '사파리', '항상', '쉴드', '앱 막'])) return null;
    if (_hasAny(t, ['스케줄', '키워드', '영상', '채널'])) return null;
    // "사파리 차단 해제" (시간 없음) → 영구 해제(relax_block)이 처리
    if (t.contains('차단 해제') && !RegExp(r'\d+\s*분').hasMatch(t) &&
        !_hasAny(t, ['잠깐', '잠시', 'pause'])) return null;

    final mins = _parseAllMinutes(t);
    var pause = 10;
    if (mins.isNotEmpty) {
      pause = mins.first;
    } else if (t.contains('5분') || t.contains('5 분')) {
      pause = 5;
    } else if (t.contains('15분') || t.contains('15 분')) {
      pause = 15;
    }
    pause = pause.clamp(5, 15);
    if (pause != 5 && pause != 10 && pause != 15) {
      pause = pause <= 7 ? 5 : (pause <= 12 ? 10 : 15);
    }

    return BlockChatPlan(
      action: 'safari_pause',
      pauseMinutes: pause,
      reply: 'Safari·앱 쉴드를 ${pause}분만 임시 해제합니다. 만료 후 자동 재잠금.',
    );
  }

  static BlockChatPlan? _parseReelsGuardToggle(String t) {
    // 릴스 둠스크롤 멈춤 오버레이 전용 — 단순 숨김(toggle_reels)이 먼저 처리
    final scrollCue = _hasAny(t, [
      '둠스크롤',
      '무한스크롤',
      '무한 스크롤',
      '스크롤 멈',
      '스크롤막',
      '넘기면 멈',
    ]);
    final reels = _hasAny(t, ['릴', 'reels', '릴스', '인스타', 'instagram']);
    if (!scrollCue && !(reels && _hasAny(t, ['멈춰', '멈추', '끊', '멈춤']))) {
      return null;
    }

    final show = _hasAny(t, ['끄', '꺼', '해제', '풀어', '다시', 'off']);
    final hide = _hasAny(t, [
      '멈춰',
      '멈추',
      '막',
      '끊',
      'guard',
      '둠스크롤',
      '무한',
      '그만',
      '싫',
    ]);
    final on = hide && !show;

    return BlockChatPlan(
      action: 'toggle_reels_guard',
      toggleOn: on,
      reply: on ? '인스타 피드 릴스 둠스크롤 멈춤을 켭니다.' : '릴스 둠스크롤 멈춤을 끕니다.',
    );
  }

  /// "2300" 같은 순수 4자리 HHMM — "시" 마커 없이 숫자만 쓰는 표현.
  static (int hour, int minute)? _parseHHMMToken(String token) {
    if (token.length != 4) return null;
    final h = int.tryParse(token.substring(0, 2));
    final m = int.tryParse(token.substring(2, 4));
    if (h == null || m == null || h > 23 || m > 59) return null;
    return (h, m);
  }

  static (int hour, int minute)? _parseNightStartTime(String raw, String t) {
    final startOnly = RegExp(
      r'(?:밤|저녁|야간|오후)?\s*(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?\s*(?:부터|이후|부터는|이후로|넘으면|에서|에서는)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (startOnly != null) {
      final rawHour = int.tryParse(startOnly.group(1)!) ?? 23;
      final minute = (int.tryParse(startOnly.group(2) ?? '') ?? 0).clamp(0, 59);
      var hour = rawHour;
      final nightCue = _hasAny(t, ['밤', '저녁', '야간', '취침', '오후']) ||
          (_hasAny(t, ['부터', '이후']) && rawHour >= 9 && rawHour <= 11);
      if (nightCue && hour >= 1 && hour <= 11) hour += 12;
      if (hour == 12 && _hasAny(t, ['밤', '자정', '취침'])) hour = 0;
      return (hour.clamp(0, 23), minute);
    }
    // "23시" 대신 "2300부터"처럼 순수 숫자만 쓴 경우 — 실사용 버그(2026-07-06,
    // cage 앱 카카오톡 "2300부터 0700까지")로 발견. 못 읽으면 야간 나눠쓰기 경로
    // 자체가 발동을 안 해서 시간대 제한 없이 하루 종일 적용돼 버린다.
    final hhmm = RegExp(r'(\d{4})\s*(?:부터|이후|부터는|이후로|넘으면|에서|에서는)')
        .firstMatch(raw);
    if (hhmm != null) return _parseHHMMToken(hhmm.group(1)!);
    // "23:00부터"처럼 콜론(HH:MM) + 한국어 조사 — 하이픈 범위가 아니어도
    // 흔히 쓰는 표기라 못 읽으면 시작 시각이 통째로 사라진다(2026-07-11 cage 제보).
    final clockBeforeFrom = RegExp(r'(\d{1,2}):(\d{2})\s*(?:부터|이후|부터는|이후로|넘으면|에서|에서는)')
        .firstMatch(raw);
    if (clockBeforeFrom != null) {
      final h = int.tryParse(clockBeforeFrom.group(1)!);
      final m = int.tryParse(clockBeforeFrom.group(2)!);
      if (h != null && m != null && h <= 23 && m <= 59) return (h, m);
    }
    // "22:30 - 14:00"처럼 콜론(HH:MM) 범위 — "부터/까지" 같은 한국어 조사
    // 없이도 흔히 쓰는 표기라 못 읽으면 시작 시각이 통째로 사라진다
    // (2026-07-11 cage 제보). "-"·"~"로 구분된 첫 번째 시각을 시작으로 본다.
    final clockRange =
        RegExp(r'(\d{1,2}):(\d{2})\s*[-~]\s*\d{1,2}:\d{2}').firstMatch(raw);
    if (clockRange != null) {
      final h = int.tryParse(clockRange.group(1)!);
      final m = int.tryParse(clockRange.group(2)!);
      if (h != null && m != null && h <= 23 && m <= 59) return (h, m);
    }
    return null;
  }

  /// 「다음날 12시까지」「아침 7시까지」 — 야간 구간의 종료 시각.
  /// 정오(12시)를 밤 시작 시각처럼 24h 변환해 자정 넘겨 버리지 않게 그대로 둔다.
  static (int hour, int minute)? _parseNightEndTime(String raw, String t) {
    final m = RegExp(
      r'(?:다음\s*날|다음날|익일|이튿날|아침|새벽|낮|정오)?\s*(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?\s*까지',
      caseSensitive: false,
    ).firstMatch(raw);
    if (m != null) {
      final h = int.tryParse(m.group(1)!);
      if (h == null || h < 0 || h > 23) return null;
      final min = (int.tryParse(m.group(2) ?? '') ?? 0).clamp(0, 59);
      return (h, min);
    }
    // "0700까지"처럼 순수 HHMM — 시작 시각과 동일한 실사용 버그.
    final hhmm = RegExp(r'(\d{4})\s*까지').firstMatch(raw);
    if (hhmm != null) return _parseHHMMToken(hhmm.group(1)!);
    // "22:30 - 14:00" — 콜론 범위의 두 번째(끝) 시각.
    final clockRange =
        RegExp(r'\d{1,2}:\d{2}\s*[-~]\s*(\d{1,2}):(\d{2})').firstMatch(raw);
    if (clockRange != null) {
      final h = int.tryParse(clockRange.group(1)!);
      final min = int.tryParse(clockRange.group(2)!);
      if (h != null && min != null && h <= 23 && min <= 59) return (h, min);
    }
    // "11:30까지"처럼 콜론(HH:MM) 단독 종료 시각 — 시작 쪽(_parseNightStartTime의
    // clockBeforeFrom)엔 이미 지원되는데 종료 쪽엔 빠져 있었다(2026-07-13 실사용
    // 확인: "11:30까지는 인터넷 브라우저 차단해줘"가 아무 파서에도 안 걸렸음).
    final clockBeforeUntil =
        RegExp(r'(\d{1,2}):(\d{2})\s*까지').firstMatch(raw);
    if (clockBeforeUntil != null) {
      final h = int.tryParse(clockBeforeUntil.group(1)!);
      final min = int.tryParse(clockBeforeUntil.group(2)!);
      if (h != null && min != null && h <= 23 && min <= 59) return (h, min);
    }
    return null;
  }

  /// "브라우저는 10시부터 쓸 수 있게 해줘"/"카톡 9시부터 열어줘"처럼 "차단"
  /// 이란 단어 없이 시작 경계 하나만("~까지"는 없이) 말하는 요청 — 자정부터
  /// 그 시각까지는 막고 그 이후엔 자유롭게 쓰게 하는 아침 차단으로 해석한다
  /// (night_schedule과 동일 실행 경로 재사용 — 이미 다중 타깃/카탈로그 지원됨).
  /// _parseAllowWindow는 유튜브 전용+닫힌 구간("부터~까지" 둘 다 필요)만
  /// 지원해서, 이 문장은 아무 파서에도 안 걸리고 AI 폴백으로 새고 있었다
  /// (2026-07-13 발견 — "브라우저는 1000부터 쓸 수 있게 해줘").
  static BlockChatPlan? _parseAllowFromMorningBlock(String raw, String t) {
    final allowCue =
        _hasAny(t, ['쓸 수', '쓸수', '쓰게', '허용', '열어', '풀어', '보게']);
    if (!allowCue) return null;
    // 닫힌 범위("~까지")는 _parseAllowWindow(유튜브)/night_schedule 쪽 몫 —
    // 여기는 시작 경계 하나만 있는 경우 전용.
    if (_hasAny(t, ['까지'])) return null;

    final target = _parseUsageBudgetTarget(t);
    if (target == null) return null;

    final clockMatch =
        RegExp(r'(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?\s*(?:부터|이후)')
            .firstMatch(raw);
    int hour;
    int minute;
    if (clockMatch != null) {
      hour = int.tryParse(clockMatch.group(1)!) ?? -1;
      minute = int.tryParse(clockMatch.group(2) ?? '') ?? 0;
    } else {
      final hhmmMatch = RegExp(r'(\d{4})\s*부터').firstMatch(raw);
      if (hhmmMatch == null) return null;
      final token = _parseHHMMToken(hhmmMatch.group(1)!);
      if (token == null) return null;
      hour = token.$1;
      minute = token.$2;
    }
    if (hour < 0 || hour > 23) return null;
    // 자정 시작("0시부터")이면 사실상 막는 구간이 없는 요청 — 다른 파서(허용
    // 창 등)로 넘긴다.
    if (hour == 0 && minute == 0) return null;

    final appId = target.$1 == 'app' ? target.$2 : null;
    final limitPlatform = target.$1 != 'app' ? target.$1 : null;
    final label = target.$3;

    return BlockChatPlan(
      action: 'night_schedule',
      scheduleName: '아침 $label 차단 (AI)',
      startHour: 0,
      startMinute: 0,
      endHour: hour,
      endMinute: minute,
      appId: appId,
      limitPlatform: limitPlatform,
      reply: '매일 00:00~${_fmt(hour, minute)}까지 $label 를 막고, '
          '그 이후엔 자유롭게 쓸 수 있게 할게요.',
    );
  }

  /// 카테고리 키워드 → 차단 카탈로그 타깃 매핑. `_parseMultiCategoryNightBlock`과
  /// 집중 모드(`_parseFocusModeAnswer`)가 공유(cage 2026-07-13 이식). 모아는
  /// 인앱(isle_*) 전용 제품이라 유튜브·인스타·브라우저만 대상이고, 카카오톡·
  /// 틱톡·게임처럼 모아 안에 대응하는 인앱 화면이 없는 건 아예 다루지 않는다
  /// (2026-07-11/12 사용자 확정 — Cage와 달리 실기기 앱 자체를 못 막는다).
  static ({
    List<String> targetIds,
    List<String> labels,
    List<String> unmapped,
    bool blockSafari,
  }) _matchAppBlockCategories(String t) {
    final targetIds = <String>[];
    final labels = <String>[];
    final unmapped = <String>[];

    final mentionsMusic = _hasAny(t, ['뮤직', 'music', 'ytm']);
    final mentionsYoutube = _hasAny(t, ['유튜브', 'youtube']);
    if (mentionsYoutube && !mentionsMusic) {
      targetIds.add('isle_youtube');
      labels.add('YouTube');
    }
    if (_hasAny(t, ['인스타', 'instagram'])) {
      targetIds.add('isle_instagram');
      labels.add('Instagram');
    }

    var blockSafari = false;
    if (_hasAny(t, ['브라우저', '사파리', 'safari', '크롬', 'chrome'])) {
      blockSafari = true;
      labels.add('브라우저(Safari)');
    }
    // 카탈로그에 없는 카테고리(특정 앱 하나로 못 좁히는 것들) — 자동으로는
    // 못 고르니 Screen Time 앱 선택창에서 사용자가 직접 추가해야 한다고 안내만.
    if (_hasAny(t, ['코딩', '개발툴', '개발 툴', 'coding'])) {
      unmapped.add('AI 코딩 툴');
    }

    return (
      targetIds: targetIds,
      labels: labels,
      unmapped: unmapped,
      blockSafari: blockSafari,
    );
  }

  /// "집중 모드 해줘" 트리거만 담당 — 실제로 뭘 막을지는 다음 메시지로
  /// 미룬다(cage 2026-07-13 이식). Cage와 동일하게 `_parseFollowUpCorrection`
  /// (previousPlan 기반 후속 교정) 훅을 그대로 재사용한다.
  static BlockChatPlan? _parseFocusModeTrigger(String t) {
    if (!_hasAny(t, ['집중모드', '집중 모드', '포커스모드', '포커스 모드'])) {
      return null;
    }
    return const BlockChatPlan(
      action: 'focus_mode_ask',
      reply: '오늘 하루 집중 모드! 오늘은 뭘 막을까요? — 예: "유튜브랑 인스타" · '
          '"인스타만" · "전부 다"\n(모아는 앱 안에서 보는 유튜브·인스타·브라우저만 '
          '다뤄요 — 실제 기기의 다른 앱은 못 막아요.)',
    );
  }

  static int? _parseDurationHours(String raw) {
    final match = RegExp(r'(\d+)\s*시간(?:\s*(?:동안|짜리|간))?').firstMatch(raw);
    final h = match == null ? null : int.tryParse(match.group(1)!);
    return h != null && h > 0 ? h : null;
  }

  static BlockChatPlan? _parseStudyMode(String raw, String t) {
    if (!_hasAny(t, ['공부모드', '공부 모드', '스터디모드', '스터디 모드', 'study mode'])) {
      return null;
    }
    final hours = _parseDurationHours(raw) ?? 6;
    final wantsBrowser = _hasAny(t, ['브라우저', '사파리', 'safari', '크롬', 'chrome']);
    final wantsYoutube = _hasAny(t, ['유튜브', 'youtube']);
    final wantsPomodoro = _hasAny(t, ['pomodoro', '포모도로', '포모도']);
    final wantsYoutubeLimit = wantsYoutube &&
        (_hasAny(t, ['8분', '10분', '15분', '20분', '30분']) || _hasAny(t, ['제한']));

    final subPlans = <BlockChatPlan>[
      if (wantsBrowser)
        BlockChatPlan(
          action: 'quick_block_now',
          limitPlatform: 'safari',
          windowMinutes: hours * 60,
          reply: '',
        ),
      if (wantsYoutubeLimit)
        BlockChatPlan(
          action: 'usage_budget',
          limitPlatform: 'youtube',
          dailyMinutes: 480,
          sessionMinutes: _parseAllMinutes(t).isNotEmpty ? _parseAllMinutes(t).first : 8,
          windowMinutes: 60,
          cooldownMinutes: 60,
          reply: '',
        ),
      if (wantsYoutube && !wantsYoutubeLimit)
        BlockChatPlan(
          action: 'quick_block_now',
          limitPlatform: 'youtube',
          windowMinutes: hours * 60,
          reply: '',
        ),
    ];

    if (subPlans.isEmpty) {
      subPlans.add(
        BlockChatPlan(
          action: 'quick_block_now',
          limitPlatform: 'safari',
          windowMinutes: hours * 60,
          reply: '',
        ),
      );
    }

    return BlockChatPlan(
      action: 'study_mode',
      scheduleName: '공부 모드 (AI)',
      windowMinutes: hours * 60,
      subPlans: subPlans,
      reply: '공부 모드를 ${hours}시간 동안 켤게요.'
          '${wantsPomodoro ? ' 포모도로도 같이 켭니다.' : ''}',
    );
  }

  /// focus_mode_ask 직후 카테고리 답변 — "유튜브랑 인스타"/"전부 다"류.
  /// Cage(temp_block, 절대시각 만료)와 달리 모아 스케줄 모델엔 1회성 만료
  /// 개념(oneShot)이 아예 없어서(2026-07-13 확인) 그 방식을 그대로 못
  /// 쓴다 — 대신 기존에 이미 지원되는 "밤 시작 시각 > 종료 시각"이면 자정을
  /// 넘겨 처리하는 night_schedule 엔진을 오늘 요일 하루치 슬롯으로 재사용한다.
  /// 다만 이 스케줄은 요일 단위 반복이라 다음 주 같은 요일에도 다시
  /// 켜진다는 한계가 있어(cage의 옛날 _parseImmediateTimedBlock 한계와
  /// 동일) 답변 문구에 명시한다.
  static BlockChatPlan? _parseFocusModeAnswer(String t) {
    final wantsAll = _hasAny(t, ['전부', '모두', '전체']);
    final matched = wantsAll
        ? (
            targetIds: <String>['isle_youtube', 'isle_instagram'],
            labels: <String>['YouTube', 'Instagram', '브라우저(Safari)'],
            unmapped: <String>[],
            blockSafari: true,
          )
        : _matchAppBlockCategories(t);

    final categoryCount = matched.labels.length + matched.unmapped.length;
    if (categoryCount == 0) {
      return const BlockChatPlan(
        action: 'focus_mode_ask',
        reply: '음, 뭘 막을지 못 알아들었어요. "유튜브", "인스타", "브라우저" 중에서 '
            '골라 말해주거나 "전부 다"라고 해주세요.',
      );
    }

    final now = DateTime.now();
    final today = (now.weekday - 1).clamp(0, 6);
    final allLabels = [...matched.labels, ...matched.unmapped].join(', ');
    final unmappedNote = matched.unmapped.isEmpty
        ? ''
        : ' ${matched.unmapped.join(', ')}은(는) 특정 앱 하나로 못 정해서 자동으로는 안 골라져요.';

    return BlockChatPlan(
      action: 'night_schedule',
      scheduleName: '집중 모드 — $allLabels (AI)',
      days: [today],
      startHour: now.hour,
      startMinute: now.minute,
      endHour: 1,
      endMinute: 0,
      extraTargetIds: matched.targetIds,
      blockSafariNote: matched.blockSafari,
      unmappedCategoryLabels: matched.unmapped.isEmpty ? null : matched.unmapped,
      reply: '오늘 집중 모드 시작! $allLabels 지금부터 오늘 밤(자정 넘겨) 01:00까지 '
          '차단해요.$unmappedNote 다만 이 요일마다 매주 반복되는 스케줄이라, '
          '한 번만 쓰려면 끝난 뒤 스케줄에서 지워주세요.',
    );
  }

  /// "23:00-10:00까지 유튜브, 카카오톡, 브라우저 차단해줘"처럼 한 문장에
  /// 카테고리가 2개 이상 섞여 있으면 전부 같은 스케줄 하나에 동시에 건다
  /// (cage 2026-07-11 이식). 카테고리가 1개뿐이면 null을 반환해 기존
  /// _parseNightSchedule(단일 타깃 전용)로 흘러가게 한다.
  /// "7월25일부터 7월30일까지 인스타 차단해줘"/"내일부터 3일간 유튜브
  /// 차단해줘"/"다음주부터 일주일 동안 SNS 막아줘" — 특정 미래 날짜(구간)
  /// 에만 적용되는 예약 스케줄(2026-07-20 신설, "여행 동안" 류 사용자 요청).
  /// 기간이 보통 며칠 단위(1-2시간짜리 즉석차단과 다름)라 기본적으로
  /// `reservationLocked: true`로 만든다 — 사용자가 "예약 기간에도 타임락
  /// 해제가 통하면 안 된다"고 명시적으로 요청했다.
  static BlockChatPlan? _parseScheduledReservation(String raw, String t) {
    if (_hasAny(t, ['풀어', '풀기', '해제', '허용', '열어'])) return null;
    if (!_hasAny(t, ['막', '차단', '블락', '블록', 'block', '금지'])) return null;

    final range = _parseReservationDateRange(raw, t);
    if (range == null) return null;

    final matched = _matchAppBlockCategories(t);
    final targetIds = matched.targetIds;
    final labels = matched.labels;
    if (labels.isEmpty && matched.unmapped.isEmpty && !matched.blockSafari) {
      return null;
    }
    final allLabels = [...labels, ...matched.unmapped].join(', ');

    final df = '${range.start.month}/${range.start.day}';
    final dfEnd = '${range.end.month}/${range.end.day}';
    return BlockChatPlan(
      action: 'scheduled_reservation',
      scheduleName: '$allLabels 예약차단 ($df~$dfEnd)',
      extraTargetIds: targetIds,
      blockSafariNote: matched.blockSafari,
      unmappedCategoryLabels: matched.unmapped.isEmpty ? null : matched.unmapped,
      scheduledActivationAtMs: range.start.millisecondsSinceEpoch,
      scheduledDeactivationAtMs: range.end.millisecondsSinceEpoch,
      reservationLocked: true,
      reply: '$df부터 $dfEnd까지 $allLabels을(를) 예약 차단합니다. '
          '이 기간엔 타임락 대기로도 해제할 수 없어요 — 기간이 끝나면 자동으로 풀려요.',
    );
  }

  /// 앱 켠 지 N분 트리거("아침에 모아 앱에 들어가서 킨지 30분 동안은
  /// 유튜브에 못 들어가게 해줘", 2026-07-20 신설) — 고정 시각이 아니라
  /// "앱을 여는 순간"부터 N분을 재는 상대적 트리거라 clock-time 기반
  /// morning_schedule과 다르다. 실제 발동은 [AppOpenBlockTriggerService]가
  /// 매 앱 실행마다 담당하고, 여기선 설정만 저장한다.
  static BlockChatPlan? _parseAppOpenBlockTrigger(String raw, String t) {
    final hasOpenCue = _hasAny(t, [
      '앱에 들어가',
      '앱 들어가',
      '앱켜',
      '앱 켜',
      '앱 실행',
      '앱실행',
      '킨지',
      '킨 지',
      '켠지',
      '켠 지',
      '연지',
      '연 지',
    ]);
    if (!hasOpenCue) return null;
    if (_hasAny(t, ['풀어', '풀기', '해제', '허용', '열어줘'])) return null;
    // "못 들어가게"/"못 보게"처럼 "차단"류 단어 없이 부정형으로만 말하는
    // 게 이 기능의 원문 사용자 요청 그대로였다("...유튜브에 못들어가게
    // 해줘") — '막'/'차단' 같은 리터럴만 요구하면 이 원문 자체가 안 걸림.
    if (!_hasAny(t, [
      '막',
      '차단',
      '블락',
      '블록',
      'block',
      '금지',
      '못 들어가',
      '못들어가',
      '못 보게',
      '못보게',
      '못 하게',
      '못하게',
    ])) {
      return null;
    }

    final minuteMatch = RegExp(r'(\d+)\s*분').firstMatch(t);
    if (minuteMatch == null) return null;
    final minutes = int.tryParse(minuteMatch.group(1)!);
    if (minutes == null || minutes <= 0) return null;

    final matched = _matchAppBlockCategories(t);
    final targetIds = matched.targetIds;
    final labels = matched.labels;
    if (labels.isEmpty && matched.unmapped.isEmpty && !matched.blockSafari) {
      return null;
    }
    final allLabels = [...labels, ...matched.unmapped].join(', ');
    final morningOnly = t.contains('아침');

    return BlockChatPlan(
      action: 'app_open_block_trigger',
      scheduleName: '앱 켠 지 $minutes분 · $allLabels 차단',
      extraTargetIds: targetIds,
      blockSafariNote: matched.blockSafari,
      unmappedCategoryLabels: matched.unmapped.isEmpty ? null : matched.unmapped,
      appOpenTriggerMinutes: minutes,
      appOpenTriggerMorningOnly: morningOnly,
      reply: '${morningOnly ? "아침에 " : ""}모아 앱을 켤 때마다(그날 첫 실행) $minutes분간 '
          '$allLabels을(를) 막을게요. 이미 오늘 발동했으면 내일부터 적용돼요.',
    );
  }

  /// 예약 스케줄의 시작~종료 시각 추출. 지원 형태:
  /// - 상대 시작("내일부터"/"모레부터"/"다음주부터"/"오늘부터") + 기간
  ///   ("N일간"/"N일 동안"/"일주일"/"이틀"/"사흘")
  /// - 절대 날짜 범위("7월 25일부터 7월 30일까지", 연도 생략시 올해/내년 중
  ///   미래가 되는 쪽으로 보정)
  static ({DateTime start, DateTime end})? _parseReservationDateRange(
    String raw,
    String t,
  ) {
    final now = TrustedTimeGuard.effectiveNow();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? start;
    if (t.contains('오늘부터')) {
      start = today;
    } else if (t.contains('내일부터')) {
      start = today.add(const Duration(days: 1));
    } else if (t.contains('모레부터')) {
      start = today.add(const Duration(days: 2));
    } else if (t.contains('다음주부터') || t.contains('다음 주부터')) {
      start = today.add(const Duration(days: 7));
    } else if (t.contains('다음달부터') || t.contains('다음 달부터')) {
      start = DateTime(now.year, now.month + 1, now.day);
    }

    // 절대 날짜 범위 "7월 25일부터 7월 30일까지" (연도 생략 가정)
    final absRange = RegExp(r'(\d{1,2})\s*월\s*(\d{1,2})\s*일\s*부터.*?(\d{1,2})\s*월\s*(\d{1,2})\s*일\s*까지')
        .firstMatch(raw);
    if (absRange != null) {
      final sm = int.tryParse(absRange.group(1)!);
      final sd = int.tryParse(absRange.group(2)!);
      final em = int.tryParse(absRange.group(3)!);
      final ed = int.tryParse(absRange.group(4)!);
      if (sm != null && sd != null && em != null && ed != null) {
        var s = DateTime(now.year, sm, sd);
        if (s.isBefore(today)) s = DateTime(now.year + 1, sm, sd);
        var e = DateTime(s.year, em, ed);
        if (!e.isAfter(s)) e = DateTime(s.year + 1, em, ed);
        return (start: s, end: e.add(const Duration(days: 1)));
      }
    }

    if (start == null) return null;

    // 기간(일수) — "N일간"/"N일 동안"/흔한 한글 일수 낱말.
    int? days;
    final numDays = RegExp(r'(\d+)\s*일\s*(?:간|동안)').firstMatch(t);
    if (numDays != null) days = int.tryParse(numDays.group(1)!);
    days ??= t.contains('일주일') ? 7 : null;
    days ??= t.contains('이틀') ? 2 : null;
    days ??= t.contains('사흘') ? 3 : null;
    days ??= t.contains('나흘') ? 4 : null;
    if (days == null) return null;

    final end = start.add(Duration(days: days));
    return (start: start, end: end);
  }

  static BlockChatPlan? _parseMultiCategoryNightBlock(String raw, String t) {
    if (_hasAny(t, ['풀어', '풀기', '해제', '허용', '열어'])) return null;
    if (!_hasAny(t, ['막', '차단', '블락', '블록', 'block', '금지'])) return null;

    final startTime = _parseNightStartTime(raw, t);
    final endTime = _parseNightEndTime(raw, t);
    if (startTime == null || endTime == null) return null;

    final matched = _matchAppBlockCategories(t);
    final targetIds = matched.targetIds;
    final labels = matched.labels;
    final unmapped = matched.unmapped;
    final blockSafari = matched.blockSafari;

    final categoryCount = labels.length + unmapped.length;
    if (categoryCount < 2) return null;

    final allLabels = [...labels, ...unmapped].join(', ');
    final unmappedNote = unmapped.isEmpty
        ? ''
        : ' ${unmapped.join(', ')}은(는) 특정 앱 하나로 정하기 어려워서 자동으로는 '
            '못 골라요 — 저장 후 뜨는 Screen Time 앱 선택창에서 직접 추가해 주세요.';

    return BlockChatPlan(
      action: 'night_schedule',
      scheduleName: '$allLabels 차단 (AI)',
      startHour: startTime.$1,
      startMinute: startTime.$2,
      endHour: endTime.$1,
      endMinute: endTime.$2,
      extraTargetIds: targetIds,
      blockSafariNote: blockSafari,
      unmappedCategoryLabels: unmapped.isEmpty ? null : unmapped,
      reply:
          '매일 ${_fmt(startTime.$1, startTime.$2)}~${_fmt(endTime.$1, endTime.$2)}에 '
          '$allLabels 차단 스케줄을 만듭니다.$unmappedNote',
    );
  }

  static BlockChatPlan? _parseNightSchedule(String raw, String t) {
    // 야간 차단은 "막기" 전용 — "풀어/허용"은 허용 창(allow_window)이 처리.
    // "안 보게/못 보게"는 차단 의도이므로 통과 허용.
    final relaxOnly = (t.contains('보게') && !t.contains('안 보게') && !t.contains('못 보게')) ||
        _hasAny(t, ['풀', '해제', '허용', '볼 수', '볼수', '열어']);
    if (relaxOnly) return null;
    // "늘려줘/연장해줘/줄여줘"는 새 스케줄을 만들라는 게 아니라 이미 있는
    // 스케줄을 수정하라는 의도다 — update_schedule_time·나눠쓰기 연장 전용
    // 파서가 처리해야 하는데, 여기서 먼저 걸리면 완전히 새로운 야간 차단
    // 스케줄을 만들어버린다(2026-07-13 확인: "유튜브 뮤직 블락 23:00부터
    // 11:00까지 늘려줘"가 콜론 단독 종료 시각 지원을 추가한 뒤 여기로 잘못
    // 새서 night_schedule을 새로 만들었음).
    if (_hasAny(t, ['늘려', '늘리', '연장', '줄여', '줄이', '확장', '단축'])) {
      return null;
    }
    // 0시~N시 아침 차단(morning_schedule)과 구분 — 단, "23:00 - 10:00까지"처럼
    // 콜론·하이픈 범위로 명시적 시작 시각을 준 경우는 "부터" 단어가 없어도
    // 이미 시작 시각이 자정이 아님을 알 수 있으므로 morning_schedule로 잘못
    // 넘기면 안 된다(2026-07-11 cage 제보 — 23시 시작이 통째로 무시되고
    // "매일 0시~10시"로 오인식됨).
    final hasExplicitTimeRange = RegExp(r'\d{1,2}:\d{2}\s*[-~]\s*\d{1,2}:\d{2}')
            .hasMatch(raw) ||
        RegExp(r'\d{4}\s*[-~]\s*\d{4}').hasMatch(raw);
    if (_hasAny(t, ['매일', '아침']) &&
        _hasAny(t, ['까지', 'isle', '이슬', '앱', '인앱']) &&
        !_hasAny(t, ['밤', '부터', '야간', '저녁', 'night', 'sns 야간']) &&
        !hasExplicitTimeRange) {
      return null;
    }

    final nightCue = _hasAny(t, [
      '야간',
      '밤',
      '저녁',
      'night',
      '잠들',
      '취침',
      'sns 야간',
    ]);
    final blockCue = _hasAny(t, [
      '막',
      '차단',
      '블락',
      '블록',
      'block',
      '금지',
      '안 되',
      '안되',
      '못 쓰',
      '못쓰',
      '못 보',
      '못보',
      '보지 못',
      '못하게',
      '이후로',
    ]);
    // "2300부터 0800까지"처럼 "시" 없이 순수 HHMM·콜론으로만 시간을 쓰면
    // 아래 두 조건 다 걸리지 않아 overnight 자체가 인식 안 됐다 — 밤/야간
    // 같은 한국어 단어가 없어도 숫자 자체가 이미 하루를 넘는 범위(23xx→0~11xx
    // 등)를 뜻하는 경우가 많다(실사용 버그 2026-07-10, "인터넷 브라우저는
    // 2300부터 0800까지 차단해줘"가 파싱조차 안 됨). _parseNightStartTime/
    // _parseNightEndTime는 이미 이 형식들을 지원하므로, 그 결과가 잡히면
    // overnight로 인정한다.
    final parsedStart = _parseNightStartTime(raw, t);
    final parsedEnd = _parseNightEndTime(raw, t);
    final overnight = RegExp(r'(\d{1,2})\s*시').allMatches(t).length >= 2 ||
        (_hasAny(t, ['부터', '까지']) &&
            _hasAny(t, ['밤', '야간', '저녁', 'night', '새벽', '취침'])) ||
        (_hasAny(t, ['부터', '까지']) && (parsedStart != null || parsedEnd != null));

    if (!blockCue) return null;
    if (!nightCue && !overnight) return null;
    if (_hasAny(t, ['isle', '이슬', '이젤', '인앱', '앱 유튜브']) &&
        _hasAny(t, ['유튜브', 'youtube'])) {
      return null;
    }
    // "유튜브 뮤직 ... 10분에 3분만" 같은 세션/충전 정보가 있으면 Screen Time
    // 기반 music_foreground_limit 전용 경로로 넘긴다 — 여기서 가로채면 그
    // 세션 정보가 통째로 사라지고 일반 유튜브(메인 앱) 완전 차단으로 잘못
    // 저장된다(2026-07-11 cage 제보). 하지만 세션 정보 없이 그냥 "유튜브 뮤직
    // 차단해줘"류 순수 전체 차단까지 무조건 넘기면, music_foreground_limit이
    // 세션 정보 없는 요청은 안 받아줘서 결국 아무도 못 잡고 _parseIsleYoutubeSchedule
    // (아침 전용, night_schedule의 밤 시작 시각을 무시함)로 새어버린다
    // (2026-07-11 moa 실사용 제보) — 세션 신호가 있을 때만 넘긴다.
    final isMusic = _hasAny(t, ['뮤직', 'music', 'ytm']);
    final hasSessionCue = _hasAny(t, [
      '씩',
      '마다',
      '충전',
      '리필',
      '나눠',
      '나누',
      '쪼개',
      '포그라운드',
      'foreground',
      '백그라운드',
      'background',
      '온스크린',
      'onscreen',
      'on screen',
    ]);
    if (isMusic && hasSessionCue) return null;

    var startH = parsedStart?.$1 ?? 21;
    var startM = parsedStart?.$2 ?? 0;
    var endH = parsedEnd?.$1 ?? 7;
    var endM = parsedEnd?.$2 ?? 0;

    if (parsedStart == null && _hasAny(t, ['야간 sns', 'sns 야간'])) {
      startH = 21;
      endH = 7;
    }

    // 밤/저녁/오후 표현 → 24시간제 (예: "밤 11시"→23, "밤 12시"→0 자정)
    if (_hasAny(t, ['밤', '저녁', '야간', '취침', '오후']) &&
        startH >= 1 &&
        startH <= 11) {
      startH += 12;
    }
    if (startH == 12 && _hasAny(t, ['밤', '자정', '취침'])) startH = 0;
    startH = startH.clamp(0, 23);
    endH = endH.clamp(0, 23);

    // "인스타랑 유튜브 둘 다 밤에 막아줘"처럼 타깃이 2개 이상이면, 하나만 골라
    // 조용히 처리하지 말고 "둘 다 같은 조건으로 적용할까요?"를 먼저 물어본다
    // (2026-07-11 cage 요청). 기존 스케줄이 있으면 어떻게 바뀌는지도 미리 설명.
    // 카카오톡·틱톡은 모아 인앱 화면이 없어 "완전 차단" 대상이 될 수 없다
    // (2026-07-12 확정) — 여기서 걸러야 이 확인 질문에 끼어 "완전 차단"
    // 대상으로 잘못 제안되지 않는다.
    final allTargets = _parseAllUsageBudgetTargets(t)
        .where((tg) => !(tg.$1 == 'app' && (tg.$2 == 'kakao' || tg.$2 == 'tiktok')))
        .toList();
    if (allTargets.length >= 2) {
      final multi =
          _buildMultiTargetNightConfirm(allTargets, startH, startM, endH, endM);
      if (multi != null) return multi;
    }

    // 어떤 앱을 말하는지 특정할 수 있으면 appId/limitPlatform에 남겨서
    // executor가 Instagram으로 기본 처리하지 않고 그 앱을 대상으로 삼게 한다.
    final target = _parseUsageBudgetTarget(t);
    // 모아는 인앱(isle_*) 전용 제품 스코프(2026-07-11 확정) — 카카오톡·틱톡은
    // 모아 안에 대응하는 인앱 화면이 없어 "완전 차단(야간 스케줄)" 대상이 될
    // 수 없다. 예전엔 여기서 걸러지지 않고 executor의 _nightScheduleLimitTarget
    // 이 null을 반환한 뒤 그게 조용히 Instagram 기본값으로 새서, "카카오톡
    // 차단해줘"가 실제로는 Instagram을 막아버리는 오작동이 생겼다
    // (2026-07-12 발견). 파서 단계에서 명확히 "지원 안 함"으로 answer한다.
    if (target != null &&
        target.$1 == 'app' &&
        (target.$2 == 'kakao' || target.$2 == 'tiktok')) {
      return BlockChatPlan(
        action: 'explain',
        reply: '모아는 앱 안의 유튜브·인스타그램·브런치·인앱 브라우저만 직접 차단할 수 있어요. '
            '${target.$3}처럼 모아 밖의 앱은 아이폰 자체 스크린 타임 기능으로 제한해 주세요.',
      );
    }
    final appId = target?.$1 == 'app' ? target?.$2 : null;
    final limitPlatform = target != null && target.$1 != 'app' ? target.$1 : null;
    final targetLabel = target?.$3 ?? 'SNS';
    final label = '야간 $targetLabel 차단 (AI)';

    return BlockChatPlan(
      action: 'night_schedule',
      scheduleName: label,
      startHour: startH,
      startMinute: startM.clamp(0, 59),
      endHour: endH,
      endMinute: endM.clamp(0, 59),
      blockSafariNote: false,
      appId: appId,
      limitPlatform: limitPlatform,
      reply: '매일 ${_fmt(startH, startM)}~${_fmt(endH, endM)} 야간 스케줄 — '
          '$targetLabel 앱을 막을게요.',
    );
  }

  /// `_parseUsageBudgetTarget`은 첫 매칭 하나만 반환해서 "인스타랑 유튜브"처럼
  /// 여러 타깃이 한 문장에 있으면 하나가 조용히 버려진다 — 여기선 전부 모은다.
  static List<(String, String?, String)> _parseAllUsageBudgetTargets(String t) {
    final found = <(String, String?, String)>[];
    for (final entry in _appAliasCatalog) {
      if (_hasAny(t, entry.$4) && !found.any((f) => f.$3 == entry.$3)) {
        found.add((entry.$1, entry.$2, entry.$3));
      }
    }
    return found;
  }

  /// 타깃 2개 이상 야간 차단 요청 — 같은 조건으로 subPlans를 만들어 두고,
  /// "둘 다 적용"/"아니요"로 답할 때까지는 아무것도 저장하지 않는다.
  static BlockChatPlan? _buildMultiTargetNightConfirm(
    List<(String, String?, String)> targets,
    int startH,
    int startM,
    int endH,
    int endM,
  ) {
    final canCheckExisting = BlockScheduleStore.isOpen;
    final existingAll =
        canCheckExisting ? BlockScheduleStore.loadAll() : const <BlockSchedule>[];

    final subPlans = <BlockChatPlan>[];
    final lines = <String>[];
    for (final target in targets) {
      final appId = target.$1 == 'app' ? target.$2 : null;
      final limitPlatform = target.$1 != 'app' ? target.$1 : null;
      final targetLabel = target.$3;
      final label = '야간 $targetLabel 차단 (AI)';
      subPlans.add(
        BlockChatPlan(
          action: 'night_schedule',
          scheduleName: label,
          startHour: startH,
          startMinute: startM.clamp(0, 59),
          endHour: endH,
          endMinute: endM.clamp(0, 59),
          blockSafariNote: false,
          appId: appId,
          limitPlatform: limitPlatform,
          reply: '매일 ${_fmt(startH, startM)}~${_fmt(endH, endM)} 야간 스케줄 — '
              'iPhone $targetLabel 앱 차단 (Screen Time 선택 필요)',
        ),
      );

      final tag = appId ?? limitPlatform ?? '';
      final existing = existingAll
          .where((s) => s.enabled && BlockChatRationTag.matches(s, tag))
          .toList();
      if (existing.isNotEmpty) {
        lines.add(
          '「$targetLabel」: 기존 「${existing.first.name}」 스케줄이 매일 '
          '${_fmt(startH, startM)}~${_fmt(endH, endM)} 완전 차단 방식으로 바뀌어요.',
        );
      } else {
        lines.add(
          '「$targetLabel」: 새 스케줄로 매일 ${_fmt(startH, startM)}~${_fmt(endH, endM)} '
          '완전 차단을 만들어요.',
        );
      }
    }

    final names = targets.map((t) => t.$3).join('·');
    return BlockChatPlan(
      action: 'explain',
      pendingConfirmAction: 'reset_reapply',
      subPlans: subPlans,
      reply: '$names 둘 다 같은 조건으로 적용할까요?\n\n${lines.join('\n')}',
      quickReplies: const [
        BlockChatQuickReplyOption(label: '둘 다 적용', value: '둘 다 적용'),
        BlockChatQuickReplyOption(label: '아니요, 괜찮습니다', value: '아니요, 괜찮습니다'),
      ],
    );
  }

  static BlockChatPlan? _parseNightScheduleCorrection(
    String raw,
    String t,
    BlockChatPlan previous,
  ) {
    if (!_hasTimeToken(t)) return null;
    if (_hasAny(t, ['해제', '풀', '삭제', '끄', '취소'])) return null;

    var startH = previous.startHour ?? 21;
    var startM = previous.startMinute ?? 0;
    var endH = previous.endHour;
    var endM = previous.endMinute;
    var changed = false;

    final fromTo = RegExp(
      r'(?:밤|저녁|야간|오후)?\s*(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?\s*(?:부터|~|에서|-).*?(?:다음날|익일|아침|새벽)?\s*(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?',
      caseSensitive: false,
    ).firstMatch(raw);
    if (fromTo != null) {
      startH = _normalizeNightStartHour(
        int.tryParse(fromTo.group(1)!) ?? startH,
        t,
        previousStartHour: previous.startHour,
      );
      startM = int.tryParse(fromTo.group(2) ?? '') ?? 0;
      endH = (int.tryParse(fromTo.group(3)!) ?? endH).clamp(0, 23);
      endM = (int.tryParse(fromTo.group(4) ?? '') ?? 0).clamp(0, 59);
      changed = true;
    } else {
      final single = RegExp(
        r'(?:밤|저녁|야간|오후|아침|새벽)?\s*(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?',
        caseSensitive: false,
      ).firstMatch(raw);
      if (single == null) return null;
      final hour = int.tryParse(single.group(1)!) ?? -1;
      if (hour < 0) return null;
      final minute = (int.tryParse(single.group(2) ?? '') ?? 0).clamp(0, 59);
      final isEndCorrection = _hasAny(t, ['까지', '아침', '새벽', '끝', '종료']);
      if (isEndCorrection) {
        endH = hour.clamp(0, 23);
        endM = minute;
      } else {
        startH = _normalizeNightStartHour(
          hour,
          t,
          previousStartHour: previous.startHour,
        );
        startM = minute;
      }
      changed = true;
    }

    if (!changed) return null;
    startH = startH.clamp(0, 23);
    startM = startM.clamp(0, 59);
    endH = endH.clamp(0, 23);
    endM = endM.clamp(0, 59);
    return previous.copyWith(
      startHour: startH,
      startMinute: startM,
      endHour: endH,
      endMinute: endM,
      reply: '좋아요. 직전 야간 차단 카드를 '
          '${_fmt(startH, startM)}~${_fmt(endH, endM)}로 고쳐서 보여드릴게요.',
    );
  }

  static bool _hasTimeToken(String t) {
    return RegExp(r'\d{1,2}\s*(?:시|:)', caseSensitive: false).hasMatch(t);
  }

  static int _normalizeNightStartHour(
    int hour,
    String t, {
    int? previousStartHour,
  }) {
    var h = hour;
    final shouldTreatAsNight = _hasAny(t, ['밤', '저녁', '야간', '오후']) ||
        ((previousStartHour ?? 0) >= 12 && h >= 1 && h <= 11);
    if (shouldTreatAsNight && h >= 1 && h <= 11) h += 12;
    if (h == 12 && _hasAny(t, ['밤', '자정', '취침'])) h = 0;
    return h.clamp(0, 23);
  }

  static BlockChatPlan? _parseBlockWebsite(String raw, String t) {
    if (!_hasAny(t, ['막', '차단', '블락', '블록', 'block', '금지'])) return null;
    if (_hasAny(t, ['풀', '해제', '삭제', 'remove', 'unblock', '없애', '제거'])) {
      return null;
    }
    // 유튜브 채널 지정(채널 URL/「채널」)은 block_channel이 처리 → 도메인 전체 차단 방지
    if (_hasAny(t, ['채널', 'channel']) ||
        RegExp(r'youtube\.com/(@|channel/|c/|user/)', caseSensitive: false)
            .hasMatch(raw)) {
      return null;
    }

    final domain = _extractDomainForBlock(raw, t);
    if (domain == null) return null;

    final label = WebsiteBlockStore.catalog
        .where((c) => c.domain == domain)
        .map((c) => c.label)
        .firstOrNull;

    // "mingky05.live"처럼 번호로 우회하는 미러 사이트는 이 번호 하나만 막아도
    // mingky06.live·mingky07.live... 로 계속 새로 나온다 — UrlRuleDetector가
    // 이미 이 "숫자 우회 패턴"(어간+숫자)을 감지하는 로직을 갖고 있었지만
    // 예전엔 설정 화면의 스케줄별 URL 규칙에서만 쓰였고 채팅에선 전혀
    // 활용되지 않았다(2026-07-10, "mingky05.live 성인 사이트 왜 안 막히지"
    // 제보 후속). 여기서도 같은 감지 로직을 재사용해, 항상-켜짐 정규식
    // 패턴으로 어간까지 같이 등록한다 — mingky01.live 같은 아직 안 나온
    // 번호 변형도 한 번에 막힌다.
    final detected = UrlRuleDetector.detect(domain);
    final stem = detected.secondaryHost != null ? detected.pattern : null;

    final reply = StringBuffer();
    reply.write(label != null
        ? 'Safari에서 $label($domain) 차단 목록에 추가합니다.'
        : 'Safari Content Blocker에 「$domain」을 추가합니다.');
    if (stem != null) {
      reply.write(' 🔢 번호를 바꿔가며 우회하는 미러 사이트로 보여서, '
          '「$stem」로 시작하고 숫자가 붙는 주소는 앞으로 나올 것까지 '
          '전부 자동으로 막을게요.');
    }

    return BlockChatPlan(
      action: 'block_website',
      websiteDomain: domain,
      websiteDomainStem: stem,
      reply: reply.toString(),
    );
  }

  static BlockChatPlan? _parseBlockUrl(String raw, String t) {
    if (!_hasAny(t, ['막', '차단', '블락', '블록', 'block', '숨김', '금지'])) return null;
    if (_hasAny(t, ['제거', '해제', '풀', '삭제', 'remove', 'unblock', '없애'])) {
      return null;
    }
    // 「채널」 지정은 block_channel이 처리 (URL 전체 차단으로 새지 않게)
    if (_hasAny(t, ['채널', 'channel'])) return null;

    final url = _extractUrl(raw);
    if (url == null || url.length < 8) return null;

    final short = url.length > 40 ? '${url.substring(0, 37)}…' : url;
    return BlockChatPlan(
      action: 'block_url',
      removeUrl: url,
      reply: 'URL 「$short」를 차단 목록에 추가합니다.',
    );
  }

  static BlockChatPlan? _parseBlockChannel(String raw, String t) {
    if (!_hasAny(t, ['채널', 'channel'])) return null;
    if (!_hasAny(t, ['막', '차단', '블락', '블록', '숨김', 'block', '그만'])) return null;

    final quoted = _extractQuoted(raw);
    var name = quoted;
    // 유튜브 채널 URL에서 핸들/ID 추출 (예: youtube.com/@handle → @handle)
    name ??= RegExp(
      r'youtube\.com/(@[\w.\-]+|channel/[\w\-]+|c/[\w.\-]+|user/[\w.\-]+)',
      caseSensitive: false,
    ).firstMatch(raw)?.group(1);
    if (name == null) {
      final m = RegExp(
        r'(.+?)\s*채널.*?(막|차단|블락|숨김|숨겨|숨기|block|그만)',
        caseSensitive: false,
      ).firstMatch(raw);
      name = m?.group(1)?.trim();
    }
    if (name == null || name.length < 2) return null;
    name = name.replaceAll(RegExp(r'^(유튜브|youtube)\s*'), '').trim();
    if (name.length < 2) return null;

    return BlockChatPlan(
      action: 'block_channel',
      channelName: name,
      reply: '유튜브 채널 「$name」을 숨깁니다.',
    );
  }

  static BlockChatPlan? _parsePlatformLimit(String t) {
    if (_looksLikeSchedule(t)) return null;
    if (_hasAny(t, ['쓰고', '쉬', '세션', '쿨다운', 'session'])) return null;

    String? platform;
    if (_hasAny(t, ['인스타', 'instagram'])) {
      platform = 'instagram';
    } else if (_hasAny(t, ['브런치', 'brunch'])) {
      platform = 'brunch';
    }
    if (platform == null) return null;
    if (!_hasAny(t, ['한도', '제한', 'limit', '하루', '일일', '분'])) return null;

    final mins = _parseAllMinutes(t);
    if (mins.isEmpty) return null;
    final daily = mins.last;

    final label = platform == 'instagram' ? 'Instagram' : 'Brunch';
    return BlockChatPlan(
      action: 'platform_limit',
      limitPlatform: platform,
      dailyMinutes: daily,
      reply: 'Isle $label 일일 한도를 ${daily}분으로 설정합니다.',
    );
  }

  static String? _extractDomainForBlock(String raw, String t) {
    final url = _extractUrl(raw);
    if (url != null) {
      return WebsiteBlockStore.normalizeDomain(url);
    }

    // 하드코딩된 TLD 목록(com/net/org/io/kr)만 인식하던 예전 정규식은 .live,
    // .xyz, .cc, .to 같은 흔한(특히 우회용 미러 사이트가 자주 쓰는) TLD를
    // 놓쳐서 "mingky05.live 차단해줘"가 도메인으로 아예 인식 안 되고 엉뚱하게
    // add_keyword로 새던 실사용 버그(2026-07-10, Cage에서 먼저 발견·이식) —
    // 임의의 2자 이상 알파벳 TLD를 받아들이게 넓힌다.
    final domainRe = RegExp(
      r'([a-z0-9][-a-z0-9]*(?:\.[a-z0-9][-a-z0-9]*)*\.[a-z]{2,24})',
      caseSensitive: false,
    );
    final m = domainRe.firstMatch(t);
    if (m != null) {
      var d = m.group(1)!.toLowerCase();
      if (d == 'twitter.com') d = 'x.com';
      return d;
    }

    for (final def in WebsiteBlockStore.catalog) {
      final key = def.domain.split('.').first;
      if (t.contains(key) || t.contains(def.label.toLowerCase())) {
        return def.domain;
      }
    }
    return null;
  }
}
