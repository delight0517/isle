import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/social/instagram_safari_launch_guard.dart';

void main() {
  test('instagram login URL is redirect target', () {
    expect(
      InstagramSafariLaunchGuard.redirectsToInstagram(
        'https://www.instagram.com/accounts/login/',
      ),
      isTrue,
    );
  });

  test('non-instagram URL is not redirect', () {
    expect(
      InstagramSafariLaunchGuard.redirectsToInstagram('https://example.com/'),
      isFalse,
    );
  });
}
