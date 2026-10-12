import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/ai/block_chat/block_chat_models.dart';
import 'package:isle/core/ai/block_chat/block_chat_preview.dart';

/// 모아 쪽 동일 감사 — Cage의 `block_chat_confirm_card_bullets_coverage_test.dart`
/// 와 같은 목적/구조 (2026-07-11, 사용자 요청: "카드에서 필수적인 정보가 뜨는지,
/// 누락된거 없는지 테스트"). 모아·Cage는 독립적으로 drift된 포크라 액션 목록이
/// 다르다 — quick_block_now(모아 전용, Cage엔 export_active_blocks 대신 이게 있음),
/// set_default_lock_cooldown(모아 전용) 포함.
void main() {
  const alwaysInformative = [
    'morning_schedule',
    'allow_window',
    'night_schedule',
    'youtube_budget',
    'usage_budget',
    'platform_limit',
    'music_foreground_limit',
    'relax_block',
    'remove_schedule',
    'morning_habit_pack',
    'toggle_shorts',
    'toggle_reels',
    'toggle_reels_guard',
    'explain_status',
    'quick_block_now',
    'set_default_lock_cooldown',
  ];

  for (final action in alwaysInformative) {
    test('"$action" 확인 카드는 필드가 없어도 항상 불릿을 보여준다', () {
      final plan = BlockChatPlan(action: action);
      expect(BlockChatPreview.bullets(plan), isNotEmpty,
          reason: '$action이 확인 카드에 아무 내용도 없이 취소/확인 버튼만 보이면 안 됨');
    });
  }

  test('add_keyword — 키워드가 있으면 반드시 불릿에 나온다', () {
    final plan = BlockChatPlan(action: 'add_keyword', keyword: '도박');
    expect(BlockChatPreview.bullets(plan), contains(contains('도박')));
  });

  test('block_website — 도메인이 있으면 반드시 불릿에 나온다', () {
    final plan =
        BlockChatPlan(action: 'block_website', websiteDomain: 'example.com');
    expect(BlockChatPreview.bullets(plan), contains(contains('example.com')));
  });

  test('rename_schedule — 새 이름이 있으면 반드시 불릿에 나온다', () {
    final plan =
        BlockChatPlan(action: 'rename_schedule', scheduleNewName: '야간 차단');
    expect(BlockChatPreview.bullets(plan), contains(contains('야간 차단')));
  });

  test('night_schedule은 대상 앱을 보여줘야 함 (Cage에서 먼저 발견, 2026-07-11 '
      '비주얼 리뷰 시뮬레이션에서 이식 — 모아는 아예 대상 표시 자체가 없었음)',
      () {
    final plan = BlockChatPlan(action: 'night_schedule', appId: 'kakao');
    final bullets = BlockChatPreview.bullets(plan);
    expect(bullets, contains(contains('카카오톡')),
        reason: '완전 차단 카드에도 대상 앱이 나와야 함');
  });

  test('youtube_music은 카드에서 플레인 유튜브가 아니라 YouTube Music으로 정확히 '
      '표시돼야 함 (Cage에서 먼저 발견, 2026-07-11 이식)', () {
    final plan = BlockChatPlan(action: 'usage_budget', limitPlatform: 'youtube_music');
    final bullets = BlockChatPreview.bullets(plan);
    expect(BlockChatPreview.headline(plan), contains('YouTube Music'));
    final target = bullets.where((b) => b.startsWith('대상:')).toList();
    if (target.isNotEmpty) {
      expect(target.first, contains('YouTube Music'));
    }
  });

  test('모든 액션이 최소한 headline()은 제네릭 기본값이 아니거나, bullets()가 비어 있지 않다', () {
    const fieldDependent = [
      'add_keyword',
      'remove_keyword',
      'block_channel',
      'block_website',
      'block_url',
      'remove_url',
      'rename_schedule',
      'update_schedule_time',
      'add_schedule_days',
      'remove_schedule_days',
      'safari_pause',
      'youtube_limit',
      'app_session_limit',
      'persona_bundle',
    ];
    for (final action in fieldDependent) {
      final plan = BlockChatPlan(action: action);
      expect(BlockChatPreview.headline(plan), isNot('설정 적용'),
          reason: '$action의 헤드라인이 제네릭 기본값으로 새면 안 됨');
    }
  });
}
