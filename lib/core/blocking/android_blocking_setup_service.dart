import 'dart:io' show Platform;

import '../blocking/blocking_controller_provider.dart';

/// Android 차단 3종 권한 — 접근성 · 배터리 예외
class AndroidBlockingSetupStatus {
  const AndroidBlockingSetupStatus({
    required this.accessibilityOn,
    required this.batteryIgnored,
  });

  final bool accessibilityOn;
  final bool batteryIgnored;

  bool get isReady => accessibilityOn && batteryIgnored;

  int get completedSteps =>
      (accessibilityOn ? 1 : 0) + (batteryIgnored ? 1 : 0);
}

class AndroidBlockingSetupService {
  AndroidBlockingSetupService._();

  static Future<AndroidBlockingSetupStatus> load() async {
    if (!Platform.isAndroid) {
      return const AndroidBlockingSetupStatus(
        accessibilityOn: false,
        batteryIgnored: true,
      );
    }
    final c = resolveBlockingController();
    return AndroidBlockingSetupStatus(
      accessibilityOn: await c.isAuthorized(),
      batteryIgnored: await c.isBatteryOptimizationIgnored(),
    );
  }

  static Future<void> openAccessibilitySettings() =>
      resolveBlockingController().openSystemSettings();

  static Future<void> openBatterySettings() =>
      resolveBlockingController().openBatteryOptimizationSettings();

  static Future<void> openManufacturerBatterySettings() async {
    if (!Platform.isAndroid) return;
    await resolveBlockingController().openManufacturerBatterySettings();
  }
}
