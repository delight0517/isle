import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:isle/core/focus/kakao_shorts_addiction_analyzer.dart';
import 'package:isle/core/focus/kakao_shorts_addiction_store.dart';
import 'package:isle/core/focus/kakao_shorts_session.dart';

void main() {
  setUpAll(() async {
    Hive.init('test_kakao_shorts');
    await KakaoShortsAddictionStore.ensureOpen();
  });

  setUp(() async {
    final box = Hive.box<String>('isle_kakao_shorts');
    await box.clear();
  });

  test('analyze returns low risk with no sessions', () {
    final i = KakaoShortsAddictionAnalyzer.analyze();
    expect(i.riskLevel, KakaoShortsRiskLevel.low);
    expect(i.sessionCountToday, 0);
  });

  test('long session elevates risk', () async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(minutes: 40)).millisecondsSinceEpoch;
    final end = now.millisecondsSinceEpoch;
    final box = Hive.box<String>('isle_kakao_shorts');
    await box.put(
      'sessions_v1',
      '[{"id":"t1","start_ms":$start,"end_ms":$end,"source":"manual"}]',
    );
    final i = KakaoShortsAddictionAnalyzer.analyze(now: now);
    expect(i.riskLevel, KakaoShortsRiskLevel.high);
    expect(i.longestStreakMinutes, greaterThanOrEqualTo(35));
  });
}
