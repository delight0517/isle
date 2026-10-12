import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_executor.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/library/platform_watch_limit_store.dart';
import 'package:isle/core/services/isle_user_defaults.dart';
import 'package:isle/core/usage_budget/usage_budget_store.dart';
import 'package:isle/core/youtube/youtube_watch_timer_store.dart';
import 'package:isle/core/youtube/youtube_weekly_usage_store.dart';

/// 2026-07-13 신규: 요일별 하루 총량 오버라이드 / "이번주만" 임시 주간 총량 /
/// 매주 반복 영구 주간 총량.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    final dir = Directory.systemTemp.createTempSync('isle_yt_weekly_quota_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await PlatformWatchLimitStore.ensureOpen();
    await YoutubeWatchTimerStore.ensureOpen();
    await UsageBudgetStore.ensureOpen();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('"일요일에는 하루 유튜브 총량 7시간으로 늘려줘" saves a weekday override',
      () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('일요일에는 하루 유튜브 총량 7시간으로 늘려줘');
    expect(usedAi, false);
    expect(plan.action, 'youtube_weekday_limit');
    expect(plan.dailyMinutes, 420);
    expect(plan.startHour, 7); // DateTime.weekday: 7=일요일

    final result = await BlockChatExecutor.apply(plan);
    expect(result.isFailure, false, reason: result.summary);
    expect(IsleUserDefaults.youtubeWeekdayLimitOverrides[7], 420);
  });

  test('weekday override only changes the limit for that weekday', () async {
    await IsleUserDefaults.setYoutubeWeekdayLimitOverride(7, 420);
    // 일요일(7)이 아닌 다른 요일엔 override가 안 걸림 — dailyLimitSeconds가
    // DateTime.now().weekday에 따라 달라지므로, override map 자체가 다른
    // 요일 키를 포함하지 않는지로 검증.
    expect(IsleUserDefaults.youtubeWeekdayLimitOverrides.containsKey(1), false);
    expect(IsleUserDefaults.youtubeWeekdayLimitOverrides[7], 420);
  });

  test('"이번주는 일주일 유튜브 시간 4시간으로 줄여줘" saves a temporary '
      'this-week-only override', () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('이번주는 일주일 유튜브 시간 4시간으로 줄여줘');
    expect(usedAi, false);
    expect(plan.action, 'youtube_weekly_limit');
    expect(plan.dailyMinutes, 240);
    expect(plan.toggleOn, true, reason: '"이번주는"이 임시(이번 주만) 시그널');

    final result = await BlockChatExecutor.apply(plan);
    expect(result.isFailure, false, reason: result.summary);
    expect(IsleUserDefaults.youtubeWeeklyLimitTempMinutes, 240);
    expect(IsleUserDefaults.youtubeWeeklyLimitMinutes, 0,
        reason: '임시 한도는 영구 한도와 별개 슬롯에 저장돼야 함');
  });

  test('"이번주 유튜브 총량은 10시간으로 제한해줘" saves a permanent recurring '
      'weekly limit (no "만")', () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('이번주 유튜브 총량은 10시간으로 제한해줘');
    expect(usedAi, false);
    expect(plan.action, 'youtube_weekly_limit');
    expect(plan.dailyMinutes, 600);
    expect(plan.toggleOn, false);

    final result = await BlockChatExecutor.apply(plan);
    expect(result.isFailure, false, reason: result.summary);
    expect(IsleUserDefaults.youtubeWeeklyLimitMinutes, 600);
  });

  test('permanent weekly limit actually blocks usage once exceeded',
      () async {
    await IsleUserDefaults.setYoutubeWeeklyLimitMinutes(1);
    expect(YoutubeWatchTimerStore.isLimitReached, false);
    YoutubeWatchTimerStore.addSeconds(90); // 1.5분 > 1분 한도
    expect(YoutubeWeeklyUsageStore.secondsUsedThisWeek, 90);
    expect(YoutubeWatchTimerStore.isLimitReached, true,
        reason: '주간 한도(1분)를 넘겼으니 일일 한도와 무관하게 막혀야 함');
  });

  test('daily limit still applies independently when weekly limit is off',
      () async {
    expect(IsleUserDefaults.youtubeWeeklyLimitMinutes, 0);
    await IsleUserDefaults.setYoutubeDailyLimitEnabled(true);
    await IsleUserDefaults.setYoutubeDailyLimitMinutes(20);
    expect(YoutubeWatchTimerStore.isLimitReached, false);
    YoutubeWatchTimerStore.addSeconds(20 * 60 + 1);
    expect(YoutubeWatchTimerStore.isLimitReached, true);
  });
}
