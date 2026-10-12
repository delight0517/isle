import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_executor.dart';
import 'package:isle/core/ai/block_chat/block_chat_models.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/schedule_enforcement_mode.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/intervention/app_usage_limit_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_store.dart';
import 'package:isle/core/youtube/content_filter_store.dart';

/// SCHEDULE_CONVERT — "카카오톡 밤에 통째로 블락 말고 10분마다 3분만" 이 실제로
/// 기존 fullBlock 스케줄을 찾아 limitInSlot 으로 바꾸는지 검증.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_convert_schedule_mode');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await ContentFilterStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await ScheduleRuleStore.ensureOpen();
  });

  setUp(() async {
    await BlockScheduleStore.saveAll(const []);
  });

  Future<BlockChatPlan> createKakaoNightPlan() async => BlockChatPlan(
        action: 'night_schedule',
        reply: '',
        scheduleName: '카카오톡 밤',
        startHour: 21,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        days: const [0, 1, 2, 3, 4, 5, 6],
        appId: 'kakao',
      );

  test('막 만든 스케줄(타임락 중)은 즉시 변형되지 않고 안전하게 대기(needsUnlockWait)', () async {
    final created = await BlockChatExecutor.apply(await createKakaoNightPlan());
    expect(created.isFailure, isFalse, reason: created.summary);
    expect(
      BlockScheduleStore.loadAll().first.enforcementMode,
      ScheduleEnforcementMode.fullBlock,
    );

    final convertPlan = BlockChatPlan(
      action: 'convert_schedule_mode',
      reply: '',
      scheduleQuery: '카카오톡 밤',
      appId: 'kakao',
      sessionMinutes: 3,
      windowMinutes: 10,
    );
    final result = await BlockChatExecutor.apply(convertPlan);

    // rename_schedule 등 다른 스케줄 변경과 동일한 타임락 보호 — 방금 만든 락은
    // 즉시 편집 불가(phase=.locked)라 대기 상태로 큐잉되고, 모드는 아직 안 바뀐다.
    expect(result.needsUnlockWait, isTrue, reason: result.summary);
    expect(
      BlockScheduleStore.loadAll().first.enforcementMode,
      ScheduleEnforcementMode.fullBlock,
      reason: '타임락 대기 중에는 모드가 바뀌면 안 됨',
    );
  });

  test('편집 창이 열려 있으면(잠금 아님) fullBlock → limitInSlot(3분/10분)으로 실제 변형됨',
      () async {
    await BlockChatExecutor.apply(await createKakaoNightPlan());
    // 테스트 격리를 위해 saveAll로 직접 잠금 해제 — setUp의 saveAll([]) 관례와 동일하게
    // upsert()의 커밋먼트 락 guard(ScheduleImportGuard)를 우회해 "편집 창 열림" 상태를 시뮬레이션.
    final created = BlockScheduleStore.loadAll().first;
    await BlockScheduleStore.saveAll([created.copyWith(locked: false)]);

    final convertPlan = BlockChatPlan(
      action: 'convert_schedule_mode',
      reply: '',
      scheduleQuery: '카카오톡 밤',
      appId: 'kakao',
      sessionMinutes: 3,
      windowMinutes: 10,
    );
    final result = await BlockChatExecutor.apply(convertPlan);
    expect(result.isFailure, isFalse, reason: result.summary);
    expect(result.needsUnlockWait, isFalse);

    final schedule = BlockScheduleStore.loadAll().first;
    expect(schedule.enforcementMode, ScheduleEnforcementMode.limitInSlot);

    final entries = ScheduleAppTargetsStore.loadForSchedule(schedule.id);
    final kakaoEntry = entries.where((e) => e.targetId == 'ios_kakao');
    expect(kakaoEntry, isNotEmpty);
    final entry = kakaoEntry.first;
    expect(entry.limitEnabled, isTrue);
    expect(entry.blockInSlot, isFalse);
    expect(entry.limitMinutes, 3);
    expect(entry.windowMinutes, 10);
  });

  test('존재하지 않는 스케줄을 변형하려 하면 실패 응답', () async {
    final plan = BlockChatPlan(
      action: 'convert_schedule_mode',
      reply: '',
      scheduleQuery: '이런 스케줄 없음 12345',
      appId: 'kakao',
      sessionMinutes: 3,
      windowMinutes: 10,
    );
    final result = await BlockChatExecutor.apply(plan);
    expect(result.isFailure, isTrue);
  });
}
