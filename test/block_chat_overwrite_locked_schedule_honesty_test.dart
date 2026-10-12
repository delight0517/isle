import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/ai_config_store.dart';
import 'package:isle/core/ai/block_chat/block_chat_executor.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_store.dart';
import 'package:isle/core/intervention/app_usage_limit_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/usage_budget/usage_budget_store.dart';
import 'package:isle/core/youtube/content_filter_store.dart';

/// 2026-07-13 실사용 확인 — "전부 덮어쓰기" 확인 후 겹치는 기존 스케줄을 끄려고
/// 하는데, 그 스케줄이 타임락(커밋먼트 락) 중이면 `BlockScheduleStore.upsert`가
/// 내부적으로 `SchedulePersistGuard`를 거치며 enabled:false를 조용히 되돌린다.
/// 그런데 `_disableConflictingRationSchedules`가 그 결과를 확인 안 하고 "껐다"고
/// 보고해서, 채팅이 "기존 스케줄 정리: OO 껐어요"라는 거짓 성공 메시지를 냈다 —
/// 실제로는 두 스케줄(옛 완전 차단 + 새 나눠쓰기)이 겹친 채로 남아 있었다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    final dir =
        Directory.systemTemp.createTempSync('isle_moa_overwrite_locked_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleRuleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await ContentFilterStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await UsageBudgetStore.ensureOpen();
    await AiConfigStore.ensureOpen();
  });

  test('겹치는 타임락 스케줄을 "전부 덮어쓰기"해도 실제로 못 끄면 정직하게 경고하고, '
      '거짓으로 "껐어요"라고 하지 않는다', () async {
    final (blockPlan, _) = await BlockChatParser.parse(
      '매일 12:30까지 전날 밤부터 인터넷 브라우저 차단해줘',
    );
    final r1 = await BlockChatExecutor.apply(blockPlan);
    expect(r1.isFailure, false, reason: r1.summary);

    final schedule = BlockScheduleStore.loadAll()
        .firstWhere((s) => s.name.contains('Safari'));
    expect(schedule.locked, true, reason: '방금 만든 스케줄은 타임락(커밋먼트 락)이 걸려 있어야 함');

    final (rationPlan, _) = await BlockChatParser.parse(
      '매일 09:30부터 12:30까지 인터넷 50분에 10분만 허락해줘',
    );
    expect(rationPlan.overwriteCandidates, isNotEmpty,
        reason: '겹치는 기존 스케줄이 있으면 바로 적용하지 않고 먼저 물어봐야 함');

    final (confirmed, _) =
        await BlockChatParser.parseWithContext('전부', previousPlan: rationPlan);
    final r2 = await BlockChatExecutor.apply(confirmed);
    expect(r2.isFailure, false, reason: r2.summary);

    // 새 나눠쓰기 정책은 정상적으로 저장돼야 한다.
    final policy = UsageBudgetStore.policyFor('app:safari');
    expect(policy?.enabled, true);
    expect(policy?.windowStartMinute, 9 * 60 + 30);
    expect(policy?.windowEndMinute, 12 * 60 + 30);

    // 옛 스케줄은 타임락 때문에 실제로는 안 꺼진 채 남아 있어야 하고(정직한 현재 상태),
    final stillLocked = BlockScheduleStore.loadAll()
        .firstWhere((s) => s.id == schedule.id);
    expect(stillLocked.enabled, true,
        reason: '타임락 중인 스케줄은 실제로 꺼지지 않는다 — 이게 실제 상태다');

    // 거짓 성공("...껐어요")이 아니라 정직하게 못 껐다고 경고해야 한다.
    expect(r2.summary, isNot(contains('${schedule.name} 껐어요')));
    expect(r2.summary, contains('타임락 중이라 못 껐어요'));
  });
}
