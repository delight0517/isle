import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';
import 'block_schedule_enforcement_service.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'models/schedule_enforcement_mode.dart';
import 'models/schedule_slot.dart';
import 'schedule_app_target_catalog.dart';
import 'schedule_app_targets_service.dart';
import 'schedule_app_targets_store.dart';

/// 설치 시 자동으로 켜지는 "최소한의 안전 라인" — 챗으로 반복 수정하다가
/// 기존 설정이 통째로 날아가는 사고(사용자 제보, 2026-07-16)를 막기 위한
/// 최소 보장선. 일반 챗 스케줄과 똑같이 `locked:true`(커밋먼트 잠금)로 만들어
/// 기존 [ScheduleLockService]/[ScheduleEditGuard] 메커니즘을 그대로 재사용한다
/// — 이미 "스위치 내리기 + 타임락 대기 후에만 편집 가능"이 구현돼 있어서
/// 새로 만들 필요가 없다. 챗도 이 스케줄을 잠금 상태에서는 절대 못 끄고,
/// 편집 창이 열려야만(=타임락을 다 기다려야만) 끌 수 있다 — 그 흐름은
/// 일반 잠긴 스케줄과 동일하다.
///
/// 조건(2026-07-16 사용자 지정):
/// 1) 유튜브 하루 총 시청 최대 2시간 — 아래 2)번 리필 한도(10:00~21:30,
///    시간당 10분 ≈ 최대 115분)로 이미 2시간 밑에서 자동으로 만족된다.
///    iOS Screen Time은 "리필 윈도우와 별개인 하루 총량" 개념이 없어서
///    (isle 인앱 웹뷰 전용 UsageBudgetEngine에만 있고 실기기 앱엔 없음)
///    독립적인 하루 총량 항목을 따로 만들지 않고, 2)+3) 조합의 자연스러운
///    상한으로 처리한다.
/// 2) 유튜브 10:00~21:30: 1시간마다 10분만 허용 (limitInSlot)
/// 3) 유튜브·(Isle 자체) 브라우저 21:30~10:00: 완전 차단
/// 4) 유튜브 뮤직 온스크린 10:00~21:30: 매시간마다 10분만 허용(백그라운드
///    재생은 iOS DeviceActivity가 애초에 포그라운드만 재는 구조라 자동으로
///    한도 밖 — 2026-07-16 사용자 신규 조건, 유튜브(조건 2)와 동일 패턴을
///    `ios_youtube_music` 타깃으로 이식).
///
/// "인터넷 브라우저 30분 쓰고 10분 쉬기" 세션 제한은 뺐다 — 진짜 Safari는
/// 이 앱 네이티브 코드상 Content Blocker(도메인)·앱 아이콘 쉴드만 지원되고
/// [ScheduleAppTargetsStore]의 limitInSlot 리필 개념 자체가 없어서
/// (`IsleScheduleShieldSync.swift`: "Safari 전용 차단은 Content Blocker
/// 확장 + 앱 아이콘 쉴드만 사용") 세션 리필로는 못 만든다 — 사용자 확인 후
/// 21:30~10:00 완전 차단만 적용하기로 결정(2026-07-16).
///
/// **[seedIfNeeded]는 반드시 UI가 뜬 뒤(`IsleDeferredOsSyncService`)에서만
/// 호출할 것 — main.dart 부팅 시퀀스에서 직접 부르면 안 된다.** 내부에서
/// 쓰는 [ScheduleAppTargetsService.saveAndSync]가 스케줄마다
/// `syncPlatformEnforcement`(네이티브 Screen Time 호출)를 부르는데, 이걸
/// 부팅 도중(UI 표시 전) 기다리면 기기의 첫 Screen Time 인증 절차와 얽혀
/// 부팅이 영영 안 끝나는 "무한 로딩 화면" 사고가 실기기에서 났다
/// (2026-[REDACTED]). 무거운 OS 동기화는 UI가 뜬 뒤에만 하기로 한 기존 규칙
/// (`IsleDeferredOsSyncService` 클래스 doc)을 그대로 따른다.
class SafetyBaselineService {
  SafetyBaselineService._();

