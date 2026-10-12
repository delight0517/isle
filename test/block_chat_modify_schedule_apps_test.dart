import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_executor.dart';
import 'package:isle/core/ai/block_chat/block_chat_models.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/block_schedule.dart';
import 'package:isle/core/block_schedule/models/schedule_enforcement_mode.dart';
import 'package:isle/core/block_schedule/models/schedule_slot.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/intervention/schedule_screen_time_store.dart';

/// "게임 pc방 인증 앱에서 하나 더 추가할래!!" 같은 실사용 제보(2026-[REDACTED]) —
/// 기존엔 이 패턴이 로컬 파서에 아예 없어서 매번 AI로 새고, AI도 앱 이름을
/// app_id에 자유 텍스트로만 담아 explain으로 죽었다. 로컬 파서가 카탈로그
/// 앱(카카오·틱톡 등)을 직접 인식해서 기존 스케줄에 바로 추가/제거하는지 검증.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    final dir = Directory.systemTemp.createTempSync('isle_modify_schedule_apps_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    await ScheduleRuleStore.ensureOpen();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('parser recognizes "카카오톡 추가해줘" as modify_schedule_apps, not explain',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse('카카오톡 추가해줘');
    expect(usedAi, isFalse, reason: '로컬 파서가 잡아야 AI로 안 샌다');
    expect(plan.action, 'modify_schedule_apps');
    expect(plan.appId, 'kakao');
    expect(plan.toggleOn, isTrue);
  });

  test('parser recognizes remove verbs("틱톡 빼줘") with toggleOn=false', () async {
    final (plan, usedAi) = await BlockChatParser.parse('틱톡 빼줘');
    expect(usedAi, isFalse);
    expect(plan.action, 'modify_schedule_apps');
    expect(plan.appId, 'tiktok');
    expect(plan.toggleOn, isFalse);
  });

  test('end-to-end: 야간 게임 차단 스케줄을 만든 뒤 "카카오톡 추가해줘"를 보내면 '
      '그 스케줄에 ios_kakao가 실제로 추가된다', () async {
    // night_schedule로 만들면 항상 locked:true(unlockStartedAtMs 없음)라
    // 즉시 완전 잠금 상태가 되고, 그 상태에서 앱 추가는 즉시 반영이 아니라
    // 타임락 큐잉으로 빠진다(기존 스케줄 편집 공통 정책) — 이 테스트는 그
    // 잠금 정책이 아니라 modify_schedule_apps 자체의 동작을 격리해서
    // 검증하려는 것이므로 잠금 해제(편집 창) 상태로 직접 seed한다.
    final scheduleId = 'sch_test_night_games';
    await BlockScheduleStore.upsert(BlockSchedule(
      id: scheduleId,
      name: '야간 게임 차단 (AI)',
      enabled: true,
      locked: false,
      slots: const [ScheduleSlot(day: 0, startMinute: 0, endMinute: 1439)],
      enforcementMode: ScheduleEnforcementMode.fullBlock,
    ));

    final (plan, usedAi) =
        await BlockChatParser.parse('야간 게임 차단 앱에서 카카오톡 추가해줘');
    expect(usedAi, isFalse);
    expect(plan.action, 'modify_schedule_apps');

    final result = await BlockChatExecutor.apply(plan);
    expect(result.isFailure, false, reason: result.summary);

    final entry = ScheduleAppTargetsStore.entryFor(scheduleId, 'ios_kakao');
    expect(entry, isNotNull);
    expect(entry!.blockInSlot, isTrue,
        reason: '완전차단 스케줄이라 blockInSlot으로 추가돼야 함');
  });

  test('remove: 추가돼 있던 앱을 빼면 blockInSlot/limitEnabled가 모두 꺼진다',
      () async {
    final scheduleId = 'sch_test_pcbang_cert';
    await BlockScheduleStore.upsert(BlockSchedule(
      id: scheduleId,
      name: 'PC방 인증 앱 절제 (AI)',
      enabled: true,
      locked: false,
      slots: const [ScheduleSlot(day: 0, startMinute: 0, endMinute: 1439)],
      enforcementMode: ScheduleEnforcementMode.fullBlock,
    ));

    await BlockChatExecutor.apply(const BlockChatPlan(
      action: 'modify_schedule_apps',
      appId: 'kakao',
      limitPlatform: 'app',
      scheduleQuery: 'PC방 인증 앱',
      toggleOn: true,
      reply: '',
    ));
    expect(ScheduleAppTargetsStore.entryFor(scheduleId, 'ios_kakao')?.blockInSlot,
        isTrue);

    await BlockChatExecutor.apply(const BlockChatPlan(
      action: 'modify_schedule_apps',
      appId: 'kakao',
      limitPlatform: 'app',
      scheduleQuery: 'PC방 인증 앱',
      toggleOn: false,
      reply: '',
    ));
    final entry = ScheduleAppTargetsStore.entryFor(scheduleId, 'ios_kakao');
    expect(entry?.blockInSlot ?? false, isFalse);
    expect(entry?.limitEnabled ?? false, isFalse);
  });
}
