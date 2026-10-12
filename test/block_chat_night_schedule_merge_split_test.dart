import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_executor.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/schedule_slot.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_store.dart';
import 'package:isle/core/intervention/app_usage_limit_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/youtube/content_filter_store.dart';

/// (cage에서 2026-07-13 이식) 두 가지 실제 버그를 확인·회귀 방지한다:
/// 1) 이미 다른 시간대(예: 14:00-16:00)로 존재하는 스케줄에 새 시간대 요청이
///    오면 slots를 통째로 덮어써서 기존 시간대가 사라지던 버그 — 이제 하나의
///    스케줄에 여러 시간대로 병합된다.
/// 2) "분리해줘"로 병합된 스케줄을 시간대별로 다시 나눌 수 있다 — 단, 병합
///    직후엔 그 병합 자체가 스케줄을 즉시 잠그므로 분리는 정직하게 거부된다
///    (커밋먼트 락 보호, 의도된 동작).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    final dir = Directory.systemTemp.createTempSync('isle_night_merge_split_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await ContentFilterStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await ScheduleRuleStore.ensureOpen();
    await BlockScheduleStore.saveAll(const []);
  });

  test('새 시간대 요청이 기존 시간대를 지우지 않고 하나의 스케줄에 병합된다',
      () async {
    final schedule = await BlockScheduleStore.create(
      name: '야간 Safari 차단 (AI)',
      slots: [
        for (var d = 0; d < 7; d++)
          const ScheduleSlot(day: 0, startMinute: 840, endMinute: 960),
      ],
      locked: false,
    );
    await BlockScheduleStore.upsert(schedule.copyWith(enabled: true));

    final (mergePlan, usedAi) = await BlockChatParser.parse(
      '23:00부터 다음날 07:00까지 브라우저 차단해줘',
    );
    expect(usedAi, false);
    final result = await BlockChatExecutor.apply(mergePlan);
    expect(result.isFailure, false, reason: result.summary);

    final merged = BlockScheduleStore.loadAll()
        .firstWhere((s) => s.name.contains('야간 Safari'));
    final hasOldWindow =
        merged.slots.any((s) => s.startMinute == 840 && s.endMinute == 960);
    final hasNewWindow =
        merged.slots.any((s) => s.startMinute == 1380 && s.endMinute == 420);
    expect(hasOldWindow, true, reason: '기존 14:00-16:00 시간대가 지워지면 안 됨(덮어쓰기 버그)');
    expect(hasNewWindow, true, reason: '새 23:00-07:00 시간대도 반영돼야 함');
  });

  test('"분리해줘"는 병합 직후엔 커밋먼트 락으로 정직하게 거부된다', () async {
    final schedule = await BlockScheduleStore.create(
      name: '야간 Safari 차단 (AI)',
      slots: [
        for (var d = 0; d < 7; d++)
          const ScheduleSlot(day: 0, startMinute: 840, endMinute: 960),
      ],
      locked: false,
    );
    await BlockScheduleStore.upsert(schedule.copyWith(enabled: true));

    final (mergePlan, _) = await BlockChatParser.parse(
      '23:00부터 다음날 07:00까지 브라우저 차단해줘',
    );
    await BlockChatExecutor.apply(mergePlan);

    final (splitPlan, usedAi) = await BlockChatParser.parseWithContext(
      '분리해줘',
      previousPlan: mergePlan,
    );
    expect(usedAi, false);
    expect(splitPlan.action, 'split_night_schedule');

    final splitResult = await BlockChatExecutor.apply(splitPlan);
    expect(splitResult.isFailure, true,
        reason: '병합 직후엔 스케줄이 잠겨있어 분리가 정직하게 거부돼야 함');
    expect(splitResult.summary, contains('타임락'));

    final active = BlockScheduleStore.loadAll().where((s) => s.enabled).toList();
    expect(active.length, 1,
        reason: '분리가 거부됐으니 병합된 스케줄 1개 그대로 남아야 함');
  });
}
