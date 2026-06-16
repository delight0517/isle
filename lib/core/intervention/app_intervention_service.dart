import '../block_schedule/block_schedule_enforcement_service.dart';
import '../blocking/blocking_controller_provider.dart';
import '../platform/ios_family_activity_pick_result.dart';
import '../services/isle_app_log_service.dart';
import 'external_app_shield_store.dart';

export '../platform/ios_family_activity_pick_result.dart';

/// 다른 앱 개입 — [BlockingController] 경유 (iOS Screen Time 쉴드 / Android 접근성 차단).
/// [Bridge] 규칙: 플랫폼 분기 없이 `resolveBlockingController()` 만 사용.
class AppInterventionService {
  AppInterventionService._();

  static Future<bool> ensureAuthorized() async {
    final c = resolveBlockingController();
    if (!await c.isAvailable()) return false;
    if (await c.isAuthorized()) return true;
    final r = await c.requestAuthorization();
    return r.ok;
  }

  /// 차단 대상 앱 선택. 기존 호환을 위해 [IosFamilyActivityPickResult] 반환
  /// (Android 에선 [IosFamilyActivityPickResult.encoded] = 패키지 CSV, webDomainCount=0).
  static Future<IosFamilyActivityPickResult?> pickApps({
    String? existingEncoded,
  }) async {
    final c = resolveBlockingController();
    if (!await ensureAuthorized()) return null;
    final existing = existingEncoded ?? ExternalAppShieldStore.encodedSelection;
    final sel = await c.pickTargets(
      existing: (existing != null && existing.isNotEmpty)
          ? BlockSelection(platform: currentBlockingPlatform(), encoded: existing)
          : null,
    );
    if (sel == null) return null;
    return IosFamilyActivityPickResult(
      encoded: sel.encoded,
      applicationCount: sel.appCount,
      categoryCount: sel.categoryCount,
      webDomainCount: 0,
    );
  }

  static Future<bool> applySavedAppShield() async {
    if (!ExternalAppShieldStore.hasSelection) return false;
    final c = resolveBlockingController();
    final encoded = ExternalAppShieldStore.encodedSelection!;
    final ok = await c.applyAppShield(
      BlockSelection(
        platform: currentBlockingPlatform(),
        encoded: encoded,
        appCount: ExternalAppShieldStore.applicationCount,
        categoryCount: ExternalAppShieldStore.categoryCount,
      ),
    );
    if (ok) await ExternalAppShieldStore.setShieldMarkedActive(true);
    IsleAppLogService.log('applyAppShield: $ok apps=${ExternalAppShieldStore.applicationCount}');
    return ok;
  }

  static Future<void> clearAppShield() async {
    await resolveBlockingController().clearAppShield();
    await ExternalAppShieldStore.setShieldMarkedActive(false);
  }

  static Future<void> syncWithActiveSchedules() async {
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
  }
}
