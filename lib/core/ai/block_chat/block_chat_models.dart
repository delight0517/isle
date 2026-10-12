/// AI 차단 챗 — 의도·적용 결과
import 'package:flutter/material.dart';

class BlockChatMessage {
  const BlockChatMessage({
    required this.role,
    required this.text,
    this.result,
    this.isLoading = false,
    this.plan,
    this.usedAi,
    this.createdAt,
    this.awaitingConfirm = false,
  });

  final BlockChatRole role;
  final String text;
  final BlockChatResult? result;
  final bool isLoading;

  /// 개발자용보내기 — 파싱된 action
  final BlockChatPlan? plan;
  final bool? usedAi;
  final DateTime? createdAt;

  /// 미리보기 상태 — 사용자가 「확인」을 누르기 전. [plan]을 들고 있다가 확인 시 적용.
  final bool awaitingConfirm;

  BlockChatMessage copyWith({
    String? text,
    BlockChatResult? result,
    bool? isLoading,
    BlockChatPlan? plan,
    bool? usedAi,
    DateTime? createdAt,
    bool? awaitingConfirm,
  }) =>
      BlockChatMessage(
        role: role,
        text: text ?? this.text,
        result: result ?? this.result,
        isLoading: isLoading ?? this.isLoading,
        plan: plan ?? this.plan,
        usedAi: usedAi ?? this.usedAi,
        createdAt: createdAt ?? this.createdAt,
        awaitingConfirm: awaitingConfirm ?? this.awaitingConfirm,
      );
}

enum BlockChatRole { user, assistant }

/// 정보성(explain) 답변 아래 붙는 버튼 — 탭하면 [value]를 그대로 다시 보낸 것처럼
/// 처리한다. `__info__:` 접두어가 붙은 값은 재파싱하지 않고 안내 문구만 보여준다
/// (예: "조금 더 세부적으로…" 버튼).
class BlockChatQuickReplyOption {
  const BlockChatQuickReplyOption({required this.label, required this.value});
  final String label;
  final String value;
}

class BlockChatPlan {
  const BlockChatPlan({
    required this.action,
    this.reply = '',
    this.keyword,
    this.scheduleName,
    this.endHour = 9,
    this.endMinute = 0,
    this.days = const [0, 1, 2, 3, 4, 5, 6],
    this.blockSafariNote = false,
    this.blockIsleYoutube = false,
    this.appId,
    this.dailyMinutes,
    this.sessionMinutes,
    this.cooldownMinutes,
    this.removeScheduleQuery,
    this.scheduleQuery,
    this.scheduleNewName,
    this.removeKeyword,
    this.removeUrl,
    this.relaxTarget,
    this.toggleOn,
    this.limitPlatform,
    this.suggestTimelock = false,
    this.windowMinutes,
    this.channelName,
    this.websiteDomain,
    this.pauseMinutes,
    this.startHour,
    this.startMinute,
    this.personaId,
    this.presetId,
    this.topicLabel,
    this.languageCode = 'ko',
    this.subPlans,
    this.extendsExistingBudget = false,
    this.budgetWindowEndMinuteOfDay,
    this.websiteDomainStem,
    this.pendingConfirmAction,
    this.overwriteCandidates,
    this.quickReplies,
    this.extraSlotMinutes,
    this.disableFuzzyDedup = false,
    this.extraTargetIds,
    this.unmappedCategoryLabels,
    this.scheduledActivationAtMs,
    this.scheduledDeactivationAtMs,
    this.reservationLocked = false,
    this.appOpenTriggerMinutes,
    this.appOpenTriggerMorningOnly = false,
  });

  final String action;
  final String reply;
  final String? keyword;
  final String? scheduleName;
  final int endHour;
  final int endMinute;
  final List<int> days;
  final bool blockSafariNote;
  final bool blockIsleYoutube;
  final String? appId;
  final int? dailyMinutes;
  final int? sessionMinutes;
  final int? cooldownMinutes;
  final String? removeScheduleQuery;

  /// rename·시간·요일 변경·해제 공통 — 정확한 이름 없어도 키워드로 매칭
  final String? scheduleQuery;

  /// rename_schedule
  final String? scheduleNewName;
  final String? removeKeyword;

