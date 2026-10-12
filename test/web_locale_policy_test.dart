import 'package:flutter_test/flutter_test.dart';
import '../lib/core/localization/web_locale_policy.dart';

void main() {
  test('display-language hint preserves videos, duplicate params and fragments',
      () {
    final uri = WebLocalePolicy.initialUri(
        'https://m.youtube.com/watch?v=abc&t=30&x=1&x=2&hl=en#details',
        'ko-KR');
    expect(uri.queryParameters['v'], 'abc');
    expect(uri.queryParameters['t'], '30');
    expect(uri.queryParametersAll['x'], ['1', '2']);
    expect(uri.queryParametersAll['hl'], ['ko']);
    expect(uri.fragment, 'details');
    expect(WebLocalePolicy.headers(uri, 'ko'), {'Accept-Language': 'ko'});
    final dm = WebLocalePolicy.initialUri(
        'https://www.instagram.com/direct/inbox/', 'en-US');
    expect(dm.path, '/direct/inbox/');
    expect(dm.queryParameters['hl'], 'en');
  });
  test('does not change auth, media, other websites or lookalike hosts', () {
    for (final url in [
      'https://accounts.google.com/ServiceLogin?continue=abc',
      'https://www.instagram.com/accounts/login/',
      'https://www.instagram.com/challenge/abc/',
      'https://www.youtube.com/signin',
      'https://instagram.com.evil.example/',
      'https://cdn.instagram.com/image?signature=abc',
      'https://example.com/?hl=en',
      'http://www.youtube.com/watch?v=abc',
    ]) {
      expect(WebLocalePolicy.initialUri(url, 'ko').toString(), url);
      expect(WebLocalePolicy.headers(Uri.parse(url), 'ko'), isEmpty);
    }
  });
}
