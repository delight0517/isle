import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/youtube/youtube_safari_launch_guard.dart';

void main() {
  test('google youtube login URL is treated as youtube redirect', () {
    const url =
        'https://accounts.google.com/ServiceLogin?service=youtube&continue=https://m.youtube.com/';
    expect(YoutubeSafariLaunchGuard.redirectsToYoutube(url), isTrue);
  });

  test('plain google accounts page is not youtube redirect', () {
    expect(
      YoutubeSafariLaunchGuard.redirectsToYoutube('https://accounts.google.com/'),
      isFalse,
    );
  });

  test('youtube home is redirect target', () {
    expect(
      YoutubeSafariLaunchGuard.redirectsToYoutube('https://m.youtube.com/'),
      isTrue,
    );
  });

  test('passkey challenge URL is youtube auth escape', () {
    expect(
      YoutubeSafariLaunchGuard.isYoutubeAuthOrBrowseUrl(
        'https://accounts.google.com/v3/signin/challenge/pk?flowEntry=ServiceLogin',
      ),
      isTrue,
    );
  });
}
