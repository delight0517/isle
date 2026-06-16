/// AI 차단 챗 — 의도·적용 결과
class BlockChatMessage {
  const BlockChatMessage({
    required this.role,
    required this.text,
    this.result,
    this.isLoading = false,
  });

  final BlockChatRole role;
  final String text;
  final BlockChatResult? result;
  final bool isLoading;

  BlockChatMessage copyWith({
    String? text,
    BlockChatResult? result,
    bool? isLoading,
  }) =>
      BlockChatMessage(
        role: role,
        text: text ?? this.text,
        result: result ?? this.result,
        isLoading: isLoading ?? this.isLoading,
      );
}

enum BlockChatRole { user, assistant }

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
    this.removeKeyword,
    this.toggleOn,
    this.limitPlatform,
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
  final String? removeKeyword;
  /// toggle_shorts / toggle_reels — true=숨김 ON
  final bool? toggleOn;
  /// youtube_limit — 플랫폼 (기본 youtube)
  final String? limitPlatform;

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
      removeKeyword: (j['remove_keyword'] as String?)?.trim(),
      toggleOn: j['toggle_on'] as bool?,
      limitPlatform: (j['limit_platform'] as String?)?.trim(),
    );
  }
}

class BlockChatAppliedStep {
  const BlockChatAppliedStep({
    required this.title,
    required this.detail,
    this.route,
    this.routeLabel,
  });

  final String title;
  final String detail;
  final String? route;
  final String? routeLabel;
}

class BlockChatResult {
  const BlockChatResult({
    required this.summary,
    required this.steps,
    this.usedAi = false,
    this.needsUnlockWait = false,
    this.unlockMinutes,
    this.isFailure = false,
  });

  final String summary;
  final List<BlockChatAppliedStep> steps;
  final bool usedAi;
  final bool needsUnlockWait;
  final int? unlockMinutes;
  final bool isFailure;

  factory BlockChatResult.fail(String msg) => BlockChatResult(
        summary: msg,
        steps: const [],
        isFailure: true,
      );
}
