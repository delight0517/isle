import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/ai_config_store.dart';
import 'package:isle/core/ai/block_chat/block_chat_executor.dart';
import 'package:isle/core/ai/block_chat/block_chat_models.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/ai/block_chat/block_chat_schedule_dedup.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/schedule_enforcement_mode.dart';
import 'package:isle/core/block_schedule/safety_baseline_service.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/block_schedule/schedule_lock_phase.dart';
import 'package:isle/core/block_schedule/schedule_lock_service.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/intervention/schedule_screen_time_store.dart';
import 'package:isle/core/library/platform_watch_limit_store.dart';
import 'package:isle/core/usage_budget/usage_budget_store.dart';

/// "안전 라인"(최소 안전장치) — 설치 시 자동 ON. 2026-07-20 사용자 확정:
/// 채팅으로 변경을 "요청"하는 것 자체는 이제 가능하지만, 일반 잠긴 스케줄과
/// 동일하게 항상 15분 타임락 카운트다운을 거쳐야 하고 즉시·silent 적용은
/// 절대 없다 — 스위치를 내리는 것과 같은 흐름을 채팅이 대신 시작해줄 뿐이다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    final dir = Directory.systemTemp.createTempSync('isle_safety_baseline_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    await PlatformWatchLimitStore.ensureOpen();
    await UsageBudgetStore.ensureOpen();
    await AiConfigStore.ensureOpen();
    await ScheduleRuleStore.ensureOpen();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('seedIfNeeded creates the 4 protected schedules exactly once '
      '(night block + youtube hourly + youtube music hourly + lockdown)', () async {
    expect(SafetyBaselineService.isSeeded, isFalse);
    expect(SafetyBaselineService.isLockdownSeeded, isFalse);
    await SafetyBaselineService.seedIfNeeded();
    expect(SafetyBaselineService.isSeeded, isTrue);
    expect(SafetyBaselineService.isLockdownSeeded, isTrue);

    final all = BlockScheduleStore.loadAll();
    final nightBlock =
        all.where((s) => s.id == SafetyBaselineService.nightBlockScheduleId);
    final ytRefill =
        all.where((s) => s.id == SafetyBaselineService.youtubeRefillScheduleId);
    final ytMusicRefill = all.where(
        (s) => s.id == SafetyBaselineService.youtubeMusicRefillScheduleId);
    final lockdown =
        all.where((s) => s.id == SafetyBaselineService.lockdownScheduleId);
    expect(nightBlock.length, 1);
    expect(ytRefill.length, 1);
    expect(ytMusicRefill.length, 1);
    expect(lockdown.length, 1);
    expect(nightBlock.first.isSafetyBaseline, isTrue);
    expect(ytRefill.first.isSafetyBaseline, isTrue);
    expect(ytMusicRefill.first.isSafetyBaseline, isTrue);
    expect(lockdown.first.isSafetyBaseline, isTrue);
    expect(nightBlock.first.locked, isTrue);
    expect(ytRefill.first.locked, isTrue);
    expect(ytMusicRefill.first.locked, isTrue);
    expect(lockdown.first.locked, isTrue);
    expect(lockdown.first.lockdownAllApps, isTrue);
    expect(
      lockdown.first.slots.every((s) => s.startMinute == 23 * 60 && s.endMinute == 7 * 60),
      isTrue,
    );

    // 조건 4: 유튜브 뮤직 온스크린 시간당 10분(포그라운드 리필 방식 —
    // 백그라운드 재생은 iOS DeviceActivity가 애초에 포그라운드만 재므로
    // 별도 예외 처리가 필요 없다).
    final musicEntry = ScheduleAppTargetsStore.loadForSchedule(
      SafetyBaselineService.youtubeMusicRefillScheduleId,
    ).firstWhere((e) => e.targetId == 'ios_youtube_music');
    expect(musicEntry.limitEnabled, isTrue);
    expect(musicEntry.limitMinutes, 10);
    expect(musicEntry.windowMinutes, 60);

    // 조건 1: "유튜브의 최종 시청 시간은 하루 2시간이 최대" — 시간당 리필과
    // 별개인 진짜 하루 총량 상한(자정에야 풀림, 2026-07-20 추가).
    final ytEntry = ScheduleAppTargetsStore.loadForSchedule(
      SafetyBaselineService.youtubeRefillScheduleId,
    ).firstWhere((e) => e.targetId == 'ios_youtube');
    expect(ytEntry.dailyLimitMinutes, 120);

    // 재호출해도 스케줄이 늘어나지 않아야 함(멱등).
    await SafetyBaselineService.seedIfNeeded();
    expect(
      BlockScheduleStore.loadAll()
          .where((s) => s.isSafetyBaseline)
          .length,
      4,
    );
  });

  test(
      'chat request against a safety-baseline schedule queues a 15-min '
      'timelock instead of refusing outright or applying instantly',
      () async {
    await SafetyBaselineService.seedIfNeeded();
    const plan = BlockChatPlan(
      action: 'remove_schedule',
      scheduleQuery: SafetyBaselineService.nightBlockName,
    );
    final result = await BlockChatExecutor.apply(plan);

    expect(result.isFailure, isFalse,
        reason: '더 이상 즉시 거부하지 않는다 — 요청은 받아들이되 큐잉만 됨');
    expect(result.needsUnlockWait, isTrue,
        reason: '이름이 정확히 겹치는 요청이라도 겹친 안전 라인 스케줄이 여러 개면 '
            '_relaxBlock(scope=all)로 새는데, 그 경로도 needsUnlockWait로 '
            '"즉시 안 됨"을 표시해야 함');

    final schedule = BlockScheduleStore.loadAll()
        .firstWhere((s) => s.id == SafetyBaselineService.nightBlockScheduleId);
    expect(ScheduleLockService.phase(schedule), ScheduleLockPhase.countdown,
        reason: '채팅 요청이 스위치를 내린 것과 동일하게 카운트다운을 시작시켜야 함');
  });

  test(
      'chat cannot remove a safety-baseline schedule instantly — it stays '
      'fully enforced through the 15-min countdown, and only actually turns '
      'off once the timelock has genuinely elapsed (simulated)', () async {
    await SafetyBaselineService.seedIfNeeded();
    const plan = BlockChatPlan(
      action: 'remove_schedule',
      scheduleQuery: SafetyBaselineService.nightBlockName,
    );

    await BlockChatExecutor.apply(plan);

    // 카운트다운 시작 직후 — 여전히 완전히 그대로 보호돼야 함.
    var protected = BlockScheduleStore.loadAll()
        .where((s) => s.id == SafetyBaselineService.nightBlockScheduleId);
    expect(protected.length, 1);
    expect(protected.first.locked, isTrue);
    expect(protected.first.enabled, isTrue);
    expect(protected.first.enforcementMode, ScheduleEnforcementMode.fullBlock);

    // 15분이 이미 지난 것처럼 시뮬레이션(실시간 대기 대신 타임스탬프 조작).
    // upsert()는 SchedulePersistGuard(ScheduleImportGuard.mergeIncoming)를
    // 거치는데, 그 가드는 "아직 잠긴(=countdown) 스케줄"의 unlockStartedAtMs를
    // 항상 기존 값으로 되돌려버려서(=바로 이 테스트가 뚫으려는 그 우회 방지
    // 로직) 여기서 시간 조작이 씹힌다 — ScheduleLockService.startUnlockCountdown
    // 자신이 쓰는 저수준 saveAll()로 직접 써야 실제 "시간이 지남"을 흉내낼 수 있다.
    final list = BlockScheduleStore.loadAll();
    final idx = list.indexWhere(
        (s) => s.id == SafetyBaselineService.nightBlockScheduleId);
    final started = list[idx].copyWith(
      unlockStartedAtMs: DateTime.now()
          .subtract(const Duration(minutes: 20))
          .millisecondsSinceEpoch,
    );
    list[idx] = started;
    await BlockScheduleStore.saveAll(list);
    expect(ScheduleLockService.phase(started), ScheduleLockPhase.editWindow);

    // 편집 창에서 같은 요청을 다시 보내면 그제서야 실제로 꺼짐 — 즉시도 아니고
    // silent도 아니고, 명시적으로 다시 요청했을 때만 적용됨.
    final second = await BlockChatExecutor.apply(plan);
    expect(second.isFailure, isFalse);

    protected = BlockScheduleStore.loadAll()
        .where((s) => s.id == SafetyBaselineService.nightBlockScheduleId);
    expect(protected.first.enabled, isFalse,
        reason: '편집 창이 열린 뒤 명시적으로 재요청했을 때만 실제로 꺼져야 함');
  });

  test('reset_all_blocks (모든 차단 초기화) never wipes safety-baseline schedules',
      () async {
    await SafetyBaselineService.seedIfNeeded();
    await BlockChatExecutor.performFullReset();

    final all = BlockScheduleStore.loadAll();
    expect(
      all.any((s) => s.id == SafetyBaselineService.nightBlockScheduleId),
      isTrue,
      reason: '안전 라인은 "모든 차단 초기화"로도 절대 지워지면 안 됨',
    );
    expect(
      all.any((s) => s.id == SafetyBaselineService.youtubeRefillScheduleId),
      isTrue,
    );
  });

  test(
      'fuzzy dedup (findNightSns/findExactName/findAiNamedPack) never returns '
      'a safety-baseline schedule — an unrelated night-block chat request must '
      'not hijack/overwrite it', () async {
    await SafetyBaselineService.seedIfNeeded();

    final byExactName =
        BlockChatScheduleDedup.findExactName(SafetyBaselineService.nightBlockName);
    expect(byExactName, isNull,
        reason: 'exact-name lookup은 실제 사용자가 그 이름 그대로 입력했을 때만 '
            '쓰이는데, 그마저도 안전 라인 후보에서 빠져야 재사용 시도 자체가 '
            '생기지 않음(대신 chat executor가 이름 매치 실패로 새 스케줄을 '
            '만들려다가 다른 dedup 경로로도 이 스케줄을 못 찾아야 함)');

    final byNight = BlockChatScheduleDedup.findNightSns(
      targetIds: const ['ios_youtube'],
    );
    expect(
      byNight?.id,
      isNot(SafetyBaselineService.nightBlockScheduleId),
      reason: 'ios_youtube를 겨냥한 무관한 야간 차단 요청이 안전 라인의 '
          '21:30~10:00 완전 차단 스케줄을 "기존 스케줄"로 오인해 재사용하면 '
          '안 됨',
    );

    final byAiPack = BlockChatScheduleDedup.findAiNamedPack('youtube');
    expect(byAiPack?.id, isNot(SafetyBaselineService.youtubeRefillScheduleId));
  });

  /// 사용자 요청(2026-07-16): "채팅을 통해서 혹시 모르게 그냥 중복되는 것을
  /// 해제할 수 있는지도 테스트해줘" — 다양한 실사용 문구로 직접 채팅 파이프라인
  /// (파서→실행기) 전체를 태워서, 안전 라인 3개가 어떤 경로로도 안 지워지고
  /// 안 풀리고 시간·한도가 안 바뀌는지 스윕 테스트.
  void expectBaselineIntact() {
    final all = BlockScheduleStore.loadAll();
    final baseline = all.where((s) => s.isSafetyBaseline).toList();
    expect(baseline.length, 4, reason: '안전 라인 4개가 그대로 있어야 함');
    final night = baseline
        .firstWhere((s) => s.id == SafetyBaselineService.nightBlockScheduleId);
    expect(night.locked, isTrue);
    expect(night.enabled, isTrue);
    expect(night.enforcementMode, ScheduleEnforcementMode.fullBlock);
    final yt = baseline.firstWhere(
        (s) => s.id == SafetyBaselineService.youtubeRefillScheduleId);
    expect(yt.locked, isTrue);
    expect(yt.enabled, isTrue);
    final ytEntry = ScheduleAppTargetsStore.loadForSchedule(yt.id)
        .firstWhere((e) => e.targetId == 'ios_youtube');
    expect(ytEntry.limitMinutes, 10);
    expect(ytEntry.windowMinutes, 60);
    final ytMusic = baseline.firstWhere(
        (s) => s.id == SafetyBaselineService.youtubeMusicRefillScheduleId);
    expect(ytMusic.locked, isTrue);
    expect(ytMusic.enabled, isTrue);
  }

  group('중복/우회 시도 스윕 — 실제 챗 파이프라인(파서→실행기) 전체를 태워서 확인', () {
    setUp(() async {
      await SafetyBaselineService.seedIfNeeded();
    });

    final bypassAttempts = <String>[
      '유튜브 차단 다 풀어줘',
      '유튜브 지금 좀 급한 일 있어서 잠깐 풀어줘',
      '모든 차단 초기화',
      '차단 싹 다 초기화해줘',
      '유튜브 스케줄 지워줘',
      '야간 차단 스케줄 꺼줘',
      // 안전 라인과 시간대가 겹치는 새 요청 — dedup이 "기존 스케줄"로
      // 오인해 안전 라인을 재사용(=덮어쓰기)하려는 가장 위험한 시나리오.
      '밤 9시반부터 아침 10시까지 유튜브 차단해줘',
      '10시부터 21시반까지 유튜브 시간당 10분만 허용해줘',
    ];

    for (final text in bypassAttempts) {
      test('"$text" — 안전 라인은 그대로 유지돼야 함', () async {
        final (plan, usedAi) = await BlockChatParser.parse(text);
        if (usedAi) return; // AI 폴백은 이 테스트 환경에서 검증 불가, 스킵.
        await BlockChatExecutor.apply(plan);
        expectBaselineIntact();
      });
    }
  });
}
