import 'dart:io' show Platform;

import '../block_schedule/block_schedule_enforcement_service.dart';
import '../block_schedule/block_schedule_store.dart';
import '../blocking/blocking_controller_provider.dart';
import '../blocking/blocking_controller.dart';
import '../platform/ios_screen_time_service.dart';
import '../platform/isle_apple_platform.dart';
import '../intervention/schedule_screen_time_store.dart';
import '../services/isle_app_log_service.dart';
import 'kakao_shorts_addiction_store.dart';
import 'kakao_shorts_preset_service.dart';

/// 포모도로 10분 휴식 — 카카오톡 OS 차단 (알림만으로는 부족)
class KakaoPomodoroBreakEnforcement {
  KakaoPomodoroBreakEnforcement._();

  static bool _breakShieldActive = false;

  static Future<void> syncOnResume() async {
    await KakaoShortsAddictionStore.ensureOpen();
    if (KakaoShortsAddictionStore.isOnBreak) {
      await onBreakStarted();
    } else if (_breakShieldActive) {
      await onBreakEnded();
    }
  }

  static Future<void> onBreakStarted() async {
    if (_breakShieldActive) return;
    final encoded = await _kakaoScreenTimeEncoded();
    if (encoded == null || encoded.isEmpty) {
      IsleAppLogService.log(
        'Kakao pomodoro break: Screen Time에 카카오톡 미선택 — 휴식 차단 스킵',
        level: IsleLogLevel.warn,
      );
      return;
    }

    var ok = false;
    if (IsleApplePlatform.isScreenTimeHost) {
      ok = await IosScreenTimeService.applyAppShield(encoded: encoded);
    } else if (Platform.isAndroid) {
      final csv = encoded.contains('kakao') ? encoded : 'com.kakao.talk';
      final c = resolveBlockingController();
      ok = await c.applyAppShield(
        BlockSelection(
          platform: 'android',
          encoded: csv,
          appCount: csv.split(',').where((p) => p.trim().isNotEmpty).length,
        ),
      );
    }
    if (ok) {
      _breakShieldActive = true;
      IsleAppLogService.log('Kakao pomodoro break shield ON');
    }
  }

  static Future<void> onBreakEnded() async {
    if (!_breakShieldActive) return;
    _breakShieldActive = false;
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    IsleAppLogService.log('Kakao pomodoro break shield OFF');
  }

  static Future<String?> _kakaoScreenTimeEncoded() async {
    await BlockScheduleStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    final schedule = BlockScheduleStore.loadAll()
        .where((s) => s.name == KakaoShortsPresetService.microRefillScheduleName)
        .firstOrNull;
    if (schedule == null) return null;
    return ScheduleScreenTimeStore.encodedFor(schedule.id);
  }
}
