import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/block_schedule.dart';
import 'package:isle/core/block_schedule/models/pending_schedule_field_edit.dart';
import 'package:isle/core/block_schedule/models/schedule_enforcement_mode.dart';
import 'package:isle/core/block_schedule/models/schedule_slot.dart';
import 'package:isle/core/block_schedule/schedule_pending_field_service.dart';
import 'package:isle/core/block_schedule/schedule_pending_field_store.dart';
import 'package:isle/core/intervention/app_usage_limit_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/intervention/schedule_screen_time_store.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_store.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';

/// 잠금 걸린 스케줄의 시간표·이름·모드·enabled 변경 예약(2026-07-20 요청) —
/// 앱 타깃(SchedulePendingTargetService)과 동일한 패턴을 스케줄 레벨 필드까지
/// 확장한 것. "수동으로 적용을 눌러도 자동으로 timelock 이후에 적용" 검증.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('isle_pending_field_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await SchedulePendingFieldStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    await ScheduleRuleStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  Future<BlockSchedule> makeSchedule({bool locked = true}) async {
    final s = await BlockScheduleStore.create(
      name: '야간 차단',
      slots: const [ScheduleSlot(day: 0, startMinute: 1260, endMinute: 420)],
      locked: locked,
      lockCooldownMinutes: 15,
    );
    return s;
  }

  test('잠금 안 걸린 스케줄은 즉시 적용된다', () async {
    final s = await makeSchedule(locked: false);
    final desired = s.copyWith(name: '취침 모드');
    final outcome = await SchedulePendingFieldService.requestFieldChange(
      current: s,
      desired: desired,
    );
    expect(outcome.kind, ScheduleFieldChangeOutcomeKind.immediate);
    final saved = BlockScheduleStore.loadAll().firstWhere((x) => x.id == s.id);
    expect(saved.name, '취침 모드');
  });

  test('잠금 걸린 스케줄은 즉시 안 바뀌고 15분 카운트다운을 시작한다', () async {
    final s = await makeSchedule();
    final desired = s.copyWith(name: '취침 모드');
    final outcome = await SchedulePendingFieldService.requestFieldChange(
      current: s,
      desired: desired,
    );
    expect(outcome.kind, ScheduleFieldChangeOutcomeKind.scheduled);
    expect(outcome.startedCountdown, isTrue);

    final saved = BlockScheduleStore.loadAll().firstWhere((x) => x.id == s.id);
    expect(saved.name, '야간 차단', reason: '편집 창 열리기 전엔 이름이 그대로여야 함');

    final pending = SchedulePendingFieldService.pendingFor(s.id);
    expect(pending?.name, '취침 모드');
  });

  test('같은 잠금 대기 중 여러 필드를 순서대로 바꾸면 병합된다(이전 요청이 안 날아감)', () async {
    final s = await makeSchedule();
    await SchedulePendingFieldService.requestFieldChange(
      current: s,
      desired: s.copyWith(name: '취침 모드'),
    );
    // 실제 UI라면 첫 요청 후 화면이 다시 로드되며 최신(카운트다운 시작된)
    // 스케줄 상태를 들고 있는다 — 테스트에서도 최신 상태를 다시 읽어야
    // _planApply가 "이미 카운트다운 중"으로 정확히 판단한다.
    final refreshed = BlockScheduleStore.loadAll().firstWhere((x) => x.id == s.id);
    final second = await SchedulePendingFieldService.requestFieldChange(
      current: refreshed,
      desired: refreshed.copyWith(enforcementMode: ScheduleEnforcementMode.limitInSlot),
    );
    expect(second.kind, ScheduleFieldChangeOutcomeKind.alreadyPending);

    final pending = SchedulePendingFieldService.pendingFor(s.id);
    expect(pending?.name, '취침 모드', reason: '먼저 요청한 이름 변경이 안 날아가야 함');
    expect(pending?.enforcementMode, ScheduleEnforcementMode.limitInSlot);
  });

  test('바뀌는 게 없으면 noop', () async {
    final s = await makeSchedule();
    final outcome = await SchedulePendingFieldService.requestFieldChange(
      current: s,
      desired: s,
    );
    expect(outcome.kind, ScheduleFieldChangeOutcomeKind.noop);
    expect(SchedulePendingFieldService.pendingFor(s.id), isNull);
  });

  test('15분이 지나 편집 창이 열리면 processDue()가 실제로 적용한다', () async {
    final s = await makeSchedule();
    await SchedulePendingFieldService.requestFieldChange(
      current: s,
      desired: s.copyWith(
        name: '취침 모드',
        slots: const [ScheduleSlot(day: 0, startMinute: 1320, endMinute: 480)],
      ),
    );

    // 15분이 이미 지난 것처럼 시뮬레이션 — 스케줄 자체의 잠금 상태(저수준
    // saveAll()로, upsert()의 보호 가드를 우회하지 않고 안전 라인 테스트와
    // 같은 패턴)뿐 아니라, 대기 중인 편집 항목 자체의 applyAt도 과거로
    // 당겨야 한다 — processDue()는 둘 다(편집 항목의 타이머 + 스케줄의
    // 실제 편집 창 여부) 확인하는 이중 게이트라서.
    final list = BlockScheduleStore.loadAll();
    final idx = list.indexWhere((x) => x.id == s.id);
    list[idx] = list[idx].copyWith(
      unlockStartedAtMs:
          DateTime.now().subtract(const Duration(minutes: 20)).millisecondsSinceEpoch,
    );
    await BlockScheduleStore.saveAll(list);

    final pendingBefore = SchedulePendingFieldStore.findFor(s.id)!;
    await SchedulePendingFieldStore.saveAll([
      ...SchedulePendingFieldStore.loadAll().where((p) => p.scheduleId != s.id),
      PendingScheduleFieldEdit(
        scheduleId: pendingBefore.scheduleId,
        applyAtMs: DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
        scheduledAtMs: pendingBefore.scheduledAtMs,
        name: pendingBefore.name,
        slots: pendingBefore.slots,
        enforcementMode: pendingBefore.enforcementMode,
        enabled: pendingBefore.enabled,
      ),
    ]);

    final applied = await SchedulePendingFieldService.processDue();
    expect(applied, 1);

    final saved = BlockScheduleStore.loadAll().firstWhere((x) => x.id == s.id);
    expect(saved.name, '취침 모드');
    expect(saved.slots.first.startMinute, 1320);
    expect(SchedulePendingFieldService.pendingFor(s.id), isNull,
        reason: '적용됐으면 대기 목록에서 빠져야 함');
  });
}
