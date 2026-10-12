import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_executor.dart';
import 'package:isle/core/ai/block_chat/block_chat_models.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/block_schedule/schedule_pending_target_store.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';

/// Cage에서 먼저 발견·수정한 스플릿-브레인 잠금 버그를 모아에도 이식
/// (2026-07-11/12, 사용자 요청으로 모아도 같은 문제 있는지 점검).
///
/// 실측 확인: 잠긴 완전 차단 스케줄에 리필(완화) 요청을 하면, 스케줄 레벨
/// enforcementMode는 fullBlock으로 유지되는데 앱별 타깃 항목만 limitEnabled로
/// 바뀌어 모순 상태가 됐고, 채팅은 "리필 스케줄을 만들었어요"라고 거짓 성공
/// 보고를 했다. Cage와 같은 수정(ScheduleAppTargetsGuard로 완화만 막고 강화는
/// 허용, 막힌 완화는 SchedulePendingTargetService에 예약)을 이식.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    final dir = Directory.systemTemp
        .createTempSync('isle_moa_relaxation_reservation_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await ScheduleRuleStore.ensureOpen();
    await SchedulePendingTargetStore.ensureOpen();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('완전 차단 스케줄에 겹치는 리필(완화) 요청 → 스케줄·타깃 항목이 '
      '일관되게 거부되고, 예약 큐에 들어가서 채팅으로 정직하게 안내된다',
      () async {
    final fullBlockPlan = BlockChatPlan(
      action: 'night_schedule',
      scheduleName: '유튜브 야간 (테스트)',
      limitPlatform: 'youtube',
      startHour: 22,
      endHour: 9,
      endMinute: 30,
    );
    final r1 = await BlockChatExecutor.apply(fullBlockPlan);
    expect(r1.isFailure, false, reason: r1.summary);

    final schedule = BlockScheduleStore.loadAll()
        .firstWhere((s) => s.name.contains('유튜브 야간'));
    var entry = ScheduleAppTargetsStore.entryFor(schedule.id, 'isle_youtube');
    expect(entry?.blockInSlot, true);

    final refillPlan = BlockChatPlan(
      action: 'night_schedule',
      scheduleName: '유튜브 야간 (테스트)',
      limitPlatform: 'youtube',
      startHour: 0,
      endHour: 6,
      sessionMinutes: 10,
      windowMinutes: 50,
    );
    final r2 = await BlockChatExecutor.apply(refillPlan);
    expect(r2.isFailure, false, reason: r2.summary);

    // 스플릿-브레인 없음 — 스케줄 레벨·타깃 레벨 둘 다 완전 차단 유지.
    final after = BlockScheduleStore.loadAll()
        .firstWhere((s) => s.id == schedule.id);
    expect(after.enforcementMode.name, 'fullBlock');
    entry = ScheduleAppTargetsStore.entryFor(schedule.id, 'isle_youtube');
    expect(entry?.blockInSlot, true,
        reason: '완화가 잠금 때문에 거부됐으면 타깃 항목도 완전 차단으로 남아야 함');
    expect(entry?.limitEnabled, false);

    // 거짓 성공 보고("리필 스케줄을 만들었어요")가 아니라 정직하게 안내.
    expect(r2.summary, contains('완화 요청은 잠금 중이라'));
    expect(r2.summary, contains('적용돼요'));

    final pending = SchedulePendingTargetStore.loadForSchedule(schedule.id);
    expect(pending, isNotEmpty);
    expect(pending.first.targetId, 'isle_youtube');
  });

  test('강화(완전 차단으로 더 세게) 요청은 잠금 중에도 즉시 반영된다', () async {
    final refillPlan = BlockChatPlan(
      action: 'night_schedule',
      scheduleName: '인스타 야간 (테스트)',
      limitPlatform: 'instagram',
      startHour: 22,
      endHour: 9,
      endMinute: 30,
      sessionMinutes: 15,
      windowMinutes: 20,
    );
    final r1 = await BlockChatExecutor.apply(refillPlan);
    expect(r1.isFailure, false, reason: r1.summary);

    final fullBlockPlan = BlockChatPlan(
      action: 'night_schedule',
      scheduleName: '인스타 야간 (테스트)',
      limitPlatform: 'instagram',
      startHour: 22,
      endHour: 9,
      endMinute: 30,
    );
    final r2 = await BlockChatExecutor.apply(fullBlockPlan);
    expect(r2.isFailure, false, reason: r2.summary);

    final schedule = BlockScheduleStore.loadAll()
        .firstWhere((s) => s.name.contains('인스타 야간'));
    final entry = ScheduleAppTargetsStore.entryFor(schedule.id, 'isle_instagram');
    expect(entry?.blockInSlot, true,
        reason: '강화 요청은 잠금과 무관하게 즉시 반영돼야 함');
    expect(r2.summary, isNot(contains('완화 요청은 잠금 중이라')));

    final pending = SchedulePendingTargetStore.loadForSchedule(schedule.id);
    expect(pending, isEmpty, reason: '강화는 예약 큐에 들어가면 안 됨');
  });
}
