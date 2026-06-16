import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/block_schedule.dart';
import 'package:isle/core/block_schedule/models/schedule_enforcement_mode.dart';
import 'package:isle/core/block_schedule/models/schedule_slot.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_enforcement.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_kind.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_store.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_web_block_guard.dart';
import 'package:isle/core/services/isle_user_defaults.dart';

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_sched_rules');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleRuleStore.ensureOpen();
    await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);
  });

  test('mingky13.net blocked by urlContains when schedule active', () async {
    const sid = 'test_sched_mingky';
    final now = DateTime.now();
    final schedule = BlockSchedule(
      id: sid,
      name: 'test',
      enabled: true,
      enforcementMode: ScheduleEnforcementMode.fullBlock,
      slots: [
        ScheduleSlot(
          day: now.weekday - 1,
          startMinute: 0,
          endMinute: 1439,
        ),
      ],
    );
    await BlockScheduleStore.upsert(schedule);
    await ScheduleRuleStore.saveAll([
      ScheduleRule(
        id: 'r1',
        scheduleId: sid,
        kind: ScheduleRuleKind.urlContains,
        pattern: 'mingky',
        addedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ]);

    expect(
      ScheduleWebBlockGuard.matchUrl('https://mingky13.net/page'),
      isNotNull,
    );
    expect(
      ScheduleRuleEnforcement.urlMatchesActiveRules('https://mingky01.live/movie/x'),
      isTrue,
    );
  });
}
