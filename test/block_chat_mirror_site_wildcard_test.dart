import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_executor.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/intervention/always_on_url_pattern_store.dart';
import 'package:isle/core/intervention/website_block_store.dart';
import 'package:isle/core/safe_browser/web_content_rule_compiler.dart';

/// User request (2026-07-10): "mingky05.live" is a numbered-mirror adult
/// site (mingky01.live, mingky02.live, ... keep rotating to evade blocking).
/// Blocking one exact number doesn't help once the site rotates. Isle
/// already had a "numeric evasion" pattern detector (UrlRuleDetector) used
/// only by the per-schedule, time-windowed "advanced URL rules" settings
/// screen -- never reachable from chat, and never always-on (only active
/// during whatever schedule window it's attached to). This wires the same
/// detection into the chat block_website flow and makes it genuinely
/// always-on + wildcard, by emitting a pure regex `url-filter` Safari
/// Content Blocker rule (no `if-domain`) that matches the stem followed by
/// digits, catching any future numbered/TLD variant in one rule.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    final dir =
        Directory.systemTemp.createTempSync('isle_mirror_wildcard_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await WebsiteBlockStore.ensureOpen();
    await AlwaysOnUrlPatternStore.ensureOpen();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('"mingky05.live 차단해줘" detects the numeric-mirror stem and applies '
      'both the exact domain and an always-on wildcard pattern', () async {
    final (plan, usedAi) = await BlockChatParser.parse('mingky05.live 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'block_website');
    expect(plan.websiteDomain, 'mingky05.live');
    expect(plan.websiteDomainStem, 'mingky');
    expect(plan.reply, contains('번호를 바꿔가며'));

    final result = await BlockChatExecutor.apply(plan);
    expect(result.isFailure, false, reason: result.summary);

    expect(WebsiteBlockStore.loadDomains(), contains('mingky05.live'));
    expect(AlwaysOnUrlPatternStore.loadStems(), contains('mingky'));

    final stems = await WebContentRuleCompiler.collectAlwaysOnStems();
    final rules = WebContentRuleCompiler.rulesFromStems(stems);
    expect(rules, isNotEmpty);
    final filter = rules.first['trigger']['url-filter'] as String;
    // Must match any future numbered/TLD variant, not just the exact one.
    expect(RegExp(filter, caseSensitive: false).hasMatch('mingky99.xyz'), true);
    expect(RegExp(filter, caseSensitive: false).hasMatch('mingky1.net'), true);
    expect(RegExp(filter, caseSensitive: false).hasMatch('somethingelse.com'),
        false);
  });

  test('a normal well-known domain (no numeric mirror pattern) does not '
      'create a wildcard entry', () async {
    final (plan, usedAi) = await BlockChatParser.parse('pornhub.com 막아줘');
    expect(usedAi, false);
    expect(plan.websiteDomainStem, isNull);

    final result = await BlockChatExecutor.apply(plan);
    expect(result.isFailure, false, reason: result.summary);
    expect(AlwaysOnUrlPatternStore.loadStems(), isEmpty);
  });
}
