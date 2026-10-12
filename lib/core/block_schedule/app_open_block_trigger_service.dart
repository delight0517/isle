import '../services/isle_user_defaults.dart';
import '../services/trusted_time_guard.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'models/schedule_enforcement_mode.dart';
import 'models/schedule_slot.dart';
import 'schedule_app_targets_service.dart';
import 'schedule_app_targets_store.dart';

/// 앱 켠 지 N분 트리거("아침에 모아 앱에 들어가서 킨지 30분 동안은 유튜브에
/// 못 들어가게 해줘", 2026-07-20 신설) — 하루 중 (설정에 따라 컷오프 시각
/// 이전) 처음 앱을 여는 순간부터 N분간 지정 앱을 막는다.
///
/// [ScheduleReservationService]와 동일한 `scheduledDeactivationAtMs`+
/// `reservationLocked` 메커니즘을 재사용해 자동 종료시킨다 — 별도
/// 리컨실 루프가 필요 없다. 단, 이 전용 스케줄은 `locked`(일반 커밋먼트
/// 락)는 절대 켜지 않는다 — 켜두면 이 서비스 자신의 다음날 재기동
/// upsert가 `ScheduleImportGuard`(locked 스케줄 편집 방지 가드)에
/// 막혀버린다(우연히 자기 자신을 잠그는 꼴). 활성 기간 중 보호는
/// `reservationLocked` 하나로 충분하다.
class AppOpenBlockTriggerService {
  AppOpenBlockTriggerService._();

  static const scheduleId = '__isle_app_open_trigger__';

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 앱 콜드부팅·리쥼마다 호출 — 조건 맞으면 그 자리에서 트리거 발동.
  static Future<bool> maybeTriggerOnAppOpen() async {
    if (!IsleUserDefaults.appOpenTriggerEnabled) return false;
    final targetIds = IsleUserDefaults.appOpenTriggerTargetIds;
    if (targetIds.isEmpty) return false;

    final now = TrustedTimeGuard.effectiveNow();
    final todayKey = dateKey(now);
    if (IsleUserDefaults.appOpenTriggerLastDateKey == todayKey) return false;
    if (IsleUserDefaults.appOpenTriggerMorningOnly &&
        now.hour >= IsleUserDefaults.appOpenTriggerCutoffHour) {
      // 오늘은 이미 컷오프를 지나 첫 실행 — 오늘치는 스킵하되, 다음날 다시
      // 시도할 수 있게 lastDateKey는 건드리지 않는다.
      return false;
    }

    await IsleUserDefaults.setAppOpenTriggerLastDateKey(todayKey);
    await _activate(now, targetIds);
    return true;
  }

  static Future<void> _activate(DateTime now, List<String> targetIds) async {
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();

    final durationMinutes = IsleUserDefaults.appOpenTriggerDurationMinutes;
    final deactivateAt = now.add(Duration(minutes: durationMinutes));
    final slots = <ScheduleSlot>[
      for (var d = 0; d < 7; d++) ScheduleSlot(day: d, startMinute: 0, endMinute: 1439),
    ];

    final blockSafari = IsleUserDefaults.appOpenTriggerBlockSafari;
    final list = BlockScheduleStore.loadAll();
    final existing = list.where((s) => s.id == scheduleId).firstOrNull;
    // BlockScheduleStore.create()는 항상 새 랜덤 id를 발급해서 이 전용
    // 스케줄의 고정 id(scheduleId)를 못 쓴다 — 매번 재사용해야 하는
    // 싱글턴 스케줄이라 QuickBlockService._ensurePresetSchedule()과 같은
    // 패턴으로 직접 생성한다.
    final activated = (existing ??
            BlockSchedule(
              id: scheduleId,
              name: '앱 켠 지 N분 (자동)',
            ))
        .copyWith(
      enabled: true,
      locked: false,
      enforcementMode: ScheduleEnforcementMode.fullBlock,
      blockIsleInApp: blockSafari,
      slots: slots,
      scheduledDeactivationAtMs: deactivateAt.millisecondsSinceEpoch,
      reservationLocked: true,
      clearScheduledActivation: true,
    );
    if (existing == null) {
      await BlockScheduleStore.saveAll([...list, activated]);
    } else {
      await BlockScheduleStore.upsert(activated);
    }

    var entries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(scheduleId),
    );
    entries = entries.map((e) {
      if (targetIds.contains(e.targetId)) {
        return e.copyWith(blockInSlot: true, limitEnabled: false);
      }
      return e;
    }).toList();
    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: scheduleId,
      entries: entries,
      schedule: activated,
    );
  }
}
