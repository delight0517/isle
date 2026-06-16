import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/block_schedule/isle_youtube_schedule_service.dart';

void main() {
  group('IsleYoutubeScheduleService', () {
    test('formatEndLabel whole hour', () {
      expect(IsleYoutubeScheduleService.formatEndLabel(600), '10시');
    });

    test('formatEndLabel with minutes', () {
      expect(IsleYoutubeScheduleService.formatEndLabel(630), '10시 30분');
    });
  });
}
