import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/block_schedule/schedule_block_reconcile_service.dart';

void main() {
  test('scopeFromQuery maps youtube keywords', () {
    expect(
      ScheduleBlockReconcileService.scopeFromQuery('아침 유튜브'),
      BlockRelaxScope.youtube,
    );
    expect(
      ScheduleBlockReconcileService.scopeFromQuery('safari'),
      BlockRelaxScope.safari,
    );
  });
}
