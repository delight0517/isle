import 'package:flutter/services.dart';

import '../constants/app_release_info.dart';
import '../services/isle_app_log_service.dart';
import '../intervention/screen_time_persistence_service.dart';
import 'ios_family_activity_pick_result.dart';
import 'isle_apple_platform.dart';
import 'screen_time_auth_status.dart';

export 'ios_family_activity_pick_result.dart';
export 'screen_time_auth_status.dart';

/// `requestAuthorizationDetailed` 결과. 실패 시 [code]·[message]로 원인 분류.
class ScreenTimeAuthResult {
  const ScreenTimeAuthResult({
    required this.ok,
    required this.status,
    this.code,
    this.message,
  });

  final bool ok;
  final ScreenTimeAuthStatus status;

  /// simulator | canceled | conflict | invalidAccountType | network |
  /// passcodeRequired | restricted | unavailable | familyControlsUnknown |
  /// error_<NSError code> | missing_plugin | platform_unsupported
  final String? code;

  /// UI에 그대로 노출 가능한 한국어 사유 (Swift에서 분류 후 내려옴).
  final String? message;

  bool get isSimulator => code == 'simulator';
  bool get isDenied => status == ScreenTimeAuthStatus.denied;
  bool get isUnavailable =>
      code == 'unavailable' ||
      code == 'platform_unsupported' ||
      code == 'missing_plugin';
  bool get needsSettings =>
      isDenied || code == 'passcodeRequired' || code == 'restricted';
}

/// Apple Screen Time (FamilyControls) — iOS + macOS Safari·Chrome 등 시스템 차단
class IosScreenTimeService {
  IosScreenTimeService._();

  static const _channel = MethodChannel('com.isle.app/screen_time');

  static bool get isSupported => IsleApplePlatform.isScreenTimeHost;

  static Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      final v = await _channel.invokeMethod<bool>('isAvailable');
      return v == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool?> hasFamilyControlsEntitlement() async {
    if (!isSupported) return null;
    try {
      final v =
          await _channel.invokeMethod<bool>('hasFamilyControlsEntitlement');
      return v;
    } catch (_) {
      return null;
    }
  }

  static Future<ScreenTimeAuthStatus> authorizationStatus() async {
    if (!isSupported) return ScreenTimeAuthStatus.unavailable;
    try {
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
    } on MissingPluginException {
      return ScreenTimeAuthStatus.unavailable;
    } catch (_) {
      return ScreenTimeAuthStatus.unavailable;
    }
  }

  /// 6VPN `authorize()` — 시스템 UI 후 실제 `.approved` 여부 반환
  static Future<bool> requestAuthorization() async {
    final detail = await requestAuthorizationDetailed();
    return detail.ok;
  }

