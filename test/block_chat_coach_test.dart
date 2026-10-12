import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_coach_service.dart';
import 'package:isle/core/ai/block_chat/block_chat_models.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/library/engagement_tracker.dart';
import 'package:isle/core/library/platform_watch_limit_store.dart';

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_block_chat_coach');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await Hive.openBox<String>('isle_engagement');
    await Hive.openBox<String>('isle_external_app_shield');
    await Hive.openBox<String>('isle_platform_watch_limits');
    await EngagementTracker.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await PlatformWatchLimitStore.ensureOpen();
  });

  test('coach includes how-to after shorts toggle apply', () async {
    const plan = BlockChatPlan(action: 'toggle_shorts', toggleOn: true);
    const applied = BlockChatResult(
      summary: '숏츠 숨김',
      steps: [],
    );

    final coach =
        await BlockChatCoachService.build(plan: plan, applied: applied);

    expect(coach.isEmpty, false);
    expect(
      coach.howToUse.any((t) => t.title.contains('숏츠')),
      true,
    );
  });

  test('coach skips recommendation for already-applied action', () async {
    const plan = BlockChatPlan(action: 'toggle_shorts', toggleOn: true);
    const applied = BlockChatResult(summary: 'ok', steps: []);

    final coach =
        await BlockChatCoachService.build(plan: plan, applied: applied);

    expect(
      coach.recommendations.any((r) => r.title.contains('숏츠')),
      false,
    );
  });

  test('coach keeps follow-up recommendations small and progressive', () async {
    const plan = BlockChatPlan(action: 'youtube_limit', dailyMinutes: 30);
    const applied = BlockChatResult(summary: 'ok', steps: []);

    final coach =
        await BlockChatCoachService.build(plan: plan, applied: applied);

    expect(coach.recommendations.length, lessThanOrEqualTo(2));
    expect(
      coach.recommendations.any((r) => r.title.contains('나눠 쓰기')),
      true,
    );
  });

  test('coach explains usage budget can be adjusted later', () async {
    const plan = BlockChatPlan(
      action: 'usage_budget',
      limitPlatform: 'instagram',
      dailyMinutes: 30,
      sessionMinutes: 10,
      windowMinutes: 60,
    );
    const applied = BlockChatResult(summary: 'ok', steps: []);

    final coach =
        await BlockChatCoachService.build(plan: plan, applied: applied);

    expect(
      coach.howToUse.any((t) => t.title.contains('미세 조절')),
      true,
    );
    expect(coach.recommendations.length, lessThanOrEqualTo(2));
  });

  test('persona bundle collects sub-plan actions for coach', () async {
    const plan = BlockChatPlan(
      action: 'persona_bundle',
      personaId: 'minsu_exam_morning',
    );
    const applied = BlockChatResult(summary: 'ok', steps: []);

    final coach =
        await BlockChatCoachService.build(plan: plan, applied: applied);

    expect(coach.howToUse.isNotEmpty, true);
    expect(
      coach.howToUse
          .any((t) => t.title.contains('스케줄') || t.title.contains('타임락')),
      true,
    );
  });

  test('failure result yields empty coach', () async {
    const plan = BlockChatPlan(action: 'toggle_shorts');
    final coach = await BlockChatCoachService.build(
      plan: plan,
      applied: BlockChatResult.fail('실패'),
    );
    expect(coach.isEmpty, true);
  });
}