  /// remove_url — 차단 URL 해제
  final String? removeUrl;

  /// relax_block — youtube|safari|instagram|all
  final String? relaxTarget;

  /// toggle_shorts / toggle_reels — true=숨김 ON
  final bool? toggleOn;

  /// youtube_limit — 플랫폼 (기본 youtube)
  final String? limitPlatform;

  /// morning_habit_pack — 타임락 안내 카드 노출
  final bool suggestTimelock;

  /// music_foreground_limit — 주기 창 분 (기본 60)
  final int? windowMinutes;

  /// block_channel — 채널명 (ID 없으면 이름으로 매칭)
  final String? channelName;

  /// block_website — 도메인 (twitter.com 등)
  final String? websiteDomain;

  /// block_website — 숫자 우회 미러 사이트 감지 시("mingky05.live" → "mingky")
  /// 어간. 있으면 항상-켜짐 정규식 패턴으로도 같이 등록해 아직 안 나온 번호
  /// 변형(mingky01.live 등)까지 막는다.
  final String? websiteDomainStem;

  /// safari_pause — 임시 해제 분 (5/10/15)
  final int? pauseMinutes;

  /// night_schedule — 야간 시작 시·분 (기본 21:00)
  final int? startHour;
  final int? startMinute;

  /// persona_bundle — [BlockChatPersonaScenarios] id
  final String? personaId;

  /// apply_premade_pack — [PremadeBlockPackService] 팩 id (예: adultCombinedPackId)
  final String? presetId;

  /// block_genre — [ChannelGenreAiService] 장르/주제 라벨 (예: "게임")
  final String? topicLabel;
  final String languageCode;

  /// reset_reapply — 순차 실행할 하위 계획 목록(persona_bundle의 subPlans 패턴 재사용).
  final List<BlockChatPlan>? subPlans;

  /// youtube_budget / usage_budget — "이미 켜져있는 나눠쓰기를 늘려/연장/줄여줘" 류.
  /// true면 executor가 UsageBudgetStore의 실제 활성 정책값을 베이스로 쓰고,
  /// 이 메시지에서 언급 안 된 필드(daily/session/window/cooldown)는 하드코딩 기본값
  /// 대신 기존 값을 그대로 이어간다.
  final bool extendsExistingBudget;

  /// extendsExistingBudget용 — 이번 메시지에서 실제로 "OO시까지"가 언급됐을 때만
  /// 채워짐(하루 중 분 단위, 0–1439). endHour/endMinute는 기본값 9:0이 있어
  /// "언급 안 함"과 구분이 안 되므로 별도 nullable 필드로 명시적으로 표시한다.
  final int? budgetWindowEndMinuteOfDay;

  /// 여러 개의 기존 스케줄과 겹칠 수 있는 나눠쓰기/한도 요청 — "전부 덮어쓸까요,
  /// 하나만 고를까요?" 질문(action='explain')을 던질 때, 사용자가 답하면
  /// 이 값으로 실제 실행할 action을 복원한다(예: 'music_foreground_limit').
  final String? pendingConfirmAction;

  /// 위 질문에서 후보로 제시한 기존 스케줄 이름 목록. 사용자가 그중 하나를
  /// 이름으로 답하면 [BlockChatPlan.scheduleQuery]로 매칭해 그 스케줄만 정리한다.
  final List<String>? overwriteCandidates;

  /// 정보성(explain) 질문에 딸린 버튼들 — 예: "하루 30분" / "1시간에 30분씩" /
  /// "둘 다 적용" / "아니요, 괜찮습니다".
  final List<BlockChatQuickReplyOption>? quickReplies;

  /// night_schedule 전용 — 기본 startHour/Minute~endHour/Minute 구간 외에
  /// 추가로 같은 방식(같은 세션·창)으로 걸 시간대. 하루 종일 시간대 도중에
  /// 다른 구간(예: 완전 차단)이 끼어 있어 나눠쓰기 구간이 2개로 쪼개질 때
  /// (예: "22:30-23:00 나눠쓰기, 23:00-13:00 완전차단, 13:00-14:00 나눠쓰기")
  /// 사용한다. [start1, end1, start2, end2, ...] 형태로 분 단위(0-1439) 평탄화.
  final List<int>? extraSlotMinutes;

