import 'dart:io' show Platform;

import '../blocking/blocking_controller_provider.dart';
import '../intervention/app_intervention_service.dart';
import '../intervention/external_app_shield_store.dart';
import '../intervention/schedule_screen_time_service.dart';
import '../platform/ios_screen_time_service.dart';
import '../platform/screen_time_auth_status.dart';
import '../platform/isle_apple_platform.dart';
import '../services/isle_user_defaults.dart';
import 'block_schedule_enforcement_service.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'models/schedule_slot.dart';
import 'schedule_active_service.dart';

/// 차단 탭 — 설정 상태·원터치 SNS 야간 차단 (앱 자체, WebView 아님)
class BlockFocusStatus {
  const BlockFocusStatus({
    required this.osAuthorized,
    required this.osAvailable,
    required this.hasApps,
    required this.appCount,
    required this.hasSchedule,
    required this.scheduleCount,
    required this.masterOn,
    required this.scheduleActiveNow,
    required this.activeScheduleCount,
  });

  final bool osAuthorized;
  final bool osAvailable;
  final bool hasApps;
  final int appCount;
  final bool hasSchedule;
  final int scheduleCount;
  final bool masterOn;
  final bool scheduleActiveNow;
  final int activeScheduleCount;

  bool get isReady => osAuthorized && hasApps && hasSchedule && masterOn;

  /// 사용자에게 보여줄 한 줄 상태
  String get headline {
    if (!IsleApplePlatform.isNativeBlockHost) {
      return '이 기기에서는 네이티브 앱 차단을 지원하지 않아요';
    }
    if (Platform.isAndroid) {
      if (!osAvailable) return 'Android 차단 엔진을 사용할 수 없어요';
      if (!osAuthorized) return '접근성 차단 서비스를 켜 주세요';
    } else {
      if (!osAvailable) return '이 빌드는 Screen Time을 지원하지 않아요';
      if (!osAuthorized) return '먼저 Screen Time 권한이 필요해요';
    }
    if (!hasApps) return 'Instagram·Chrome 등 막을 앱을 고르세요';
    if (!hasSchedule) return '언제 막을지 스케줄을 만드세요';
    if (!masterOn) return '스케줄 차단 스위치를 켜 주세요';
    if (scheduleActiveNow) {
      return '지금 $activeScheduleCount개 스케줄로 앱·웹이 막혀 있어요';
    }
    return '설정 완료 — 스케줄 시간에 자동 차단됩니다';
  }
}

class BlockFocusService {
  BlockFocusService._();

  static Future<BlockFocusStatus> loadStatus() async {
    await BlockScheduleStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();

    var auth = false;
    var avail = false;
    if (Platform.isAndroid) {
      final c = resolveBlockingController();
      avail = await c.isAvailable();
      auth = await c.isAuthorized();
    } else if (IsleApplePlatform.isScreenTimeHost) {
      avail = await IosScreenTimeService.isAvailable();
      auth = await IosScreenTimeService.isAuthorized();
    }

    final schedules = BlockScheduleStore.loadAll();
    final active = ScheduleActiveService.activeSchedulesNow();

    return BlockFocusStatus(
      osAuthorized: auth,
      osAvailable: avail,
      hasApps: ExternalAppShieldStore.hasSelection,
      appCount: ExternalAppShieldStore.applicationCount,
      hasSchedule: schedules.any((s) => s.slots.isNotEmpty),
      scheduleCount: schedules.length,
      masterOn: BlockScheduleStore.masterEnabled,
      scheduleActiveNow: active.isNotEmpty,
      activeScheduleCount: active.length,
    );
  }

  /// 평일·주말 21:00–07:00 — Instagram·SNS 앱 자체 차단
  static Future<BlockSchedule> ensureNightSnsSchedule() async {
    await BlockScheduleStore.ensureOpen();
    await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);
    await ExternalAppShieldStore.setSyncWithBlockSchedule(true);

