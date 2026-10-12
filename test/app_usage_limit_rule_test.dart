import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/intervention/models/app_usage_limit_rule.dart';

void main() {
  test('saved hourly Screen Time limit keeps its app selection and schedule', () {
    const rule = AppUsageLimitRule(
      id: 'instagram-night',
      label: 'Instagram',
      minutesPerWindow: 25,
      windowMinutes: 60,
      iosFamilyActivityEncoded: 'opaque-family-selection',
      scheduleId: 'night',
      enabled: true,
    );

    final restored = AppUsageLimitRule.fromJson(rule.toJson());

    expect(restored.id, 'instagram-night');
    expect(restored.minutesPerWindow, 25);
    expect(restored.windowMinutes, 60);
    expect(restored.iosFamilyActivityEncoded, 'opaque-family-selection');
    expect(restored.scheduleId, 'night');
    expect(restored.enabled, isTrue);
  });

  test('legacy daily limits restore as daily Screen Time rules', () {
    final restored = AppUsageLimitRule.fromJson({
      'id': 'youtube',
      'label': 'YouTube',
      'minutes_per_day': 45,
      'enabled': true,
      'ios_encoded': 'saved-selection',
    });

    expect(restored.minutesPerWindow, 45);
    expect(restored.windowMinutes, 1440);
    expect(restored.iosFamilyActivityEncoded, 'saved-selection');
  });
}
