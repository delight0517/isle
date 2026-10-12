import 'dart:async';
import 'dart:io' show Platform;

import '../intervention/external_app_shield_store.dart';
import '../intervention/safari_pause_service.dart';
import '../platform/ios_screen_time_service.dart';
import '../services/isle_app_log_service.dart';
import '../services/volt_lifecycle_service.dart';
import 'block_schedule_enforcement_service.dart';
import 'block_schedule_store.dart';
import 'schedule_active_service.dart';
import 'schedule_lock_service.dart';
import 'schedule_notification_service.dart';

/// [Volt] 스케줄 경계 — 백그라운드 타이머 없이 pause/resume 타임스탬프로 상태 복구
class VoltScheduleBoundaryService {
  VoltScheduleBoundaryService._();

  /// 앱 비활성화 직전 스냅샷 (한 번의 Hive put 배치)
  static Future<void> recordPauseSnapshot() async {
    if (!BlockScheduleStore.masterEnabled) {
      await VoltLifecycleService.putScheduleSnapshot(blocked: false, activeIds: '');
      return;
    }
    final at = DateTime.now();
    final blocked = ScheduleActiveService.isYoutubeWebViewBlockedNow(at);
    final ids = ScheduleActiveService.activeScheduleIdsNow(at).join(',');
    await VoltLifecycleService.putScheduleSnapshot(blocked: blocked, activeIds: ids);
  }

  /// 부팅 직후 — 잠금·Safari 일시해제만 (Screen Time/DeviceActivity 동기화는 지연)
  static Future<void> reconcileLocksOnly() async {
    await SafariPauseService.checkAndRestoreIfExpired();
    await ScheduleLockService.finalizeExpiredLocks();
  }

  /// 재개 시: 잠금 FSM 정리 + 경계 넘었으면 1회 동기화 (Device Activity 없이 가능한 최대)
  static Future<void> reconcileAfterResume() async {
    // 잠깐 풀기 만료 여부 먼저 확인 — 만료됐으면 쉴드 복원, 유효하면 타이머 재설치.
    await SafariPauseService.checkAndRestoreIfExpired();
    await ScheduleLockService.finalizeExpiredLocks();

    final pausedAt = VoltLifecycleService.lastPausedAt();
    final snap = VoltLifecycleService.scheduleSnapshot();

    final nowBlocked = BlockScheduleStore.masterEnabled &&
        ScheduleActiveService.isYoutubeWebViewBlockedNow();
    final nowIds = ScheduleActiveService.activeScheduleIdsNow().join(',');

    var boundaryCrossed = false;
    if (pausedAt != null && snap != null) {
      final wasBlocked = snap.blocked;
      final wasIds = snap.activeIds;
      boundaryCrossed = wasBlocked != nowBlocked || wasIds != nowIds;
      if (boundaryCrossed) {
        IsleAppLogService.log(
          'Schedule boundary while away: blocked $wasBlocked→$nowBlocked '
          'active=[$wasIds]→[$nowIds] (paused ${pausedAt.toUtc().toIso8601String()})',
        );
      }
    }

    // 항상-막기(global) 쉴드는 스케줄 경계가 없어 boundaryCrossed=false →
    // OS가 권한 변경·재시작으로 쉴드를 떨궈도 캐시 일치로 재적용 안 됨(기술부채 #2).
    // 항상-막기가 켜져 있으면 resume·부팅마다 강제 재적용해 확실히 유지한다.
    // 단, 잠깐 풀기(SafariPauseService) 중에는 의도적 해제이므로 재적용 skip.
    // Android(Light)는 이 박스를 열지 않고 자체 enforcement 경로를 쓰므로 제외.
    final globalShieldActive = !SafariPauseService.isPaused &&
        ExternalAppShieldStore.isOpen &&
        !ExternalAppShieldStore.syncWithBlockSchedule &&
        ExternalAppShieldStore.hasSelection;
    await BlockScheduleEnforcementService.syncPlatformEnforcement(
      force: boundaryCrossed || globalShieldActive,
    );
    if (Platform.isIOS) {
      await IosScreenTimeService.syncShieldFromSnapshot();
    }
    unawaited(ScheduleNotificationService.rescheduleAll());
  }

  /// 다음 활성↔비활성 전환 시각 (UI 표시용, 폴링 없음)
  static DateTime? nextYoutubeBlockTransition([DateTime? from]) {
    if (!BlockScheduleStore.masterEnabled) return null;
    if (BlockScheduleStore.loadAll().every((s) => !s.enabled || s.slots.isEmpty)) return null;

    final start = from ?? DateTime.now();
    final nowBlocked = ScheduleActiveService.isYoutubeWebViewBlockedNow(start);
    for (var m = 1; m < 24 * 60 * 8; m++) {
      final at = start.add(Duration(minutes: m));
      if (ScheduleActiveService.isYoutubeWebViewBlockedNow(at) != nowBlocked) {
        return at;
      }
    }
    return null;
  }

  static String? nextTransitionLabel([DateTime? from]) {
    final next = nextYoutubeBlockTransition(from);
    if (next == null) return null;
    final nowBlocked = ScheduleActiveService.isYoutubeWebViewBlockedNow(from ?? DateTime.now());
    final h = next.hour.toString().padLeft(2, '0');
    final min = next.minute.toString().padLeft(2, '0');
    return nowBlocked ? 'Isle 내 차단 해제 $h:$min' : 'Isle 내 차단 시작 $h:$min';
  }
}