  static const _seededKey = 'safety_baseline_seeded_v1';
  // 록다운은 기존 안전 라인(v1)이 이미 심어진 기기에도 나중에 새로 추가된
  // 조건이라 별도 게이트를 쓴다 — _seededKey만 재사용하면 이미 v1이 심어진
  // 기존 사용자에게는 록다운이 영원히 안 생긴다(2026-[REDACTED]).
  static const _lockdownSeededKey = 'safety_baseline_lockdown_seeded_v1';

  static const nightBlockScheduleId = 'safety_baseline_night_block';
  static const youtubeRefillScheduleId = 'safety_baseline_youtube_refill';
  static const youtubeMusicRefillScheduleId =
      'safety_baseline_youtube_music_refill';
  static const lockdownScheduleId = 'safety_baseline_lockdown';

  static const nightBlockName = '안전 라인 — 야간 완전 차단 (21:30~10:00)';
  static const youtubeRefillName = '안전 라인 — 유튜브 시간당 10분 (10:00~21:30)';
  static const youtubeMusicRefillName =
      '안전 라인 — 유튜브 뮤직 시간당 10분 (10:00~21:30)';
  static const lockdownName = '안전 라인 — 올나이트 록다운 (23:00~07:00)';

  static const lockCooldownMinutes = 15;

  static const _nightStartMinute = 21 * 60 + 30; // 21:30
  static const _nightEndMinute = 10 * 60; // 10:00
  static const _dayStartMinute = 10 * 60; // 10:00
  static const _dayEndMinute = 21 * 60 + 30; // 21:30
  static const _lockdownStartMinute = 23 * 60; // 23:00
  static const _lockdownEndMinute = 7 * 60; // 07:00

  static Box<String> get _prefs => Hive.box<String>('isle_cache');

  static bool get isSeeded => _prefs.get(_seededKey) == '1';
  static bool get isLockdownSeeded => _prefs.get(_lockdownSeededKey) == '1';

