import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';

/// Cage에서 2026-07-13 발견·수정한 3가지 문제를 모아에도 이식한 회귀
/// 테스트 (drift-check 후 이식, 사용자 요청):
/// 1) "N분 동안 차단해줘"(시간 단위만 받던 _parseQuickBlockNow가 분 단위도
///    받게)
/// 2) "몇 개"/"뭐뭐"처럼 queryCue 목록에 없던 질문 변형이 add_keyword로
///    오인되던 문제
/// 3) "유트브"/"카톡오"/"인스타그렘" 같은 앱 이름 오타가 유사도(Levenshtein)
///    매칭 없이는 대상을 못 찾던 문제
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
        Directory.systemTemp.createTempSync('isle_moa_typo_status_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('"카톡오 지금부터 30분 동안 차단해줘" (분 단위 + 오타) still works',
      () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('카톡오 지금부터 30분 동안 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'quick_block_now');
    expect(plan.appId, 'kakao');
    expect(plan.windowMinutes, 30);
  });

  test('"유트브 지금부터 1시간 동안 차단해줘" (오타) still recognizes YouTube',
      () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('유트브 지금부터 1시간 동안 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'quick_block_now');
    expect(plan.limitPlatform, 'youtube');
  });

  test('"인스타그렘 지금부터 1시간 동안 차단해줘" (오타) still recognizes Instagram',
      () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('인스타그렘 지금부터 1시간 동안 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'quick_block_now');
    expect(plan.limitPlatform, 'instagram');
  });

  test('"카카오톡 차단 몇 개 걸려있는거야" is a status query, not add_keyword',
      () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('카카오톡 차단 몇 개 걸려있는거야');
    expect(usedAi, false);
    expect(plan.action, isNot('add_keyword'));
  });

  test('"요즘 차단 뭐뭐 켜놨지" is a status query, not add_keyword', () async {
    final (plan, usedAi) = await BlockChatParser.parse('요즘 차단 뭐뭐 켜놨지');
    expect(usedAi, false);
    expect(plan.action, isNot('add_keyword'));
  });

  test('negative: common 2-char filler words must not fuzzy-match a short '
      'app alias (regression: "지금"→지니뮤직, "중인"→LINE)', () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('지금 차단 상황 알려줘');
    expect(usedAi, false);
    expect(plan.action, isNot('add_keyword'));
  });

  test('"지금 현재 차단 중인 목록 데이터 다 출력해줘" is a status query, not '
      'add_keyword (mutationCue의 포괄적 "해줘"가 queryCue의 "출력해줘" 자체를 '
      '다시 지워버리던 자기모순 버그, 2026-07-13 발견)', () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('지금 현재 차단 중인 목록 데이터 다 출력해줘');
    expect(usedAi, false);
    expect(plan.action, isNot('add_keyword'));
  });

  test('"지금 진행 중인 차단 전부 내보내줘" is a status query, not add_keyword',
      () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('지금 진행 중인 차단 전부 내보내줘');
    expect(usedAi, false);
    expect(plan.action, isNot('add_keyword'));
  });
}
