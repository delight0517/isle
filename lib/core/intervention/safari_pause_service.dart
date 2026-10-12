import 'dart:async';

import '../block_schedule/block_schedule_enforcement_service.dart';
import '../intervention/app_intervention_service.dart';
import '../intervention/external_app_shield_store.dart';
import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';

/// Safari·앱 쉴드를 N분 임시 해제.
/// 앱이 백그라운드로 간 사이 만료되면 resume 시 자동 복원.
class SafariPauseService {
  SafariPauseService._();

  static Timer? _timer;

  static int get _storedMs => IsleUserDefaults.shieldPauseUntilMs;

  static bool get isPaused {
    final ms = _storedMs;
    if (ms <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch < ms;
  }

  static DateTime? get pauseUntil {
    final ms = _storedMs;
    if (ms <= 0) return null;
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    return t.isBefore(DateTime.now()) ? null : t;
  }

  static int get remainingSeconds {
    final until = pauseUntil;
    if (until == null) return 0;
    return until.difference(DateTime.now()).inSeconds.clamp(0, 99999);
  }

  /// N분 임시 해제 — 쉴드 해제 후 타이머 설정.
  static Future<void> pauseFor(int minutes) async {
    final until = DateTime.now().add(Duration(minutes: minutes));
    await IsleUserDefaults.setShieldPauseUntilMs(until.millisecondsSinceEpoch);
    await AppInterventionService.clearAppShield();
    IsleAppLogService.log('SafariPause: ${minutes}m until ${until.toIso8601String()}');
    _scheduleAutoRestore(until);
  }

  /// 취소 — 즉시 쉴드 재적용.
  static Future<void> cancelPause() async {
    _timer?.cancel();
    _timer = null;
    await IsleUserDefaults.setShieldPauseUntilMs(0);
    await AppInterventionService.applySavedAppShield();
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    IsleAppLogService.log('SafariPause: cancelled → shield reapplied');
  }

  /// 앱 resume 시 호출 — 만료됐으면 쉴드 복원, 아직 유효하면 타이머 재설치.
  static Future<void> checkAndRestoreIfExpired() async {
    final ms = _storedMs;
    if (ms <= 0) return;
    final until = DateTime.fromMillisecondsSinceEpoch(ms);
    if (until.isBefore(DateTime.now())) {
      await _restore();
    } else {
      _scheduleAutoRestore(until);
    }
  }

  static Future<void> _restore() async {
    _timer?.cancel();
    _timer = null;
    await IsleUserDefaults.setShieldPauseUntilMs(0);
    final shouldReapply = ExternalAppShieldStore.isOpen &&
        !ExternalAppShieldStore.syncWithBlockSchedule &&
        ExternalAppShieldStore.hasSelection;
    if (shouldReapply) {
      await AppInterventionService.applySavedAppShield();
      await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    }
    IsleAppLogService.log('SafariPause: expired → shield restored (reapply=$shouldReapply)');
  }

  static void _scheduleAutoRestore(DateTime until) {
    _timer?.cancel();
    final delay = until.difference(DateTime.now());
    if (delay.inSeconds <= 0) {
      unawaited(_restore());
      return;
    }
    _timer = Timer(delay, () => unawaited(_restore()));
  }
}
