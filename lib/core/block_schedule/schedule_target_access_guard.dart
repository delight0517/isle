import '../explorer/explorer_site.dart';
import 'schedule_active_service.dart';
import 'schedule_app_target_catalog.dart';
import 'schedule_app_targets_store.dart';
import 'schedule_bundle_usage_store.dart';
import 'block_schedule_store.dart';

/// Isle / 스케줄 슬롯 — 앱 타깃별 차단·한도
class ScheduleTargetAccessGuard {
  ScheduleTargetAccessGuard._();

  static bool isTargetBlocked(String targetId, [DateTime? at]) {
    if (!BlockScheduleStore.masterEnabled) return false;
    for (final s in ScheduleActiveService.activeSchedulesNow(at)) {
      final e = ScheduleAppTargetsStore.entryFor(s.id, targetId);
      if (e != null && e.blockInSlot) return true;
    }
    return false;
  }

  static bool get isIsleYoutubeBlocked => isTargetBlocked('isle_youtube');

  static bool get isIsleInstagramBlocked => isTargetBlocked('isle_instagram');

  static bool get isIsleInstagramDmBlocked => isTargetBlocked('isle_instagram_dm');

  static bool get isIsleBrunchBlocked => isTargetBlocked('isle_brunch');

  /// "브라우저/인터넷 차단해줘" 채팅으로 직접 지정된 인앱 브라우저 타깃.
  static bool get isIsleCustomWebTargeted => isTargetBlocked('isle_customweb');

  /// 아침 Safari 스케줄 등 — Isle 타깃 전부 슬롯 차단 시 custom 웹(Safari)도 막음.
  /// (2026-07-12: 직접 지정된 isle_customweb 타깃이 있으면 그것부터 확인 —
  /// 예전엔 이 heuristic(전부 차단일 때만 우연히 커버)이 유일한 경로라
  /// "브라우저만 콕 집어서" 막는 요청은 아무리 채팅으로 말해도 실제로는
  /// 아무것도 막히지 않았다.)
  static bool get isIsleCustomWebBlocked {
    if (!BlockScheduleStore.masterEnabled) return false;
    if (isIsleCustomWebTargeted) return true;
    final isleIds = ScheduleAppTargetCatalog.isleTargets().map((t) => t.id).toList();
    for (final s in ScheduleActiveService.activeSchedulesNow()) {
      if (!s.blockIsleInApp) continue;
      final entries = ScheduleAppTargetsStore.loadForSchedule(s.id);
      final allBlocked = isleIds.every(
        (id) => entries.any((e) => e.targetId == id && e.blockInSlot),
      );
      if (allBlocked) return true;
    }
    return false;
  }

  static bool isInstagramExplorerBlocked({required bool dmOnly}) {
    if (dmOnly) {
      if (isIsleInstagramDmBlocked) return true;
    } else {
      if (isIsleInstagramBlocked) return true;
    }
    return false;
  }

  static String? _bundleForExplorer(ExplorerSite site, {bool instagramDmOnly = false}) {
    if (site.isYoutube) return 'youtube';
    if (site.isInstagram) return 'instagram';
    if (site.isBrunch) return 'brunch';
    return null;
  }

  static Future<bool> isExplorerBlocked(
    ExplorerSite site, {
    bool instagramDmOnly = false,
  }) async {
    if (site == ExplorerSite.custom && isIsleCustomWebBlocked) return true;
    if (site.isYoutube && isIsleYoutubeBlocked) return true;
    if (site.isInstagram && isInstagramExplorerBlocked(dmOnly: instagramDmOnly)) {
      return true;
    }
    if (site.isBrunch && isIsleBrunchBlocked) return true;
    final bundle = _bundleForExplorer(site, instagramDmOnly: instagramDmOnly);
    if (bundle == null) return false;
    return await isBundleLimitBlocking(bundle);
  }

  static Future<bool> isBundleLimitBlocking(String bundleId) async {
    final hit = await activeBundleLimitHit();
    return hit == bundleId;
  }

  /// 활성 스케줄에서 번들 한도 초과 (슬롯 안·한도 켠 경우)
  static Future<String?> activeBundleLimitHit([DateTime? at]) async {
    if (!BlockScheduleStore.masterEnabled) return null;
    for (final s in ScheduleActiveService.activeSchedulesNow(at)) {
      for (final bundle in ScheduleAppTargetCatalog.bundles) {
        final entries = ScheduleAppTargetsStore.loadForSchedule(s.id);
        final enabled = entries.where((e) {
          final def = ScheduleAppTargetCatalog.defFor(e.targetId);
          return def?.bundleId == bundle.id && e.limitEnabled;
        }).toList();
        if (enabled.isEmpty) continue;
        final minutes = enabled.first.limitMinutes;
        final window = enabled.first.windowMinutes;
        final hit = await ScheduleBundleUsageStore.isLimitReached(
          scheduleId: s.id,
          bundleId: bundle.id,
          limitMinutes: minutes,
          windowMinutes: window,
        );
        if (hit) return bundle.id;
      }
    }
    return null;
  }