  /// night_schedule 전용 — 컴파운드(나눠쓰기+완전차단) 조합처럼 "같은 앱을
  /// 대상으로 하는 이름 다른 스케줄 여러 개"를 한 번에 만들 때, 이름이 흐릿한
  /// 기존 dedup(`findNightSns`, 같은 앱 타깃이면 재사용)이 방금 막 만든 다른
  /// 스케줄을 잘못 재사용해버린다 — true면 정확한 이름 일치(findExactName)만
  /// 사용한다.
  final bool disableFuzzyDedup;

  /// night_schedule — "OO, 브라우저, 유튜브 차단해줘"처럼 여러 카테고리를
  /// 한 문장·한 스케줄에 동시에 걸 때, 단일 appId/limitPlatform 필드로는
  /// 표현 못 하는 **추가** 앱 타깃 카탈로그 ID 목록(cage 2026-07-11 이식).
  final List<String>? extraTargetIds;

  /// 위와 같은 다중 카테고리 요청 중, 카탈로그에 없어 자동 차단이 안 되고
  /// Screen Time 앱 선택창에서 사용자가 직접 골라야 하는 카테고리 이름
  /// (예: "AI 코딩 툴") — 있으면 응답 문구에 안내를 덧붙인다.
  final List<String>? unmappedCategoryLabels;

  /// 예약 스케줄("여행 동안" 류, 2026-07-20) — 이 시각까지는 비활성 상태로
  /// 만들어두고, [ScheduleReservationService]가 자동으로 켠다.
  final int? scheduledActivationAtMs;

  /// 예약 스케줄 종료 시각 — 지나면 자동으로 꺼진다.
  final int? scheduledDeactivationAtMs;

  /// true면 예약 기간 동안 일반 커밋먼트 락의 대기-후-해제 경로가 전혀
  /// 안 통한다(사용자가 "1-2시간 이상 예약은 타임락으로도 못 풀리게" 요청,
  /// 2026-07-20) — [ScheduleEditGuard.isCommitmentLocked] 참고.
  final bool reservationLocked;

  /// 앱 켠 지 N분 트리거("아침에 앱 켠 지 30분은 유튜브 차단", 2026-07-20) —
  /// null이면 이 액션이 아님. [AppOpenBlockTriggerService]가 실제 앱 실행
  /// 시점마다 이 설정으로 예약 스케줄과 동일한 메커니즘을 재사용해 발동한다.
  final int? appOpenTriggerMinutes;

  /// true면 컷오프 시각(기본 11시) 이전 그날 첫 실행에만 발동 — "아침에"
  /// 명시했을 때만 켠다. false면 그날 첫 실행이면 시간대 무관하게 발동.
  final bool appOpenTriggerMorningOnly;

  factory BlockChatPlan.fromJson(Map<String, dynamic> j) {
    final daysRaw = j['days'] as List?;
    return BlockChatPlan(
      action: (j['action'] as String? ?? 'explain').trim(),
      reply: (j['reply'] as String? ?? '').trim(),
      keyword: (j['keyword'] as String?)?.trim(),
      scheduleName: (j['schedule_name'] as String?)?.trim(),
      endHour: (j['end_hour'] as num?)?.toInt() ?? 9,
      endMinute: (j['end_minute'] as num?)?.toInt() ?? 0,
      days: daysRaw != null
          ? daysRaw.map((e) => (e as num).toInt()).toList()
          : const [0, 1, 2, 3, 4, 5, 6],
      blockSafariNote: j['block_safari'] as bool? ?? false,
      blockIsleYoutube: j['block_isle_youtube'] as bool? ?? false,
      appId: (j['app_id'] as String?)?.trim(),
      dailyMinutes: (j['daily_minutes'] as num?)?.toInt(),
      sessionMinutes: (j['session_minutes'] as num?)?.toInt(),
      cooldownMinutes: (j['cooldown_minutes'] as num?)?.toInt(),
      removeScheduleQuery: (j['remove_schedule_query'] as String?)?.trim(),
      scheduleQuery: (j['schedule_query'] as String?)?.trim() ??
          (j['remove_schedule_query'] as String?)?.trim(),
      scheduleNewName: (j['schedule_new_name'] as String?)?.trim() ??
          (j['new_schedule_name'] as String?)?.trim(),
      removeKeyword: (j['remove_keyword'] as String?)?.trim(),
      removeUrl: (j['remove_url'] as String?)?.trim(),
      relaxTarget: (j['relax_target'] as String?)?.trim(),
      toggleOn: j['toggle_on'] as bool?,
      limitPlatform: (j['limit_platform'] as String?)?.trim(),
      suggestTimelock: j['suggest_timelock'] as bool? ?? false,
      windowMinutes: (j['window_minutes'] as num?)?.toInt(),
      channelName: (j['channel_name'] as String?)?.trim(),
      websiteDomain: (j['website_domain'] as String?)?.trim(),
      pauseMinutes: (j['pause_minutes'] as num?)?.toInt(),
      startHour: (j['start_hour'] as num?)?.toInt(),
      startMinute: (j['start_minute'] as num?)?.toInt(),
      personaId: (j['persona_id'] as String?)?.trim(),
      presetId: (j['preset_id'] as String?)?.trim(),
      topicLabel: (j['topic_label'] as String?)?.trim(),
      languageCode: (j['language_code'] as String?)?.trim() ?? 'ko',
    );
  }