  /// 실패 사유까지 같이 받는 버전 — UI가 시뮬레이터·iCloud·거부 등을 분류해 안내할 수 있음.
  static Future<ScreenTimeAuthResult> requestAuthorizationDetailed() async {
    if (!isSupported) {
      return const ScreenTimeAuthResult(
        ok: false,
        status: ScreenTimeAuthStatus.unavailable,
        code: 'platform_unsupported',
        message: '이 기기에서는 Screen Time을 쓸 수 없어요.',
      );
    }
    try {
      final entitlement = await hasFamilyControlsEntitlement();
      if (entitlement == false) {
        final status = await authorizationStatus();
        return ScreenTimeAuthResult(
          ok: false,
          status: status,
          code: 'entitlement_missing',
          message:
              '앱 서명에 Family Controls 권한이 빠져 있어요. Apple Developer에서 Capability를 켜고 프로비저닝 프로파일을 다시 발급한 뒤 재설치해 주세요.',
        );
      }
      final raw =
          await _channel.invokeMethod<dynamic>('requestAuthorizationDetailed');
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        var ok = map['ok'] == true;
        final statusStr = map['status']?.toString();
        var status = _parseStatus(statusStr) ?? await authorizationStatus();
        var code = map['code']?.toString();
        var message = map['message']?.toString();

        if (!ok && code == 'error_4099') {
          // iOS helper(XPC) restart race: 짧게 대기 후 1회 재시도.
          await Future<void>.delayed(const Duration(milliseconds: 450));
          try {
            final retryRaw = await _channel
                .invokeMethod<dynamic>('requestAuthorizationDetailed');
            if (retryRaw is Map) {
              final retryMap = Map<String, dynamic>.from(retryRaw);
              ok = retryMap['ok'] == true;
              status = _parseStatus(retryMap['status']?.toString()) ??
                  await authorizationStatus();
              code = retryMap['code']?.toString();
              message = retryMap['message']?.toString();
              IsleAppLogService.log(
                'Screen Time auth retried after 4099: ok=$ok status=$status code=$code',
              );
            }
          } catch (e, st) {
            IsleAppLogService.log(
              'Screen Time auth retry after 4099 failed: $e',
              level: IsleLogLevel.error,
              stack: st,
            );
          }
        }

        final res = ScreenTimeAuthResult(
            ok: ok, status: status, code: code, message: message);
        IsleAppLogService.log(
          'Screen Time auth: status=$status ok=$ok code=${res.code} msg=${res.message}',
        );
        if (ok) {
          await ScreenTimePersistenceService.onAuthorizationGranted();
        }
        return res;
      }
      final status = await authorizationStatus();
      return ScreenTimeAuthResult(
        ok: status == ScreenTimeAuthStatus.approved,
        status: status,
      );
    } on MissingPluginException catch (e, st) {
      IsleAppLogService.log(
        'Screen Time auth missing plugin: ${e.message}',
        level: IsleLogLevel.error,
        stack: st,
      );
      // 구 버전 네이티브 — 단순 bool API로 폴백.
      return _requestAuthorizationLegacy();
    } on PlatformException catch (e, st) {
      IsleAppLogService.log(
        'Screen Time auth failed: ${e.code} ${e.message}',
        level: IsleLogLevel.error,
        stack: st,
      );
      final status = await authorizationStatus();
      return ScreenTimeAuthResult(
        ok: false,
        status: status,
        code: e.code,
        message: e.message ?? '권한 요청에 실패했어요.',
      );
    } catch (e, st) {
      IsleAppLogService.log('Screen Time auth failed: $e',
          level: IsleLogLevel.error, stack: st);
      final status = await authorizationStatus();
      return ScreenTimeAuthResult(
        ok: false,
        status: status,
        code: 'unknown',
        message: '권한 요청 중 오류가 발생했어요: $e',
      );
    }
  }

  static Future<ScreenTimeAuthResult> _requestAuthorizationLegacy() async {
    try {
      await _channel.invokeMethod<bool>('requestAuthorization');
    } catch (_) {}
    final status = await authorizationStatus();
    final ok = status == ScreenTimeAuthStatus.approved;
    if (ok) {
      await ScreenTimePersistenceService.onAuthorizationGranted();
    }
    return ScreenTimeAuthResult(
      ok: ok,
      status: status,
    );
  }

  static ScreenTimeAuthStatus? _parseStatus(String? raw) {
    switch (raw) {
      case 'approved':
        return ScreenTimeAuthStatus.approved;
      case 'denied':
        return ScreenTimeAuthStatus.denied;
      case 'notDetermined':
        return ScreenTimeAuthStatus.notDetermined;
      case 'unavailable':
        return ScreenTimeAuthStatus.unavailable;
      default:
        return null;
    }
  }

  static Future<bool> isAuthorized() async {
    final s = await authorizationStatus();
    return s == ScreenTimeAuthStatus.approved;
  }

  /// 활성 스케줄 도메인 병합 → OS web filter (`IsleSchedule` 스토어)
  static Future<void> applyMergedShield(List<String> domains) async {
    if (!isSupported || domains.isEmpty) return;
    try {
      await _channel
          .invokeMethod<bool>('applyScheduleWebDomains', {'domains': domains});
    } catch (e, st) {
      IsleAppLogService.log('applyScheduleWebDomains: $e',
          level: IsleLogLevel.error, stack: st);
    }
  }

  static Future<bool> applyAppShield({required String encoded}) async {
    if (!isSupported || encoded.isEmpty) return false;
    try {
      final v = await _channel
          .invokeMethod<bool>('applyAppShield', {'encoded': encoded});
      return v == true;
    } catch (e, st) {
      IsleAppLogService.log('applyAppShield: $e',
          level: IsleLogLevel.error, stack: st);
      return false;
    }
  }

  /// "올나이트 록다운" — 개별 앱 선택과 별개로 설치된 앱 전체를 카테고리
  /// 단위로 쉴드한다. 켜져 있는 록다운 스케줄이 하나도 없으면 `enable:false`로
  /// 호출해 반드시 꺼야 한다(2026-[REDACTED] 신설).
  static Future<bool> applyLockdownShield(
    bool enable, {
    String? allowedAppsEncoded,
  }) async {
    if (!isSupported) return false;
    try {
      final v = await _channel.invokeMethod<bool>('applyLockdownShield', {
        'enable': enable,
        if (allowedAppsEncoded != null)
          'allowedAppsEncoded': allowedAppsEncoded,
      });
      return v == true;
    } catch (e, st) {
      IsleAppLogService.log('applyLockdownShield: $e',
          level: IsleLogLevel.error, stack: st);
      return false;
    }
  }

  static Future<void> clearScheduleEnforcement() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('clearScheduleEnforcement');
    } catch (_) {}
  }

  static Future<void> stopShield() async {
    await clearScheduleEnforcement();
  }

  static Future<void> saveScheduleSelection({
    required String scheduleId,
    required String encoded,
    String? bundleId,
  }) async {
    if (!isSupported || scheduleId.isEmpty || encoded.isEmpty) return;
    try {
      await _channel.invokeMethod<bool>('saveScheduleSelection', {
        'scheduleId': scheduleId,
        'encoded': encoded,
        if (bundleId != null && bundleId.isNotEmpty) 'bundleId': bundleId,
      });
    } catch (e, st) {
      IsleAppLogService.log('saveScheduleSelection: $e',
          level: IsleLogLevel.warn, stack: st);
    }
  }

  static Future<void> saveGlobalFallbackSelection(String encoded) async {
    if (!isSupported || encoded.isEmpty) return;
    try {
      await _channel.invokeMethod<bool>(
          'saveGlobalFallbackSelection', {'encoded': encoded});
    } catch (_) {}
  }

  static Future<bool> applyActiveScheduleShield({
    required List<String> scheduleIds,
    required List<String> domains,
    String? fallbackEncoded,
    bool lockdownActive = false,
    String? lockdownAllowedAppsEncoded,
  }) async {
    if (!isSupported) return false;
    try {
      final v = await _channel.invokeMethod<bool>('applyActiveScheduleShield', {
        'scheduleIds': scheduleIds,
        'domains': domains,
        'lockdownActive': lockdownActive,
        if (lockdownAllowedAppsEncoded != null)
          'lockdownAllowedAppsEncoded': lockdownAllowedAppsEncoded,
        if (fallbackEncoded != null && fallbackEncoded.isNotEmpty)
          'fallbackEncoded': fallbackEncoded,
      });
      return v == true;
    } catch (e, st) {
      IsleAppLogService.log('applyActiveScheduleShield: $e',
          level: IsleLogLevel.error, stack: st);
      return false;
    }
  }

  static Future<void> stopScheduleDeviceActivities() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('stopScheduleDeviceActivities');
    } catch (_) {}
  }

  static Future<bool> syncShieldFromSnapshot() async {
    if (!isSupported) return false;
    try {
      final v = await _channel.invokeMethod<bool>('syncShieldFromSnapshot');
      return v == true;
    } catch (e, st) {
      IsleAppLogService.log('syncShieldFromSnapshot: $e',
          level: IsleLogLevel.warn, stack: st);
      return false;
    }
  }

  static Future<IosFamilyActivityPickResult?> pickFamilyActivitySelection({
    String? existingEncoded,
    bool additiveOnly = false,
    String purpose = 'block',
  }) async {
    if (!isSupported) return null;
    try {
      final raw = await _channel.invokeMethod<dynamic>(
        'pickFamilyActivitySelection',
        <String, dynamic>{
          if (existingEncoded != null && existingEncoded.isNotEmpty)
            'existingEncoded': existingEncoded,
          'additiveOnly': additiveOnly,
          'purpose': purpose,
        },
      );
      if (raw == null) return null;
      if (raw is! Map) return null;
      return IosFamilyActivityPickResult.fromMap(
          Map<String, dynamic>.from(raw));
    } catch (e, st) {
      IsleAppLogService.log('pickFamilyActivitySelection: $e',
          level: IsleLogLevel.error, stack: st);
      return null;
    }
  }

  static Future<void> openScreenTimeSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('openSettings');
    } catch (_) {}
  }

  /// OS `webContent.blockedByFilter`는 Isle WKWebView까지 막음 — 적용하지 않고 해제만.
  @Deprecated(
      'Use clearAllWebContentFilters + app shield / Safari Content Blocker')
  static Future<bool> applyYoutubeWebDomainBlock() async {
    await clearAllWebContentFilters();
    return false;
  }

  static Future<void> clearWebContentBlock() async {
    await clearAllWebContentFilters();
  }

  /// Manual·Schedule 스토어의 youtube.com OS 차단 해제 (Isle WebView 복구).
  static Future<void> clearAllWebContentFilters() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('clearAllWebContentFilters');
    } catch (e, st) {
      IsleAppLogService.log('clearAllWebContentFilters: $e',
          level: IsleLogLevel.error, stack: st);
    }
  }

  /// 앱 시작 시 1회 — 예전 설정으로 WebView가 막혀 있으면 해제.
  static Future<void> ensureIsleYoutubeWebViewUnblocked() async {
    await clearAllWebContentFilters();
  }

  static String buildSupportCode({required String phase, String? detail}) {
    final sanitizedDetail = (detail ?? 'unknown')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final now = DateTime.now();
    final stamp =
        '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'ISLE-ST-$phase-${sanitizedDetail.isEmpty ? 'unknown' : sanitizedDetail}-$stamp';
  }

  static String buildSupportCopyText({
    required String traceCode,
    required ScreenTimeAuthResult result,
  }) {
    return [
      '[ScreenTimeSetup]',
      'trace=$traceCode',
      'app=${AppReleaseInfo.label}',
      'status=${result.status.name}',
      'code=${result.code ?? 'n/a'}',
      'message=${result.message ?? 'n/a'}',
      'hint=/settings/app-log',
    ].join('\n');
  }
}
