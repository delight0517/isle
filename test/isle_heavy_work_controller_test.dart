import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/perf/isle_heavy_work_controller.dart';

void main() {
  test('remainingPercent decreases with progress', () {
    const snap = IsleHeavyWorkSnapshot(progress: 0.7, estimatedTotalMs: 1000);
    expect(snap.remainingPercent, 30);
    expect(snap.estimatedRemainingSec, 1);
  });
}
