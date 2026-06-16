import 'dart:io' show Platform;

import '../block_schedule/block_schedule_enforcement_service.dart';
import '../block_schedule/block_schedule_store.dart';
import '../block_schedule/models/block_schedule.dart';
import '../block_schedule/models/schedule_app_target_entry.dart';
import '../block_schedule/models/schedule_enforcement_mode.dart';
import '../block_schedule/models/schedule_slot.dart';
import '../block_schedule/schedule_app_limit_sync_service.dart';
import '../block_schedule/schedule_app_targets_service.dart';
import '../block_schedule/schedule_app_targets_store.dart';
import '../intervention/app_usage_limit_store.dart';
import '../intervention/app_intervention_service.dart';
import '../intervention/platform_app_limit_service.dart';
import '../intervention/schedule_screen_time_service.dart';
import '../intervention/schedule_screen_time_store.dart';
import '../intervention/website_block_store.dart';
import '../platform/ios_rules_export_service.dart';
import '../platform/ios_screen_time_service.dart';
import '../platform/isle_apple_platform.dart';
import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';
import 'kakao_micro_refill_setup_result.dart';
import 'kakao_shorts_addiction_store.dart';

/// 카카오 쇼츠 권장 프리셋 — 스케줄·도메인·포모도로
class KakaoShortsPresetService {
  KakaoShortsPresetService._();

  static const microRefillScheduleName = '카카오 쇼츠 · 5분 리필';

  /// iOS DeviceActivity는 5분 롤링 창 미지원 → 매시간 N분 허용
  static ({int windowMinutes, int limitMinutes}) microRefillLimits() {
    if (Platform.isIOS) return (windowMinutes: 60, limitMinutes: 5);
    return (windowMinutes: 5, limitMinutes: 3);
  }

  /// 5분(Android) / 매시간 5분(iOS) 리필 — 마스터 ON · OS 한도 동기화 · 피커
  static Future<KakaoMicroRefillSetupResult> applyMicroRefillSchedule({
    bool openPicker = true,
  }) async {
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();

    final limits = microRefillLimits();
    var pickerAttempted = false;

    final existing = BlockScheduleStore.loadAll()
        .where((s) => s.name == microRefillScheduleName)
        .toList();
    BlockSchedule schedule;
    if (existing.isNotEmpty) {
      schedule = existing.first;
    } else {
      schedule = await BlockScheduleStore.create(
        name: microRefillScheduleName,
        slots: [
          for (var d = 0; d < 7; d++)
            ScheduleSlot(day: d, startMinute: 0, endMinute: 1440),
        ],
      );
    }

    schedule = schedule.copyWith(
      enabled: true,
      enforcementMode: ScheduleEnforcementMode.limitInSlot,
      domains: const [],
      blockIsleInApp: false,
    );
    await BlockScheduleStore.upsert(schedule);

    await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);

    const entries = [
      ScheduleAppTargetEntry(
        targetId: 'ios_kakao',
        blockInSlot: false,
        limitEnabled: true,
      ),
    ];
    final configured = entries
        .map(
          (e) => e.copyWith(
            limitMinutes: limits.limitMinutes,
            windowMinutes: limits.windowMinutes,
          ),
        )
        .toList();

    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: schedule.id,
      entries: configured,
      schedule: schedule,
    );

    if (openPicker && IsleApplePlatform.isNativeBlockHost) {
      if (Platform.isAndroid) {
        await AppInterventionService.ensureAuthorized();
      } else {
        if (!await IosScreenTimeService.isAuthorized()) {
          await IosScreenTimeService.requestAuthorizationDetailed();
        }
      }
      if (ScheduleScreenTimeStore.appCountFor(schedule.id) == 0) {
        pickerAttempted = true;
        await ScheduleScreenTimeService.pickForSchedule(schedule.id);
        await ScheduleAppTargetsService.saveAndSync(
          scheduleId: schedule.id,
          entries: configured,
          schedule: schedule,
        );
      }
    }

    if (Platform.isAndroid) {
      if (!await PlatformAppLimitService.hasUsageAccess()) {
        await PlatformAppLimitService.openUsageAccessSettings();
      }
    }

    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    await ScheduleAppLimitSyncService.syncAll();

    final ruleId = 'schedule_${schedule.id}_kakao_talk';
    final rule = AppUsageLimitStore.loadRules().where((r) => r.id == ruleId).firstOrNull;
    final appCount = ScheduleScreenTimeStore.appCountFor(schedule.id);

    IsleAppLogService.log(
      'Kakao micro-refill ready id=${schedule.id} apps=$appCount '
      'win=${limits.windowMinutes}m limit=${limits.limitMinutes}m rule=${rule != null}',
    );

    return KakaoMicroRefillSetupResult(
      schedule: schedule,
      masterEnabled: IsleUserDefaults.youtubeScheduleLockEnabled,
      limitMinutes: limits.limitMinutes,
      windowMinutes: limits.windowMinutes,
      screenTimeAppCount: appCount,
      limitRuleRegistered: rule != null && (rule.iosFamilyActivityEncoded?.isNotEmpty == true || Platform.isAndroid),
      pickerAttempted: pickerAttempted,
    );
  }

  /// Safari에서 카카오 웹 쇼츠 (보조)
  static Future<void> enableSafariKakaoDomain() async {
    await WebsiteBlockStore.ensureOpen();
    if (!WebsiteBlockStore.isBlocked('kakao.com')) {
      await WebsiteBlockStore.toggle('kakao.com');
    }
    await IosRulesExportService.exportNow();
  }

  static Future<void> enablePomodoro30x10() => KakaoShortsAddictionStore.setPomodoroEnabled(true);
}
