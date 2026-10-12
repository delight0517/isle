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

/// cage에서 이식한 야간 limit-in-slot(카카오톡 "밤 10분마다 3분") 실제 실행 검증.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_night_kakao_limit');
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
    // BlockScheduleStore.delete()는 커밋먼트 락 guard를 타서 locked 스케줄을
    // 못 지운다(의도된 보호). 테스트 격리를 위해 직접 saveAll([])로 비운다.
    await BlockScheduleStore.saveAll(const []);
  });

  test('카카오톡 밤 스케줄 → limitInSlot 모드 + 3분/10분 리필로 실행됨', () async {
    final plan = BlockChatPlan(
      action: 'night_schedule',
      reply: '',
      scheduleName: '카카오톡 야간 리필',
      startHour: 21,
      startMinute: 0,
      endHour: 7,
      endMinute: 0,
      days: const [0, 1, 2, 3, 4, 5, 6],
      appId: 'kakao',
      sessionMinutes: 3,
      windowMinutes: 10,
    );

    final result = await BlockChatExecutor.apply(plan);
    expect(result.isFailure, isFalse, reason: result.summary);

    final schedules = BlockScheduleStore.loadAll();
    expect(schedules.length, 1, reason: '스케줄이 정확히 1개 생성되어야 함');
    final schedule = schedules.first;

    // fullBlock 이 아니라 limitInSlot 이어야 "통째 블락"이 아닌 "N분마다 M분"이 된다.
    expect(schedule.enforcementMode, ScheduleEnforcementMode.limitInSlot);

    final entries = ScheduleAppTargetsStore.loadForSchedule(schedule.id);
    final kakaoEntry = entries.where((e) => e.targetId == 'ios_kakao');
    expect(kakaoEntry, isNotEmpty, reason: 'ios_kakao 타깃 엔트리가 있어야 함');
    final entry = kakaoEntry.first;
    expect(entry.limitEnabled, isTrue);
    expect(entry.blockInSlot, isFalse);
    expect(entry.limitMinutes, 3);
    expect(entry.windowMinutes, 10);
  });

  test('일반 야간 SNS(카카오 아님) → 기존처럼 fullBlock 유지 (회귀 없음)', () async {
    final plan = BlockChatPlan(
      action: 'night_schedule',
      reply: '',
      startHour: 21,
      startMinute: 0,
      endHour: 7,
      endMinute: 0,
      days: const [0, 1, 2, 3, 4, 5, 6],
    );

    final result = await BlockChatExecutor.apply(plan);
    expect(result.isFailure, isFalse, reason: result.summary);

    final schedule = BlockScheduleStore.loadAll().first;
    expect(schedule.enforcementMode, ScheduleEnforcementMode.fullBlock);
  });
}
