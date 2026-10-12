import 'dart:io' show Platform;

import '../blocking/blocking_controller_provider.dart';
import '../intervention/external_app_shield_store.dart';
import '../intervention/schedule_screen_time_store.dart';
import '../intervention/website_block_store.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'quick_block_service.dart';
import '../platform/ios_rules_export_service.dart';
import '../platform/ios_schedule_device_activity_service.dart';
import '../platform/ios_schedule_snapshot.dart';
import '../platform/ios_screen_time_service.dart';
import '../platform/mac_app_block_service.dart';
import '../platform/mac_browser_session_service.dart';
import '../services/isle_user_defaults.dart';
import 'schedule_app_limit_sync_service.dart';
import 'schedule_enforcement_policy.dart';

/// 앱 resume·스케줄 변경 시 플랫폼 차단 동기화 (§4 side effects)
class BlockScheduleEnforcementService {
  BlockScheduleEnforcementService._();

  static String? _lastShieldKey;
  static String? _lastAndroidKey;
  static bool? _lastLockdownActive;

  /// [Volt] 동일 도메인·상태면 Screen Time 브리지 호출 생략
  static Future<void> syncPlatformEnforcement({bool force = false}) async {
    await QuickBlockService.pruneExpired();
    await ScheduleScreenTimeStore.ensureOpen();

    // [Bridge] Android 는 BlockingController(접근성/VpnService) 경로로 완전 분리 처리.
    // iOS/macOS 경로(아래)는 절대 건드리지 않음.
    if (Platform.isAndroid) {
      await _syncAndroidEnforcement(force: force);
      return;
    }

    final shieldActive = ScheduleEnforcementPolicy.shieldSchedulesNow();

    // "올나이트 록다운" — 개별 앱 선택(shieldActive의 encoded selection)과는
    // 독립된 네이티브 카테고리 쉴드라, 아래 shieldActive 캐시 키/early-return과
    // 무관하게 별도로 캐시·적용한다(2026-[REDACTED]).
    if (Platform.isIOS) {
      final lockdownActive = shieldActive.any((s) => s.lockdownAllApps);
      if (force || _lastLockdownActive != lockdownActive) {
        _lastLockdownActive = lockdownActive;
        await IosScreenTimeService.applyLockdownShield(
          lockdownActive,
          allowedAppsEncoded: IsleUserDefaults.lockdownAllowedAppsEncoded,
        );
      }
    }

    final keepGlobalShield = !ExternalAppShieldStore.syncWithBlockSchedule &&
        ExternalAppShieldStore.hasSelection;
    final globalEncoded =
        keepGlobalShield ? ExternalAppShieldStore.encodedSelection! : '';
    if (shieldActive.isEmpty) {
      final key = keepGlobalShield ? 'global_only|$globalEncoded' : 'off';
      if (!force && _lastShieldKey == key) {
        if (BlockScheduleStore.masterEnabled) {
          await ScheduleAppLimitSyncService.syncAll();
          if (Platform.isIOS) {
            await IosScheduleDeviceActivityService.syncMonitorsFromStore();
          }
        }
        return;
      }
      _lastShieldKey = key;
      if (keepGlobalShield) {
        await IosScreenTimeService.applyAppShield(encoded: globalEncoded);
        await ExternalAppShieldStore.setShieldMarkedActive(true);
      } else {
        await IosScreenTimeService.clearScheduleEnforcement();
        await ExternalAppShieldStore.setShieldMarkedActive(false);
      }
      if (Platform.isIOS) {
        await IosScreenTimeService.stopScheduleDeviceActivities();
      }
      if (Platform.isMacOS) {
        await MacAppBlockService.syncFromPolicy(scheduleBlockingActive: false);
      }
      if (BlockScheduleStore.masterEnabled) {
        await ScheduleAppLimitSyncService.syncAll();
        if (Platform.isIOS) {
          await IosScheduleDeviceActivityService.syncMonitorsFromStore();
        }
      }
      return;
    }
    final domains = ScheduleEnforcementPolicy.mergedDomainsForShieldNow()
      ..sort();
    final ids = shieldActive.map((e) => e.id).toList()..sort();
    final perSel =
        ids.map((id) => ScheduleScreenTimeStore.encodedFor(id) ?? '').join(';');
    // "항상 차단" 섹션/설정 화면은 켤 때 syncWithBlockSchedule=false로 설정한다
    // ("지금부터 전역 차단" — 스케줄과 무관하게 항상 켜져 있길 원함). 그런데 이
    // 조건이 syncWithBlockSchedule==true(스케줄 시간에만 적용하는 별개 설정)일
    // 때만 fallback을 포함시키고 있어서, 다른 스케줄이 동시에 활성화되면 항상
    // 차단이 골라둔 앱이 네이티브 쉴드에서 조용히 빠지는 버그였음(cage에서
    // 07-08 진단·수정 후 이식). syncWithBlockSchedule 값과 무관하게 선택이
    // 있으면 항상 포함시켜 두 의미(스케줄 시간에만/항상) 다 스케줄 활성 중엔
    // 적용되게 통일한다.
    final fallback = ExternalAppShieldStore.hasSelection
        ? ExternalAppShieldStore.encodedSelection!
        : '';
    final key = '${domains.join('|')}|$perSel|$fallback';
    if (!force && _lastShieldKey == key) return;
    _lastShieldKey = key;

    if (!await IosScreenTimeService.isAvailable()) return;
    if (!await IosScreenTimeService.isAuthorized()) {
      return;
    }

    if (Platform.isIOS) {
      for (final id in ids) {
        final enc = ScheduleScreenTimeStore.encodedFor(id);
        if (enc != null && enc.isNotEmpty) {
          await IosScreenTimeService.saveScheduleSelection(
              scheduleId: id, encoded: enc);
        }
      }
      if (fallback.isNotEmpty) {
        await IosScreenTimeService.saveGlobalFallbackSelection(fallback);
      }
      await IosScreenTimeService.applyActiveScheduleShield(
        scheduleIds: ids,
        domains: domains,
        fallbackEncoded: fallback.isEmpty ? null : fallback,
        lockdownActive: ids.any((id) => shieldActive.any(
              (schedule) => schedule.id == id && schedule.lockdownAllApps,
            )),
        lockdownAllowedAppsEncoded: IsleUserDefaults.lockdownAllowedAppsEncoded,
      );
      if (fallback.isNotEmpty ||
          perSel.contains(RegExp(r'[A-Za-z0-9+/=]{8,}'))) {
        await ExternalAppShieldStore.setShieldMarkedActive(true);
      }
    } else {
      if (domains.isNotEmpty) {
        await IosScreenTimeService.applyMergedShield(domains);
      }
      if (fallback.isNotEmpty) {
        await IosScreenTimeService.applyAppShield(encoded: fallback);
        await ExternalAppShieldStore.setShieldMarkedActive(true);
      }
    }

    if (Platform.isMacOS) {
      final scheduleOn = IsleUserDefaults.youtubeScheduleLockEnabled &&
          shieldActive.isNotEmpty;
      await MacAppBlockService.syncFromPolicy(
          scheduleBlockingActive: scheduleOn);
      if (scheduleOn) {
        await MacBrowserSessionService.startMonitoring();
      }
    }

    if (Platform.isIOS) {
      await IosScheduleSnapshot.writeNow();
      await IosRulesExportService.exportNow();
      await IosScheduleDeviceActivityService.syncMonitorsFromStore();
    }
    await ScheduleAppLimitSyncService.syncAll();
  }

