import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/block/models/pending_rule_removal.dart';
import 'package:isle/core/block/rule_pending_removal_service.dart';
import 'package:isle/core/block/rule_pending_removal_store.dart';
import 'package:isle/core/services/isle_user_defaults.dart';
import 'package:isle/core/youtube/content_filter_store.dart';

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_pending_removal_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await ContentFilterStore.ensureOpen();
    await RulePendingRemovalStore.ensureOpen();
    RulePendingRemovalService.registerHandlers(
      removeKeyword: (key) async {
        final list = ContentFilterStore.loadKeywords()..removeWhere((k) => k == key);
        await ContentFilterStore.saveKeywords(list);
      },
      removeUrl: (_) async {},
    );
  });

  setUp(() async {
    await ContentFilterStore.saveKeywords(['테스트']);
    await RulePendingRemovalStore.saveAll([]);
    await IsleUserDefaults.setRuleRemovalLockEnabled(true);
    await IsleUserDefaults.setRuleRemovalFreezeMinutes(15);
  });

  test('lock on schedules keyword removal without immediate delete', () async {
    final outcome = await RulePendingRemovalService.requestKeywordRemove('테스트');
    expect(outcome.kind, RuleRemovalOutcomeKind.scheduled);
    expect(ContentFilterStore.loadKeywords(), contains('테스트'));
    expect(
      RulePendingRemovalStore.find(PendingRuleRemovalKind.keyword, '테스트'),
      isNotNull,
    );
  });

  test('processDue removes keyword after delay', () async {
    final now = DateTime.now();
    await RulePendingRemovalStore.saveAll([
      PendingRuleRemoval(
        kind: PendingRuleRemovalKind.keyword,
        key: '테스트',
        scheduledAtMs: now.millisecondsSinceEpoch,
        removeAtMs: now.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch,
      ),
    ]);
    final removed = await RulePendingRemovalService.processDue();
    expect(removed, 1);
    expect(ContentFilterStore.loadKeywords(), isEmpty);
  });

  test('lock off removes keyword immediately', () async {
    await IsleUserDefaults.setRuleRemovalLockEnabled(false);
    final outcome = await RulePendingRemovalService.requestKeywordRemove('테스트');
    expect(outcome.kind, RuleRemovalOutcomeKind.immediate);
    expect(ContentFilterStore.loadKeywords(), isEmpty);
  });
}
