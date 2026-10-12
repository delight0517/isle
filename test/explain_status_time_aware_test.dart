import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_executor.dart';
import 'package:isle/core/ai/block_chat/block_chat_models.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/schedule_slot.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/intervention/app_usage_limit_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/youtube/content_filter_store.dart';

/// "왜 지금 유튜브 뮤직이 차단되어 있어??" 류 조회가 정적 enabled 플래그가 아니라
/// 지금 이 순간 실제로 시간대 창(window) 안인지를 답해야 한다
/// (cage에서 먼저 발견·수정, 2026-07-07 실사용 버그).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_moa_explain_status_now');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await ContentFilterStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
  });

  setUp(() async {
    await BlockScheduleStore.saveAll(const []);
  });

  test('status query reports "지금 활성" when now falls inside the schedule window',
      () async {
    final now = DateTime.now();
    final today = now.weekday - 1;
    final nowMinute = now.hour * 60 + now.minute;
    final startMinute = (nowMinute - 5).clamp(0, 1438);
    final endMinute = (nowMinute + 55).clamp(startMinute + 1, 1439);

    await BlockScheduleStore.create(
      name: 'YouTube Music · 화면 한도 (AI)',
      slots: [ScheduleSlot(day: today, startMinute: startMinute, endMinute: endMinute)],
    );

    const plan = BlockChatPlan(
      action: 'explain_status',
      limitPlatform: 'youtube_music',
      reply: '',
    );
    final result = await BlockChatExecutor.apply(plan);

    expect(result.isFailure, isFalse, reason: result.summary);
    expect(result.summary, contains('지금 활성'));
  });

  test(
      'status query reports "지금은 시간대 밖" when now falls outside the schedule window',
      () async {
    final now = DateTime.now();
    final today = now.weekday - 1;
    final nowMinute = now.hour * 60 + now.minute;
    final startMinute = (nowMinute + 120).clamp(0, 1400);
    final endMinute = (startMinute + 30).clamp(startMinute + 1, 1439);

    await BlockScheduleStore.create(
      name: 'YouTube Music · 화면 한도 (AI)',
      slots: [ScheduleSlot(day: today, startMinute: startMinute, endMinute: endMinute)],
    );

    const plan = BlockChatPlan(
      action: 'explain_status',
      limitPlatform: 'youtube_music',
      reply: '',
    );
    final result = await BlockChatExecutor.apply(plan);

    expect(result.isFailure, isFalse, reason: result.summary);
    expect(result.summary, contains('시간대 밖'));
  });
}
