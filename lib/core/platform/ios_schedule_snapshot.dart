import 'dart:convert';

import 'package:flutter/services.dart';

import '../block_schedule/block_schedule_store.dart';
import '../block_schedule/models/block_schedule.dart';
import '../block_schedule/models/schedule_slot.dart';
import '../block_schedule/models/schedule_enforcement_mode.dart';
import '../block_schedule/schedule_enforcement_policy.dart';
import '../services/isle_app_log_service.dart';

/// App Group `schedule_snapshot_v1.json` — BGTask / DeviceActivity 확장용 (6VPN 패턴).
class IosScheduleSnapshot {
  IosScheduleSnapshot._();

  static const _channel = MethodChannel('com.isle.app/screen_time');
  static const fileName = 'schedule_snapshot_v1.json';

  static Future<void> writeNow() async {
    try {
      final payload = _buildPayload();
      await _channel.invokeMethod<void>('writeScheduleSnapshot', {
        'json': jsonEncode(payload),
      });
    } catch (e, st) {
      IsleAppLogService.log(
        'IosScheduleSnapshot.writeNow failed: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
    }
  }

  static Map<String, dynamic> _buildPayload() {
    final now = DateTime.now();
    final schedules = BlockScheduleStore.loadAll();
    final shieldIds = ScheduleEnforcementPolicy.shieldSchedulesNow(now).map((e) => e.id).toList();
    return {
      'version': 1,
      'writtenAtMs': now.millisecondsSinceEpoch,
      'masterEnabled': BlockScheduleStore.masterEnabled,
      'activeScheduleIds': shieldIds,
      'shieldDomains': ScheduleEnforcementPolicy.mergedDomainsForShieldNow(now),
      'schedules': schedules.map(_scheduleMap).toList(),
    };
  }

  static Map<String, dynamic> _scheduleMap(BlockSchedule s) => {
        'id': s.id,
        'enabled': s.enabled,
        'locked': s.locked,
        'enforcementMode': s.enforcementMode.storageKey,
        'slots': s.slots.map(_slotMap).toList(),
        'domains': s.domains,
      };

  static Map<String, dynamic> _slotMap(ScheduleSlot slot) => {
        'day': slot.day,
        'startMinute': slot.startMinute,
        'endMinute': slot.endMinute,
      };
}
