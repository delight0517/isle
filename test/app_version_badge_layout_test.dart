import 'package:flutter_test/flutter_test.dart';

import 'package:isle/core/constants/app_version_badge_layout.dart';

void main() {
  test('badge lift clears and notifies', () {
    var notified = 0;
    AppVersionBadgeLayout.instance.addListener(() => notified++);
    addTearDown(AppVersionBadgeLayout.instance.clearLift);

    AppVersionBadgeLayout.instance.setLift(140);
    expect(AppVersionBadgeLayout.instance.extraBottomLift, 140);
    expect(notified, 1);

    AppVersionBadgeLayout.instance.setLift(140);
    expect(notified, 1);

    AppVersionBadgeLayout.instance.clearLift();
    expect(AppVersionBadgeLayout.instance.extraBottomLift, 0);
    expect(notified, 2);
  });
}
