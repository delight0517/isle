import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/ai/block_chat/block_chat_preview.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';

/// 모아 실사용 스크린샷 제보(2026-07-11): "지금 현재 차단중인 차단 설정 보여줘"를
/// 보내면 확인 카드가 "이렇게 바꿀게요" 헤더에 불릿이 하나도 없이 취소/확인
/// 버튼만 뜬다. Cage와 같은 원인 — `BlockChatPreview.bullets()`의 switch에
/// `explain_status` case가 아예 없어서 default(빈 리스트)로 빠졌다.
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
        Directory.systemTemp.createTempSync('isle_moa_explain_status_bullets');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('"지금 현재 차단중인 차단 설정 보여줘" → 확인 카드가 빈 화면이 아니라 '
      '뭘 조회하는지 불릿으로 보여준다', () async {
    final (plan, _) =
        await BlockChatParser.parse('지금 현재 차단중인 차단 설정 보여줘');
    expect(plan.action, 'explain_status');
    expect(BlockChatPreview.bullets(plan), isNotEmpty,
        reason: '확인 카드에 최소한 "뭘 조회하는지"는 보여야 함');
    expect(BlockChatPreview.headline(plan), isNot('설정 적용'),
        reason: '헤드라인도 제네릭 기본값이 아니라 조회 전용 문구여야 함');
  });
}
