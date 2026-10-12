import '../explorer/explorer_site.dart';
import '../usage_budget/usage_budget_models.dart';
import '../usage_budget/usage_budget_store.dart';
import '../youtube/youtube_access_guard.dart';
import '../youtube/youtube_watch_timer_store.dart';
import '../navigation/isle_routes.dart';
import '../services/isle_user_defaults.dart';
import 'models/block_schedule.dart';
import 'schedule_active_service.dart';
import 'schedule_app_targets_store.dart';
import 'schedule_block_explain_service.dart';
import 'schedule_display_helper.dart';
import 'schedule_target_access_guard.dart';
import 'url_rules/schedule_web_block_guard.dart';

/// 진입 차단 종류 — 스케줄 vs 시청 한도 UI 분기
enum BlockEntryKind {
  schedule,
  youtubeDailyLimit,
  youtubeScheduleLimit,
  generic,
}

/// 진입 차단 — 사용자 친화 문구 (도메인·스케줄명·종료 시각)
class ScheduleBlockEntryCopy {
  const ScheduleBlockEntryCopy({
    required this.title,
    required this.body,
    required this.fixHint,
    this.kind = BlockEntryKind.generic,
    this.scheduleId,
    this.scheduleName,
    this.timeLine,
    this.endsHint,
    this.layerLabel,
    this.usageChip,
    this.primaryButtonLabel,
    this.primaryRoute,
  });

  final String title;
  final String body;
  final String fixHint;
  final BlockEntryKind kind;
  final String? scheduleId;
  final String? scheduleName;
  final String? timeLine;
  final String? endsHint;
  final String? layerLabel;
  /// 예: 「45 / 45분 사용」
  final String? usageChip;
  final String? primaryButtonLabel;
  final String? primaryRoute;

  bool get isYoutubeDailyLimit => kind == BlockEntryKind.youtubeDailyLimit;

  String get oneLine {
    if (isYoutubeDailyLimit) {
      return '$title — ${usageChip ?? body.split('\n').first}';
    }
    if (scheduleName != null) {
      return '$title — 「$scheduleName」${endsHint != null ? ' ($endsHint)' : ''}';
    }
    return '$title — $body'.split('\n').first;
  }
}

abstract final class ScheduleBlockUserMessage {
  ScheduleBlockUserMessage._();

  static ScheduleBlockEntryCopy entryCopy({
    ExplorerSite? site,
    String? url,
    String? legacyMessage,
    bool inAppExplorer = true,
  }) {
    final now = DateTime.now();
    final siteLabel = _siteLabel(site, url);

    // 시청 한도는 스케줄보다 먼저 — 둘 다 켜져 있어도 한도 소진이면 한도로 안내
    if (_isYoutubeContext(site, url)) {
      // 스케줄 리필 한도(안전 라인의 "시간당 10분" 포함)로 막힌 경우도
      // "왜 막혔는지" 홈 카드에서 제대로 안내해야 함 — 이전엔 dailyLimit·
      // budget만 처리해서 스케줄 리필 한도로 막힌 상태는 여기서 안 걸리고
      // 아래 일반 스케줄 안내로 새거나 최악엔 아무 안내도 못 찾았음
      // (2026-07-20, 인앱 유튜브 스케줄 리필 한도 버그 수정과 짝).
      final scheduleLimitCopy = _youtubeScheduleLimitEntry(siteLabel);
      if (scheduleLimitCopy != null) return scheduleLimitCopy;
      final limitCopy = _youtubeDailyLimitEntry(siteLabel);
      if (limitCopy != null) return limitCopy;
    }

    final primary = _primaryBlockingSchedule(site: site, url: url, now: now);

    if (primary != null) {
      final timeLine = ScheduleDisplayHelper.todayStatusLine(primary, at: now);
      final ends = ScheduleDisplayHelper.activeSlotEndsLabel(primary, at: now);
      final layer = _layerFor(site: site, url: url, schedule: primary);
      return ScheduleBlockEntryCopy(
        title: '$siteLabel을(를) 열 수 없어요',
        body: '「${primary.name}」 스케줄이 지금 켜져 있어요.\n'
            '$timeLine'
            '${ends != null ? '\n$ends' : ''}',
        fixHint: layer.fixHint,
        kind: BlockEntryKind.schedule,
        scheduleId: primary.id,
        scheduleName: primary.name,
        timeLine: timeLine,
        endsHint: ends,
        layerLabel: layer.label,
        primaryButtonLabel: '이 스케줄 편집',
        primaryRoute: IsleRoutes.blockScheduleEditOutsideShell(primary.id),
      );
    }

    final report = url != null && url.trim().isNotEmpty
        ? ScheduleBlockExplainService.explainUrl(url, inAppExplorer: inAppExplorer)
        : ScheduleBlockExplainService.explainSite(
            site ?? ExplorerSite.youtube,
            url: url,
            inAppExplorer: inAppExplorer,
          );

    if (report.blocked && report.items.isNotEmpty) {
      final hit = report.items.firstWhere(
        (i) => !_isInfoLayer(i.layer),
        orElse: () => report.items.first,
      );
      return ScheduleBlockEntryCopy(
        title: '$siteLabel을(를) 열 수 없어요',
        body: hit.detail,
        fixHint: hit.fixHint ?? '차단 탭 → 스케줄에서 설정을 확인해 주세요',
        kind: BlockEntryKind.schedule,
        scheduleId: hit.scheduleId,
        scheduleName: hit.scheduleName,
        layerLabel: hit.title,
        primaryButtonLabel:
            hit.scheduleId != null ? '이 스케줄 편집' : '스케줄 목록',
        primaryRoute: hit.scheduleId != null
            ? IsleRoutes.blockScheduleEditOutsideShell(hit.scheduleId!)
            : IsleRoutes.blockSchedulesOutsideShell,
      );
    }

    return ScheduleBlockEntryCopy(
      title: '$siteLabel을(를) 열 수 없어요',
      body: legacyMessage?.replaceFirst(RegExp(r'^스케줄 차단:\s*'), '') ??
          report.summary,
      fixHint: '차단 탭 → 스케줄 목록에서 활성 스케줄을 확인해 주세요',
    );
  }

