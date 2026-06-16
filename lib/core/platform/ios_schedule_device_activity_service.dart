import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../block_schedule/block_schedule_store.dart';
import '../block_schedule/models/block_schedule.dart';
import '../block_schedule/models/schedule_enforcement_mode.dart';
import '../block_schedule/models/schedule_slot.dart';
import '../block_schedule/schedule_enforcement_policy.dart';
import '../services/isle_app_log_service.dart';

/// Runner — 스케줄 슬롯 DeviceActivity 등록 (확장 임베드 시 경계에서 쉴드 동기화).
class IosScheduleDeviceActivityService {
  IosScheduleDeviceActivityService._();

  static const _channel = MethodChannel('com.isle.app/screen_time');

  static Future<void> syncMonitorsFromStore() async {
    if (!Platform.isIOS) return;
    try {
      final payload = _buildPayload();
      await _channel.invokeMethod<bool>('syncScheduleDeviceActivities', {
        'json': jsonEncode(payload),
      });
    } catch (e, st) {
      IsleAppLogService.log(
        'IosScheduleDeviceActivityService.sync failed: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
    }
  }

  static Map<String, dynamic> _buildPayload() {
    final schedules = ScheduleEnforcementPolicy.deviceActivitySchedules()
        .map(_scheduleMap)
        .toList();
    return {
      'version': 1,
      'masterEnabled': BlockScheduleStore.masterEnabled,
      'schedules': schedules,
    };
  }

  static Map<String, dynamic> _scheduleMap(BlockSchedule s) => {
        'id': s.id,
        'enabled': s.enabled,
        'enforcementMode': s.enforcementMode.storageKey,
        'slots': s.slots.map(_slotMap).toList(),
      };

  static Map<String, dynamic> _slotMap(ScheduleSlot slot) => {
        'day': slot.day,
        'startMinute': slot.startMinute,
        'endMinute': slot.endMinute,
      };
}
