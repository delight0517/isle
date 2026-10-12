import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/navigation/isle_routes.dart';

void main() {
  test('overlay-safe block schedule routes', () {
    expect(IsleRoutes.blockSchedulesOutsideShell, '/block/schedules');
    expect(
      IsleRoutes.blockScheduleEditOutsideShell('isle_youtube_timelock'),
      '/block/schedules/isle_youtube_timelock',
    );
    expect(IsleRoutes.youtubeLimits, '/youtube/limits');
  });
}
