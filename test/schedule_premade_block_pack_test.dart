import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:isle/core/block/rule_pending_removal_service.dart';
import 'package:isle/core/block/rule_pending_removal_store.dart';
import 'package:isle/core/block/rule_removal_lock.dart';
import 'package:isle/core/block/schedule_premade_block_pack_service.dart';
import 'package:isle/core/block/schedule_premade_pack_store.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_store.dart';

void main() {
  const scheduleId = 'test_schedule_premade';
  const testPackId = 'premade_gaming_400';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir =
        Directory.systemTemp.createTempSync('isle_schedule_premade_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await ScheduleRuleStore.ensureOpen();
    await SchedulePremadePackStore.ensureOpen();
    await RulePendingRemovalStore.ensureOpen();
    RulePendingRemovalService.registerHandlers(
      removeKeyword: (_) async {},
      removeUrl: (_) async {},
      removePremadePack: (key) async {
        if (SchedulePremadePackService.isSchedulePendingKey(key)) {
          final sid =
              SchedulePremadePackService.parseScheduleIdFromPendingKey(key);
          final pid = SchedulePremadePackService.parsePackIdFromPendingKey(key);
          if (sid != null && pid != null) {
            await SchedulePremadePackService.unlinkImmediate(
              scheduleId: sid,
              packId: pid,
            );
          }
        }
      },
    );
  });

  tearDown(() async {
    await ScheduleRuleStore.deleteForSchedule(scheduleId);
    await SchedulePremadePackService.deleteScheduleLinks(scheduleId);
    RuleRemovalLock.setLockEnabled(false);
  });

  test('linkPack adds schedule rules with premadePackId', () async {
    final result = await SchedulePremadePackService.linkPack(
      scheduleId: scheduleId,
      packId: testPackId,
    );
    expect(result.rulesAdded, greaterThan(0));

    expect(
      SchedulePremadePackService.isLinked(
        scheduleId: scheduleId,
        packId: testPackId,
      ),
      isTrue,
    );

    final rules = ScheduleRuleStore.loadForSchedule(scheduleId);
    expect(rules.any((r) => r.premadePackId == testPackId), isTrue);
  });

  test('unlinkImmediate removes only premade rules', () async {
    await SchedulePremadePackService.linkPack(
      scheduleId: scheduleId,
      packId: testPackId,
    );
    await SchedulePremadePackService.unlinkImmediate(
      scheduleId: scheduleId,
      packId: testPackId,
    );

    expect(
      SchedulePremadePackService.isLinked(
        scheduleId: scheduleId,
        packId: testPackId,
      ),
      isFalse,
    );
    expect(
      ScheduleRuleStore.loadForSchedule(scheduleId)
          .where((r) => r.premadePackId == testPackId),
      isEmpty,
    );
  });

  test('scheduled unlink respects timer lock', () async {
    await SchedulePremadePackService.linkPack(
      scheduleId: scheduleId,
      packId: testPackId,
    );
    RuleRemovalLock.setLockEnabled(true);

    final outcome =
        await RulePendingRemovalService.requestSchedulePremadePackRemove(
      scheduleId: scheduleId,
      packId: testPackId,
    );
    expect(outcome.kind, RuleRemovalOutcomeKind.scheduled);

    expect(
      SchedulePremadePackService.isLinked(
        scheduleId: scheduleId,
        packId: testPackId,
      ),
      isTrue,
    );
  });
}
