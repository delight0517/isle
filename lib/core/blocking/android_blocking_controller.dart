import 'package:flutter/services.dart';

import '../services/isle_app_log_service.dart';
import 'blocking_controller.dart';

/// Android 구현 — AccessibilityService(앱 차단) + VpnService(웹 차단) 기반.
///
/// 네이티브 채널 `com.isle.app/blocking` — Kotlin [BlockingPlugin] 과 1:1.
/// 미구현·오류 시 graceful no-op.
/// (예: 'com.instagram.android,com.zhiliaoapp.musically').
class AndroidBlockingController implements BlockingController {
  const AndroidBlockingController();

  static const _channel = MethodChannel('com.isle.app/blocking');

  @override
  String get platformLabel => 'Android 차단';

  @override
  BlockingCapabilities get capabilities => const BlockingCapabilities(
        // 앱=접근성, 웹=로컬 VpnService DNS 필터. 둘 다 OS 강제가 아닌 보조(우회 가능) — 정직히 표기.
        appBlock: BlockEnforcement.bestEffort,
        webBlock: BlockEnforcement.bestEffort,
        scheduleLock: BlockEnforcement.bestEffort,
        canPreventUninstall: false,
        note: '앱 차단은 접근성, 웹사이트 차단은 로컬 VPN(DNS 필터) 기반 보조 차단입니다. '
            'iOS Screen Time 처럼 OS 가 강제하지 않으므로 권한을 끄거나 DoH 브라우저를 쓰면 우회될 수 있어요.',
      );

  /// 네이티브 미존재(=Phase 1 미구현)면 true 로 graceful-no-op 처리.
  Future<T> _guard<T>(Future<T> Function() body, T fallback) async {
    try {
      return await body();
    } on MissingPluginException {
      // 네이티브 BlockingPlugin 아직 없음 — 조용히 미지원 반환.
      return fallback;
    } catch (e, st) {
      IsleAppLogService.log('AndroidBlockingController: $e',
          level: IsleLogLevel.warn, stack: st);
      return fallback;
    }
  }

  @override
  Future<bool> isAvailable() =>
      _guard(() async => await _channel.invokeMethod<bool>('isAvailable') == true, false);

  @override
  Future<ScreenTimeAuthStatus> authorizationStatus() => _guard(() async {
        final raw = await _channel.invokeMethod<String>('authorizationStatus');
        switch (raw) {
          case 'approved':
            return ScreenTimeAuthStatus.approved;
          case 'denied':
            return ScreenTimeAuthStatus.denied;
          case 'notDetermined':
            return ScreenTimeAuthStatus.notDetermined;
          default:
            return ScreenTimeAuthStatus.unavailable;
        }
      }, ScreenTimeAuthStatus.unavailable);

  @override
  Future<BlockingAuthResult> requestAuthorization() => _guard(() async {
        final raw = await _channel.invokeMethod<dynamic>('requestAuthorization');
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          return BlockingAuthResult(
            ok: map['ok'] == true,
            status: map['ok'] == true
                ? ScreenTimeAuthStatus.approved
                : ScreenTimeAuthStatus.denied,
            code: map['code']?.toString(),
            message: map['message']?.toString(),
          );
        }
        return BlockingAuthResult.unsupported;
      }, BlockingAuthResult.unsupported);

  @override
  Future<bool> isAuthorized() async =>
      (await authorizationStatus()) == ScreenTimeAuthStatus.approved;

  @override
  Future<BlockSelection?> pickTargets({
    BlockSelection? existing,
    bool additiveOnly = false,
  }) =>
      _guard<BlockSelection?>(() async {
        final raw = await _channel.invokeMethod<dynamic>('pickApps', {
          if (existing != null) 'existing': existing.encoded,
          'additiveOnly': additiveOnly,
        });
        if (raw is! Map) return null;
        final map = Map<String, dynamic>.from(raw);
        final encoded = map['encoded'] as String? ?? '';
        if (encoded.isEmpty) return null;
        return BlockSelection(
          platform: 'android',
          encoded: encoded,
          appCount: (map['appCount'] as num?)?.toInt() ?? 0,
        );
      }, null);

  @override
  Future<bool> applyAppShield(BlockSelection selection) {
    if (selection.platform != 'android' || selection.isEmpty) {
      return Future.value(false);
    }
    return _guard(
      () async =>
          await _channel.invokeMethod<bool>('applyAppShield', {'packages': selection.encoded}) ==
          true,
      false,
    );
  }

  @override
  Future<void> clearAppShield() =>
      _guard(() => _channel.invokeMethod<void>('clearAppShield'), null);

  @override
  Future<bool> applyWebBlock(List<String> domains) {
    if (domains.isEmpty) return Future.value(false);
    return _guard(
      () async =>
          await _channel.invokeMethod<bool>('applyWebBlock', {'domains': domains}) == true,
      false,
    );
  }

  @override
  Future<void> clearWebBlock() =>
      _guard(() => _channel.invokeMethod<void>('clearWebBlock'), null);

  @override
  Future<void> ensureInAppWebViewUnblocked() async {
    // Android 인앱 WebView 는 OS 도메인 필터에 막히지 않음 — no-op.
  }

  @override
  Future<void> openSystemSettings() =>
      _guard(() => _channel.invokeMethod<void>('openSettings'), null);

  @override
  Future<bool> isBatteryOptimizationIgnored() => _guard(
        () async =>
            await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored') == true,
        true,
      );

  @override
  Future<void> openBatteryOptimizationSettings() =>
      _guard(() => _channel.invokeMethod<void>('openBatterySettings'), null);

  @override
  Future<void> openManufacturerBatterySettings() =>
      _guard(() => _channel.invokeMethod<void>('openManufacturerBatterySettings'), null);
}
