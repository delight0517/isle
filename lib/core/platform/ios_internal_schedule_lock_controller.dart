import 'dart:io' show Platform;

import '../block_schedule/schedule_enforcement_policy.dart';
import '../intervention/external_app_shield_store.dart';
import '../services/isle_user_defaults.dart';
import 'ios_screen_time_service.dart';
import 'isle_apple_platform.dart';

/// L3 — 스케줄 활성인데 OS 쉴드가 꺼져 있을 때 인앱 전면 오버레이 (6VPN internal lock 패턴).
enum IosInternalLockMode { off, auto, always }

class IosInternalScheduleLockController {
  IosInternalScheduleLockController._();

  static IosInternalLockMode get mode {
    switch (IsleUserDefaults.iosInternalLockMode) {
      case 'always':
        return IosInternalLockMode.always;
      case 'off':
        return IosInternalLockMode.off;
      default:
        return IosInternalLockMode.auto;
    }
  }

  static Future<void> setMode(IosInternalLockMode m) async {
    final raw = switch (m) {
      IosInternalLockMode.off => 'off',
      IosInternalLockMode.always => 'always',
      IosInternalLockMode.auto => 'auto',
    };
    await IsleUserDefaults.setIosInternalLockMode(raw);
  }

  static Future<bool> shouldShowOverlay() async {
    if (!IsleApplePlatform.isScreenTimeHost || !Platform.isIOS) return false;
    if (mode == IosInternalLockMode.off) return false;
    if (mode == IosInternalLockMode.always) {
      return ScheduleEnforcementPolicy.shieldSchedulesNow().isNotEmpty;
    }
    // auto
    if (ScheduleEnforcementPolicy.shieldSchedulesNow().isEmpty) return false;
    if (!await IosScreenTimeService.isAuthorized()) return true;
    if (!ExternalAppShieldStore.hasSelection) return true;
    if (!ExternalAppShieldStore.shieldMarkedActive) return true;
    return false;
  }
}
