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

  const BlockSchedule({
    required this.id,
    required this.name,
    this.enabled = true,
    this.locked = false,
    this.lockCooldownMinutes = 30,
    this.unlockStartedAtMs,
    this.unlockUntilMs,
    this.slots = const [],
    this.domains = const ['youtube.com', 'm.youtube.com', 'youtu.be'],
    this.enforcementMode = ScheduleEnforcementMode.fullBlock,
    this.blockIsleInApp = false,
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
        domains: List<String>.from(j['domains'] as List? ?? defaultYoutubeDomains),
        enforcementMode: ScheduleEnforcementModeX.parse(j['enforcement_mode'] as String?),
        blockIsleInApp: j['block_isle_in_app'] as bool? ?? false,
      );

  BlockSchedule copyWith({
    String? name,
    bool? enabled,
    bool? locked,
    int? lockCooldownMinutes,
    int? unlockStartedAtMs,
    int? unlockUntilMs,
    bool clearUnlock = false,
    List<ScheduleSlot>? slots,
    List<String>? domains,
    ScheduleEnforcementMode? enforcementMode,
    bool? blockIsleInApp,
  }) =>
      BlockSchedule(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        locked: locked ?? this.locked,
        lockCooldownMinutes: lockCooldownMinutes ?? this.lockCooldownMinutes,
        unlockStartedAtMs: clearUnlock ? null : (unlockStartedAtMs ?? this.unlockStartedAtMs),
        unlockUntilMs: clearUnlock ? null : (unlockUntilMs ?? this.unlockUntilMs),
        slots: slots ?? this.slots,
        domains: domains ?? this.domains,
        enforcementMode: enforcementMode ?? this.enforcementMode,
        blockIsleInApp: blockIsleInApp ?? this.blockIsleInApp,
      );
}