  static String shortDenial({
    ExplorerSite? site,
    String? url,
    String? legacyMessage,
  }) =>
      entryCopy(site: site, url: url, legacyMessage: legacyMessage).oneLine;

  /// `/youtube/browser` 오버레이 — 스케줄 잠금 전용 (한도와 분리)
  static ScheduleBlockEntryCopy youtubeWebViewScheduleLockCopy() {
    final now = DateTime.now();
    final primary = _primaryBlockingSchedule(
      site: ExplorerSite.youtube,
      url: null,
      now: now,
    );
    final timeLine =
        primary != null ? ScheduleDisplayHelper.todayStatusLine(primary, at: now) : null;
    final ends =
        primary != null ? ScheduleDisplayHelper.activeSlotEndsLabel(primary, at: now) : null;
    final layer = primary != null
        ? _layerFor(site: ExplorerSite.youtube, url: null, schedule: primary)
        : null;

    return ScheduleBlockEntryCopy(
      title: 'YouTube 시청이 잠겨 있어요',
      body: [
        if (primary != null && timeLine != null) '「${primary.name}」 · $timeLine',
        'Isle 앱 안에서 YouTube를 막아 두었어요.',
        if (ends != null) ends,
        layer?.fixHint ?? '스케줄 편집 → ③ 「Isle 유튜브」체크를 끄면 다시 볼 수 있어요.',
      ].join('\n'),
      fixHint: layer?.fixHint ?? '스케줄 편집에서 해제',
      kind: BlockEntryKind.schedule,
      scheduleId: primary?.id,
      scheduleName: primary?.name,
      timeLine: timeLine,
      endsHint: ends,
      layerLabel: layer?.label ?? 'Isle 앱 안 YouTube 잠금',
      primaryButtonLabel: primary != null ? '이 스케줄 편집' : '스케줄 목록',
      primaryRoute: primary != null
          ? IsleRoutes.blockScheduleEditOutsideShell(primary.id)
          : IsleRoutes.blockSchedulesOutsideShell,
    );
  }

  static String scheduleDomainSnack(String hostOrLabel) {
    final friendly = _friendlyHost(hostOrLabel);
    final copy = entryCopy(
      site: _siteFromHost(hostOrLabel),
      url: _guessUrl(hostOrLabel),
      legacyMessage: friendly,
    );
    return copy.oneLine;
  }

  static bool _isInfoLayer(String layer) =>
      layer == 'master' || layer == 'slot' || layer == 'youtube_ok';

