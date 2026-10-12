import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/platform/platform_copy_resolver.dart';
import 'package:isle/core/platform/platform_kind.dart';

/// iOS/Android 카피가 서로 덮어쓰이지 않았는지 고정 검증.
void main() {
  group('PlatformCopyResolver parity', () {
    test('iOS keeps Safari branding in nav', () {
      expect(
        PlatformCopyResolver.inAppBrowserNavLabel(PlatformKind.ios),
        'Safari',
      );
      expect(
        PlatformCopyResolver.urlSheetTitle(PlatformKind.ios),
        contains('Safari'),
      );
      expect(
        PlatformCopyResolver.externalPasskeyBrowserName(PlatformKind.ios),
        'Safari',
      );
    });

    test('Android never shows Safari or Screen Time in nav copy', () {
      final nav = PlatformCopyResolver.inAppBrowserNavLabel(PlatformKind.android);
      expect(nav, isNot(contains('Safari')));
      expect(nav, '웹 브라우저');

      expect(
        PlatformCopyResolver.externalAppsSubtitle(PlatformKind.android),
        isNot(contains('Screen Time')),
      );
      expect(
        PlatformCopyResolver.blockingCapabilitiesTitle(PlatformKind.android),
        contains('Android'),
      );
      expect(
        PlatformCopyResolver.systemYoutubeBlockGuideLabel(PlatformKind.android),
        contains('Chrome'),
        reason: 'Android guide must reference Chrome not Safari',
      );
    });

    test('iOS never shows Android-only accessibility copy in focus hint', () {
      final hint = PlatformCopyResolver.blockFocusExternalAppsHint(PlatformKind.ios);
      expect(hint, contains('Screen Time'));
      expect(hint, isNot(contains('접근성')));
    });

    test('Android never shows iPhone Screen Time in focus hint', () {
      final hint =
          PlatformCopyResolver.blockFocusExternalAppsHint(PlatformKind.android);
      expect(hint, contains('접근성'));
      expect(hint, isNot(contains('Screen Time')));
    });

    test('safe browser intro references correct external browser', () {
      expect(
        PlatformCopyResolver.safeBrowserIntro(PlatformKind.ios),
        contains('Safari'),
      );
      expect(
        PlatformCopyResolver.safeBrowserIntro(PlatformKind.android),
        contains('Chrome'),
      );
      expect(
        PlatformCopyResolver.safeBrowserIntro(PlatformKind.android),
        isNot(contains('Safari')),
      );
    });

    test('google search filter label differs by platform', () {
      expect(
        PlatformCopyResolver.googleSearchFilterLabel(PlatformKind.ios),
        contains('Safari'),
      );
      expect(
        PlatformCopyResolver.googleSearchFilterLabel(PlatformKind.android),
        '구글 검색',
      );
    });

    test('schedule web chip label', () {
      expect(
        PlatformCopyResolver.scheduleWebTargetChipLabel(PlatformKind.ios),
        'Safari·웹',
      );
      expect(
        PlatformCopyResolver.scheduleWebTargetChipLabel(PlatformKind.android),
        '웹',
      );
    });
  });
}
