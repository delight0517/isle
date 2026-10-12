import 'dart:io' show Platform;

import '../block_schedule/block_schedule_enforcement_service.dart';
import '../block_schedule/block_schedule_store.dart';
import '../block_schedule/schedule_edit_guard.dart';
import '../platform/ios_screen_time_service.dart';
import '../platform/isle_apple_platform.dart';
import '../services/isle_app_log_service.dart';
import 'app_intervention_service.dart';
import 'external_app_shield_store.dart';
import 'schedule_screen_time_store.dart';

/// 스케줄별 FamilyActivityPicker + App Group 동기화.
class ScheduleScreenTimeService {
  ScheduleScreenTimeService._();

  /// `pickForSchedule`이 false를 반환했을 때 실제 사유 — 예전엔 호출부가
  /// 전부 이유 구분 없이 "취소되었거나 권한이 없어요"로 뭉뚱그려서, 사용자가
  /// 거부(denied)/기기 제한(restricted)/시뮬레이터/일시적 오류 중 뭘 만났는지
  /// 알 방법이 없었다(2026-07-21 사용자 제보 — Screen Time 권한이
  /// notDetermined로 멈춰있는데 원인을 알 수 없어 앱을 하나도 못 골랐음).
  /// 호출부는 false를 받으면 이 필드를 읽어 구체적 안내(설정으로 이동 등)를
  /// 보여준다.
  static ScreenTimeAuthResult? lastAuthFailure;

  static Future<bool> pickForSchedule(
    String scheduleId, {
    bool additiveOnly = false,
    bool deferEnforcement = false,
    // Phase 2(2026-07-06) — 특정 앱(bundle) 체크박스에서만 고르고 싶을 때.
    // Phase 3(네이티브 확장, 완료)부터는 `saveScheduleSelection`이 bundleId를
    // 그대로 네이티브에 전달해 스케줄×bundle별 키에 저장되고,
    // `IsleScheduleShieldSync.applyActiveSchedules`가 이 bundle 키들을 union해
    // 실제 쉴드를 만든다 — 체크박스 하나가 진짜로 그 앱 하나만 제어한다.
    String? bundleId,
  }) async {
    if (Platform.isAndroid) {
      await ScheduleScreenTimeStore.ensureOpen();
      if (!await AppInterventionService.ensureAuthorized()) return false;

      final existing = ScheduleScreenTimeStore.encodedFor(
            scheduleId,
            bundleId: bundleId,
          ) ??
          ScheduleScreenTimeStore.encodedFor(scheduleId) ??
          (additiveOnly ? ExternalAppShieldStore.encodedSelection : null);

      final pick =
          await AppInterventionService.pickApps(existingEncoded: existing);
      if (pick == null) return false;

      await ScheduleScreenTimeStore.savePick(
        scheduleId: scheduleId,
        encoded: pick.encoded,
        applicationCount: pick.applicationCount,
        categoryCount: pick.categoryCount,
      );
      IsleAppLogService.log(
        'schedule Android pick $scheduleId apps=${pick.applicationCount}',
      );
      if (!deferEnforcement) {
        await BlockScheduleEnforcementService.syncPlatformEnforcement(
            force: true);
      }
      return true;
    }

    if (!IsleApplePlatform.isScreenTimeHost) return false;
    await ScheduleScreenTimeStore.ensureOpen();
    lastAuthFailure = null;
    if (!await IosScreenTimeService.isAuthorized()) {
      final auth = await IosScreenTimeService.requestAuthorizationDetailed();
      if (!auth.ok) {
        lastAuthFailure = auth;
        IsleAppLogService.log(
          'schedule ST pick $scheduleId auth failed: '
          'code=${auth.code} message=${auth.message}',
          level: IsleLogLevel.warn,
        );
        return false;
      }
    }

    final useBundle = bundleId != null && bundleId.isNotEmpty;
    // bundle 지정 시에도 기존 전체 선택을 시드해야 네이티브가 아직 모르는
    // 다른 bundle의 선택이 이번 픽으로 지워지지 않는다 — additive 강제.
    final existing = ScheduleScreenTimeStore.encodedFor(
          scheduleId,
          bundleId: bundleId,
        ) ??
        ScheduleScreenTimeStore.encodedFor(scheduleId) ??
        (additiveOnly ? ExternalAppShieldStore.encodedSelection : null);

    final pick = await IosScreenTimeService.pickFamilyActivitySelection(
      existingEncoded: existing,
      additiveOnly: additiveOnly || useBundle,
    );
    // pick==null은 사용자가 피커를 그냥 취소한 경우(권한 문제 아님) —
    // lastAuthFailure를 그대로 두면 다음 실패 때 엉뚱한 예전 사유가 남는다.
    if (pick == null) {
      lastAuthFailure = null;
      return false;
    }

    if (useBundle) {
      await ScheduleScreenTimeStore.savePick(
        scheduleId: scheduleId,
        bundleId: bundleId,
        encoded: pick.encoded,
        applicationCount: pick.applicationCount,
        categoryCount: pick.categoryCount,
      );
    }
    // legacy whole-schedule 키도 계속 갱신 — 실제 쉴드는 이제 bundle 키
    // union으로 결정되니 여기엔 더 이상 필요 없지만(applyActiveSchedules가
    // bundle 선택이 있으면 legacy를 무시함), "Screen Time N개 선택" 요약
    // UI(ScreenTimeSelectionSummary 등)가 아직 legacy 키를 읽으므로 유지.
    await ScheduleScreenTimeStore.savePick(
      scheduleId: scheduleId,
      encoded: pick.encoded,
      applicationCount: pick.applicationCount,
      categoryCount: pick.categoryCount,
    );
    await IosScreenTimeService.saveScheduleSelection(
      scheduleId: scheduleId,
      bundleId: useBundle ? bundleId : null,
      encoded: pick.encoded,
    );
    IsleAppLogService.log(
      'schedule ST pick $scheduleId${useBundle ? ' bundle=$bundleId' : ''} '
      'apps=${pick.applicationCount} cats=${pick.categoryCount}',
    );
    if (!deferEnforcement) {
      await BlockScheduleEnforcementService.syncPlatformEnforcement(
          force: true);
    }
    return true;
  }

