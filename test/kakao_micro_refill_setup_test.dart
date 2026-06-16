import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/block_schedule/models/block_schedule.dart';
import 'package:isle/core/focus/kakao_micro_refill_setup_result.dart';
import 'package:isle/core/focus/kakao_shorts_preset_service.dart';

void main() {
  test('microRefillLimits returns positive window and limit', () {
    final limits = KakaoShortsPresetService.microRefillLimits();
    expect(limits.windowMinutes, greaterThan(0));
    expect(limits.limitMinutes, greaterThan(0));
    expect(limits.limitMinutes, lessThan(limits.windowMinutes));
  });

  test('setup result warns when Screen Time apps missing', () {
    const result = KakaoMicroRefillSetupResult(
      schedule: BlockSchedule(id: 'sch_test', name: 'test'),
      masterEnabled: true,
      limitMinutes: 5,
      windowMinutes: 60,
      screenTimeAppCount: 0,
      limitRuleRegistered: false,
      pickerAttempted: true,
    );
    expect(result.needsScreenTimePick, isTrue);
    expect(result.statusMessage(isIos: true), contains('Screen Time'));
  });
}
