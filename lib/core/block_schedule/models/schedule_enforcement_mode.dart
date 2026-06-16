import '../../localization/schedule_strings.dart';

/// 스케줄 슬롯 안·밖에서 앱을 어떻게 제한할지
enum ScheduleEnforcementMode {
  /// 슬롯 시간: 완전 차단 (Screen Time 쉴드 + YouTube 도메인)
  fullBlock,

  /// 슬롯 시간: 완전 차단 없음 · 시간당 N분 한도만 (OS)
  limitInSlot,

  /// 슬롯 시간: 완전 차단 · 슬롯 밖: 시간당 N분 한도
  blockInSlotLimitOutside,
}

extension ScheduleEnforcementModeX on ScheduleEnforcementMode {
  static ScheduleEnforcementMode parse(String? raw) => switch (raw) {
        'limit_in_slot' => ScheduleEnforcementMode.limitInSlot,
        'block_in_slot_limit_outside' => ScheduleEnforcementMode.blockInSlotLimitOutside,
        _ => ScheduleEnforcementMode.fullBlock,
      };

  String get storageKey => switch (this) {
        ScheduleEnforcementMode.fullBlock => 'full_block',
        ScheduleEnforcementMode.limitInSlot => 'limit_in_slot',
        ScheduleEnforcementMode.blockInSlotLimitOutside => 'block_in_slot_limit_outside',
      };

  /// Korean default — prefer [localizedLabel] with [ScheduleStrings].
  String get label => localizedLabel('ko');

  String get subtitle => localizedSubtitle('ko');

  String get scenarioText => localizedScenario('ko');

  String localizedLabel(String lang) => ScheduleStrings(lang).modeLabel(this);

  String localizedSubtitle(String lang) => ScheduleStrings(lang).modeSubtitle(this);

  String localizedScenario(String lang) => ScheduleStrings(lang).modeScenario(this);

  bool get appliesShieldInSlot =>
      this == ScheduleEnforcementMode.fullBlock ||
      this == ScheduleEnforcementMode.blockInSlotLimitOutside;

  bool get appliesLimitInSlot => this == ScheduleEnforcementMode.limitInSlot;

  bool get appliesLimitOutsideSlot =>
      this == ScheduleEnforcementMode.blockInSlotLimitOutside;
}
