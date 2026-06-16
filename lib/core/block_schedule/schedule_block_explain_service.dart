import '../explorer/explorer_site.dart';
import '../intervention/website_block_guard.dart';
import '../safety/content_safety_guard.dart';
import '../youtube/blocked_channel_store.dart';
import '../youtube/blocked_url_guard.dart';
import '../youtube/blocked_url_store.dart';
import '../youtube/content_filter_store.dart';
import '../youtube/youtube_access_guard.dart';
import '../youtube/youtube_channel_block_guard.dart';
import '../youtube/youtube_limit_gate.dart';
import '../youtube/youtube_watch_timer_store.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'models/schedule_enforcement_mode.dart';
import 'schedule_active_service.dart';
import 'schedule_app_target_catalog.dart';
import 'schedule_app_targets_store.dart';
import 'schedule_display_helper.dart';
import 'url_rules/schedule_web_block_guard.dart';

/// 차단 이유 한 줄 요약 + 스케줄·규칙 상세 (더보기 시트용)
class ScheduleBlockExplainItem {
  const ScheduleBlockExplainItem({
    required this.layer,
    required this.title,
    required this.detail,
    this.scheduleId,
    this.scheduleName,
    this.fixHint,
    this.iconName = 'block',
  });

  final String layer;
  final String title;
  final String detail;
  final String? scheduleId;
  final String? scheduleName;
  final String? fixHint;
  final String iconName;
}

class ScheduleBlockExplainReport {
  const ScheduleBlockExplainReport({
    required this.blocked,
    required this.summary,
    required this.items,
    this.url,
    this.siteLabel,
  });

  final bool blocked;
  final String summary;
  final List<ScheduleBlockExplainItem> items;
  final String? url;
  final String? siteLabel;

  String? get primaryScheduleId {
    for (final i in items) {
      if (i.scheduleId != null) return i.scheduleId;
    }
    return null;
  }
}

class ScheduleBlockExplainService {
  ScheduleBlockExplainService._();

  static ScheduleBlockExplainReport explainUrl(
    String raw, {
    bool inAppExplorer = false,
  }) {
    var url = raw.trim();
    if (url.isEmpty) {
      return const ScheduleBlockExplainReport(
        blocked: false,
        summary: '차단 없음',
        items: [],
      );
    }
    if (!url.startsWith('http')) url = 'https://$url';
    return _build(url: url, inAppExplorer: inAppExplorer);
  }

  static ScheduleBlockExplainReport explainSite(
    ExplorerSite site, {
    String? url,
    bool inAppExplorer = true,
  }) {
    final u = url?.trim().isNotEmpty == true ? url! : site.defaultHomeUrl;
    return _build(
      url: u,
      site: site,
      inAppExplorer: inAppExplorer,
    );
  }

