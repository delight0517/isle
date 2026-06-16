import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'android_blocking_controller.dart';
import 'blocking_controller.dart';
import 'ios_blocking_controller.dart';

export 'blocking_controller.dart';

/// 현재 플랫폼에 맞는 [BlockingController] 단일 진입점.
///
/// 상위 코드는 `ref.read(blockingControllerProvider)` 만 호출하면 된다 —
/// 어떤 플랫폼인지 알 필요 없음. 이것이 [Bridge] 규칙의 핵심:
/// 차단 로직의 플랫폼 분기를 이 한 곳으로 격리한다.
final blockingControllerProvider =
    Provider<BlockingController>((ref) => resolveBlockingController());

/// Riverpod ref 없는 정적 서비스(예: `AppInterventionService`)에서 현재 플랫폼 컨트롤러 획득.
BlockingController resolveBlockingController() {
  if (Platform.isIOS || Platform.isMacOS) return const IosBlockingController();
  if (Platform.isAndroid) return const AndroidBlockingController();
  return const UnsupportedBlockingController();
}

/// [BlockSelection.platform] 태그용 현재 플랫폼 식별자 ('ios' | 'android' | 'unsupported').
String currentBlockingPlatform() {
  if (Platform.isIOS || Platform.isMacOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  return 'unsupported';
}

/// 데스크톱(Windows/Linux)·웹 등 차단 미지원 플랫폼 — 전 메서드 no-op.
class UnsupportedBlockingController implements BlockingController {
  const UnsupportedBlockingController();

  @override
  String get platformLabel => '차단 미지원 플랫폼';

  @override
  BlockingCapabilities get capabilities => const BlockingCapabilities(
        appBlock: BlockEnforcement.unsupported,
        webBlock: BlockEnforcement.unsupported,
        scheduleLock: BlockEnforcement.unsupported,
        canPreventUninstall: false,
        note: '이 플랫폼에서는 차단 기능을 제공하지 않습니다.',
      );

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<ScreenTimeAuthStatus> authorizationStatus() async =>
      ScreenTimeAuthStatus.unavailable;

  @override
  Future<BlockingAuthResult> requestAuthorization() async =>
      BlockingAuthResult.unsupported;

  @override
  Future<bool> isAuthorized() async => false;

  @override
  Future<BlockSelection?> pickTargets({
    BlockSelection? existing,
    bool additiveOnly = false,
  }) async =>
      null;

  @override
  Future<bool> applyAppShield(BlockSelection selection) async => false;

  @override
  Future<void> clearAppShield() async {}

  @override
  Future<bool> applyWebBlock(List<String> domains) async => false;

  @override
  Future<void> clearWebBlock() async {}

  @override
  Future<void> ensureInAppWebViewUnblocked() async {}

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<bool> isBatteryOptimizationIgnored() async => true;

  @override
  Future<void> openBatteryOptimizationSettings() async {}

  @override
  Future<void> openManufacturerBatterySettings() async {}
}
