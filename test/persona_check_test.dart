import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/ai_config_store.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';

/// 페르소나 점검 — 앱을 잘 모르는 유저가 한국어로 자연스럽게 명령했을 때
/// 파서가 어떻게 해석하는지 출력해서 "기대대로/이상한지" 눈으로 확인한다. (모아/SNS)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    final dir = Directory.systemTemp.createTempSync('isle_persona_check');
    Hive.init(dir.path);
    await AiConfigStore.ensureOpen();
  });

  Future<void> run(String title, List<String> prompts) async {
    // ignore: avoid_print
    print('\n================ $title ================');
    for (var i = 0; i < prompts.length; i++) {
      final p = prompts[i];
      final (plan, usedAi) = await BlockChatParser.parse(p);
      final f = <String>[];
      if (plan.keyword != null) f.add('keyword=${plan.keyword}');
      if (plan.endHour != 0 || plan.endMinute != 0) {
        f.add('end=${plan.endHour}:${plan.endMinute}');
      }
      if (plan.startHour != null) f.add('start=${plan.startHour}:${plan.startMinute}');
      if (plan.blockIsleYoutube) f.add('isleYoutube');
      if (plan.blockSafariNote) f.add('safari');
      if (plan.removeUrl != null) f.add('removeUrl=${plan.removeUrl}');
      if (plan.websiteDomain != null) f.add('domain=${plan.websiteDomain}');
      if (plan.relaxTarget != null) f.add('relax=${plan.relaxTarget}');
      if (plan.pauseMinutes != null) f.add('pause=${plan.pauseMinutes}m');
      if (plan.dailyMinutes != null) f.add('daily=${plan.dailyMinutes}m');
      if (plan.sessionMinutes != null) f.add('session=${plan.sessionMinutes}m');
      if (plan.channelName != null) f.add('channel=${plan.channelName}');
      if (plan.limitPlatform != null) f.add('platform=${plan.limitPlatform}');
      if (plan.toggleOn != null) f.add('on=${plan.toggleOn}');
      if (plan.scheduleQuery != null) f.add('q=${plan.scheduleQuery}');
      // ignore: avoid_print
      print('${i + 1}. 「$p」\n   → ${plan.action} ${usedAi ? "[AI]" : "[local]"} '
          '${f.join(", ")}\n   reply: ${plan.reply.replaceAll("\n", " ").trim()}');
    }
  }

  test('모아/SNS — 라운드1 (10)', () async {
    await run('모아/SNS 라운드1', [
      '아침 10시까지 유튜브 좀 막아줘',
      '밤 11시부터 아침 7시까지 인스타 막아줘',
      '담배 관련 글 안 뜨게 해줘',
      'youtube.com 막아줘',
      '유튜브 하루 30분만 보게 해줘',
      '인스타 차단 풀어줘',
      '릴스 그만 보고 싶어',
      '오후 2시부터 4시까지 유튜브 잠깐 풀어줘',
      '도박 사이트 다 막아줘',
      '이 채널 차단해줘 https://youtube.com/@somechannel',
    ]);
    expect(true, true);
  });

  test('모아/SNS — 라운드2 (10, 신규)', () async {
    await run('모아/SNS 라운드2', [
      '유튜브 숏츠 안 보이게 해줘',
      '인스타 하루 1시간만 쓰게 해줘',
      "유튜브 채널 '침착맨' 차단해줘",
      '밤 10시부터 아침 6시까지 폰 SNS 다 막아줘',
      '게임 관련 영상 숨겨줘',
      '넷플릭스 막아줘',
      '유튜브 하루 2시간 한도로 해줘',
      '오전 9시부터 오후 6시까지 유튜브 풀어줘',
      '릴스 다시 보게 해줘',
      '인스타 20분 쓰고 40분 쉬게 해줘',
    ]);
    expect(true, true);
  });
}