  static ScheduleBlockExplainReport _build({
    required String url,
    ExplorerSite? site,
    required bool inAppExplorer,
  }) {
    final items = <ScheduleBlockExplainItem>[];
    final now = DateTime.now();

    if (!BlockScheduleStore.masterEnabled) {
      items.add(
        const ScheduleBlockExplainItem(
          layer: 'master',
          title: '스케줄 마스터 OFF',
          detail: '「스케줄 차단」스위치가 꺼져 있어요. 켜진 스케줄만 아래에 표시됩니다.',
          fixHint: '차단 탭 → 스케줄 목록 상단 마스터 스위치',
          iconName: 'info',
        ),
      );
    }

    final active = ScheduleActiveService.activeSchedulesNow(now);
    if (active.isEmpty && BlockScheduleStore.masterEnabled) {
      items.add(
        const ScheduleBlockExplainItem(
          layer: 'slot',
          title: '지금은 활성 스케줄 슬롯 없음',
          detail: '현재 시각에 켜진 시간대가 없어요. 스케줄 시간이 아니면 차단이 안 됩니다.',
          iconName: 'schedule',
        ),
      );
    }

    for (final s in active) {
      items.addAll(_scheduleItems(s, now, url: url, inAppExplorer: inAppExplorer));
    }

    final safety = ContentSafetyGuard.matchUrl(url);
    if (safety != null) {
      items.add(ScheduleBlockExplainItem(
        layer: 'safety',
        title: '안전 필터',
        detail: safety.snackMessage,
        fixHint: '설정 → 안전 검색·콘텐츠 필터',
        iconName: 'shield',
      ));
    }

    final web = WebsiteBlockGuard.matchUrl(url);
    if (web != null) {
      items.add(ScheduleBlockExplainItem(
        layer: 'website',
        title: '항상 차단 웹사이트',
        detail: web.snackMessage,
        fixHint: '차단 탭 → 웹사이트 차단',
        iconName: 'public_off',
      ));
    }

    if (!inAppExplorer) {
      final scheduleWeb = ScheduleWebBlockGuard.matchUrl(url);
      if (scheduleWeb != null) {
        items.add(ScheduleBlockExplainItem(
          layer: 'schedule_domain',
          title: '스케줄 도메인 (Safari·외부 브라우저)',
          detail: scheduleWeb.snackMessage,
          fixHint: '스케줄 편집 → 차단 방식·도메인·슬롯 확인',
          iconName: 'schedule',
        ));
      }
    }

    final blockedUrls = BlockedUrlStore.loadAll();
    final urlHit = BlockedUrlGuard.match(url, blockedUrls);
    if (urlHit != null) {
      items.add(ScheduleBlockExplainItem(
        layer: 'url',
        title: '차단 URL',
        detail: urlHit.snackMessage,
        fixHint: '피드·유튜브 관리 → URL 차단',
        iconName: 'link_off',
      ));
    }

    final isYt = url.contains('youtube.com') || url.contains('youtu.be');
    if (isYt) {
      final yt = YoutubeChannelBlockGuard.matchUrl(
        url,
        channels: BlockedChannelStore.loadAll(),
        videos: ContentFilterStore.loadVideos(),
        keywords: ContentFilterStore.loadKeywords(),
        blockedUrls: blockedUrls,
      );
      if (yt != null) {
        items.add(ScheduleBlockExplainItem(
          layer: 'youtube_rule',
          title: '유튜브 콘텐츠 필터',
          detail: yt.snackMessage,
          fixHint: '나의 Isle → 유튜브·SNS 관리',
          iconName: 'play_disabled',
        ));
      }

      if (YoutubeAccessGuard.shouldBlockWebView) {
        final lock = YoutubeAccessGuard.activeLock();
        if (lock != null) {
          items.add(ScheduleBlockExplainItem(
            layer: 'youtube_limit',
            title: lock == YoutubeLockReason.schedule
                ? 'Isle 유튜브 스케줄 잠금'
                : '유튜브 일일 한도',
            detail: YoutubeLimitGate.blockedTitle(lock),
            fixHint: lock == YoutubeLockReason.schedule
                ? '스케줄 편집 → Isle · YouTube 체크 해제 또는 슬롯 조정'
                : '유튜브 시청 시간 카드 → 한도 늘리기/끄기',
            iconName: 'timer',
          ));
        }
      } else if (YoutubeWatchTimerStore.isEnabled) {
        items.add(
          ScheduleBlockExplainItem(
            layer: 'youtube_ok',
            title: '유튜브 시청 한도',
            detail: YoutubeWatchTimerStore.formatStatusLine(),
            iconName: 'check',
          ),
        );
      }
    }

    final blocking = items.where((i) {
      if (_isInfoOnly(i.layer)) return false;
      if (inAppExplorer && i.layer == 'schedule_domain') return false;
      return true;
    }).toList();
    final blocked = blocking.isNotEmpty;
    final summary = blocked
        ? blocking.first.title
        : (items.isNotEmpty ? '지금은 차단 조건 없음' : '차단 없음');

    return ScheduleBlockExplainReport(
      blocked: blocked,
      summary: summary,
      items: items,
      url: url,
      siteLabel: site?.name,
    );
  }

