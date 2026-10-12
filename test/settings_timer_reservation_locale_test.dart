import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/localization/settings_strings.dart';

void main() {
  test('timer reservation copy resolves in every supported app language', () {
    for (final locale in ['ko', 'en', 'ja', 'zh', 'he']) {
      final strings = SettingsStrings(locale);
      expect(strings.t('timer_change_title'), isNot('timer_change_title'));
      expect(
        strings.t('timer_change_body', args: {'minutes': '30'}),
        allOf(isNot(contains('{minutes}')), contains('30')),
      );
      expect(strings.t('timer_change_action'), isNot('timer_change_action'));
      expect(strings.t('timer_change_done'), isNot('timer_change_done'));
    }
  });
}
