import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/block_schedule/models/block_schedule.dart';
import 'package:isle/core/block_schedule/models/schedule_slot.dart';
import 'package:isle/core/block_schedule/schedule_import_guard.dart';
import 'package:isle/core/block_schedule/schedule_lock_service.dart';
import 'package:isle/core/block_schedule/schedule_persist_guard.dart';

void main() {
  test('import guard preserves locked schedule fields', () {
    final existing = BlockSchedule(
      id: 'a',
      name: '야간',
      enabled: true,
      locked: true,
      unlockStartedAtMs: DateTime.now().millisecondsSinceEpoch,
      slots: const [ScheduleSlot(day: 1, startMinute: 1200, endMinute: 1380)],
      domains: const ['youtube.com'],
    );
    expect(ScheduleLockService.isEffectivelyLocked(existing), isTrue);

    final incoming = existing.copyWith(
      enabled: false,
      locked: false,
      clearUnlock: true,
      slots: const [],
      domains: const [],
    );
    final merged = ScheduleImportGuard.mergeIncoming(
      existing: existing,
      incoming: incoming,
    );
    expect(merged.enabled, isTrue);
    expect(merged.locked, isTrue);
    expect(merged.slots.length, 1);
    expect(merged.domains, contains('youtube.com'));
  });

  test('persist guard blocks delete while commitment locked', () {
    final locked = BlockSchedule(
      id: 'b',
      name: '아침',
      enabled: true,
      locked: true,
      unlockStartedAtMs: DateTime.now().millisecondsSinceEpoch,
      slots: const [ScheduleSlot(day: 0, startMinute: 0, endMinute: 480)],
    );
    expect(SchedulePersistGuard.canDelete(locked), isFalse);
    expect(
      SchedulePersistGuard.sanitizeUpsert(
        existing: locked,
        incoming: locked.copyWith(enabled: false, slots: const []),
      ).enabled,
      isTrue,
    );
  });
}