  static String _siteLabel(ExplorerSite? site, String? url) {
    if (site != null) {
      return switch (site) {
        ExplorerSite.youtube => 'YouTube',
        ExplorerSite.instagram => 'Instagram',
        ExplorerSite.brunch => 'Brunch',
        ExplorerSite.custom => '웹 브라우저',
        _ => '이 페이지',
      };
    }
    final u = (url ?? '').toLowerCase();
    if (u.contains('youtube') || u.contains('youtu.be')) return 'YouTube';
    if (u.contains('instagram')) return 'Instagram';
    if (u.contains('brunch')) return 'Brunch';
    return '이 사이트';
  }

  static ExplorerSite? _siteFromHost(String raw) {
    final h = raw.toLowerCase();
    if (h.contains('youtube') || h.contains('youtu')) return ExplorerSite.youtube;
    if (h.contains('instagram')) return ExplorerSite.instagram;
    if (h.contains('brunch')) return ExplorerSite.brunch;
    return null;
  }

  static String? _guessUrl(String raw) {
    final t = raw.trim();
    if (t.startsWith('http')) return t;
    if (t.contains('.')) return 'https://$t';
    return null;
  }

  static String _friendlyHost(String raw) {
    final h = raw.toLowerCase();
    if (h.contains('youtube') || h.contains('youtu.be') || h == 'm.youtube.com') {
      return 'YouTube';
    }
    if (h.contains('instagram')) return 'Instagram';
    if (h.contains('google.com')) return 'Google 검색';
    return raw;
  }

  static BlockSchedule? _primaryBlockingSchedule({
    ExplorerSite? site,
    String? url,
    required DateTime now,
  }) {
    final active = ScheduleActiveService.activeSchedulesNow(now);
    if (active.isEmpty) return null;

    if (site == ExplorerSite.youtube || _urlIsYoutube(url)) {
      for (final s in active) {
        final e = ScheduleAppTargetsStore.entryFor(s.id, 'isle_youtube');
        if (e != null && e.blockInSlot) return s;
      }
      return null;
    }
    if (site == ExplorerSite.instagram) {
      for (final s in active) {
        final e = ScheduleAppTargetsStore.entryFor(s.id, 'isle_instagram');
        if (e != null && e.blockInSlot) return s;
      }
    }

    if (url != null && ScheduleWebBlockGuard.matchUrl(url) != null) {
      for (final s in active) {
        if (s.domains.isNotEmpty) return s;
      }
    }

    return active.length == 1 ? active.first : null;
  }

  static bool _urlIsYoutube(String? url) {
    if (url == null) return false;
    final u = url.toLowerCase();
    return u.contains('youtube.com') || u.contains('youtu.be');
  }

  static bool _isYoutubeContext(ExplorerSite? site, String? url) =>
      site == ExplorerSite.youtube || _urlIsYoutube(url);

  static ScheduleBlockEntryCopy? _youtubeScheduleLimitEntry(String siteLabel) {
    if (YoutubeAccessGuard.activeLock() != YoutubeLockReason.scheduleLimit) return null;
    final etaSeconds = ScheduleTargetAccessGuard.youtubeScheduleLimitEtaSecondsSync();
    final waitLabel =
        etaSeconds == null ? '다음 리필 창' : _formatDurationKo(Duration(seconds: etaSeconds));
    return ScheduleBlockEntryCopy(
      title: '$siteLabel 리필 한도를 다 썼어요',
      body: '스케줄이 정한 유튜브 리필 한도에 도달했어요.\n'
          '$waitLabel 후 다시 볼 수 있어요.',
      fixHint: '겹친 스케줄 중 가장 빡빡한 규칙이 적용돼요 — 스케줄 목록에서 확인하세요.',
      kind: BlockEntryKind.youtubeScheduleLimit,
      layerLabel: '스케줄 리필 한도',
      endsHint: '다시 볼 수 있을 때까지: $waitLabel',
    );
  }

