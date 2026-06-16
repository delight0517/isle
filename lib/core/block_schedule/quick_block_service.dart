import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../intervention/external_app_shield_store.dart';
import '../intervention/schedule_screen_time_store.dart';
import '../services/isle_local_data_sync.dart';
import '../services/isle_user_defaults.dart';
import 'block_schedule_enforcement_service.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
/// 6VPN Quick Block — 프리셋 스케줄 + 타이머 세션 (조기 취소 없음).
class QuickBlockService {
  QuickBlockService._();

  static const presetScheduleId = '__isle_quick_block__';
  static const _boxName = 'isle_quick_block';
  static const _sessionsKey = 'sessions_v1';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static List<QuickBlockSession> loadSessions() {
    final raw = _box?.get(_sessionsKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => QuickBlockSession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveSessions(List<QuickBlockSession> list) async {
    await _box!.put(_sessionsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static Future<void> restoreSessionsFromJson(List<dynamic> raw) async {
    await ensureOpen();
    final sessions = raw
        .whereType<Map>()
        .map((e) => QuickBlockSession.fromJson(Map<String, dynamic>.from(e)))
        .where((s) => s.endsAt.isAfter(DateTime.now()))
        .toList();
    if (sessions.isEmpty) return;
    await _saveSessions(sessions);
  }

  static List<QuickBlockSession> activeSessions([DateTime? at]) {
    final now = at ?? DateTime.now();
    return loadSessions().where((s) => s.endsAt.isAfter(now)).toList();
  }

  static bool get hasActive => activeSessions().isNotEmpty;

  /// 1 · 3 · 6 · 11 · 24 시간
  static Future<void> pruneExpired() async {
    await ensureOpen();
    final now = DateTime.now();
    final all = loadSessions();
    final kept = all.where((s) => s.endsAt.isAfter(now)).toList();
    if (kept.length != all.length) await _saveSessions(kept);
  }

  static Future<void> start({required int hours}) async {
    await ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    await BlockScheduleStore.ensureOpen();
    await _ensurePresetSchedule();
    await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);
    await ExternalAppShieldStore.setSyncWithBlockSchedule(true);

    final ends = DateTime.now().add(Duration(hours: hours));
    final sessions = loadSessions()
      ..add(QuickBlockSession(
        id: 'qb_${ends.millisecondsSinceEpoch}',
        endsAt: ends,
        hours: hours,
      ));
    await _saveSessions(sessions);
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
  }

  static Future<void> _ensurePresetSchedule() async {
    final list = BlockScheduleStore.loadAll();
    if (list.any((s) => s.id == presetScheduleId)) return;
    list.add(
      const BlockSchedule(
        id: presetScheduleId,
        name: '빠른 차단',
        enabled: false,
        slots: [],
      ),
    );
    await BlockScheduleStore.saveAll(list);
  }
}

class QuickBlockSession {
  const QuickBlockSession({
    required this.id,
    required this.endsAt,
    required this.hours,
  });

  final String id;
  final DateTime endsAt;
  final int hours;

  Map<String, dynamic> toJson() => {
        'id': id,
        'endsAt': endsAt.toIso8601String(),
        'hours': hours,
      };

  factory QuickBlockSession.fromJson(Map<String, dynamic> j) => QuickBlockSession(
        id: j['id'] as String? ?? '',
        endsAt: DateTime.tryParse(j['endsAt'] as String? ?? '') ?? DateTime.now(),
        hours: (j['hours'] as num?)?.toInt() ?? 1,
      );
}
