import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/ai_config_store.dart';
import 'package:isle/core/ai/block_chat/block_chat_executor.dart';
import 'package:isle/core/ai/block_chat/block_chat_models.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/schedule_enforcement_mode.dart';
import 'package:isle/core/block_schedule/models/schedule_slot.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/intervention/app_usage_limit_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/usage_budget/usage_budget_models.dart';
import 'package:isle/core/usage_budget/usage_budget_store.dart';
import 'package:isle/core/youtube/content_filter_store.dart';

/// "오늘 블락은 뭐가 켜져있어?" — 특정 앱을 안 짚은 전체 조회는 YouTube로 조용히
/// 좁혀지던 버그(2026-07-10) 대신 앱별 오늘 24시간 타임라인을 만들어야 한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    final dir = Directory.systemTemp.createTempSync('isle_moa_explain_status_broad');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await ContentFilterStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await UsageBudgetStore.ensureOpen();
    await AiConfigStore.ensureOpen();
  });

  setUp(() async {
    await BlockScheduleStore.saveAll(const []);
  });

  test('"오늘 블락은 뭐가 켜져있어?" parses to explain_status with no single target',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse('오늘 블락은 뭐가 켜져있어?');
    expect(usedAi, false);
    expect(plan.action, 'explain_status');
    expect(plan.limitPlatform, isNull);
    expect(plan.appId, isNull);
  });

  test('broad status query builds a dailyTimeline covering an active fullBlock schedule',
      () async {
    final now = DateTime.now();
    final today = now.weekday - 1;
    final nowMinute = now.hour * 60 + now.minute;
    final start = (nowMinute - 5).clamp(0, 1438);
    final end = (nowMinute + 55).clamp(start + 1, 1439);

    final s = await BlockScheduleStore.create(
      name: '야간 SNS 차단',
      slots: [ScheduleSlot(day: today, startMinute: start, endMinute: end)],
    );
    await BlockScheduleStore.upsert(
      s.copyWith(enforcementMode: ScheduleEnforcementMode.fullBlock),
    );

    const plan = BlockChatPlan(action: 'explain_status', reply: '');
    final result = await BlockChatExecutor.apply(plan);

    expect(result.isFailure, isFalse, reason: result.summary);
    expect(result.dailyTimeline, isNotNull);
    expect(result.dailyTimeline, isNotEmpty);
    final item = result.dailyTimeline!.first;
    expect(item.segments, isNotEmpty);
    expect(item.segments.first.kind, BlockTimelineSegmentKind.fullBlock);
  });

  test('broad status query includes an enabled usage-budget target as partialAllow',
      () async {
    await UsageBudgetStore.savePolicy(
      UsageBudgetPolicy(
        target: UsageBudgetTarget.youtube,
        enabled: true,
        dailyCapMinutes: 60,
        burstCapMinutes: 3,
        refillAmountMinutes: 3,
        refillIntervalMinutes: 10,
        cooldownMinutes: 5,
        updatedAt: DateTime.now(),
        windowStartMinute: 7 * 60,
        windowEndMinute: 10 * 60,
      ),
    );

    const plan = BlockChatPlan(action: 'explain_status', reply: '');
    final result = await BlockChatExecutor.apply(plan);

    expect(result.isFailure, isFalse, reason: result.summary);
    expect(result.dailyTimeline, isNotNull);
    final youtubeItem =
        result.dailyTimeline!.where((i) => i.label == 'YouTube').toList();
    expect(youtubeItem, isNotEmpty);
    expect(youtubeItem.first.segments.first.kind, BlockTimelineSegmentKind.partialAllow);
    expect(youtubeItem.first.segments.first.startMinute, 7 * 60);
    expect(youtubeItem.first.segments.first.endMinute, 10 * 60);

    await UsageBudgetStore.clearPolicy(UsageBudgetTarget.youtube);
  });

  test(
      '"오늘 유튜브 뮤직 블락은 어떤 상황이야? 어떤 상태야?" is a status question, '
      'not a new youtube_limit mutation (2026-07-10)', () async {
    final now = DateTime.now();
    final today = now.weekday - 1;
    final nowMinute = now.hour * 60 + now.minute;
    final start = (nowMinute - 30).clamp(0, 1400);
    final end = (start + 180).clamp(start + 1, 1439);
    final s = await BlockScheduleStore.create(
      name: 'YouTube Music · 화면 한도 (AI)',
      slots: [ScheduleSlot(day: today, startMinute: start, endMinute: end)],
    );
    await BlockScheduleStore.upsert(
      s.copyWith(enforcementMode: ScheduleEnforcementMode.limitInSlot),
    );

    final (plan, usedAi) =
        await BlockChatParser.parse('오늘 유튜브 뮤직 블락은 어떤 상황이야? 어떤 상태야?');
    expect(usedAi, false);
    expect(plan.action, 'explain_status');
    expect(plan.limitPlatform, 'youtube_music');

    final result = await BlockChatExecutor.apply(plan);
    expect(result.isFailure, isFalse, reason: result.summary);
    expect(result.usedAi, false);
    expect(result.summary, contains('YouTube Music'));
    expect(result.dailyTimeline, isNotNull);
    expect(result.dailyTimeline, isNotEmpty);
  });
}
