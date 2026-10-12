import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_executor.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_store.dart';
import 'package:isle/core/intervention/app_usage_limit_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/youtube/content_filter_store.dart';

/// Real conversation repro (exported 2026-07-10, 모아 v1.6.0+327):
/// "인터넷 브라우저는 2300부터 0800까지 차단해줘" fell all the way through to
/// the AI fallback (and "인터넷을 2300부터 차단해줘" was even worse -- the
/// whole phrase got registered as an add_keyword). Two root causes:
/// 1. "인터넷"/"브라우저" weren't recognized as Safari synonyms at all.
/// 2. `_parseNightSchedule`'s own inline time regex only understood "N시"
///    Korean-hour notation, never delegating to the already-fixed
///    `_parseNightStartTime`/`_parseNightEndTime` helpers that support bare
///    HHMM ("2300") -- and its overnight-intent gate required an explicit
///    Korean night word (밤/야간/저녁) even when the raw numbers themselves
///    (23xx -> 0~11xx) already unambiguously imply an overnight span.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 2026-07-12: 인앱 브라우저(isle_customweb)는 Screen Time 없이 100%
  // 자동으로 막히는데, executor의 permission-gap 로직이 night_schedule이면
  // 무조건 "OS 권한 필요" 경고를 붙이던 버그로 사용자에게 거짓 경고가 나갔다.
  test('applying a browser-only night_schedule does NOT attach a false '
      '"Screen Time으로 선택하세요" permission gap', () async {
    const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    final dir = Directory.systemTemp.createTempSync('isle_browser_permgap');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await ContentFilterStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await ScheduleRuleStore.ensureOpen();
    await BlockScheduleStore.saveAll(const []);

    final (plan, _) = await BlockChatParser.parse('인터넷은 오후 1시까지 막아줘');
    final result = await BlockChatExecutor.apply(plan);
    expect(result.isFailure, isFalse, reason: result.summary);
    expect(result.summary, isNot(contains('Screen Time')));
    expect(
      result.steps.any((s) => s.needsManualSetup),
      isFalse,
      reason: '인앱 브라우저는 Screen Time 앱 선택이 필요 없어야 함',
    );
  });

  test('"인터넷 브라우저는 2300부터 0800까지 차단해줘" applies a real Safari '
      'night schedule', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '인터넷 브라우저는 2300부터 0800까지 차단해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.appId, 'safari');
    expect(plan.startHour, 23);
    expect(plan.startMinute, 0);
    expect(plan.endHour, 8);
    expect(plan.endMinute, 0);
  });

  test('"인터넷을 2300부터 차단해줘" is not misfiled as an add_keyword',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '인터넷을 2300부터 차단해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.appId, 'safari');
    expect(plan.startHour, 23);
  });

  test('"사파리 2300부터 0800까지 차단해줘" (explicit Safari, bare HHMM) works',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '사파리 2300부터 0800까지 차단해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'night_schedule');
    expect(plan.appId, 'safari');
    expect(plan.startHour, 23);
    expect(plan.endHour, 8);
  });
}
