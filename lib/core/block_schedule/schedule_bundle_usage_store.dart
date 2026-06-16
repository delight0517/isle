import 'package:hive_flutter/hive_flutter.dart';

import '../library/platform_watch_limit_store.dart';
import '../intervention/platform_app_limit_service.dart';
import 'dart:io' show Platform;

import 'schedule_app_target_catalog.dart';

/// 스케줄·번들별 리셋 창 사용량 (Isle WebView + 가능 시 Android iOS 앱)
class ScheduleBundleUsageStore {
  ScheduleBundleUsageStore._();

  static const _boxName = 'isle_schedule_bundle_usage';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('ScheduleBundleUsageStore.ensureOpen() first');
    return b;
  }

  static String _windowStartKey(String scheduleId, String bundleId) =>
      'ws_${scheduleId}_$bundleId';

  static String _secondsKey(String scheduleId, String bundleId) =>
      'sec_${scheduleId}_$bundleId';

  static int _windowStartMs(String scheduleId, String bundleId, int windowMinutes) {
    final k = _windowStartKey(scheduleId, bundleId);
    final raw = box.get(k);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (raw == null) {
      box.put(k, '$now');
      box.put(_secondsKey(scheduleId, bundleId), '0');
      return now;
    }
    final start = int.tryParse(raw) ?? now;
    final elapsedMin = (now - start) ~/ 60000;
    if (elapsedMin >= windowMinutes) {
      box.put(k, '$now');
      box.put(_secondsKey(scheduleId, bundleId), '0');
      for (final t in ScheduleAppTargetCatalog.targets.where((d) => d.bundleId == bundleId)) {
        box.delete(_targetSecondsKey(scheduleId, t.id));
      }
      return now;
    }
    return start;
  }

  static String _targetSecondsKey(String scheduleId, String targetId) => 'sec_${scheduleId}_$targetId';

  static void addIsleTargetSeconds(
    String scheduleId,
    String targetId,
    int windowMinutes,
    int seconds,
  ) {
    if (seconds <= 0) return;
    final def = ScheduleAppTargetCatalog.defFor(targetId);
    if (def == null) return;
    _windowStartMs(scheduleId, def.bundleId, windowMinutes);
    final k = _targetSecondsKey(scheduleId, targetId);
    final cur = int.tryParse(box.get(k) ?? '') ?? 0;
    box.put(k, '${cur + seconds}');
  }

  static int _isleSecondsInWindow(String scheduleId, String bundleId, int windowMinutes) {
    _windowStartMs(scheduleId, bundleId, windowMinutes);
    var total = 0;
    for (final t in ScheduleAppTargetCatalog.targets.where((d) => d.bundleId == bundleId && d.isIsle)) {
      total += int.tryParse(box.get(_targetSecondsKey(scheduleId, t.id)) ?? '') ?? 0;
    }
    return total;
  }

  static int _platformSecondsForBundle(String bundleId) {
    switch (bundleId) {
      case 'instagram_feed':
      case 'instagram':
        return PlatformWatchLimitStore.secondsUsedToday(PlatformWatchId.instagram);
      case 'instagram_dm':
        return PlatformWatchLimitStore.secondsUsedToday(PlatformWatchId.instagramDm);
      case 'youtube':
        return PlatformWatchLimitStore.secondsUsedToday(PlatformWatchId.youtube);
      case 'brunch':
        return PlatformWatchLimitStore.secondsUsedToday(PlatformWatchId.brunch);
      case 'kakao_talk':
        return 0;
      default:
        return 0;
    }
  }

  static Future<int> _androidIosAppSeconds(String bundleId) async {
    if (!Platform.isAndroid) return 0;
    final defs = ScheduleAppTargetCatalog.targets.where((t) => t.bundleId == bundleId && t.isIos);
    var total = 0;
    for (final d in defs) {
      final pkg = d.androidPackage;
      if (pkg == null) continue;
      total += await PlatformAppLimitService.usageMinutesToday(androidPackage: pkg) * 60;
    }
    return total;
  }

  /// 번들 내 Isle + (일일) 플랫폼 시청 + Android 앱 사용량 합산
  static Future<int> combinedSecondsInWindow({
    required String scheduleId,
    required String bundleId,
    required int windowMinutes,
  }) async {
    final isle = _isleSecondsInWindow(scheduleId, bundleId, windowMinutes);
    final platform = windowMinutes >= 1440 ? _platformSecondsForBundle(bundleId) : 0;
    final android = await _androidIosAppSeconds(bundleId);
    return isle + platform + android;
  }

  static Future<bool> isLimitReached({
    required String scheduleId,
    required String bundleId,
    required int limitMinutes,
    required int windowMinutes,
  }) async {
    final used = await combinedSecondsInWindow(
      scheduleId: scheduleId,
      bundleId: bundleId,
      windowMinutes: windowMinutes,
    );
    return used >= limitMinutes * 60;
  }
}
