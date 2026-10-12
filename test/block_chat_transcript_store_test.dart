import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_models.dart';
import 'package:isle/core/ai/block_chat/block_chat_transcript_store.dart';
import 'package:isle/core/constants/app_release_info.dart';

/// 실제 채팅 원문(사용자 발화+AI 응답 전문) 7일 보관 store (2026-07-20 요청) —
/// BlockAuditLogStore(14일, 구조화 요약만)와 별개로 대화 텍스트까지 담는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('isle_chat_transcript_test');
    Hive.init(dir.path);
    await BlockChatTranscriptStore.ensureOpen();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('recordTurn()이 버전·plan·outcome을 함께 저장한다', () async {
    const plan = BlockChatPlan(action: 'night_schedule', endHour: 22, endMinute: 0);
    await BlockChatTranscriptStore.recordTurn(
      userText: '유튜브 10시부터 차단해줘',
      assistantText: '「안전 라인 — 야간 완전 차단」 스케줄을 만들었어요.',
      plan: plan,
      outcome: 'applied',
    );

    final entries = BlockChatTranscriptStore.loadRecent();
    expect(entries, hasLength(1));
    final e = entries.first;
    expect(e.userText, '유튜브 10시부터 차단해줘');
    expect(e.assistantText, contains('안전 라인'));
    expect(e.appVersion, AppReleaseInfo.pubspecVersion);
    expect(e.planAction, 'night_schedule');
    expect(e.planJson?['end_hour'], 22);
    expect(e.outcome, 'applied');
    expect(e.source, 'live');
  });

  test('7일보다 오래된 항목은 pruneNow()로 정리된다', () async {
    final old = {
      'id': 'old_1',
      'at': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
      'appVersion': '1.0.0+1',
      'userText': '오래된 대화',
      'assistantText': '옛날 응답',
      'outcome': 'applied',
      'source': 'live',
    };
    await BlockChatTranscriptStore.box.put('entries_v1', jsonEncode([old]));

    await BlockChatTranscriptStore.recordTurn(
      userText: '최근 대화',
      assistantText: '최근 응답',
      outcome: 'applied',
    );

    final recent = BlockChatTranscriptStore.loadRecent();
    expect(recent, hasLength(1));
    expect(recent.first.userText, '최근 대화');
  });

  test('cancelled/info_only outcome도 그대로 저장된다', () async {
    await BlockChatTranscriptStore.recordTurn(
      userText: '아 됐어 취소',
      assistantText: '취소했어요. 바꾸고 싶은 내용을 다시 말씀해 주세요.',
      outcome: 'cancelled',
    );
    await BlockChatTranscriptStore.recordTurn(
      userText: '지금 뭐 막혀있어?',
      assistantText: '지금은 유튜브가 막혀 있어요.',
      outcome: 'info_only',
    );
    final entries = BlockChatTranscriptStore.loadRecent();
    expect(entries.map((e) => e.outcome), containsAll(['cancelled', 'info_only']));
  });
}