    const name = 'SNS 야간 차단';
    final existing = BlockScheduleStore.loadAll().where((s) => s.name == name).firstOrNull;

    final slots = <ScheduleSlot>[];
    for (var d = 0; d < 7; d++) {
      slots.add(ScheduleSlot(day: d, startMinute: 21 * 60, endMinute: 7 * 60));
    }

    final schedule = (existing ?? await BlockScheduleStore.create(name: name)).copyWith(
      enabled: true,
      slots: slots,
      domains: BlockSchedule.defaultYoutubeDomains,
    );
    await BlockScheduleStore.upsert(schedule);
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    return schedule;
  }

  /// 권한 → 앱 피커 → 야간 스케줄 → OS 동기화
  static Future<BlockSetupResult> runInstagramBlockSetup() async {
    if (!IsleApplePlatform.isNativeBlockHost) {
      return BlockSetupResult.failed('이 기기에서는 앱 차단을 지원하지 않아요');
    }

    if (Platform.isAndroid) {
      if (!await AppInterventionService.ensureAuthorized()) {
        return BlockSetupResult.deniedAndroid();
      }
    } else {
      if (!await IosScreenTimeService.isAvailable()) {
        return BlockSetupResult.failed('Screen Time 브리지 없음 — Family Controls capability 확인');
      }
      await IosScreenTimeService.requestAuthorization();
      if (await IosScreenTimeService.authorizationStatus() != ScreenTimeAuthStatus.approved) {
        return BlockSetupResult.denied();
      }
    }

    final pick = await AppInterventionService.pickApps();
    if (pick == null || pick.applicationCount == 0 && pick.categoryCount == 0) {
      return BlockSetupResult.cancelled();
    }

    await ExternalAppShieldStore.savePickResult(
      encoded: pick.encoded,
      applicationCount: pick.applicationCount,
      categoryCount: pick.categoryCount,
    );
    await ExternalAppShieldStore.setSyncWithBlockSchedule(true);
    await AppInterventionService.applySavedAppShield();

    final schedule = await ensureNightSnsSchedule();

    await ScheduleScreenTimeService.pickForSchedule(schedule.id);

    return BlockSetupResult.success(
      apps: pick.applicationCount,
      categories: pick.categoryCount,
      scheduleName: schedule.name,
      scheduleId: schedule.id,
    );
  }
}

class BlockSetupResult {
  const BlockSetupResult._({
    required this.ok,
    this.message,
    this.apps = 0,
    this.categories = 0,
    this.scheduleName,
    this.scheduleId,
    this.denied = false,
    this.deniedAndroid = false,
    this.cancelled = false,
  });

  final bool ok;
  final String? message;
  final int apps;
  final int categories;
  final String? scheduleName;
  final String? scheduleId;
  final bool denied;
  final bool deniedAndroid;
  final bool cancelled;

  factory BlockSetupResult.success({
    required int apps,
    required int categories,
    required String scheduleName,
    required String scheduleId,
  }) =>
      BlockSetupResult._(
        ok: true,
        apps: apps,
        categories: categories,
        scheduleName: scheduleName,
        scheduleId: scheduleId,
        message: '앱 $apps개 · $scheduleName (21:00–07:00) 적용됨',
      );

  factory BlockSetupResult.failed(String msg) => BlockSetupResult._(ok: false, message: msg);

  factory BlockSetupResult.denied() => BlockSetupResult._(
        ok: false,
        denied: true,
        message: 'Screen Time 거부 — 설정 → 스크린 타임에서 Isle 허용',
      );

  factory BlockSetupResult.deniedAndroid() => BlockSetupResult._(
        ok: false,
        deniedAndroid: true,
        message: '접근성 차단 서비스가 꺼져 있어요 — 설정 → 접근성 → Isle 차단',
      );

  factory BlockSetupResult.cancelled() => BlockSetupResult._(
        ok: false,
        cancelled: true,
        message: '앱 선택을 취소했어요',
      );
}
