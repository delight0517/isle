import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/ai_config_store.dart';
import 'package:isle/core/ai/block_chat/block_chat_executor.dart';
import 'package:isle/core/ai/block_chat/block_chat_models.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/ai/block_chat/block_chat_preview.dart';
import 'package:isle/core/ai/block_chat/block_chat_transcript_store.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/schedule_enforcement_mode.dart';
import 'package:isle/core/block_schedule/safety_baseline_service.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/intervention/schedule_screen_time_store.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_store.dart';
import 'package:isle/core/library/platform_watch_limit_store.dart';
import 'package:isle/core/usage_budget/usage_budget_store.dart';

/// [디버깅 시뮬레이터] 실제 파서(BlockChatParser) → 확인 카드(BlockChatPreview)
/// → 실행기(BlockChatExecutor) 파이프라인을, 실기기와 동일한 Dart 코드로
/// 그대로 태워서 "채팅 한 마디가 실제로 어떤 확인 카드 문구를 보여주고 스토어를
/// 어떻게 바꾸는지"를 실기기 없이 재현한다(2026-07-20 사용자 요청).
///
/// 네이티브 레이어(iOS ManagedSettings 쉴드·Screen Time 권한 등)는 여기서
/// 절대 재현 불가 — 이건 파서·확인카드·스토어·잠금/타임락 같은 **Dart 로직
/// 100%**만 실기기와 동일함을 보장한다. (실제 화면 렌더링·플랫폼 채널 호출은
/// 범위 밖.)
///
/// `flutter test test/chat_confirm_card_scenarios_dump_test.dart` 로 실행하면
/// 3가지 시나리오(덮어쓰기/변동/스케줄 안내)의 전체 대화가 stdout에 출력된다.
/// 매 턴을 BlockChatTranscriptStore(source: simulator)에도 기록해서, 실사용
/// 채팅 기록과 같은 7일 로그에서 함께 조회할 수 있다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    final dir = Directory.systemTemp.createTempSync('isle_chat_simulator');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    await PlatformWatchLimitStore.ensureOpen();
    await UsageBudgetStore.ensureOpen();
    await AiConfigStore.ensureOpen();
    await ScheduleRuleStore.ensureOpen();
    await BlockChatTranscriptStore.ensureOpen();
    // 실제 설치 상태와 동일하게 안전 라인부터 깔아둔다 — "실제 이용하는
    // 스케줄 프리셋이 시스템상 어떻게 변화하는지" 재현하려면 빈 스토어가
    // 아니라 실제 부팅 후 상태에서 시작해야 함.
    await SafetyBaselineService.seedIfNeeded();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  /// 한 턴을 실제 파이프라인으로 태우고 진단 정보를 stdout에 출력.
  /// AI 폴백(usedAi)으로 새면 이 headless 환경에선 검증 불가하므로 표시만.
  Future<void> runTurn(String label, String userText, {bool confirm = true}) async {
    print('\n─────────────────────────────────────────');
    print('[$label] 사용자: "$userText"');

    final (plan, usedAi) = await BlockChatParser.parse(userText);
    print('  → 파싱 action: ${plan.action}${usedAi ? " (AI 폴백)" : ""}');

    if (BlockChatPreview.isInfoOnly(plan.action)) {
      final reply = plan.reply.isNotEmpty ? plan.reply : '(빈 응답)';
      print('  → 정보성 응답(확인 카드 없음): $reply');
      await BlockChatTranscriptStore.recordTurn(
        userText: userText,
        assistantText: reply,
        plan: plan,
        outcome: 'info_only',
        source: 'simulator',
      );
      return;
    }

    final headline = BlockChatPreview.headline(plan);
    final bullets = BlockChatPreview.bullets(plan);
    print('  → [확인 카드] 제목: $headline');
    for (final b in bullets) {
      print('       · $b');
    }

    if (!confirm) {
      print('  → (사용자가 취소함 — 적용 안 함)');
      await BlockChatTranscriptStore.recordTurn(
        userText: userText,
        assistantText: '취소했어요.',
        plan: plan,
        outcome: 'cancelled',
        source: 'simulator',
      );
      return;
    }

    final result = await BlockChatExecutor.apply(plan);
    print('  → [확인 적용 이후 실제 응답] ${result.summary}');
    for (final s in result.steps) {
      print('       · ${s.title}: ${s.detail}');
    }
    await BlockChatTranscriptStore.recordTurn(
      userText: userText,
      assistantText: result.summary,
      plan: plan,
      outcome: result.isFailure ? 'failed' : 'applied',
      source: 'simulator',
    );
  }

  void dumpSchedule(String label) {
    final all = BlockScheduleStore.loadAll();
    print('  [스토어 상태: $label] 스케줄 ${all.length}개');
    for (final s in all) {
      print(
        '    - 「${s.name}」 enabled=${s.enabled} locked=${s.locked} '
        'mode=${s.enforcementMode} slots=${s.slots.map((sl) => "${sl.day}:${sl.startMinute}-${sl.endMinute}").join(",")}',
      );
    }
  }

  test('시나리오 A — 덮어쓰기(같은 야간 스케줄을 다른 시간으로 다시 요청)', () async {
    await runTurn('A-1', '유튜브 밤 9시부터 아침 7시까지 차단해줘');
    dumpSchedule('A-1 이후');

    // 같은 종류(야간) 스케줄을 다른 시간으로 다시 요청 — 덮어쓰기/병합 갈림길.
    await runTurn('A-2', '유튜브 밤 10시부터 아침 8시까지 차단해줘');
    dumpSchedule('A-2 이후 (덮어쓰기 결과)');
  });

  test('시나리오 B — 변동(기존 스케줄 이름·시간 변경)', () async {
    await runTurn('B-1', '유튜브 밤 9시부터 아침 7시까지 차단해줘');
    dumpSchedule('B-1 이후');

    await runTurn('B-2', '방금 그 스케줄 이름을 "취침 모드"로 바꿔줘');
    dumpSchedule('B-2 이후 (이름 변경 결과)');
  });

  test('시나리오 C — 스케줄 안내(현재 상태 조회, 확인 카드 없음)', () async {
    await runTurn('C-1', '유튜브 밤 9시부터 아침 7시까지 차단해줘');
    await runTurn('C-2', '지금 뭐가 막혀있어?');
  });

  test('시나리오 D(보너스) — 안전 라인과 겹치는 요청 → 15분 타임락 큐잉 안내', () async {
    dumpSchedule('초기(안전 라인만 있음)');
    await runTurn('D-1', '유튜브 지금 좀 급한 일 있어서 잠깐 풀어줘');
    dumpSchedule('D-1 이후 (즉시 안 풀리고 큐잉만 되는지 확인)');
  });
}
