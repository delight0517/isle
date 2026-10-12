import 'schedule_enforcement_mode.dart';
import 'schedule_slot.dart';

/// 스케줄 + 커밋먼트 잠금 메타 (블루프린트 §3)
class BlockSchedule {
  final String id;
  final String name;
  final bool enabled;
  final bool locked;
  final int lockCooldownMinutes;
  final int? unlockStartedAtMs;
  final int? unlockUntilMs;
  final List<ScheduleSlot> slots;
  final List<String> domains;
  final ScheduleEnforcementMode enforcementMode;
  /// 켜야 Isle WebView에서 YouTube 등을 막음. 스케줄 시간만으로는 자동 차단 안 함.
  final bool blockIsleInApp;
  /// 설치 시 자동으로 켜지는 "최소한의 안전 라인" 스케줄인지 — 챗으로 만든
  /// 일반 스케줄과 구분해 UI에서 "안전 라인으로 인한 활성화"를 보여줄 때 쓴다
  /// ([SafetyBaselineService] 참고).
  final bool isSafetyBaseline;

  /// 예약 스케줄(2026-07-20 신설, "여행 동안" 류) — 이 시각이 되면 자동으로
  /// `enabled: true`로 켜진다. [ScheduleReservationService]가 처리.
  final int? scheduledActivationAtMs;

  /// 예약 스케줄 — 이 시각이 되면 자동으로 `enabled: false`로 꺼지고
  /// `reservationLocked`도 함께 해제된다("여행이 끝나면 원래대로").
  final int? scheduledDeactivationAtMs;

  /// true면 예약 기간 동안(`scheduledActivationAtMs`~`scheduledDeactivationAtMs`)
  /// 일반 커밋먼트 락의 "대기 후 해제" 경로가 전혀 통하지 않는다 — 사용자가
  /// 명시적으로 "예약은 못 풀리게 해줘"라고 요청한 것을 반영
  /// (2026-07-20). [ScheduleEditGuard]에서 소비.
  final bool reservationLocked;

  /// true면 이 스케줄이 활성 중일 때 개별 앱 목록과 무관하게 "설치된 앱 전체"를
  /// Screen Time 카테고리 쉴드(`shield.applicationCategories = .all(...)`)로
  /// 막는다 — 전화/긴급 통화 등 OS가 항상 예외로 두는 것만 빼고 사실상 폰을
  /// 통째로 잠그는 효과(2026-[REDACTED], "밤에 폰 자체를 잠가달라" 요청 — 서드파티
  /// 앱은 진짜 화면 잠금 API가 없어서 "설치 앱 전부 차단"이 현실적 최댓값).
  /// 다른 스케줄의 개별 앱 선택과 독립적으로 합산 적용된다
  /// ([BlockScheduleEnforcementService] 참고).
  final bool lockdownAllApps;

  const BlockSchedule({
    required this.id,
    required this.name,
    this.enabled = true,
    this.locked = false,
    this.lockCooldownMinutes = 30,
    this.unlockStartedAtMs,
    this.unlockUntilMs,
    this.slots = const [],
    this.domains = const [],
    this.enforcementMode = ScheduleEnforcementMode.fullBlock,
    this.blockIsleInApp = false,
    this.isSafetyBaseline = false,
    this.scheduledActivationAtMs,
    this.scheduledDeactivationAtMs,
    this.reservationLocked = false,
    this.lockdownAllApps = false,
  });

