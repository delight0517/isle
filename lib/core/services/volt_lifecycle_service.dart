import 'package:hive_flutter/hive_flutter.dart';

/// [Volt] 백그라운드 타이머 대신 exit 타임스탬프 저장
class VoltLifecycleService {
  VoltLifecycleService._();

  static const _keyPausedAt = 'volt_paused_at_ms';
  static const _keyResumedAt = 'volt_resumed_at_ms';
  static const _keySchedBlocked = 'volt_sched_blocked';
  static const _keySchedActiveIds = 'volt_sched_active_ids';

  static Box<String> get _box => Hive.box<String>('isle_cache');

  static void onAppPaused() {
    _box.put(_keyPausedAt, DateTime.now().millisecondsSinceEpoch.toString());
  }

  static void onAppResumed() {
    _box.put(_keyResumedAt, DateTime.now().millisecondsSinceEpoch.toString());
  }

  static DateTime? lastPausedAt() {
    final raw = _box.get(_keyPausedAt);
    final ms = int.tryParse(raw ?? '');
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// 마지막 백그라운드 진입 이후 경과 시간 (없으면 zero)
  static Duration elapsedSinceLastPause() {
    final paused = lastPausedAt();
    if (paused == null) return Duration.zero;
    return DateTime.now().difference(paused);
  }

  static Future<void> putScheduleSnapshot({
    required bool blocked,
    required String activeIds,
  }) async {
    await _box.putAll({
      _keySchedBlocked: blocked ? '1' : '0',
      _keySchedActiveIds: activeIds,
    });
  }

  static ({bool blocked, String activeIds})? scheduleSnapshot() {
    final b = _box.get(_keySchedBlocked);
    if (b == null) return null;
    return (blocked: b == '1', activeIds: _box.get(_keySchedActiveIds) ?? '');
  }
}
