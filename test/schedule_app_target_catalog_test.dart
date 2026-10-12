import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/block_schedule/schedule_app_target_catalog.dart';

void main() {
  test('Safari is an independent iPhone app target and bundle', () {
    expect(ScheduleAppTargetCatalog.defFor('ios_safari')?.bundleId, 'safari');
    expect(ScheduleAppTargetCatalog.bundleFor('safari')?.targetIds,
        ['ios_safari']);
  });
}
