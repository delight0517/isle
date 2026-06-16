import '../platform/ios_screen_time_service.dart';
import '../platform/isle_apple_platform.dart';
import 'blocking_controller.dart';

/// iOS·macOS 구현 — 기존 [IosScreenTimeService] 위임 래퍼.
///
/// ⚠️ 행동 변화 0: 모든 메서드는 검증된 기존 Screen Time 경로를 그대로 호출한다.
/// 스케줄 강제(다중 스케줄·DeviceActivity·App Group 스냅샷)는 iOS 고유 인코딩이 무거워
/// 여전히 `BlockScheduleEnforcementService` 가 직접 오케스트레이션한다 (Phase 1에서 점진 이관).
class IosBlockingController implements BlockingController {
  const IosBlockingController();

  @override
  String get platformLabel => IsleApplePlatform.screenTimeSettingsLabel;

  @override
  BlockingCapabilities get capabilities => const BlockingCapabilities(
        appBlock: BlockEnforcement.osEnforced,
        webBlock: BlockEnforcement.osEnforced,
        scheduleLock: BlockEnforcement.osEnforced,
        // iOS 도 앱 삭제 자체는 못 막지만 Screen Time 우회 난이도가 높음.
        canPreventUninstall: false,
        note: 'Screen Time(FamilyControls)으로 OS 레벨 차단. 우회가 어렵습니다.',
      );

  @override
  Future<bool> isAvailable() => IosScreenTimeService.isAvailable();

  @override
  Future<ScreenTimeAuthStatus> authorizationStatus() =>
      IosScreenTimeService.authorizationStatus();

  @override
  Future<BlockingAuthResult> requestAuthorization() async {
    final r = await IosScreenTimeService.requestAuthorizationDetailed();
    return BlockingAuthResult(
      ok: r.ok,
      status: r.status,
      code: r.code,
      message: r.message,
    );
  }

  @override
  Future<bool> isAuthorized() => IosScreenTimeService.isAuthorized();

  @override
  Future<BlockSelection?> pickTargets({
    BlockSelection? existing,
    bool additiveOnly = false,
  }) async {
    final res = await IosScreenTimeService.pickFamilyActivitySelection(
      existingEncoded: existing?.encoded,
      additiveOnly: additiveOnly,
    );
    if (res == null) return null;
    return BlockSelection(
      platform: 'ios',
      encoded: res.encoded,
      appCount: res.applicationCount,
      categoryCount: res.categoryCount,
    );
  }

  @override
  Future<bool> applyAppShield(BlockSelection selection) {
    if (selection.platform != 'ios' || selection.isEmpty) {
      return Future.value(false);
    }
    return IosScreenTimeService.applyAppShield(encoded: selection.encoded);
  }

  @override
  Future<void> clearAppShield() => IosScreenTimeService.clearScheduleEnforcement();

  @override
  Future<bool> applyWebBlock(List<String> domains) async {
    if (domains.isEmpty) return false;
    await IosScreenTimeService.applyMergedShield(domains);
    return true;
  }

  @override
  Future<void> clearWebBlock() => IosScreenTimeService.clearAllWebContentFilters();

  @override
  Future<void> ensureInAppWebViewUnblocked() =>
      IosScreenTimeService.ensureIsleYoutubeWebViewUnblocked();

  @override
  Future<void> openSystemSettings() => IosScreenTimeService.openScreenTimeSettings();

  @override
  Future<bool> isBatteryOptimizationIgnored() async => true;

  @override
  Future<void> openBatteryOptimizationSettings() async {}

  @override
  Future<void> openManufacturerBatterySettings() async {}
}
