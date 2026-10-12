import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:isle/core/block_schedule/app_block_config_service.dart';
import 'package:isle/core/block_schedule/app_block_pause_service.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/schedule_enforcement_mode.dart';
import 'package:isle/core/block_schedule/models/schedule_slot.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/intervention/schedule_screen_time_store.dart';
import 'package:isle/core/services/isle_user_defaults.dart';

/// AppBlockConfigService가 앱 하나(bundleId)당 스케줄을 정확히 1개만
/// 유지하는지 — 모드(항상 차단/시간표/나눠 쓰기)를 몇 번 바꿔도 새 스케줄이
/// 쌓이지 않아야 한다. co-mingle 버그(BlockChatScheduleDedup의 fuzzy 매칭)를
/// 피하려고 결정적 이름("$앱 차단 설정")만 쓰는 설계를 검증한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory testDirectory;

  setUpAll(() async {
    const secure =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    testDirectory =
        Directory.systemTemp.createTempSync('isle_app_block_config_test');
    Hive.init(testDirectory.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
  });

  setUp(() async {
    await BlockScheduleStore.saveAll([]);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (testDirectory.existsSync()) testDirectory.deleteSync(recursive: true);
  });

  test('mode switches (always -> schedule -> refill) reuse the same schedule',
      () async {
    await AppBlockConfigService.applyAlwaysBlock('kakao_talk', true);
    final afterAlways = BlockScheduleStore.loadAll()
        .where((s) => s.name.contains('카카오톡'))
        .toList();
    expect(afterAlways.length, 1);
    final id = afterAlways.first.id;
    expect(
        afterAlways.first.enforcementMode, ScheduleEnforcementMode.fullBlock);
    expect(afterAlways.first.slots.length, 7);

    await AppBlockConfigService.applyTimeWindow(
      'kakao_talk',
      slots: const [ScheduleSlot(day: 0, startMinute: 60, endMinute: 120)],
    );
    final afterWindow = BlockScheduleStore.loadAll()
        .where((s) => s.name.contains('카카오톡'))
        .toList();
    expect(afterWindow.length, 1, reason: '모드를 바꿔도 같은 스케줄을 갱신해야지 새로 만들면 안 됨');
    expect(afterWindow.first.id, id);
    expect(afterWindow.first.slots.length, 1);

    await AppBlockConfigService.applyRefill(
      'kakao_talk',
      slots: const [ScheduleSlot(day: 0, startMinute: 60, endMinute: 120)],
      sessionMinutes: 3,
      windowMinutes: 10,
    );
    final afterRefill = BlockScheduleStore.loadAll()
        .where((s) => s.name.contains('카카오톡'))
        .toList();
    expect(afterRefill.length, 1, reason: '세 번째 모드 전환에도 스케줄이 여전히 1개여야 함');
    expect(afterRefill.first.id, id);
    expect(
        afterRefill.first.enforcementMode, ScheduleEnforcementMode.limitInSlot);

    final entry = ScheduleAppTargetsStore.entryFor(id, 'ios_kakao');
    expect(entry, isNotNull);
    expect(entry!.limitEnabled, true);
    expect(entry.limitMinutes, 3);
    expect(entry.windowMinutes, 10);
    expect(entry.blockInSlot, false);
  });

  test('applyOff disables the schedule without deleting it', () async {
    await AppBlockConfigService.applyAlwaysBlock('tiktok', true);
    final before = await AppBlockConfigService.existingFor('tiktok');
    expect(before, isNotNull);
    expect(before!.enabled, true);

    await AppBlockConfigService.applyOff('tiktok');
    final after = await AppBlockConfigService.existingFor('tiktok');
    expect(after, isNotNull, reason: '재사용을 위해 스케줄 자체는 남아 있어야 함');
    expect(after!.enabled, false);
    final entry = ScheduleAppTargetsStore.entryFor(after.id, 'ios_tiktok');
    expect(entry!.blockInSlot, false);
    expect(entry.limitEnabled, false);
  });

  test('different apps never share a schedule', () async {
    await AppBlockConfigService.applyAlwaysBlock('kakao_talk', true);
    await AppBlockConfigService.applyAlwaysBlock('tiktok', true);
    final kakao = await AppBlockConfigService.existingFor('kakao_talk');
    final tiktok = await AppBlockConfigService.existingFor('tiktok');
    expect(kakao, isNotNull);
    expect(tiktok, isNotNull);
    expect(kakao!.id, isNot(tiktok!.id));
  });

  test('temporary pause only releases its app and cancel reapplies it',
      () async {
    await AppBlockConfigService.applyAlwaysBlock('youtube', true);
    await AppBlockConfigService.applyAlwaysBlock('safari', true);

    await AppBlockPauseService.pauseFor('youtube', 1);

    final youtube = await AppBlockConfigService.existingFor('youtube');
    final safari = await AppBlockConfigService.existingFor('safari');
    expect(AppBlockPauseService.isPaused('youtube'), isTrue);
    expect(youtube!.enabled, isFalse);
    expect(safari!.enabled, isTrue,
        reason: 'YouTube pause must not release Safari');

    await AppBlockPauseService.cancelPause('youtube');

    expect(AppBlockPauseService.isPaused('youtube'), isFalse);
    expect(
        (await AppBlockConfigService.existingFor('youtube'))!.enabled, isTrue);
    expect(
        (await AppBlockConfigService.existingFor('safari'))!.enabled, isTrue);
  });

  test('app resume restores an expired pause from persisted deadline',
      () async {
    await AppBlockConfigService.applyAlwaysBlock('kakao_talk', true);
    final schedule = await AppBlockConfigService.existingFor('kakao_talk');
    await BlockScheduleStore.upsert(schedule!.copyWith(enabled: false));
    await IsleUserDefaults.setAppBlockPauseUntilMs(
      'kakao_talk',
      DateTime.now()
          .subtract(const Duration(seconds: 1))
          .millisecondsSinceEpoch,
    );

    await AppBlockPauseService.checkAndRestoreIfExpired('kakao_talk');

    expect(AppBlockPauseService.isPaused('kakao_talk'), isFalse);
    expect((await AppBlockConfigService.existingFor('kakao_talk'))!.enabled,
        isTrue);
  });

  test(
      'existingFor finds a chat-created schedule with a different name (2026-07-07)',
      () async {
    // 챗(block_chat_executor._nightSchedule)이 만드는 스케줄은 "카카오톡 야간
    // 리필 (AI)"처럼 AppBlockConfigService의 고정 이름 규약("카카오톡 차단
    // 설정")을 안 씀 — 홈 카드가 이걸 "미설정"으로 잘못 보이던 버그 회귀 방지.
    final chatSchedule = await BlockScheduleStore.create(
      name: '카카오톡 야간 리필 (AI)',
      slots: const [
        ScheduleSlot(day: 0, startMinute: 22 * 60, endMinute: 9 * 60)
      ],
      enforcementMode: ScheduleEnforcementMode.limitInSlot,
    );
    final entries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(chatSchedule.id),
    ).map((e) {
      if (e.targetId == 'ios_kakao') {
        return e.copyWith(
            limitEnabled: true, limitMinutes: 3, windowMinutes: 10);
      }
      return e;
    }).toList();
    await ScheduleAppTargetsStore.saveForSchedule(chatSchedule.id, entries);

    final found = await AppBlockConfigService.existingFor('kakao_talk');
    expect(found, isNotNull, reason: '이름이 달라도 targetId 기준으로 찾아야 함');
    expect(found!.id, chatSchedule.id);

    // loadOrCreate도 이 스케줄을 재사용해야지, 고정 이름으로 새로 만들면 안 됨.
    final loaded = await AppBlockConfigService.loadOrCreate('kakao_talk');
    expect(loaded.id, chatSchedule.id);
    expect(
      BlockScheduleStore.loadAll().where((s) => s.name.contains('카카오톡')).length,
      1,
      reason: '챗 스케줄을 재사용하지 않고 새로 만들면 중복 스케줄이 생김',
    );
  });
}