  /// [Bridge] Android 스케줄 강제 — 활성 스케줄에 맞춰 웹 차단(VpnService) on/off,
  /// 항상-막기(글로벌) 앱 선택은 접근성으로 상시 적용. iOS 경로와 완전 분리.
  ///
  /// 참고: Android 는 [ScheduleScreenTimeStore] 에 패키지 CSV 저장 (iOS FamilyActivity 대체).
  static Future<void> _syncAndroidEnforcement({required bool force}) async {
    final shieldActive = ScheduleEnforcementPolicy.shieldSchedulesNow();
    final scheduleDomains = shieldActive.isEmpty
        ? const <String>[]
        : (ScheduleEnforcementPolicy.mergedDomainsForShieldNow()..sort());
    await WebsiteBlockStore.ensureOpen();
    final webDomains = {
      ...scheduleDomains,
      ...WebsiteBlockStore.loadDomains(),
    }.toList()
      ..sort();
    final keepGlobalApps = !ExternalAppShieldStore.syncWithBlockSchedule &&
        ExternalAppShieldStore.hasSelection;
    final scheduleAppCsv = await _androidActiveSchedulePackages(shieldActive);

    final key =
        '${webDomains.join('|')}|active=${shieldActive.isNotEmpty}|gApps=$keepGlobalApps|sched=$scheduleAppCsv';
    if (!force && _lastAndroidKey == key) return;
    _lastAndroidKey = key;

    final c = resolveBlockingController();

    if (webDomains.isNotEmpty) {
      await c.applyWebBlock(webDomains);
    } else {
      await c.clearWebBlock();
    }

    if (keepGlobalApps) {
      await c.applyAppShield(
        BlockSelection(
          platform: currentBlockingPlatform(),
          encoded: ExternalAppShieldStore.encodedSelection!,
          appCount: ExternalAppShieldStore.applicationCount,
          categoryCount: ExternalAppShieldStore.categoryCount,
        ),
      );
      await ExternalAppShieldStore.setShieldMarkedActive(true);
      return;
    }

    if (shieldActive.isNotEmpty &&
        ExternalAppShieldStore.syncWithBlockSchedule) {
      final csv = scheduleAppCsv ??
          (ExternalAppShieldStore.hasSelection
              ? ExternalAppShieldStore.encodedSelection
              : null);
      if (csv != null && csv.isNotEmpty) {
        final count = csv.split(',').where((p) => p.trim().isNotEmpty).length;
        await c.applyAppShield(
          BlockSelection(
            platform: currentBlockingPlatform(),
            encoded: csv,
            appCount: count,
          ),
        );
        await ExternalAppShieldStore.setShieldMarkedActive(true);
      } else {
        await c.clearAppShield();
        await ExternalAppShieldStore.setShieldMarkedActive(false);
      }
      return;
    }

    await c.clearAppShield();
    await ExternalAppShieldStore.setShieldMarkedActive(false);
  }

  static Future<String?> _androidActiveSchedulePackages(
      List<BlockSchedule> active) async {
    if (active.isEmpty) return null;
    await ScheduleScreenTimeStore.ensureOpen();
    final packages = <String>{};
    for (final s in active) {
      final enc = ScheduleScreenTimeStore.encodedFor(s.id);
      if (enc == null || enc.isEmpty) continue;
      for (final p in enc.split(',')) {
        final t = p.trim();
        if (t.isNotEmpty) packages.add(t);
      }
    }
    if (packages.isEmpty) return null;
    return packages.join(',');
  }
}
