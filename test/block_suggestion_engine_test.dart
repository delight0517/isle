import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/suggestion/block_suggestion_engine.dart';
import 'package:isle/core/intervention/app_usage_limit_store.dart';
import 'package:isle/core/intervention/models/app_usage_limit_rule.dart';
import 'package:isle/core/intervention/website_block_store.dart';

/// SNS 사이트만 막고 앱 한도가 없을 때 능동 제안(proactive)이 뜨는지,
/// 이미 앱 한도가 있으면 다시 제안하지 않는지(idempotent) 검증.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_suggestion_engine');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await WebsiteBlockStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
  });

  setUp(() async {
    await WebsiteBlockStore.saveDomains(const []);
    await AppUsageLimitStore.saveRules(const []);
  });

  test('instagram 사이트만 막히고 앱 한도가 없으면 인스타 앱 한도 제안', () async {
    await WebsiteBlockStore.saveDomains(const ['instagram.com']);

    final suggestions = await BlockSuggestionEngine.evaluate();

    expect(
      suggestions.any((s) => s.id == 'suggest_instagram_app_limit'),
      true,
    );
  });

  test('인스타 앱 한도가 이미 있으면 다시 제안하지 않음', () async {
    await WebsiteBlockStore.saveDomains(const ['instagram.com']);
    await AppUsageLimitStore.saveRules(const [
      AppUsageLimitRule(
        id: 'instagram',
        label: 'Instagram',
        minutesPerWindow: 30,
        presetId: 'instagram',
      ),
    ]);

    final suggestions = await BlockSuggestionEngine.evaluate();

    expect(
      suggestions.any((s) => s.id == 'suggest_instagram_app_limit'),
      false,
    );
  });

  test('아무것도 안 막혔으면 제안 없음', () async {
    final suggestions = await BlockSuggestionEngine.evaluate();
    expect(suggestions, isEmpty);
  });
}