  BlockChatPlan copyWith({
    String? action,
    String? reply,
    String? keyword,
    String? scheduleName,
    int? endHour,
    int? endMinute,
    List<int>? days,
    bool? blockSafariNote,
    bool? blockIsleYoutube,
    String? appId,
    int? dailyMinutes,
    int? sessionMinutes,
    int? cooldownMinutes,
    String? removeScheduleQuery,
    String? scheduleQuery,
    String? scheduleNewName,
    String? removeKeyword,
    String? removeUrl,
    String? relaxTarget,
    bool? toggleOn,
    String? limitPlatform,
    bool? suggestTimelock,
    int? windowMinutes,
    String? channelName,
    String? websiteDomain,
    int? pauseMinutes,
    int? startHour,
    int? startMinute,
    String? personaId,
    String? presetId,
    String? topicLabel,
    String? languageCode,
    List<BlockChatPlan>? subPlans,
    bool? extendsExistingBudget,
    int? budgetWindowEndMinuteOfDay,
    String? websiteDomainStem,
    String? pendingConfirmAction,
    List<String>? overwriteCandidates,
    List<BlockChatQuickReplyOption>? quickReplies,
    List<int>? extraSlotMinutes,
    bool? disableFuzzyDedup,
  }) =>
      BlockChatPlan(
        action: action ?? this.action,
        reply: reply ?? this.reply,
        keyword: keyword ?? this.keyword,
        scheduleName: scheduleName ?? this.scheduleName,
        endHour: endHour ?? this.endHour,
        endMinute: endMinute ?? this.endMinute,
        days: days ?? this.days,
        blockSafariNote: blockSafariNote ?? this.blockSafariNote,
        blockIsleYoutube: blockIsleYoutube ?? this.blockIsleYoutube,
        appId: appId ?? this.appId,
        dailyMinutes: dailyMinutes ?? this.dailyMinutes,
        sessionMinutes: sessionMinutes ?? this.sessionMinutes,
        cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
        removeScheduleQuery: removeScheduleQuery ?? this.removeScheduleQuery,
        scheduleQuery: scheduleQuery ?? this.scheduleQuery,
        scheduleNewName: scheduleNewName ?? this.scheduleNewName,
        removeKeyword: removeKeyword ?? this.removeKeyword,
        removeUrl: removeUrl ?? this.removeUrl,
        relaxTarget: relaxTarget ?? this.relaxTarget,
        toggleOn: toggleOn ?? this.toggleOn,
        limitPlatform: limitPlatform ?? this.limitPlatform,
        suggestTimelock: suggestTimelock ?? this.suggestTimelock,
        windowMinutes: windowMinutes ?? this.windowMinutes,
        channelName: channelName ?? this.channelName,
        websiteDomain: websiteDomain ?? this.websiteDomain,
        websiteDomainStem: websiteDomainStem ?? this.websiteDomainStem,
        pauseMinutes: pauseMinutes ?? this.pauseMinutes,
        startHour: startHour ?? this.startHour,
        startMinute: startMinute ?? this.startMinute,
        personaId: personaId ?? this.personaId,
        presetId: presetId ?? this.presetId,
        topicLabel: topicLabel ?? this.topicLabel,
        languageCode: languageCode ?? this.languageCode,
        subPlans: subPlans ?? this.subPlans,
        extendsExistingBudget:
            extendsExistingBudget ?? this.extendsExistingBudget,
        budgetWindowEndMinuteOfDay:
            budgetWindowEndMinuteOfDay ?? this.budgetWindowEndMinuteOfDay,
        pendingConfirmAction:
            pendingConfirmAction ?? this.pendingConfirmAction,
        overwriteCandidates: overwriteCandidates ?? this.overwriteCandidates,
        quickReplies: quickReplies ?? this.quickReplies,
        extraSlotMinutes: extraSlotMinutes ?? this.extraSlotMinutes,
        disableFuzzyDedup: disableFuzzyDedup ?? this.disableFuzzyDedup,
      );
}

