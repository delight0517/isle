import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_executor.dart';
import 'package:isle/core/ai/block_chat/block_chat_models.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/block/rule_removal_lock.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/intervention/app_usage_limit_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/intervention/website_block_store.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_store.dart';
import 'package:isle/core/services/isle_user_defaults.dart';
import 'package:isle/core/youtube/content_filter_store.dart';

/// cage(11-1Isle_the_Blocker)에서 먼저 구현한 "모든 차단 초기화" 기능을 이식.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    final dir = Directory.systemTemp.createTempSync('isle_moa_reset_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await ContentFilterStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await ScheduleRuleStore.ensureOpen();
    await WebsiteBlockStore.ensureOpen();
  });

  setUp(() async {
    await BlockScheduleStore.saveAll(const []);
    await WebsiteBlockStore.saveDomains(const []);
    await RuleRemovalLock.setLockEnabled(false);
    await IsleUserDefaults.setPendingFullResetRequested(false);
  });

  test('파서: "모든 차단 초기화해줘" → reset_all_blocks', () async {
    final (plan, usedAi) = await BlockChatParser.parse('모든 차단 초기화해줘');
    expect(usedAi, false);
    expect(plan.action, 'reset_all_blocks');
  });

  test('파서: 단일 앱 지칭은 여전히 다른 액션으로 (오탐 방지)', () async {
    final (plan, _) = await BlockChatParser.parse('카카오톡 차단 스케줄 초기화해줘');
    expect(plan.action, isNot('reset_all_blocks'));
  });

  test('실행: 삭제 대기 잠금 꺼져 있으면 스케줄 없는 항목들은 즉시 전부 초기화', () async {
    // 스케줄과 무관한 저장소(웹사이트 도메인 등)는 커밋먼트 잠금과 상관없이
    // 항상 즉시 지워져야 한다 — 이 락은 "스케줄" 전용 개념이라서.
    await WebsiteBlockStore.addCustomDomain('example.com');
    expect(WebsiteBlockStore.loadDomains(), isNotEmpty);

    final result = await BlockChatExecutor.apply(
      const BlockChatPlan(action: 'reset_all_blocks', reply: ''),
    );
    expect(result.isFailure, isFalse, reason: result.summary);
    expect(WebsiteBlockStore.loadDomains(), isEmpty);
    expect(IsleUserDefaults.pendingFullResetRequested, isFalse);
  });

  test(
      '실행: 커밋먼트 잠금(locked:true) 걸린 스케줄은 "모든 차단 초기화"로도 안 지워짐 '
      '(cage에서 07-11 발견·수정한 회귀 버그 이식 — 예전엔 RuleRemovalLock만 보고 '
      '스케줄 자체 잠금을 무시하고 지웠음)', () async {
    // night_schedule은 항상 locked:true + lockCooldownMinutes:30으로 생성됨
    // — 즉 사용자가 스스로 건 "삭제 대기" 커밋먼트다. RuleRemovalLock(키워드/
    // URL 전용, 별개 시스템)이 꺼져 있어도 이 스케줄 자체의 커밋먼트 잠금은
    // 별도로 지켜져야 한다.
    await BlockChatExecutor.apply(BlockChatPlan(
      action: 'night_schedule',
      reply: '',
      startHour: 21,
      endHour: 7,
      days: const [0, 1, 2, 3, 4, 5, 6],
      appId: 'kakao',
    ));
    expect(BlockScheduleStore.loadAll(), isNotEmpty);
    await RuleRemovalLock.setLockEnabled(false); // 전역 삭제-대기 락은 꺼둠

    final result = await BlockChatExecutor.apply(
      const BlockChatPlan(action: 'reset_all_blocks', reply: ''),
    );
    expect(result.isFailure, isFalse, reason: result.summary);
    expect(BlockScheduleStore.loadAll(), isNotEmpty,
        reason: '커밋먼트 잠금 스케줄은 RuleRemovalLock과 무관하게 그대로 남아야 함');
    expect(result.summary, contains('잠금'));
  });

  test('실행: 삭제 대기 잠금 켜져 있으면 즉시 적용 대신 대기 플래그만, 잠금 해제되면 자동 적용',
      () async {
    await WebsiteBlockStore.addCustomDomain('example.com');
    await RuleRemovalLock.setLockEnabled(true);
    await RuleRemovalLock.clearUnlockCountdown();

    final result = await BlockChatExecutor.apply(
      const BlockChatPlan(action: 'reset_all_blocks', reply: ''),
    );
    expect(result.isFailure, isFalse, reason: result.summary);
    expect(WebsiteBlockStore.loadDomains(), isNotEmpty, reason: '아직 지워지면 안 됨(대기 중)');
    expect(IsleUserDefaults.pendingFullResetRequested, isTrue);

    await RuleRemovalLock.setLockEnabled(false);
    await BlockChatExecutor.applyPendingFullResetIfDue();
    expect(WebsiteBlockStore.loadDomains(), isEmpty, reason: '잠금 해제 후엔 자동 적용돼야 함');
    expect(IsleUserDefaults.pendingFullResetRequested, isFalse);
  });
}
