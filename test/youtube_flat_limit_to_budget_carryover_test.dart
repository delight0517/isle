import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_executor.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/library/platform_watch_limit_store.dart';

import 'package:isle/core/usage_budget/usage_budget_store.dart';
import 'package:isle/core/usage_budget/usage_budget_models.dart';
import 'package:isle/core/youtube/youtube_watch_timer_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    final dir = Directory.systemTemp.createTempSync('isle_carryover_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await PlatformWatchLimitStore.ensureOpen();
    await YoutubeWatchTimerStore.ensureOpen();
    await UsageBudgetStore.ensureOpen();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  // 실사용 제보(2026-07-14): "유튜브 하루 20분" 평범한 총량 한도가 이미 켜져
  // 있는 상태에서 "10분씩 쪼개기" 같은 채팅 요청을 보내면, 나눠쓰기 정책엔
  // 기존 이력이 없어(existing==null) daily가 하드코딩 기본값 60으로 새면서
  // 원래 20분이 조용히 사라졌다. PlatformWatchLimitStore의 평범한 한도값도
  // daily 폴백 체인에 넣어서 고침.
  test('existing 20-min flat daily limit carries over when switching to '
      'session-split via chat, instead of resetting to the hardcoded 60min '
      'default', () async {
    await PlatformWatchLimitStore.setEnabled(PlatformWatchId.youtube, true);
    await PlatformWatchLimitStore.setLimitMinutes(PlatformWatchId.youtube, 20);

    final (plan, usedAi) =
        await BlockChatParser.parse('유튜브 나눠쓰기로 늘려줘. 30분마다 10분씩');
    expect(usedAi, false);
    expect(plan.action, 'youtube_budget');
    expect(plan.extendsExistingBudget, true);
    // flatDailyFallback(executor 쪽 수정)은 plan.extendsExistingBudget 여부와
    // 무관하게 "daily 언급 없음 + UsageBudgetStore 기존 정책 없음 + 평범한
    // 총량 한도 켜짐" 조건만으로 동작한다 — 파서가 이 문장을 "연장" 의도로
    // 잡든 못 잡든 상관없이 executor 레벨에서 안전망 역할을 한다.
    expect(plan.dailyMinutes, isNull);

    await BlockChatExecutor.apply(plan);

    final policy = UsageBudgetStore.policyFor(UsageBudgetTarget.youtube);
    expect(policy, isNotNull);
    expect(policy!.dailyCapMinutes, 20);
    expect(policy.burstCapMinutes, 10);
    expect(policy.refillIntervalMinutes, 30);
  });

  test('daily minutes explicitly stated in the message still wins over the '
      'flat-limit fallback — regression check', () async {
    await PlatformWatchLimitStore.setEnabled(PlatformWatchId.youtube, true);
    await PlatformWatchLimitStore.setLimitMinutes(PlatformWatchId.youtube, 20);

    final (plan, usedAi) =
        await BlockChatParser.parse('유튜브 하루 45분, 30분마다 10분씩 쪼개줘');
    expect(usedAi, false);
    expect(plan.dailyMinutes, 45);

    await BlockChatExecutor.apply(plan);

    final policy = UsageBudgetStore.policyFor(UsageBudgetTarget.youtube);
    expect(policy!.dailyCapMinutes, 45);
  });
}
