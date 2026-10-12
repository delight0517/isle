import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/library/platform_watch_limit_store.dart';
import 'package:isle/core/services/isle_user_defaults.dart';
import 'package:isle/core/usage_budget/usage_budget_store.dart';
import 'package:isle/core/youtube/youtube_watch_timer_store.dart';

/// 2026-07-13 신규 — 유튜브 시청 중 30/50/70/100% 소진 알림.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('newlyCrossedUsageThresholds (순수 함수)', () {
    test('30%를 막 넘으면 30만 새로 걸림', () {
      final crossed = newlyCrossedUsageThresholds(
        beforePercent: 25,
        afterPercent: 32,
        alreadyNotifiedToday: {},
      );
      expect(crossed, [30]);
    });

    test('한 번의 tick으로 30·50을 동시에 넘으면 둘 다 걸림', () {
      final crossed = newlyCrossedUsageThresholds(
        beforePercent: 20,
        afterPercent: 55,
        alreadyNotifiedToday: {},
      );
      expect(crossed, [30, 50]);
    });

    test('이미 알림 보낸 임계값은 다시 안 걸림', () {
      final crossed = newlyCrossedUsageThresholds(
        beforePercent: 25,
        afterPercent: 35,
        alreadyNotifiedToday: {30},
      );
      expect(crossed, isEmpty);
    });

    test('100% 이상 계속 넘어가도 100은 한 번만', () {
      final crossed = newlyCrossedUsageThresholds(
        beforePercent: 100,
        afterPercent: 150,
        alreadyNotifiedToday: {30, 50, 70, 100},
      );
      expect(crossed, isEmpty);
    });
  });

  group('YoutubeWatchTimerStore.addSeconds 통합', () {
    setUp(() async {
      const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secure, (call) async {
        if (call.method == 'readAll') return <String, String>{};
        return null;
      });
      final dir = Directory.systemTemp.createTempSync('isle_yt_notif_test');
      Hive.init(dir.path);
      await Hive.openBox<String>('isle_cache');
      await PlatformWatchLimitStore.ensureOpen();
      await YoutubeWatchTimerStore.ensureOpen();
      await UsageBudgetStore.ensureOpen();
      await IsleUserDefaults.setYoutubeDailyLimitEnabled(true);
      await IsleUserDefaults.setYoutubeDailyLimitMinutes(10); // 600초
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
    });

    test('하루 한도의 30%를 넘기면 30이 알림-발송-완료 목록에 기록된다',
        () async {
      expect(IsleUserDefaults.youtubeNotifiedThresholdsToday, isEmpty);
      YoutubeWatchTimerStore.addSeconds(200); // 600초의 33%
      expect(IsleUserDefaults.youtubeNotifiedThresholdsToday, contains(30));
      expect(IsleUserDefaults.youtubeNotifiedThresholdsToday, isNot(contains(50)));
    });

    test('같은 임계값을 두 번 넘어도 한 번만 기록된다(중복 알림 방지)', () async {
      YoutubeWatchTimerStore.addSeconds(200); // 33% -> 30 기록
      YoutubeWatchTimerStore.addSeconds(1); // 여전히 30%대
      final thresholds = IsleUserDefaults.youtubeNotifiedThresholdsToday;
      expect(thresholds.where((t) => t == 30).length, 1);
    });

    test('100%를 넘기면 30·50·70·100 전부 기록된다(한 번에 다 넘은 경우)',
        () async {
      YoutubeWatchTimerStore.addSeconds(700); // 600초 한도를 한 번에 초과
      final thresholds = IsleUserDefaults.youtubeNotifiedThresholdsToday;
      expect(thresholds, containsAll([30, 50, 70, 100]));
    });
  });
}
