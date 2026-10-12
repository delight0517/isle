import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_schedule_dedup.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/schedule_app_target_entry.dart';
import 'package:isle/core/block_schedule/models/schedule_slot.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';

/// findNightSns가 앱 구분 없이 "야간스러운 스케줄이면 아무거나" 매칭해서,
/// 카카오톡 야간 리필이 이미 있는데 이름이 다른 틱톡 요청이 그 카카오톡
/// 스케줄을 가로채 재사용해버리던 co-mingle 버그(2026-07-06, cage에서 발견
/// 후 이식) 회귀 방지.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir =
        Directory.systemTemp.createTempSync('isle_moa_night_dedup');
    Hive.init(dir.path);
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
  });

  test('night refill dedup does not steal another app\'s schedule', () async {
    final kakaoSchedule = await BlockScheduleStore.create(
      name: '카카오톡 야간 리필 (AI)',
      slots: const [ScheduleSlot(day: 0, startMinute: 1380, endMinute: 420)],
    );
    await ScheduleAppTargetsStore.saveForSchedule(kakaoSchedule.id, [
      const ScheduleAppTargetEntry(
        targetId: 'ios_kakao',
        blockInSlot: false,
        limitEnabled: true,
        limitMinutes: 3,
        windowMinutes: 10,
      ),
    ]);

    final withoutScoping = BlockChatScheduleDedup.findNightSns(
      preferredName: 'TikTok 야간 리필 (AI)',
    );
    expect(withoutScoping?.id, kakaoSchedule.id,
        reason: '옛 동작(버그) 재현 확인 — targetIds 없이는 카카오톡 스케줄을 그대로 반환함');

    final scoped = BlockChatScheduleDedup.findNightSns(
      preferredName: 'TikTok 야간 리필 (AI)',
      targetIds: const ['ios_tiktok'],
    );
    expect(scoped, isNull,
        reason: '틱톡을 아직 대상으로 한 적 없는 스케줄이므로 카카오톡 스케줄을 가로채면 안 됨');
  });

  test('night refill dedup still reuses the same app\'s existing schedule',
      () async {
    final igSchedule = await BlockScheduleStore.create(
      name: 'Instagram 야간 리필 (AI)',
      slots: const [ScheduleSlot(day: 0, startMinute: 1260, endMinute: 420)],
    );
    await ScheduleAppTargetsStore.saveForSchedule(igSchedule.id, [
      const ScheduleAppTargetEntry(
        targetId: 'ios_instagram',
        blockInSlot: false,
        limitEnabled: true,
        limitMinutes: 15,
        windowMinutes: 30,
      ),
    ]);

    final scoped = BlockChatScheduleDedup.findNightSns(
      preferredName: 'Instagram 야간 리필 (AI) v2',
      targetIds: const ['ios_instagram', 'isle_instagram'],
    );
    expect(scoped?.id, igSchedule.id,
        reason: '이미 같은 앱(인스타)을 대상으로 하는 스케줄이면 정상적으로 재사용해야 함');
  });
}
