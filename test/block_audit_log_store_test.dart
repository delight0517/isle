import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_audit_log_store.dart';
import 'package:isle/core/constants/app_release_info.dart';
import 'package:isle/core/services/app_update_audit_service.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/block_schedule.dart';
import 'package:isle/core/block_schedule/models/schedule_slot.dart';
import 'package:isle/core/services/isle_user_defaults.dart';

/// "언제·어디서·어떤 커맨드가 스케줄을 리셋했는지" 원인 분석용 감사 로그
/// (2026-07-16 요청) — 2주 보관·버전 스탬프·업데이트 감지를 검증한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('isle_audit_log_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await BlockAuditLogStore.ensureOpen();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('record()가 항목마다 현재 앱 버전을 찍는다', () async {
    await BlockAuditLogStore.record(
      command: '유튜브 차단해줘',
      action: 'night_schedule',
      summary: '야간 유튜브 차단 스케줄을 만들었어요.',
      steps: const ['야간 스케줄: 매일 21:00-07:00'],
      success: true,
    );
    final entries = BlockAuditLogStore.loadRecent();
    expect(entries, hasLength(1));
    expect(entries.first.appVersion, AppReleaseInfo.pubspecVersion);
  });

  test('14일 이내 항목은 보존, 그보다 오래된 항목은 pruneNow에서 사라진다', () async {
    await BlockAuditLogStore.record(
      command: 'x',
      action: 'a',
      summary: 's',
      steps: const [],
      success: true,
    );
    // 15일 전 항목을 직접 주입 — retention(14일) 밖이라 다음 prune에서 지워져야 함.
    final stale = BlockAuditLogEntry(
      id: 'stale',
      at: DateTime.now().subtract(const Duration(days: 15)),
      command: 'old',
      action: 'a',
      summary: 's',
      steps: const [],
      success: true,
      appVersion: '0.0.0',
    );
    final current = BlockAuditLogStore.loadRecent();
    // 내부 저장 포맷 그대로 다시 써서 오래된 항목을 섞는다 —
    // (loadRecent()는 항상 pruned 결과라 저장 원본을 직접 읽어 개수를 확인한다)
    final merged = [...current, stale];
    await Hive.box<String>('isle_block_audit_log').put(
      'entries_v1',
      '[${merged.map((e) => _toJsonString(e)).join(',')}]',
    );
    final rawStored = Hive.box<String>('isle_block_audit_log').get('entries_v1')!;
    expect(RegExp('"id":').allMatches(rawStored).length, 2);
    final pruned = BlockAuditLogStore.loadRecent();
    expect(pruned, hasLength(1));
    expect(pruned.first.id, isNot('stale'));
  });

  test('AppUpdateAuditService — 저장된 버전과 다르면 감사 로그에 남긴다', () async {
    await IsleUserDefaults.setLastSeenAppVersion('0.0.1');
    await IsleUserDefaults.setLastKnownScheduleCount(0);
    await AppUpdateAuditService.checkAndRecord();
    final entries = BlockAuditLogStore.loadRecent();
    expect(entries, hasLength(1));
    expect(entries.first.action, 'app_update');
    expect(entries.first.command, contains('0.0.1'));
    expect(entries.first.command, contains(AppReleaseInfo.pubspecVersion));
  });

  test('AppUpdateAuditService — 업데이트 직후 스케줄이 0으로 사라지면 실패로 표시', () async {
    await BlockScheduleStore.create(
      name: 'temp',
      slots: const [ScheduleSlot(day: 0, startMinute: 60, endMinute: 120)],
    );
    await IsleUserDefaults.setLastSeenAppVersion('0.0.1');
    await IsleUserDefaults.setLastKnownScheduleCount(3);
    // 실제 스케줄은 1개뿐이지만 "이전엔 3개였다"는 저장값과 비교해 급감 여부만 본다.
    // (0개까지는 아니므로 실패로 안 찍히는지도 함께 확인)
    await AppUpdateAuditService.checkAndRecord();
    final entries = BlockAuditLogStore.loadRecent();
    expect(entries.first.success, isTrue);

    await BlockScheduleStore.saveAll(const []);
    await IsleUserDefaults.setLastSeenAppVersion('0.0.1');
    await IsleUserDefaults.setLastKnownScheduleCount(3);
    await AppUpdateAuditService.checkAndRecord();
    final after = BlockAuditLogStore.loadRecent();
    expect(after.first.success, isFalse);
    expect(after.first.summary, contains('사라짐'));
  });

  test('첫 부팅(저장된 이전 버전 없음)은 업데이트로 기록하지 않는다', () async {
    await AppUpdateAuditService.checkAndRecord();
    expect(BlockAuditLogStore.loadRecent(), isEmpty);
    expect(IsleUserDefaults.lastSeenAppVersion, AppReleaseInfo.pubspecVersion);
  });
}

String _toJsonString(BlockAuditLogEntry e) {
  final j = e.toJson();
  final buf = StringBuffer('{');
  var first = true;
  j.forEach((k, v) {
    if (!first) buf.write(',');
    first = false;
    if (v is String) {
      buf.write('"$k":"${v.replaceAll('"', '\\"')}"');
    } else if (v is bool) {
      buf.write('"$k":$v');
    } else if (v is List) {
      buf.write('"$k":[]');
    }
  });
  buf.write('}');
  return buf.toString();
}
