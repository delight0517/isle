import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../platform/isle_apple_platform.dart';
import '../services/isle_app_log_service.dart';
import '../block_schedule/schedule_app_limit_sync_service.dart';
import '../block_schedule/models/schedule_slot.dart';
import 'models/app_usage_limit_rule.dart';

/// iOS/macOS DeviceActivity + Android Usage Stats — 외부 앱 일일 한도
class PlatformAppLimitService {
  PlatformAppLimitService._();

  static const _channel = MethodChannel('com.isle.app/app_limits');

  static Future<bool> isSupported() async {
    if (!IsleApplePlatform.isScreenTimeHost && !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestAuthorization() async {
    try {
      return await _channel.invokeMethod<bool>('requestAuthorization') == true;
    } catch (e, st) {
      IsleAppLogService.log('app_limits auth: $e', level: IsleLogLevel.error, stack: st);
      return false;
    }
  }

  static Future<bool> hasUsageAccess() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccess') == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openUsageAccessSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openUsageAccessSettings');
    } catch (_) {}
  }

  static Future<bool> syncRule(AppUsageLimitRule rule) async {
    if (!rule.enabled) {
      await removeRule(rule.id);
      return true;
    }
    try {
      final ok = await _channel.invokeMethod<bool>('registerLimit', {
        'id': rule.id,
        'label': rule.label,
        'minutes': rule.minutesPerWindow,
        'windowMinutes': rule.windowMinutes,
        'iosEncoded': rule.iosFamilyActivityEncoded ?? '',
        'androidPackage': rule.androidPackageName ?? '',
        'interventionTitle': rule.interventionTitle,
        'interventionBody': rule.interventionBody,
        'scope': 'always',
      });
      return ok == true;
    } catch (e, st) {
      IsleAppLogService.log('registerLimit ${rule.id}: $e', level: IsleLogLevel.error, stack: st);
      return false;
    }
  }

  /// [scope] `in_slot` | `outside_slot` — 스케줄 슬롯 기준 DeviceActivity
  static Future<bool> syncRuleScoped({
    required AppUsageLimitRule rule,
    required String scope,
    required List<ScheduleSlot> slots,
  }) async {
    if (!rule.enabled) {
      await removeRule(rule.id);
      return true;
    }
    try {
      final ok = await _channel.invokeMethod<bool>('registerLimit', {
        'id': rule.id,
        'label': rule.label,
        'minutes': rule.minutesPerWindow,
        'windowMinutes': rule.windowMinutes,
        'iosEncoded': rule.iosFamilyActivityEncoded ?? '',
        'androidPackage': rule.androidPackageName ?? '',
        'interventionTitle': rule.interventionTitle,
        'interventionBody': rule.interventionBody,
        'scope': scope,
        'slots': ScheduleAppLimitSyncService.slotsToJson(slots),
      });
      return ok == true;
    } catch (e, st) {
      IsleAppLogService.log('registerLimit scoped ${rule.id}: $e', level: IsleLogLevel.error, stack: st);
      return false;
    }
  }

  static Future<void> removeRule(String id) async {
    try {
      await _channel.invokeMethod<void>('unregisterLimit', {'id': id});
    } catch (_) {}
  }

  static Future<int> usageMinutesToday({String? androidPackage, String? ruleId}) async {
    try {
      final v = await _channel.invokeMethod<int>('usageMinutesToday', {
        if (androidPackage != null) 'androidPackage': androidPackage,
        if (ruleId != null) 'ruleId': ruleId,
      });
      return v ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> syncAllRules(List<AppUsageLimitRule> rules) async {
    for (final r in rules) {
      if (r.enabled) {
        await syncRule(r);
      } else {
        await removeRule(r.id);
      }
    }
  }

}