  static const defaultYoutubeDomains = ['youtube.com', 'm.youtube.com', 'youtu.be', 'www.youtube.com'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'locked': locked,
        'lock_cooldown_minutes': lockCooldownMinutes,
        if (unlockStartedAtMs != null) 'unlock_started_at': unlockStartedAtMs,
        if (unlockUntilMs != null) 'unlock_until': unlockUntilMs,
        'slots': slots.map((e) => e.toJson()).toList(),
        'domains': domains,
        'enforcement_mode': enforcementMode.storageKey,
        'block_isle_in_app': blockIsleInApp,
        if (isSafetyBaseline) 'is_safety_baseline': isSafetyBaseline,
        if (scheduledActivationAtMs != null)
          'scheduled_activation_at': scheduledActivationAtMs,
        if (scheduledDeactivationAtMs != null)
          'scheduled_deactivation_at': scheduledDeactivationAtMs,
        if (reservationLocked) 'reservation_locked': reservationLocked,
        if (lockdownAllApps) 'lockdown_all_apps': lockdownAllApps,
      };

  factory BlockSchedule.fromJson(Map<String, dynamic> j) => BlockSchedule(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '스케줄',
        enabled: j['enabled'] as bool? ?? true,
        locked: j['locked'] as bool? ?? false,
        lockCooldownMinutes: (j['lock_cooldown_minutes'] as num?)?.toInt() ?? 30,
        unlockStartedAtMs: (j['unlock_started_at'] as num?)?.toInt(),
        unlockUntilMs: (j['unlock_until'] as num?)?.toInt(),
        slots: (j['slots'] as List? ?? [])
            .map((e) => ScheduleSlot.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        domains: List<String>.from(j['domains'] as List? ?? const []),
        enforcementMode: ScheduleEnforcementModeX.parse(j['enforcement_mode'] as String?),
        blockIsleInApp: j['block_isle_in_app'] as bool? ?? false,
        isSafetyBaseline: j['is_safety_baseline'] as bool? ?? false,
        scheduledActivationAtMs: (j['scheduled_activation_at'] as num?)?.toInt(),
        scheduledDeactivationAtMs: (j['scheduled_deactivation_at'] as num?)?.toInt(),
        reservationLocked: j['reservation_locked'] as bool? ?? false,
        lockdownAllApps: j['lockdown_all_apps'] as bool? ?? false,
      );

  BlockSchedule copyWith({
    String? name,
    bool? enabled,
    bool? locked,
    int? lockCooldownMinutes,
    int? unlockStartedAtMs,
    int? unlockUntilMs,
    bool clearUnlock = false,
    bool clearUnlockUntil = false,
    List<ScheduleSlot>? slots,
    List<String>? domains,
    ScheduleEnforcementMode? enforcementMode,
    bool? blockIsleInApp,
    bool? isSafetyBaseline,
    int? scheduledActivationAtMs,
    int? scheduledDeactivationAtMs,
    bool clearScheduledActivation = false,
    bool clearScheduledDeactivation = false,
    bool? reservationLocked,
    bool? lockdownAllApps,
  }) =>
      BlockSchedule(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        locked: locked ?? this.locked,
        lockCooldownMinutes: lockCooldownMinutes ?? this.lockCooldownMinutes,
        unlockStartedAtMs: clearUnlock ? null : (unlockStartedAtMs ?? this.unlockStartedAtMs),
        unlockUntilMs: clearUnlock || clearUnlockUntil
            ? null
            : (unlockUntilMs ?? this.unlockUntilMs),
        slots: slots ?? this.slots,
        domains: domains ?? this.domains,
        enforcementMode: enforcementMode ?? this.enforcementMode,
        blockIsleInApp: blockIsleInApp ?? this.blockIsleInApp,
        isSafetyBaseline: isSafetyBaseline ?? this.isSafetyBaseline,
        scheduledActivationAtMs: clearScheduledActivation
            ? null
            : (scheduledActivationAtMs ?? this.scheduledActivationAtMs),
        scheduledDeactivationAtMs: clearScheduledDeactivation
            ? null
            : (scheduledDeactivationAtMs ?? this.scheduledDeactivationAtMs),
        reservationLocked: reservationLocked ?? this.reservationLocked,
        lockdownAllApps: lockdownAllApps ?? this.lockdownAllApps,
      );
}