  /// 앱 부팅 시 1회 — 이미 심어져 있으면 아무것도 안 함(사용자가 나중에
  /// 안전 라인 스케줄을 지워도 다시 만들지 않는다 — "설치 시 자동"이지
  /// "삭제해도 되살아남"은 요구사항에 없었다).
  static Future<void> seedIfNeeded() async {
    if (!isSeeded) {
      await _prefs.put(_seededKey, '1');

      await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);
      await _seedNightBlock();
      await _seedYoutubeHourlyRefill();
      await _seedYoutubeMusicHourlyRefill();

      IsleAppLogService.log(
        '안전 라인으로 인한 활성화 — 21:30~10:00 완전 차단 + '
        '10:00~21:30 유튜브·유튜브 뮤직 시간당 10분',
      );
    }
    if (!isLockdownSeeded) {
      await _prefs.put(_lockdownSeededKey, '1');
      await _seedLockdown();
      IsleAppLogService.log('안전 라인으로 인한 활성화 — 23:00~07:00 올나이트 록다운(설치 앱 전체 차단)');
    }
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
  }

  static Future<void> _seedLockdown() async {
    final slots = [
      for (var d = 0; d < 7; d++)
        ScheduleSlot(
          day: d,
          startMinute: _lockdownStartMinute,
          endMinute: _lockdownEndMinute,
        ),
    ];
    final schedule = BlockSchedule(
      id: lockdownScheduleId,
      name: lockdownName,
      enabled: true,
      locked: true,
      lockCooldownMinutes: lockCooldownMinutes,
      slots: slots,
      enforcementMode: ScheduleEnforcementMode.fullBlock,
      blockIsleInApp: true,
      isSafetyBaseline: true,
      lockdownAllApps: true,
    );
    await BlockScheduleStore.upsert(schedule);
  }

  static Future<void> _seedNightBlock() async {
    final slots = [
      for (var d = 0; d < 7; d++)
        ScheduleSlot(
          day: d,
          startMinute: _nightStartMinute,
          endMinute: _nightEndMinute,
        ),
    ];
    final schedule = BlockSchedule(
      id: nightBlockScheduleId,
      name: nightBlockName,
      enabled: true,
      locked: true,
      lockCooldownMinutes: lockCooldownMinutes,
      slots: slots,
      enforcementMode: ScheduleEnforcementMode.fullBlock,
      blockIsleInApp: true,
      isSafetyBaseline: true,
    );
    await BlockScheduleStore.upsert(schedule);

    final entries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(schedule.id),
    ).map((e) {
      if (e.targetId == 'ios_youtube' ||
          e.targetId == 'isle_youtube' ||
          e.targetId == 'ios_youtube_music') {
        return e.copyWith(blockInSlot: true, limitEnabled: false);
      }
      final def = ScheduleAppTargetCatalog.defFor(e.targetId);
      // Isle 자체 웹 탐색(브라우저 대용)도 야간에는 완전 차단 —
      // 진짜 Safari는 이 스케줄 기반 리스트에 타깃이 없어 여기선 못 건다
      // (blockIsleInApp 플래그 + Screen Time에서 사용자가 이미 선택해 둔
      // 항목이 있으면 그쪽으로 적용됨).
      if (def?.isIsle == true) return e.copyWith(blockInSlot: true);
      return e;
    }).toList();

    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: schedule.id,
      entries: entries,
      schedule: schedule,
    );
  }

  static Future<void> _seedYoutubeHourlyRefill() async {
    final slots = [
      for (var d = 0; d < 7; d++)
        ScheduleSlot(
          day: d,
          startMinute: _dayStartMinute,
          endMinute: _dayEndMinute,
        ),
    ];
    final schedule = BlockSchedule(
      id: youtubeRefillScheduleId,
      name: youtubeRefillName,
      enabled: true,
      locked: true,
      lockCooldownMinutes: lockCooldownMinutes,
      slots: slots,
      enforcementMode: ScheduleEnforcementMode.limitInSlot,
      isSafetyBaseline: true,
    );
    await BlockScheduleStore.upsert(schedule);

    final entries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(schedule.id),
    ).map((e) {
      if (e.targetId == 'ios_youtube' || e.targetId == 'isle_youtube') {
        return e.copyWith(
          blockInSlot: false,
          limitEnabled: true,
          limitMinutes: 10,
          windowMinutes: 60,
          // 조건 1: "유튜브의 최종 시청 시간은 하루 2시간이 최대" — 시간당
          // 리필만으로는 계속 도는 창이라 진짜 하드 컷이 아니었다(에뮬레이트만
          // 됨, 2026-07-20 추가). 이제 자정까지 실제로 막히는 진짜 상한.
          dailyLimitMinutes: 120,
        );
      }
      return e;
    }).toList();

    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: schedule.id,
      entries: entries,
      schedule: schedule,
    );
  }

  static Future<void> _seedYoutubeMusicHourlyRefill() async {
    final slots = [
      for (var d = 0; d < 7; d++)
        ScheduleSlot(
          day: d,
          startMinute: _dayStartMinute,
          endMinute: _dayEndMinute,
        ),
    ];
    final schedule = BlockSchedule(
      id: youtubeMusicRefillScheduleId,
      name: youtubeMusicRefillName,
      enabled: true,
      locked: true,
      lockCooldownMinutes: lockCooldownMinutes,
      slots: slots,
      enforcementMode: ScheduleEnforcementMode.limitInSlot,
      isSafetyBaseline: true,
    );
    await BlockScheduleStore.upsert(schedule);

    final entries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(schedule.id),
    ).map((e) {
      if (e.targetId == 'ios_youtube_music') {
        return e.copyWith(
          blockInSlot: false,
          limitEnabled: true,
          limitMinutes: 10,
          windowMinutes: 60,
        );
      }
      return e;
    }).toList();

    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: schedule.id,
      entries: entries,
      schedule: schedule,
    );
  }
}
