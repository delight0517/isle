import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../intervention/app_usage_limit_store.dart';
import '../intervention/external_app_shield_store.dart';
import '../services/isle_app_log_service.dart';

/// macOS — 실행 중 앱 display name 종료 (6VPN Blocker · Focusgate 패턴)
class MacAppBlockService {
  MacAppBlockService._();

  static const _channel = MethodChannel('com.isle.app/mac_app_block');

  static bool get isSupported => Platform.isMacOS;

  static Future<bool> setTargets(List<String> displayNames) async {
    if (!isSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('setTargets', {
        'targets': displayNames,
      });
      return ok == true;
    } catch (e, st) {
      IsleAppLogService.log('mac_app_block setTargets: $e', level: IsleLogLevel.error, stack: st);
      return false;
    }
  }

  static Future<void> clearTargets() => setTargets(const []);

  /// 활성 스케줄 + 앱 한도 규칙 → Mac terminate 목록
  static Future<void> syncFromPolicy({
    required bool scheduleBlockingActive,
  }) async {
    if (!isSupported) return;
    if (!scheduleBlockingActive &&
        !ExternalAppShieldStore.shieldMarkedActive &&
        !ExternalAppShieldStore.syncWithBlockSchedule) {
      await clearTargets();
      return;
    }

    final names = <String>{};
    if (scheduleBlockingActive && ExternalAppShieldStore.syncWithBlockSchedule) {
      names.addAll(_defaultSnsKillNames);
    }
    for (final rule in AppUsageLimitStore.loadRules()) {
      if (rule.enabled) names.add(rule.label);
    }
    await setTargets(names.toList()..sort());
  }

  static const _defaultSnsKillNames = [
    'Instagram',
    'TikTok',
    'YouTube',
    'X',
    'Facebook',
    'Snapchat',
  ];
}
