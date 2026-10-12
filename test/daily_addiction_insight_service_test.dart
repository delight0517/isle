import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/content/daily_addiction_insight_service.dart';

/// 날짜 결정적 순환 — 같은 날 호출은 같은 항목, 다른 날은 다른 항목이 나오는지 검증.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('같은 날짜로 두 번 호출하면 같은 항목이 나온다', () async {
    final date = DateTime(2026, 3, 15);
    final a = await DailyAddictionInsightService.todayInsight(now: date);
    final b = await DailyAddictionInsightService.todayInsight(now: date);
    expect(a, isNotNull);
    expect(a!.id, b!.id);
  });

  test('충분히 떨어진 날짜는 다른 항목이 나올 수 있다', () async {
    final results = <String>{};
    for (var day = 0; day < 40; day++) {
      final date = DateTime(2026, 1, 1).add(Duration(days: day));
      final insight = await DailyAddictionInsightService.todayInsight(now: date);
      if (insight != null) results.add(insight.id);
    }
    // 40개 콘텐츠를 40일 연속 순환하면 최소 여러 개의 서로 다른 항목이 나와야 함
    // (완전히 같은 값 하나만 반복되면 순환 로직이 깨진 것).
    expect(results.length, greaterThan(1));
  });

  test('콘텐츠 팩이 비어있지 않다(placeholder 아님, 실제 저작됨)', () async {
    final insight = await DailyAddictionInsightService.todayInsight(
      now: DateTime(2026, 6, 1),
    );
    expect(insight, isNotNull);
    expect(insight!.text.length, greaterThan(10));
  });
}