  /// [activeBundleLimitHit]의 동기·단일번들 버전 — 지금 활성인 **어느** 스케줄이든
  /// 이 번들 리필 한도에 이미 도달했으면 true. 여러 스케줄이 같은 앱을 겹쳐
  /// 겨냥해도 각 스케줄 사용량이 독립적으로 집계되므로, 가장 빡빡한(먼저 닿는)
  /// 스케줄에서 자동으로 막힌다 = "가장 제한적인 규칙 승리". 안전 라인
  /// 스케줄도 활성 목록에 포함되므로 항상 이 판정에 들어간다.
  static bool isBundleLimitReachedNowSync(String bundleId, [DateTime? at]) {
    if (!BlockScheduleStore.masterEnabled) return false;
    if (!ScheduleBundleUsageStore.isOpen) return false;
    for (final s in ScheduleActiveService.activeSchedulesNow(at)) {
      final entries = ScheduleAppTargetsStore.loadForSchedule(s.id);
      final enabled = entries.where((e) {
        final def = ScheduleAppTargetCatalog.defFor(e.targetId);
        return def?.bundleId == bundleId && e.limitEnabled;
      }).toList();
      if (enabled.isEmpty) continue;
      final hit = ScheduleBundleUsageStore.isLimitReachedSync(
        scheduleId: s.id,
        bundleId: bundleId,
        limitMinutes: enabled.first.limitMinutes,
        windowMinutes: enabled.first.windowMinutes,
      );
      if (hit) return true;
      // 시간당 리필 한도가 아직 안 찼어도, 진짜 하루 총량 상한(dailyLimitMinutes,
      // 안전 라인의 "하루 2시간" 등)에 닿았으면 막힌다 — 리필은 계속 도는데
      // 하루 총량만 넘긴 경우를 리필 한도 체크만으론 못 잡는다.
      final dailyCap = enabled.first.dailyLimitMinutes;
      if (dailyCap != null &&
          ScheduleBundleUsageStore.isDailyLimitReachedSync(
            scheduleId: s.id,
            bundleId: bundleId,
            dailyLimitMinutes: dailyCap,
            at: at,
          )) {
        return true;
      }
    }
    return false;
  }

  /// 지금 활성 스케줄 중 YouTube(번들 'youtube') 리필 한도를 켠 게 하나라도
  /// 있는지 — 켜져 있으면 그 창 사용량을 집계해야 한다.
  static bool hasActiveYoutubeLimitNow([DateTime? at]) {
    if (!BlockScheduleStore.masterEnabled) return false;
    for (final s in ScheduleActiveService.activeSchedulesNow(at)) {
      final entries = ScheduleAppTargetsStore.loadForSchedule(s.id);
      final on = entries.any((e) {
        final def = ScheduleAppTargetCatalog.defFor(e.targetId);
        return def?.bundleId == 'youtube' && e.limitEnabled;
      });
      if (on) return true;
    }
    return false;
  }

  /// 지금 활성 스케줄 중 YouTube 리필 한도에 이미 도달한 게 있으면 true.
  static bool isYoutubeScheduleLimitReachedNow([DateTime? at]) =>
      isBundleLimitReachedNowSync('youtube', at);

  /// 지금 유튜브 리필 한도로 막혀 있는 스케줄이 있으면, 그중 가장 늦게 풀리는
  /// 시점까지 남은 초 — 안 막혀 있으면 null. 스케줄이 여러 개 겹쳐서 막고
  /// 있으면 전부 풀려야(=가장 늦은 것 기준) 실제로 다시 볼 수 있다.
  static int? youtubeScheduleLimitEtaSecondsSync([DateTime? at]) {
    if (!BlockScheduleStore.masterEnabled) return null;
    if (!ScheduleBundleUsageStore.isOpen) return null;
    int? maxLeft;
    for (final s in ScheduleActiveService.activeSchedulesNow(at)) {
      final entries = ScheduleAppTargetsStore.loadForSchedule(s.id);
      final enabled = entries.where((e) {
        final def = ScheduleAppTargetCatalog.defFor(e.targetId);
        return def?.bundleId == 'youtube' && e.limitEnabled;
      }).toList();
      if (enabled.isEmpty) continue;
      final reachedWindow = ScheduleBundleUsageStore.isLimitReachedSync(
        scheduleId: s.id,
        bundleId: 'youtube',
        limitMinutes: enabled.first.limitMinutes,
        windowMinutes: enabled.first.windowMinutes,
      );
      final dailyCap = enabled.first.dailyLimitMinutes;
      final reachedDaily = dailyCap != null &&
          ScheduleBundleUsageStore.isDailyLimitReachedSync(
            scheduleId: s.id,
            bundleId: 'youtube',
            dailyLimitMinutes: dailyCap,
            at: at,
          );
      if (!reachedWindow && !reachedDaily) continue;

      // 하루 총량 상한으로 막힌 거면 리필 창이 아니라 자정에야 풀린다 —
      // 리필 ETA를 그대로 보여주면 "곧 풀린다"는 거짓 안내가 된다.
      final left = reachedDaily
          ? ScheduleBundleUsageStore.secondsUntilMidnight(at)
          : ScheduleBundleUsageStore.secondsUntilRefillSync(
              scheduleId: s.id,
              bundleId: 'youtube',
              windowMinutes: enabled.first.windowMinutes,
            );
      if (maxLeft == null || left > maxLeft) maxLeft = left;
    }
    return maxLeft;
  }
}
