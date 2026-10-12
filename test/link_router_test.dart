import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/navigation/link_router.dart';

void main() {
  group('LinkRouter native app QR', () {
    test('detects kakaopay universal link host', () {
      expect(
        LinkRouter.prefersNativeAppLaunch('https://link.kakaopay.com/pay/abc'),
        isTrue,
      );
      expect(
        LinkRouter.prefersNativeAppLaunch('https://example.com/pay'),
        isFalse,
      );
    });

    test('detects custom scheme app links', () {
      expect(LinkRouter.isNonHttpAppLink('kakaopay://payment?id=1'), isTrue);
      expect(LinkRouter.isNonHttpAppLink('https://kakaopay.com/x'), isFalse);
    });

    test('parses android intent to custom scheme uri', () {
      const intent =
          'intent://pay/#Intent;scheme=kakaopay;package=com.kakao.talk;'
          'S.browser_fallback_url=https%3A%2F%2Flink.kakaopay.com%2Fx;end';
      expect(
        LinkRouter.resolveAppLaunchUri(intent)?.toString(),
        'kakaopay://pay/',
      );
    });
  });
}
