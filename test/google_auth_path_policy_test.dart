import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/youtube/google_auth_path_policy.dart';

void main() {
  test('google service login is auth flow', () {
    expect(
      GoogleAuthPathPolicy.isAuthFlowUrl(
        'https://accounts.google.com/ServiceLogin?service=youtube&continue=https://m.youtube.com/',
      ),
      isTrue,
    );
  });

  test('google 2FA TOTP challenge is auth flow', () {
    expect(
      GoogleAuthPathPolicy.isAuthFlowUrl(
        'https://accounts.google.com/v3/signin/challenge/totp?TL=abc',
      ),
      isTrue,
    );
  });

  test('youtube watch is not auth flow', () {
    expect(
      GoogleAuthPathPolicy.isAuthFlowUrl(
        'https://m.youtube.com/watch?v=dQw4w9WgXcQ',
      ),
      isFalse,
    );
  });
}
