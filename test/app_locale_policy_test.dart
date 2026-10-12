import 'package:flutter_test/flutter_test.dart';
import '../lib/core/localization/app_locale_policy.dart';

void main() {
  test('normalizes saved region codes and safely defaults to Korean', () {
    expect(AppLocalePolicy.normalize(' EN_us '), 'en');
    expect(AppLocalePolicy.normalize('ko-KR'), 'ko');
    expect(AppLocalePolicy.normalize('zh-Hant'), 'zh');
    expect(AppLocalePolicy.normalize('iw-IL'), 'he');
    for (final code in [null, '', 'system', 'de', 'invalid']) {
      expect(AppLocalePolicy.normalize(code), 'ko');
    }
  });
  test('all catalogues share Korean fallback and placeholder handling', () {
    const tables = {
      'ko': {'hello': '{name}님 안녕하세요', 'only': '한국어'},
      'en': {'hello': 'Hello {name}'},
    };
    expect(
        AppLocalePolicy.translate(tables, 'en-US', 'hello',
            args: {'name': 'Moa'}),
        'Hello Moa');
    expect(AppLocalePolicy.translate(tables, 'en', 'only'), '한국어');
    expect(AppLocalePolicy.translate(tables, 'unknown', 'only'), '한국어');
    expect(AppLocalePolicy.translate(tables, 'ko', 'missing'), 'missing');
  });
}