  /// 잠긴 스케줄이면(=지금 시간대 안 활성 여부와 무관하게) Screen Time
  /// 피커를 additive-only로 열어 기존 선택 해제를 막는다.
  ///
  /// **왜 `ScheduleActiveService.activeSchedulesNow()`(지금 활성인 것만)가
  /// 아니라 `BlockScheduleStore.loadAll()`에서 찾고 `ScheduleEditGuard.
  /// isCommitmentLocked`로 판정하는가(2026-07-15 사용자 우회 우려 제보)**:
  /// 예전엔 "지금 시간대 활성 + 잠금"일 때만 additive-only였다 — 23:00–07:00
  /// 잠긴 야간 스케줄이라면, 낮 시간대(활성 아님)엔 `activeSchedulesNow()`
  /// 목록에 아예 안 잡혀 `s == null`로 additive-only가 통째로 풀렸다. 낮에
  /// 피커를 열어 대상 앱 선택을 자유롭게 지울 수 있었고, 밤이 와도 그
  /// 스케줄엔 이제 아무 앱도 안 걸려 있으니 잠금이 사실상 무력화됨 —
  /// "차단 이후 앱을 탭 목록에서 없애서 우회하는 것 아니냐"는 우려가 바로
  /// 이 경로. 활성 시간대와 무관하게, 스케줄이 존재하고 커밋먼트 잠금
  /// 상태이기만 하면 additive-only로 강제한다.
  /// `pickForSchedule`이 false를 반환한 뒤 UI가 보여줄 문구/액션 — 사유별로
  /// 분리해서, "취소되었거나 권한이 없어요" 한 문장에 denied/restricted/
  /// simulator/일시적 오류가 전부 뭉개지던 문제를 없앤다. `showSettingsAction`이
  /// true면 호출부가 `IosScreenTimeService.openScreenTimeSettings()`로 가는
  /// 스낵바 액션을 붙여야 한다.
  static ({String message, bool showSettingsAction}) describeLastFailure() {
    final f = lastAuthFailure;
    if (f == null) {
      return (message: '앱 선택이 취소됐어요.', showSettingsAction: false);
    }
    if (f.needsSettings) {
      return (
        message: f.message ?? '설정에서 Screen Time 권한을 허용해야 앱을 고를 수 있어요.',
        showSettingsAction: true,
      );
    }
    if (f.isSimulator) {
      return (
        message: '시뮬레이터에서는 Screen Time을 테스트할 수 없어요 — 실제 기기에서 시도해 주세요.',
        showSettingsAction: false,
      );
    }
    if (f.isUnavailable) {
      return (
        message: f.message ?? '이 기기·빌드에서는 Screen Time을 쓸 수 없어요.',
        showSettingsAction: false,
      );
    }
    return (
      message:
          f.message ?? '권한 요청이 실패했어요 (${f.code ?? "알 수 없음"}) — 다시 시도해 주세요.',
      showSettingsAction: false,
    );
  }

  static bool shouldUseAdditiveOnly(String scheduleId) {
    final s = BlockScheduleStore.loadAll()
        .where((e) => e.id == scheduleId)
        .firstOrNull;
    if (s == null) return false;
    return ScheduleEditGuard.isCommitmentLocked(s);
  }
}
