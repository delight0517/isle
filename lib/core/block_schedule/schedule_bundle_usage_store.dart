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

  static bool get isOpen => _box != null && _box!.isOpen;

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
    _addDailySeconds(scheduleId, def.bundleId, seconds);
  }

  static String _dayStampKey(String scheduleId, String bundleId) => 'day_${scheduleId}_$bundleId';
  static String _dailySecondsKey(String scheduleId, String bundleId) =>
      'dsec_${scheduleId}_$bundleId';

  static String _todayStamp([DateTime? at]) {
    final n = at ?? DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// 오늘(달력 날짜 기준, 시간당 리필 창과 별개) 누적 초 — 자정 지나면 0으로
  /// 리셋. "시간당 N분"이 계속 리필되며 에뮬레이트만 하던 하루 총량과 달리
  /// 이건 실제 자정까지 안 풀리는 진짜 하루 총량 카운터다(2026-07-20).
  static int dailySecondsSync(String scheduleId, String bundleId, [DateTime? at]) {
    final today = _todayStamp(at);
    final stored = box.get(_dayStampKey(scheduleId, bundleId));
    if (stored != today) {
      box.put(_dayStampKey(scheduleId, bundleId), today);
      box.put(_dailySecondsKey(scheduleId, bundleId), '0');
      return 0;
    }
    return int.tryParse(box.get(_dailySecondsKey(scheduleId, bundleId)) ?? '') ?? 0;
  }

  static void _addDailySeconds(String scheduleId, String bundleId, int seconds) {
    final current = dailySecondsSync(scheduleId, bundleId);
    box.put(_dailySecondsKey(scheduleId, bundleId), '${current + seconds}');
  }

  static bool isDailyLimitReachedSync({
    required String scheduleId,
    required String bundleId,
    required int dailyLimitMinutes,
    DateTime? at,
  }) =>
      dailySecondsSync(scheduleId, bundleId, at) >= dailyLimitMinutes * 60;

  /// 자정까지 남은 초 — 하루 총량 상한으로 막혔을 때는 시간당 리필과 달리
  /// 자정에야 풀린다.
  static int secondsUntilMidnight([DateTime? at]) {
    final n = at ?? DateTime.now();
    final midnight = DateTime(n.year, n.month, n.day + 1);
    return midnight.difference(n).inSeconds;
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

  /// [combinedSecondsInWindow]의 동기 버전 — Android 네이티브 앱 사용량(비동기
  /// 조회) 항목만 뺀다. Isle 인앱 WebView 차단 판정은 매 프레임 build()/1초 tick
  /// 에서 동기로 불려야 해서(예: [YoutubeAccessGuard.activeLock]) 비동기를 못 쓴다.
  /// 네이티브 앱 사용량은 어차피 인앱 WebView 재생이 아니라 실기기 앱 차단
  /// (VpnService/접근성) 경로에서 따로 다뤄지므로 인앱 판정에서 빼도 정확하다.
  static int combinedSecondsInWindowSync({
    required String scheduleId,
    required String bundleId,
    required int windowMinutes,
  }) {
    final isle = _isleSecondsInWindow(scheduleId, bundleId, windowMinutes);
    final platform =
        windowMinutes >= 1440 ? _platformSecondsForBundle(bundleId) : 0;
    return isle + platform;
  }

  static bool isLimitReachedSync({
    required String scheduleId,
    required String bundleId,
    required int limitMinutes,
    required int windowMinutes,
  }) {
    final used = combinedSecondsInWindowSync(
      scheduleId: scheduleId,
      bundleId: bundleId,
      windowMinutes: windowMinutes,
    );
    return used >= limitMinutes * 60;
  }

  /// 이 스케줄·번들의 리필 창이 다음에 초기화될 때까지 남은 초 — 리필 한도
  /// 오버레이에 "N분 후 다시 볼 수 있어요"를 구체적으로 보여주기 위함
  /// (2026-07-20, 이전엔 "다음 리필 창이 되면"이라는 일반 문구뿐이었음).
  static int secondsUntilRefillSync({
    required String scheduleId,
    required String bundleId,
    required int windowMinutes,
  }) {
    final start = _windowStartMs(scheduleId, bundleId, windowMinutes);
    final elapsedSec = (DateTime.now().millisecondsSinceEpoch - start) ~/ 1000;
    final left = windowMinutes * 60 - elapsedSec;
    return left < 0 ? 0 : left;
  }
}