  static bool _isInfoOnly(String layer) =>
      layer == 'master' ||
      layer == 'slot' ||
      layer == 'youtube_ok' ||
      layer == 'schedule_limit_only';

  static List<ScheduleBlockExplainItem> _scheduleItems(
    BlockSchedule schedule,
    DateTime now, {
    required String url,
    required bool inAppExplorer,
  }) {
    final out = <ScheduleBlockExplainItem>[];
    final active = ScheduleActiveService.isScheduleActiveNow(schedule, now);
    final timeLine = ScheduleDisplayHelper.todayStatusLine(schedule, at: now);
    final mode = schedule.enforcementMode;

    final entries = ScheduleAppTargetsStore.loadForSchedule(schedule.id);
    final blockedTargets = entries.where((e) => e.blockInSlot).toList();
    final limitedTargets = entries.where((e) => e.limitEnabled).toList();

    if (active && mode.appliesShieldInSlot && schedule.domains.isNotEmpty) {
      final hostNote = schedule.domains.take(5).join(', ');
      out.add(ScheduleBlockExplainItem(
        layer: 'schedule_domain',
        title: '「${schedule.name}」도메인 쉴드',
        detail: '$timeLine · ${mode.localizedLabel('ko')}\n'
            '도메인: $hostNote'
            '${inAppExplorer ? '\n(인앱은 Isle 타깃 체크 시에만 막혀요)' : ''}',
        scheduleId: schedule.id,
        scheduleName: schedule.name,
        fixHint: '스케줄 편집 → 차단 방식을 「한도만」으로 바꾸거나 도메인 비우기',
        iconName: 'public_off',
      ));
    }

    if (active && blockedTargets.isNotEmpty) {
      final labels = blockedTargets
          .map((e) => ScheduleAppTargetCatalog.defFor(e.targetId)?.label ?? e.targetId)
          .join(' · ');
      out.add(ScheduleBlockExplainItem(
        layer: 'schedule_target',
        title: '「${schedule.name}」앱 타깃 잠금',
        detail: '$timeLine\n막는 대상: $labels',
        scheduleId: schedule.id,
        scheduleName: schedule.name,
        fixHint: '스케줄 편집 → ③ 차단 대상 체크 해제',
        iconName: 'apps',
      ));
    }

    if (active && limitedTargets.isNotEmpty && mode.appliesLimitInSlot) {
      final parts = limitedTargets.map((e) {
        final def = ScheduleAppTargetCatalog.defFor(e.targetId);
        return '${def?.label ?? e.targetId} ${e.limitMinutes}분/${e.windowMinutes}분';
      }).join(' · ');
      out.add(ScheduleBlockExplainItem(
        layer: 'schedule_limit',
        title: '「${schedule.name}」시간 한도',
        detail: '$timeLine\n$parts',
        scheduleId: schedule.id,
        scheduleName: schedule.name,
        fixHint: '한도는 Screen Time·OS와 연동 — 스케줄 편집에서 분 조정',
        iconName: 'hourglass',
      ));
    }

    if (active && schedule.blockIsleInApp) {
      out.add(ScheduleBlockExplainItem(
        layer: 'schedule_isle',
        title: '「${schedule.name}」Isle 인앱 차단 ON',
        detail: '$timeLine · WebView 전체 잠금',
        scheduleId: schedule.id,
        scheduleName: schedule.name,
        fixHint: '스케줄 편집 → Isle 인앱 차단 스위치',
        iconName: 'phone_iphone',
      ));
    }

    if (active &&
        out.isEmpty &&
        mode == ScheduleEnforcementMode.limitInSlot) {
      out.add(ScheduleBlockExplainItem(
        layer: 'schedule_limit_only',
        title: '「${schedule.name}」한도만 (완전 차단 아님)',
        detail: timeLine,
        scheduleId: schedule.id,
        scheduleName: schedule.name,
        iconName: 'info',
      ));
    }

    return out;
  }
}
