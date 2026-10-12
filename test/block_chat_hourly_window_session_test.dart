import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/ai_config_store.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';

/// "유튜브 앱을 1900부터 2200까지는 한시간에 5분씩만 허락해줘"가 실제로
/// session=5분/window=60분이 아니라 session=cooldown=daily=60(입력한
/// "5분"이 통째로 무시됨)으로 나가던 실사용 버그(2026-07-15, 사용자
/// 제보 — 개발자용 채팅 로그 export로 발견).
///
/// 원인: `_matchIntervalThenSession`이 "N분에 M분"(분 단위 창)만 인식하고
/// "N시간에 M분"(시간 단위 창)은 인식하지 못해서, "한시간"→"1시간"으로는
/// 정규화됐지만 intervalMatch가 그냥 null이 됐다. intervalMatch가 null이면
/// 호출부가 _parseAllMinutes(t)의 첫 숫자를 세션으로 쓰는데, "1시간"이
/// 60분으로 환산돼 "5분"보다 먼저 mins 리스트에 들어가 있어서 세션 자리에
/// 엉뚱하게 60이 들어갔다. "시간에"도 받아서 시간→분 환산하도록 수정.
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
        Directory.systemTemp.createTempSync('isle_hourly_window_session_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await AiConfigStore.ensureOpen();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('"1900부터 2200까지는 한시간에 5분씩만 허락해줘" → session=5, not 60',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '유튜브 앱을 1900부터 2200까지는 한시간에 5분씩만 허락해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'youtube_budget');
    expect(plan.sessionMinutes, 5);
    expect(plan.cooldownMinutes, 60);
    expect(plan.startHour, 19);
    expect(plan.endHour, 22);
  });

  test('"1시간에 10분씩만" (숫자 그대로, 한글 수사 없이) also parses window/session '
      'correctly', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '유튜브 앱을 1시간에 10분씩만 허락해줘',
    );
    expect(usedAi, false);
    expect(plan.sessionMinutes, 10);
    expect(plan.cooldownMinutes, 60);
  });

  test('"0800에서 0930까지는 10분에 5분만" keeps the requested time window',
      () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '아침에는 0800에서 0930까지는 유튜브 10분에 5분만 허용해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'youtube_budget');
    expect(plan.startHour, 8);
    expect(plan.startMinute, 0);
    expect(plan.endHour, 9);
    expect(plan.endMinute, 30);
    expect(plan.sessionMinutes, 5);
    expect(plan.cooldownMinutes, 10);
  });
}
