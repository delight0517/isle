import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/social/instagram_auth_path_policy.dart';

void main() {
  test('detects login and account recovery paths', () {
    expect(
      InstagramAuthPathPolicy.isAuthFlowPath('/accounts/login/'),
      isTrue,
    );
    expect(
      InstagramAuthPathPolicy.isAuthFlowPath('/accounts/onetap/'),
      isTrue,
    );
    expect(
      InstagramAuthPathPolicy.isAuthFlowPath('/accounts/[REDACTED]'),
      isTrue,
    );
  });

  test('detects challenge and consent', () {
    expect(
      InstagramAuthPathPolicy.isAuthFlowPath('/challenge/action/123/'),
      isTrue,
    );
    expect(
      InstagramAuthPathPolicy.isAuthFlowPath('/consent/?flow=1'),
      isTrue,
    );
  });

  test('does not treat feed or DM as auth', () {
    expect(InstagramAuthPathPolicy.isAuthFlowPath('/'), isFalse);
    expect(InstagramAuthPathPolicy.isAuthFlowPath('/direct/inbox/'), isFalse);
    expect(InstagramAuthPathPolicy.isAuthFlowPath('/explore/'), isFalse);
  });

  test('isAuthFlowUrl parses full URL', () {
    expect(
      InstagramAuthPathPolicy.isAuthFlowUrl(
        'https://www.instagram.com/accounts/login/?next=/direct/inbox/',
      ),
      isTrue,
    );
  });
}
