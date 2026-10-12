import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_executor.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_store.dart';
import 'package:isle/core/intervention/app_usage_limit_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/youtube/content_filter_store.dart';

/// cage 2026-07-13 이식 — "Cage / 오늘 하루 동안은 집중 모드 해주저!!" 대화형
/// 위저드. 모아는 인앱(isle_*)만 다루고 1회성 만료(oneShot) 개념이 없어서
/// Cage의 temp_block이 아니라 기존 night_schedule 엔진(오늘 요일 하루치
/// 슬롯 + 자정 넘김)을 재사용한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    final dir = Directory.systemTemp.createTempSync('moa_focus_mode_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await ContentFilterStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await ScheduleRuleStore.ensureOpen();
  });

  test('"집중 모드 해줘"는 바로 차단하지 않고 뭘 막을지 먼저 되묻는다', () async {
    final (ask, _) = await BlockChatParser.parseWithContext('집중 모드 해줘');
    expect(ask.action, 'focus_mode_ask');
    expect(ask.reply, isNotEmpty);
  });

  test('"지금부터 유튜브 차단 6시간 동안 해줘"는 즉시 차단으로 간다',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '지금부터 유튜브 차단 6시간 동안 해줘',
    );

    expect(usedAi, false);
    expect(plan.action, 'quick_block_now');
    expect(plan.limitPlatform, 'youtube');
    expect(plan.windowMinutes, 360);
  });

  test('"지금부터 브라우저 차단 3시간 동안해줘"는 브라우저 즉시 차단으로 간다',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '지금부터 브라우저 차단 3시간 동안해줘',
    );

    expect(usedAi, false);
    expect(plan.action, 'quick_block_now');
    expect(plan.limitPlatform, 'safari');
    expect(plan.windowMinutes, 180);
    expect(plan.reply, contains('브라우저'));
  });

  test('"지금부터 공부 모드 6시간 동안 돌려줘"는 공부 모드 프리셋으로 간다',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '지금부터 공부 모드 6시간 동안 돌려줘',
    );

    expect(usedAi, false);
    expect(plan.action, 'study_mode');
    expect(plan.windowMinutes, 360);
    expect(plan.subPlans, isNotEmpty);
  });

  test('되물은 뒤 "유튜브랑 인스타"라고 답하면 그 두 앱만 골라 오늘부터 '
      '자정 넘겨 01:00까지 막는다', () async {
    final (ask, _) = await BlockChatParser.parseWithContext('포커스 모드 켜줘');
    final (answer, _) = await BlockChatParser.parseWithContext(
      '유튜브랑 인스타',
      previousPlan: ask,
    );

    expect(answer.action, 'night_schedule');
    expect(answer.extraTargetIds, containsAll(['isle_youtube', 'isle_instagram']));
    expect(answer.blockSafariNote, false);
    expect(answer.endHour, 1);
    expect(answer.endMinute, 0);

    final result = await BlockChatExecutor.apply(answer);
    expect(result.isFailure, false, reason: result.summary);

    final schedule = BlockScheduleStore.loadAll().first;
    final entries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(schedule.id),
    );
    final blockedIds =
        entries.where((e) => e.blockInSlot).map((e) => e.targetId).toSet();
    expect(blockedIds, containsAll(['isle_youtube', 'isle_instagram']));
  });

  test('"전부 다"라고 답하면 브라우저까지 포함해 전 카테고리를 막는다', () async {
    final (ask, _) = await BlockChatParser.parseWithContext('집중모드 시작');
    final (answer, _) = await BlockChatParser.parseWithContext(
      '전부 다',
      previousPlan: ask,
    );

    expect(answer.action, 'night_schedule');
    expect(answer.blockSafariNote, true);
    expect(answer.extraTargetIds, containsAll(['isle_youtube', 'isle_instagram']));
  });

  test('뭘 막을지 못 알아들으면 적용하지 않고 다시 물어본다', () async {
    final (ask, _) = await BlockChatParser.parseWithContext('집중 모드 해줘');
    final (answer, _) = await BlockChatParser.parseWithContext(
      '음... 잘 모르겠어',
      previousPlan: ask,
    );
    expect(answer.action, 'focus_mode_ask');
  });
}
