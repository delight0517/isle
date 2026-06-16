import 'package:flutter_test/flutter_test.dart';
import 'package:isle/router/app_router.dart';

void main() {
  test('creativeAnalyticsTabIndex maps query names', () {
    expect(creativeAnalyticsTabIndex(null), 0);
    expect(creativeAnalyticsTabIndex('growth'), 0);
    expect(creativeAnalyticsTabIndex('top3'), 0);
    expect(creativeAnalyticsTabIndex('outlier'), 1);
    expect(creativeAnalyticsTabIndex('narrative'), 2);
    expect(creativeAnalyticsTabIndex('matchup'), 3);
    expect(creativeAnalyticsTabIndex('2'), 2);
    expect(creativeAnalyticsTabIndex('bogus'), 0);
  });
}
