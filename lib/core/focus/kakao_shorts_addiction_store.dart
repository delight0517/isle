import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../block_schedule/schedule_notification_service.dart';
import '../services/isle_app_log_service.dart';
import 'kakao_pomodoro_break_enforcement.dart';
import 'kakao_shorts_session.dart';

/// 카카오 쇼츠 — 세션 기록 · 30분 집중 / 10분 휴식 (포모도로)
class KakaoShortsAddictionStore {
  KakaoShortsAddictionStore._();

  static const _boxName = 'isle_kakao_shorts';
  static const _sessionsKey = 'sessions_v1';
  static const _pomodoroKey = 'pomodoro_enabled';
  static const _workSecKey = 'work_seconds_cycle';
  static const _breakUntilKey = 'break_until_ms';
  static const _openSessionKey = 'open_session_id';

  static const defaultWorkMinutes = 30;
  static const defaultBreakMinutes = 10;

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get _b {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('KakaoShortsAddictionStore.ensureOpen() first');
    return b;
  }

  static bool get pomodoroEnabled => _b.get(_pomodoroKey) == 'true';

  static Future<void> setPomodoroEnabled(bool v) async {
    await _b.put(_pomodoroKey, v ? 'true' : 'false');
    if (!v) {
      await _b.delete(_workSecKey);
      await _b.delete(_breakUntilKey);
      await ScheduleNotificationService.cancelPomodoroNotifications();
      unawaited(KakaoPomodoroBreakEnforcement.onBreakEnded());
    }
  }

  static int get workSecondsInCycle => int.tryParse(_b.get(_workSecKey) ?? '') ?? 0;

  static int? get breakUntilMs => int.tryParse(_b.get(_breakUntilKey) ?? '');

  static bool get isOnBreak {
    final until = breakUntilMs;
    if (until == null) return false;
    return DateTime.now().millisecondsSinceEpoch < until;
  }

  static Duration? get breakRemaining {
    final until = breakUntilMs;
    if (until == null) return null;
    final left = until - DateTime.now().millisecondsSinceEpoch;
    if (left <= 0) return null;
    return Duration(milliseconds: left);
  }

  static Future<void> _clearBreak() async {
    await _b.delete(_breakUntilKey);
    await _b.put(_workSecKey, '0');
    await ScheduleNotificationService.cancelPomodoroNotifications();
    unawaited(KakaoPomodoroBreakEnforcement.onBreakEnded());
  }

  static Future<void> tickPomodoro(int deltaSeconds) async {
    if (!pomodoroEnabled || deltaSeconds <= 0) return;
    if (isOnBreak) {
      if (breakRemaining == null) await _clearBreak();
      return;
    }
    final next = workSecondsInCycle + deltaSeconds;
    await _b.put(_workSecKey, '$next');
    if (next >= defaultWorkMinutes * 60) {
      final until = DateTime.now().add(const Duration(minutes: defaultBreakMinutes));
      await _b.put(_breakUntilKey, '${until.millisecondsSinceEpoch}');
      await _b.put(_workSecKey, '0');
      IsleAppLogService.log(
        'KakaoShorts pomodoro break started (${defaultBreakMinutes}m)',
      );
      unawaited(
        ScheduleNotificationService.notifyPomodoroBreakStarted(
          breakEndsAt: until,
          breakMinutes: defaultBreakMinutes,
        ),
      );
      unawaited(KakaoPomodoroBreakEnforcement.onBreakStarted());
    }
  }

  static List<KakaoShortsSession> loadSessions() {
    final raw = _b.get(_sessionsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => KakaoShortsSession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveSessions(List<KakaoShortsSession> list) async {
    final trimmed = list.length > 200 ? list.sublist(list.length - 200) : list;
    await _b.put(_sessionsKey, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  static KakaoShortsSession? openSession() {
    final id = _b.get(_openSessionKey);
    if (id == null) return null;
    for (final s in loadSessions()) {
      if (s.id == id && s.isOpen) return s;
    }
    return null;
  }

  static Future<KakaoShortsSession> startManualSession() async {
    final existing = openSession();
    if (existing != null) return existing;
    final s = KakaoShortsSession(
      id: 'ks_${DateTime.now().millisecondsSinceEpoch}',
      startMs: DateTime.now().millisecondsSinceEpoch,
    );
    final list = loadSessions()..add(s);
    await _saveSessions(list);
    await _b.put(_openSessionKey, s.id);
    return s;
  }

  /// Android 접근성 — 카카오톡 포그라운드 진입 (포모도로 ON일 때만)
  static Future<KakaoShortsSession?> startAndroidSession() async {
    if (!pomodoroEnabled) return null;
    final existing = openSession();
    if (existing != null) return existing;
    final s = KakaoShortsSession(
      id: 'ks_${DateTime.now().millisecondsSinceEpoch}',
      startMs: DateTime.now().millisecondsSinceEpoch,
      source: KakaoShortsSessionSource.androidUsage,
    );
    final list = loadSessions()..add(s);
    await _saveSessions(list);
    await _b.put(_openSessionKey, s.id);
    return s;
  }

  static Future<KakaoShortsSession?> endAndroidSession() async {
    final open = openSession();
    if (open == null || open.source != KakaoShortsSessionSource.androidUsage) {
      return null;
    }
    return endOpenSession();
  }

  static Future<KakaoShortsSession?> endOpenSession() async {
    final open = openSession();
    if (open == null) return null;
    final endMs = DateTime.now().millisecondsSinceEpoch;
    final closed = KakaoShortsSession(
      id: open.id,
      startMs: open.startMs,
      endMs: endMs,
      source: open.source,
    );
    final list = loadSessions().map((s) => s.id == open.id ? closed : s).toList();
    await _saveSessions(list);
    await _b.delete(_openSessionKey);
    final sec = closed.durationSeconds();
    if (pomodoroEnabled) await tickPomodoro(sec);
    return closed;
  }
}
