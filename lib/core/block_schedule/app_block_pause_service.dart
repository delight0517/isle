import 'dart:async';

import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';
import 'app_block_config_service.dart';
import 'block_schedule_enforcement_service.dart';
import 'block_schedule_store.dart';

/// 앱별(bundleId) 개별 차단 일시 해제 — [AppBlockConfigService]가 관리하는
/// 그 앱 자신의 스케줄만 N분간 끄고 자동 복원한다. 예전 `SafariPauseService`는
/// 앱 전체가 공유하는 쉴드 하나를 통째로 풀어서 "유튜브뮤직만 5분 허용"해도
/// 카카오·Safari까지 같이 풀리는 문제가 있었다 — 이 서비스는 그 문제를
/// 구조적으로 없앤다(앱마다 별도 스케줄이므로 끄고 켜는 대상도 그 스케줄 하나뿐).
class AppBlockPauseService {
  AppBlockPauseService._();

  static final Map<String, Timer> _timers = {};

  static bool isPaused(String bundleId) {
    final ms = IsleUserDefaults.appBlockPauseUntilMs(bundleId);
    if (ms <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch < ms;
  }

  static DateTime? pauseUntil(String bundleId) {
    final ms = IsleUserDefaults.appBlockPauseUntilMs(bundleId);
    if (ms <= 0) return null;
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    return t.isBefore(DateTime.now()) ? null : t;
  }

  static int remainingSeconds(String bundleId) {
    final until = pauseUntil(bundleId);
    if (until == null) return 0;
    return until.difference(DateTime.now()).inSeconds.clamp(0, 99999);
  }

  /// N분 임시 해제 — 이 앱의 스케줄만 비활성화하고 타이머로 자동 복원 예약.
  static Future<void> pauseFor(String bundleId, int minutes) async {
    final schedule = await AppBlockConfigService.existingFor(bundleId);
    if (schedule == null || !schedule.enabled) return;
    final until = DateTime.now().add(Duration(minutes: minutes));
    await IsleUserDefaults.setAppBlockPauseUntilMs(
      bundleId,
      until.millisecondsSinceEpoch,
    );
    await BlockScheduleStore.upsert(schedule.copyWith(enabled: false));
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    IsleAppLogService.log(
      'AppBlockPause: $bundleId ${minutes}m until ${until.toIso8601String()}',
    );
    _scheduleAutoRestore(bundleId, until);
  }

  /// 취소 — 즉시 이 앱 스케줄 재활성화.
  static Future<void> cancelPause(String bundleId) async {
    _timers.remove(bundleId)?.cancel();
    await IsleUserDefaults.setAppBlockPauseUntilMs(bundleId, 0);
    await _restore(bundleId);
    IsleAppLogService.log('AppBlockPause: $bundleId cancelled → reapplied');
  }

  /// 앱 resume 시 호출 — 만료됐으면 복원, 아직 유효하면 타이머 재설치.
  static Future<void> checkAndRestoreIfExpired(String bundleId) async {
    final ms = IsleUserDefaults.appBlockPauseUntilMs(bundleId);
    if (ms <= 0) return;
    final until = DateTime.fromMillisecondsSinceEpoch(ms);
    if (until.isBefore(DateTime.now())) {
      await _restore(bundleId);
    } else {
      _scheduleAutoRestore(bundleId, until);
    }
  }

  static Future<void> checkAndRestoreAllIfExpired(
    List<String> bundleIds,
  ) async {
    for (final id in bundleIds) {
      await checkAndRestoreIfExpired(id);
    }
  }

  static Future<void> _restore(String bundleId) async {
    _timers.remove(bundleId)?.cancel();
    await IsleUserDefaults.setAppBlockPauseUntilMs(bundleId, 0);
    final schedule = await AppBlockConfigService.existingFor(bundleId);
    if (schedule != null && !schedule.enabled) {
      await BlockScheduleStore.upsert(schedule.copyWith(enabled: true));
      await BlockScheduleEnforcementService.syncPlatformEnforcement(
        force: true,
      );
    }
    IsleAppLogService.log('AppBlockPause: $bundleId expired → restored');
  }

  static void _scheduleAutoRestore(String bundleId, DateTime until) {
    _timers.remove(bundleId)?.cancel();
    final delay = until.difference(DateTime.now());
    if (delay.inSeconds <= 0) {
      unawaited(_restore(bundleId));
      return;
    }
    _timers[bundleId] = Timer(delay, () => unawaited(_restore(bundleId)));
  }
}
