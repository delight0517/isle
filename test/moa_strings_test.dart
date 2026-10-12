import 'package:flutter_test/flutter_test.dart';
import '../lib/core/localization/app_locale_policy.dart';
import '../lib/core/localization/moa_strings.dart';

void main() {
  test(
      'every supported language resolves product/navigation keys and arguments',
      () {
    for (final code in AppLocalePolicy.languageOptions.keys) {
      final strings = MoaStrings(code);
      for (final key in MoaStrings.keys) {
        expect(strings.t(key), isNot(key), reason: '$code:$key');
      }
      expect(strings.t('hidden_apps', args: {'count': '3'}), contains('3'));
      expect(strings.t('hidden_apps', args: {'count': '3'}),
          isNot(contains('{count}')));
      final syncStatus = strings.t('four_vpn_safari_sync_status', args: {
        'revision': '7',
        'count': '2',
        'timeZone': 'Asia/Seoul',
      });
      expect(syncStatus, contains('7'), reason: '$code:revision');
      expect(syncStatus, contains('2'), reason: '$code:schedules');
      expect(syncStatus, contains('Asia/Seoul'), reason: '$code:timeZone');
    }
    expect(const MoaStrings('ko-KR').t('my_moa'), '나의 모아');
    expect(const MoaStrings('en-US').t('my_moa'), 'My Moa');
  });
}