class BlockChatAppliedStep {
  const BlockChatAppliedStep({
    required this.title,
    required this.detail,
    this.route,
    this.routeLabel,
    this.needsManualSetup = false,
  });

  final String title;
  final String detail;
  final String? route;
  final String? routeLabel;

  /// Screen Time 등 사용자가 한 번 더 해야 하는 단계
  final bool needsManualSetup;
}

/// AI 적용 후 「어디에 반영됐는지」 시각화용
class BlockChatApplyLocation {
  const BlockChatApplyLocation({
    required this.tabLabel,
    required this.detail,
    required this.icon,
    this.route,
    this.routeLabel,
    this.needsManualSetup = false,
  });

  final String tabLabel;
  final String detail;
  final IconData icon;
  final String? route;
  final String? routeLabel;
  final bool needsManualSetup;
}

class BlockChatApplyTarget {
  const BlockChatApplyTarget({
    required this.label,
    required this.icon,
    this.tint,
    this.needsManualSetup = false,
  });

  final String label;
  final IconData icon;
  final Color? tint;
  final bool needsManualSetup;
}

class BlockChatApplySummary {
  const BlockChatApplySummary({
    required this.headline,
    this.scheduleId,
    this.timeRange,
    this.daysLabel,
    this.endMinute,
    this.locations = const [],
    this.targets = const [],
    this.pendingSteps = const [],
  });

  final String headline;
  final String? scheduleId;
  final String? timeRange;
  final String? daysLabel;

  /// 0–1439 — 24h 타임라인 바
  final int? endMinute;
  final List<BlockChatApplyLocation> locations;
  final List<BlockChatApplyTarget> targets;
  final List<BlockChatAppliedStep> pendingSteps;

  bool get hasScheduleVisual => timeRange != null && endMinute != null;
}

/// 스케줄은 저장됐지만 OS 권한·앱 선택이 빠진 경우
class BlockChatPermissionGap {
  const BlockChatPermissionGap({
    required this.kind,
    required this.title,
    required this.issue,
    required this.effectWhenGranted,
    required this.route,
    required this.routeLabel,
    this.actionLabel,
  });

  final BlockChatPermissionGapKind kind;
  final String title;

  /// 지금 막히는 이유
  final String issue;

  /// 허용·설정 후 사용자가 체감하는 효과
  final String effectWhenGranted;
  final String route;
  final String routeLabel;
  final String? actionLabel;
}

enum BlockChatPermissionGapKind {
  osAuth,
  scheduleAppPick,
  osUnavailable,
  unsupported,
}

/// 적용 후 「이렇게 쓰세요」 활용 팁
class BlockChatCoachTip {
  const BlockChatCoachTip({
    required this.title,
    required this.body,
    this.route,
    this.routeLabel,
  });

  final String title;
  final String body;
  final String? route;
  final String? routeLabel;
}

/// 사용량·맥락 기반 다음 추천 (챗 칩 또는 화면 이동)
class BlockChatCoachRecommendation {
  const BlockChatCoachRecommendation({
    required this.title,
    required this.reason,
    this.chatPrompt,
    this.route,
    this.routeLabel,
  });

  final String title;
  final String reason;
  final String? chatPrompt;
  final String? route;
  final String? routeLabel;
}

