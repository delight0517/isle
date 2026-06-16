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

  /// 아침 Safari 스케줄 등 — Isle 타깃 전부 슬롯 차단 시 custom 웹(Safari)도 막음
  static bool get isIsleCustomWebBlocked {
    if (!BlockScheduleStore.masterEnabled) return false;
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
}
