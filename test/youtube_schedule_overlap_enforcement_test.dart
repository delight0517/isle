import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/block_schedule.dart';
import 'package:isle/core/block_schedule/models/schedule_app_target_entry.dart';
import 'package:isle/core/block_schedule/models/schedule_enforcement_mode.dart';
import 'package:isle/core/block_schedule/models/schedule_slot.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/block_schedule/schedule_bundle_usage_store.dart';
import 'package:isle/core/block_schedule/schedule_target_access_guard.dart';
import 'package:isle/core/library/platform_watch_limit_store.dart';
import 'package:isle/core/services/isle_user_defaults.dart';
import 'package:isle/core/usage_budget/usage_budget_store.dart';
import 'package:isle/core/youtube/youtube_access_guard.dart';
import 'package:isle/core/youtube/youtube_watch_timer_store.dart';

/// 여러 스케줄이 같은 앱(유튜브)을 겹쳐 겨냥할 때 "매 순간 가장 제한적인
/// 규칙이 승리"하는지, 특히 인앱 유튜브 웹뷰가 스케줄 리필 한도를 실제로
/// 강제하는지 검증한다(2026-07-20 수정). 예전엔 인앱 유튜브 탭이 스케줄
/// 리필 한도(안전 라인의 시간당 10분 등)를 아예 안 봐서 겹친 스케줄이
/// "제대로 안 되는" 상태였다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_yt_overlap');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await ScheduleBundleUsageStore.ensureOpen();
    await UsageBudgetStore.ensureOpen();
    await PlatformWatchLimitStore.ensureOpen();
    await YoutubeWatchTimerStore.ensureOpen();
    await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);
  });

  setUp(() async {
    await BlockScheduleStore.saveAll(const []);
    await ScheduleBundleUsageStore.ensureOpen();
    // 각 테스트가 깨끗한 사용량·타깃에서 시작하도록 관련 박스 비우기.
    await ScheduleBundleUsageStore.box.clear();
    await ScheduleAppTargetsStore.box.clear();
  });

  // 하루 전체(모든 요일) 활성 슬롯 — 테스트 시각과 무관하게 항상 활성.
  List<ScheduleSlot> allDaySlots() => [
        for (var d = 0; d < 7; d++)
          ScheduleSlot(day: d, startMinute: 0, endMinute: 1440),
      ];

  Future<void> seedYoutubeLimitSchedule({
    required String id,
    required int limitMinutes,
    required int windowMinutes,
    List<ScheduleSlot>? slots,
  }) async {
    await BlockScheduleStore.upsert(BlockSchedule(
      id: id,
      name: id,
      slots: slots ?? allDaySlots(),
      enforcementMode: ScheduleEnforcementMode.limitInSlot,
    ));
    await ScheduleAppTargetsStore.saveForSchedule(id, [
      ScheduleAppTargetEntry(
        targetId: 'isle_youtube',
        limitEnabled: true,
        limitMinutes: limitMinutes,
        windowMinutes: windowMinutes,
      ),
    ]);
  }

  Future<void> seedYoutubeBlockSchedule({
    required String id,
    List<ScheduleSlot>? slots,
  }) async {
    await BlockScheduleStore.upsert(BlockSchedule(
      id: id,
      name: id,
      slots: slots ?? allDaySlots(),
      enforcementMode: ScheduleEnforcementMode.fullBlock,
      blockIsleInApp: true,
    ));
    await ScheduleAppTargetsStore.saveForSchedule(id, [
      const ScheduleAppTargetEntry(targetId: 'isle_youtube', blockInSlot: true),
    ]);
  }

  void watch(String scheduleId, int windowMinutes, int seconds) {
    ScheduleBundleUsageStore.addIsleTargetSeconds(
        scheduleId, 'isle_youtube', windowMinutes, seconds);
  }

  test('(a) 두 리필 스케줄이 겹치면 더 빡빡한 쪽에서 먼저 막힌다', () async {
    await seedYoutubeLimitSchedule(id: 'a10_60', limitMinutes: 10, windowMinutes: 60);
    await seedYoutubeLimitSchedule(id: 'b20_30', limitMinutes: 20, windowMinutes: 30);

    // 5분 시청 — 실제 앱처럼 두 활성 스케줄에 동시 적립. 아직 아무도 도달 안 함.
    watch('a10_60', 60, 300);
    watch('b20_30', 30, 300);
    expect(ScheduleTargetAccessGuard.isYoutubeScheduleLimitReachedNow(), isFalse);
    expect(YoutubeAccessGuard.activeLock(), isNull);

    // 다시 5분 더(누적 10분) — 빡빡한 A(10분/60분)가 도달, B(20분/30분)는 여유.
    watch('a10_60', 60, 300);
    watch('b20_30', 30, 300);
    expect(ScheduleTargetAccessGuard.isYoutubeScheduleLimitReachedNow(), isTrue);
    expect(YoutubeAccessGuard.activeLock(), YoutubeLockReason.scheduleLimit);
    expect(YoutubeAccessGuard.shouldBlockWebView, isTrue);
    // 한도 도달 후에는 그 창 사용량을 더 세지 않는다.
    expect(YoutubeAccessGuard.shouldCountWatchTime, isFalse);
  });

  test(
      '리필 한도로 막혀 있을 때 남은 시간 ETA는 겹친 스케줄 중 가장 늦게 풀리는 '
      '쪽(=최대) 기준이다', () async {
    // A: 10분/60분 한도, B: 20분/30분 한도 — 둘 다 도달시킨다.
    await seedYoutubeLimitSchedule(id: 'a10_60', limitMinutes: 10, windowMinutes: 60);
    await seedYoutubeLimitSchedule(id: 'b20_30', limitMinutes: 20, windowMinutes: 30);
    watch('a10_60', 60, 600);
    watch('b20_30', 30, 1200);
    expect(YoutubeAccessGuard.activeLock(), YoutubeLockReason.scheduleLimit);

    final eta = ScheduleTargetAccessGuard.youtubeScheduleLimitEtaSecondsSync();
    expect(eta, isNotNull);
    // A는 60분 창을 막 시작했으니 남은 시간이 B(30분 창)보다 길다 — 더 늦게
    // 풀리는 A 기준(최댓값)으로 ETA가 나와야, "아직 안 풀렸는데 곧 풀린다"고
    // 거짓 안내하는 일이 없다.
    expect(eta! > 25 * 60, isTrue, reason: 'A(60분 창)가 아직 거의 그대로 남아있어야 함');
  });

  test('막혀 있지 않으면 ETA는 null', () async {
    await seedYoutubeLimitSchedule(id: 'a10_60', limitMinutes: 10, windowMinutes: 60);
    watch('a10_60', 60, 60);
    expect(YoutubeAccessGuard.activeLock(), isNull);
    expect(ScheduleTargetAccessGuard.youtubeScheduleLimitEtaSecondsSync(), isNull);
  });

  test(
      '(e) 진짜 하루 총량 상한(dailyLimitMinutes) — 시간당 리필은 안 찼어도 '
      '하루 총량을 넘기면 막히고, 자정까지 안 풀린다', () async {
    // 시간당 60분/60분(사실상 안 막히는 리필)이지만 하루 총량 30분 상한.
    await BlockScheduleStore.upsert(BlockSchedule(
      id: 'daily_cap',
      name: 'daily_cap',
      slots: allDaySlots(),
      enforcementMode: ScheduleEnforcementMode.limitInSlot,
    ));
    await ScheduleAppTargetsStore.saveForSchedule('daily_cap', const [
      ScheduleAppTargetEntry(
        targetId: 'isle_youtube',
        limitEnabled: true,
        limitMinutes: 60,
        windowMinutes: 60,
        dailyLimitMinutes: 30,
      ),
    ]);

    // 20분 시청 — 리필 한도(60분)도, 하루 총량(30분)도 아직 안 참.
    watch('daily_cap', 60, 20 * 60);
    expect(YoutubeAccessGuard.activeLock(), isNull);

    // 다시 15분 더(누적 35분) — 리필 한도(60분/60분)는 여전히 여유 있지만
    // 하루 총량(30분)은 넘겼다 — 하루 총량이 이겨서 막혀야 한다.
    watch('daily_cap', 60, 15 * 60);
    expect(ScheduleTargetAccessGuard.isBundleLimitReachedNowSync('youtube'), isTrue);
    expect(YoutubeAccessGuard.activeLock(), YoutubeLockReason.scheduleLimit);

    // ETA는 리필 창(60분)이 아니라 자정까지여야 — 안 그러면 "곧 풀린다"는
    // 거짓 안내가 된다.
    final eta = ScheduleTargetAccessGuard.youtubeScheduleLimitEtaSecondsSync();
    expect(eta, isNotNull);
    final expectedMidnight = ScheduleBundleUsageStore.secondsUntilMidnight();
    expect((eta! - expectedMidnight).abs() < 5, isTrue,
        reason: '자정까지 남은 시간과 거의 같아야 함(리필 창 60분보다 훨씬 길어야 함)');
  });

  test('(b) 완전 차단 + 리필 한도가 겹치면 완전 차단이 이긴다', () async {
    await seedYoutubeBlockSchedule(id: 'block_all');
    await seedYoutubeLimitSchedule(id: 'limit', limitMinutes: 10, windowMinutes: 60);

    // 사용량 0이라 리필 한도는 미도달이지만, 완전 차단이 우선한다.
    expect(YoutubeAccessGuard.activeLock(), YoutubeLockReason.schedule);
    expect(YoutubeAccessGuard.shouldBlockWebView, isTrue);
    expect(YoutubeAccessGuard.shouldCountWatchTime, isFalse);
  });

  test('(c) 무제한 개인 스케줄이 있어도 하루 총량(2시간) 스케줄이 소진되면 막힌다', () async {
    // 안전 라인 성격의 하루 총량 상한(120분/매일) + 무제한 개인 스케줄.
    await seedYoutubeLimitSchedule(id: 'daily_cap', limitMinutes: 120, windowMinutes: 1440);
    // 개인 스케줄: 유튜브에 아무 한도·차단 없음(=무제한 주장).
    await BlockScheduleStore.upsert(BlockSchedule(
      id: 'personal_unlimited',
      name: 'personal_unlimited',
      slots: allDaySlots(),
      enforcementMode: ScheduleEnforcementMode.limitInSlot,
    ));
    await ScheduleAppTargetsStore.saveForSchedule('personal_unlimited', const []);

    watch('daily_cap', 1440, 119 * 60);
    expect(ScheduleTargetAccessGuard.isYoutubeScheduleLimitReachedNow(), isFalse);

    watch('daily_cap', 1440, 60); // 정확히 120분
    expect(ScheduleTargetAccessGuard.isYoutubeScheduleLimitReachedNow(), isTrue);
    expect(YoutubeAccessGuard.activeLock(), YoutubeLockReason.scheduleLimit);
  });

  test('(d) 야간 완전 차단(21:30~10:00)은 그 시간대에만 이기고, 밖에서는 개인 허용이 적용', () async {
    // 야간 완전 차단(모든 요일 21:30~10:00) + 유튜브를 건드리지 않는 개인 스케줄.
    final night = [
      for (var d = 0; d < 7; d++)
        ScheduleSlot(day: d, startMinute: 21 * 60 + 30, endMinute: 10 * 60),
    ];
    await seedYoutubeBlockSchedule(id: 'night', slots: night);

    // 22:00 — 차단 창 안: 막힌다.
    final at22 = DateTime(2026, 7, 20, 22, 0);
    expect(ScheduleTargetAccessGuard.isTargetBlocked('isle_youtube', at22), isTrue);
    expect(YoutubeAccessGuard.activeLock(at22), YoutubeLockReason.schedule);

    // 12:00 — 차단 창 밖: 다른 제한이 없으니 시청 가능.
    final at12 = DateTime(2026, 7, 20, 12, 0);
    expect(ScheduleTargetAccessGuard.isTargetBlocked('isle_youtube', at12), isFalse);
    expect(YoutubeAccessGuard.activeLock(at12), isNull);
  });

  test('활성 유튜브 리필 한도가 있으면 전역 한도 없이도 사용량을 집계한다', () async {
    await seedYoutubeLimitSchedule(id: 'refill', limitMinutes: 10, windowMinutes: 60);
    // 전역 UsageBudget/WatchTimer는 꺼져 있음.
    expect(ScheduleTargetAccessGuard.hasActiveYoutubeLimitNow(), isTrue);
    expect(YoutubeAccessGuard.shouldCountWatchTime, isTrue);
  });
}