  static ScheduleBlockEntryCopy? _youtubeDailyLimitEntry(String siteLabel) {
    if (!YoutubeWatchTimerStore.isEnabled) return null;
    final lock = YoutubeAccessGuard.activeLock();
    if (lock != YoutubeLockReason.dailyLimit && lock != YoutubeLockReason.budget) {
      return null;
    }

    final reset = YoutubeWatchTimerStore.timeUntilReset();
    final resetLabel = _formatDurationKo(reset);

    if (lock == YoutubeLockReason.budget) {
      final snap = UsageBudgetStore.snapshot(UsageBudgetTarget.youtube);
      if (snap == null || !snap.isLocked) return null;
      final usedMin = snap.ledger.usedSecondsToday ~/ 60;
      final capMin = snap.policy.dailyCapMinutes;
      final usageChip = '오늘 $usedMin / $capMin분 사용';
      final dailyExhausted = snap.dailyRemainingSeconds <= 0;

      return ScheduleBlockEntryCopy(
        title: 'YouTube 시청 시간을 다 썼어요',
        body: '하루 ${capMin}분만 볼 수 있게 설정했어요 (충전식).\n'
            '${dailyExhausted ? '오늘 분을 모두 썼어요' : '지금 쓸 수 있는 시간을 모두 썼어요'} ($usageChip).',
        fixHint: '스케줄이 아니라 「시청 한도」예요. '
            '한도를 늘리려면 설정 → 유튜브 시청 한도 (타임락 대기 후 변경)',
        kind: BlockEntryKind.youtubeDailyLimit,
        layerLabel: '충전식 시청 한도',
        usageChip: usageChip,
        endsHint: '다시 볼 수 있을 때까지: $resetLabel',
        primaryButtonLabel: '유튜브 시청 한도',
        primaryRoute: IsleRoutes.youtubeLimits,
      );
    }

    if (!YoutubeWatchTimerStore.isLimitReached) return null;

    final usedMin = YoutubeWatchTimerStore.secondsUsed ~/ 60;
    final capMin = YoutubeWatchTimerStore.limitSeconds ~/ 60;
    final interval = YoutubeWatchTimerStore.usesInterval;

    final usageChip = interval
        ? '이번 주기 $usedMin / $capMin분 사용'
        : '오늘 $usedMin / $capMin분 사용';

    final windowMin = IsleUserDefaults.youtubeIntervalWindowMinutes;
    final windowLabel = windowMin >= 60
        ? '${windowMin ~/ 60}시간마다'
        : '$windowMin분마다';

    final body = interval
        ? '$windowLabel ${capMin}분만 볼 수 있게 설정했어요.\n'
            '이번 주기 분을 모두 썼어요 ($usageChip).'
        : '하루 ${capMin}분만 볼 수 있게 설정했어요.\n'
            '오늘 분을 모두 썼어요 ($usageChip).';

    final endsHint = interval
        ? '다음 주기 시작: $resetLabel'
        : '자정 이후 다시 시청 가능 ($resetLabel)';

    return ScheduleBlockEntryCopy(
      title: 'YouTube 시청 시간을 다 썼어요',
      body: body,
      fixHint: '스케줄이 아니라 「시청 한도」예요. '
          '한도를 늘리려면 설정 → 유튜브 시청 한도 (타임락 대기 후 변경)',
      kind: BlockEntryKind.youtubeDailyLimit,
      layerLabel: '일일·주기 시청 한도',
      usageChip: usageChip,
      endsHint: endsHint,
      primaryButtonLabel: '유튜브 시청 한도',
      primaryRoute: IsleRoutes.youtubeLimits,
    );
  }

  static String _formatDurationKo(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '$h시간 $m분 후';
    if (m > 0) return '$m분 후';
    return '곧';
  }

  static ({String label, String fixHint}) _layerFor({
    ExplorerSite? site,
    String? url,
    required BlockSchedule schedule,
  }) {
    if (site == ExplorerSite.youtube || _urlIsYoutube(url)) {
      final e = ScheduleAppTargetsStore.entryFor(schedule.id, 'isle_youtube');
      if (e != null && e.blockInSlot) {
        return (
          label: 'Isle 앱 안 YouTube 잠금',
          fixHint: '스케줄 편집 → ③ 「Isle 유튜브」체크 해제 (Safari·도메인과 별개)',
        );
      }
    }
    if (schedule.domains.isNotEmpty) {
      return (
        label: '스케줄 도메인 규칙',
        fixHint: '스케줄 편집 → 차단 방식·도메인 목록 조정 (m.youtube.com 등)',
      );
    }
    return (
      label: '스케줄 잠금',
      fixHint: '스케줄 편집 → 시간대·차단 대상 확인',
    );
  }
}
