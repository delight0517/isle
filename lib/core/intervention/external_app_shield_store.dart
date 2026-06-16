import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_local_data_sync.dart';
import 'screen_time_persistence_service.dart';
class ExternalAppShieldStore {
  ExternalAppShieldStore._();

  static const _boxName = 'isle_external_app_shield';
  static const _encodedKey = 'family_activity_encoded';
  static const _appCountKey = 'application_count';
  static const _categoryCountKey = 'category_count';
  static const _syncScheduleKey = 'sync_with_block_schedule';
  static const _shieldActiveKey = 'shield_applied';
  static const _dailyLimitPrefix = 'daily_limit_min_';
  static const _dailyEnabledPrefix = 'daily_limit_on_';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('ExternalAppShieldStore.ensureOpen() first');
    }
    return b;
  }

  static bool get isOpen => _box?.isOpen ?? false;

  static String? get encodedSelection => box.get(_encodedKey);

  static int get applicationCount => int.tryParse(box.get(_appCountKey) ?? '') ?? 0;

  static int get categoryCount => int.tryParse(box.get(_categoryCountKey) ?? '') ?? 0;

  static bool get hasSelection =>
      encodedSelection != null && encodedSelection!.isNotEmpty;

  static bool get syncWithBlockSchedule =>
      box.get(_syncScheduleKey) != 'false';

  static Future<void> setSyncWithBlockSchedule(bool v) =>
      box.put(_syncScheduleKey, v ? 'true' : 'false');

  static bool get shieldMarkedActive => box.get(_shieldActiveKey) == 'true';

  static Future<void> savePickResult({
    required String encoded,
    required int applicationCount,
    required int categoryCount,
  }) async {
    await box.put(_encodedKey, encoded);
    await box.put(_appCountKey, '$applicationCount');
    await box.put(_categoryCountKey, '$categoryCount');
    isleNotifyLocalDataChanged();
    await ScreenTimePersistenceService.syncMirror();
  }

  static Future<void> clearSelection() async {
    await box.delete(_encodedKey);
    await box.delete(_appCountKey);
    await box.delete(_categoryCountKey);
    await box.put(_shieldActiveKey, 'false');
    await ScreenTimePersistenceService.syncMirror();
  }

  static Future<void> setShieldMarkedActive(bool v) =>
      box.put(_shieldActiveKey, v ? 'true' : 'false');

  /// 소프트 한도(분) — OS App Limits 가이드용. `instagram` `youtube_app` `safari` 등
  static int dailyLimitMinutes(String slotId) =>
      int.tryParse(box.get('$_dailyLimitPrefix$slotId') ?? '') ?? 0;

  static bool dailyLimitEnabled(String slotId) =>
      box.get('$_dailyEnabledPrefix$slotId') == 'true';

  static Future<void> setDailyLimit({
    required String slotId,
    required int minutes,
    required bool enabled,
  }) async {
    await box.put('$_dailyLimitPrefix$slotId', '$minutes');
    await box.put('$_dailyEnabledPrefix$slotId', enabled ? 'true' : 'false');
  }

  static const dailyLimitSlots = [
    ('youtube_app', 'YouTube 앱', 60),
    ('instagram', 'Instagram', 30),
    ('tiktok', 'TikTok', 30),
    ('safari', 'Safari·브라우저', 45),
  ];
}