/// 솔루션 적용 뒤 이어지는 코칭 카드
class BlockChatCoachGuide {
  const BlockChatCoachGuide({
    this.usageInsight = '',
    this.howToUse = const [],
    this.recommendations = const [],
  });

  final String usageInsight;
  final List<BlockChatCoachTip> howToUse;
  final List<BlockChatCoachRecommendation> recommendations;

  bool get isEmpty =>
      usageInsight.isEmpty && howToUse.isEmpty && recommendations.isEmpty;
}

/// 채팅 응답 아래 표시되는 퀵 리플라이 칩 — CHAT_SPEC SUGGEST.
/// kind: 'faq'(사용자가 눌러서 캔드 답변을 받는 반응형) | 'proactive'(적용 후 능동 제안).
/// answer 는 로컬 고정 텍스트 — API 호출 없이 즉시 표시한다.
class BlockChatSuggestion {
  const BlockChatSuggestion({
    required this.id,
    required this.label,
    required this.kind,
    this.answer,
  });

  final String id;
  final String label;
  final String kind;
  final String? answer;
}

class BlockChatResult {
  const BlockChatResult({
    required this.summary,
    required this.steps,
    this.impact,
    this.usedAi = false,
    this.needsUnlockWait = false,
    this.unlockMinutes,
    this.removalScheduledAuto = false,
    this.permissionGaps = const [],
    this.isFailure = false,
    this.coach,
    this.suggestions = const [],
    this.dailyTimeline,
  });

  final String summary;
  final List<BlockChatAppliedStep> steps;
  final BlockChatApplySummary? impact;
  final bool usedAi;
  final bool needsUnlockWait;
  final int? unlockMinutes;

  /// 제거 타임락·스케줄 잠금 대기 후 자동 적용 예정
  final bool removalScheduledAuto;

  /// OS 권한·앱 선택 등 — 스케줄 저장 후 추가 필요
  final List<BlockChatPermissionGap> permissionGaps;
  final bool isFailure;
  final BlockChatCoachGuide? coach;
  final List<BlockChatSuggestion> suggestions;

  /// "오늘 블락은 뭐가 켜져있어?" 류 전체 조회(explain_status) 결과 —
  /// 앱별 오늘 하루 24시간 타임라인. impact(단일 스케줄 적용 카드)와 별개.
  final List<BlockChatDailyTimelineItem>? dailyTimeline;

  BlockChatResult copyWith({
    BlockChatCoachGuide? coach,
    List<BlockChatSuggestion>? suggestions,
  }) =>
      BlockChatResult(
        summary: summary,
        steps: steps,
        impact: impact,
        usedAi: usedAi,
        needsUnlockWait: needsUnlockWait,
        unlockMinutes: unlockMinutes,
        removalScheduledAuto: removalScheduledAuto,
        permissionGaps: permissionGaps,
        isFailure: isFailure,
        coach: coach ?? this.coach,
        suggestions: suggestions ?? this.suggestions,
        dailyTimeline: dailyTimeline,
      );

  factory BlockChatResult.fail(String msg) => BlockChatResult(
        summary: msg,
        steps: const [],
        isFailure: true,
      );
}

enum BlockTimelineSegmentKind {
  /// 완전 차단 — 빨간색
  fullBlock,

  /// 시간 한도·나눠쓰기(부분 허용) — 주황/파랑 계열, 차단은 아님
  partialAllow,
}

class BlockTimelineSegment {
  const BlockTimelineSegment({
    required this.startMinute,
    required this.endMinute,
    required this.kind,
  });

  /// 0~1439 (하루 중 분 단위 시작)
  final int startMinute;

  /// startMinute보다 크며 자정을 넘기면 1440을 더한 값(다음날 새벽)까지 허용
  final int endMinute;
  final BlockTimelineSegmentKind kind;
}

/// 앱·플랫폼 1개의 오늘 하루 상태 — "이름 + 한 줄 상태 + 24시간 구간"
class BlockChatDailyTimelineItem {
  const BlockChatDailyTimelineItem({
    required this.label,
    required this.statusText,
    this.segments = const [],
  });

  final String label;
  final String statusText;
  final List<BlockTimelineSegment> segments;
}
