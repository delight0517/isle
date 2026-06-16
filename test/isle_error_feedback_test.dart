import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/services/isle_error_feedback.dart';

void main() {
  test('friendly maps login errors', () {
    expect(
      IsleErrorFeedback.friendly(StateError('Google 로그인이 필요합니다.')),
      'Google 로그인이 필요해요.',
    );
  });

  test('friendly strips StateError prefix', () {
    expect(
      IsleErrorFeedback.friendly(StateError('something broke')),
      'something broke',
    );
  });
}
