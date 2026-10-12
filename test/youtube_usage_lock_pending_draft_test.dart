import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/services/isle_user_defaults.dart';
import 'package:isle/core/youtube/youtube_usage_lock.dart';

/// "안 된다"고만 하지 않고, 타임락 대기 후 자동 적용되도록 예약하는 흐름
/// (2026-07-20 사용자 요청) — 예약/취소/자동 적용 3가지를 커버.
void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_yt_pending_draft');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
  });

  setUp(() async {
    await Hive.box<String>('isle_cache').clear();
  });

  test('reserving a draft starts the unlock countdown and stores the draft', () async {
    expect(YoutubeUsageLock.hasPendingPolicyDraft, isFalse);

    await YoutubeUsageLock.reserveDraftUntilUnlocked({
      'intervalMode': true,
      'enabled': true,
      'allowMinutes': 20.0,
      'windowHours': 3.0,
    });

    expect(YoutubeUsageLock.hasPendingPolicyDraft, isTrue);
    expect(YoutubeUsageLock.pendingPolicyDraft!['allowMinutes'], 20.0);
    // 대기가 아직 안 끝났으니 창은 안 열려 있어야 한다.
    expect(YoutubeUsageLock.unlockWindowOpen, isFalse);
    expect(YoutubeUsageLock.takeReadyPolicyDraft(), isNull);
  });

  test('cancelling a reserved draft clears both the draft and the countdown', () async {
    await YoutubeUsageLock.reserveDraftUntilUnlocked({'enabled': true});
    expect(YoutubeUsageLock.hasPendingPolicyDraft, isTrue);

    await YoutubeUsageLock.clearPendingPolicyDraft();

    expect(YoutubeUsageLock.hasPendingPolicyDraft, isFalse);
    expect(IsleUserDefaults.youtubeLimitUnlockStartedAtMs, isNull);
  });

  test('once the unlock window is open, the draft is handed back exactly once', () async {
    await YoutubeUsageLock.reserveDraftUntilUnlocked({
      'intervalMode': true,
      'allowMinutes': 20.0,
    });
    // 대기 시간이 이미 지난 것처럼 시작 시각을 과거로 되돌린다.
    await Hive.box<String>('isle_cache').put(
      'isle_pref_yt_limit_unlock_start_ms',
      DateTime.now()
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch
          .toString(),
    );

    expect(YoutubeUsageLock.unlockWindowOpen, isTrue);
    final draft = YoutubeUsageLock.takeReadyPolicyDraft();
    expect(draft, isNotNull);
    expect(draft!['allowMinutes'], 20.0);

    // 한 번 꺼내면 비워진다 — 재적용 방지.
    expect(YoutubeUsageLock.hasPendingPolicyDraft, isFalse);
    expect(YoutubeUsageLock.takeReadyPolicyDraft(), isNull);
  });

  test('reserving twice does not restart an already-running countdown', () async {
    await YoutubeUsageLock.reserveDraftUntilUnlocked({'allowMinutes': 10.0});
    final firstStart = IsleUserDefaults.youtubeLimitUnlockStartedAtMs;

    await YoutubeUsageLock.reserveDraftUntilUnlocked({'allowMinutes': 15.0});
    final secondStart = IsleUserDefaults.youtubeLimitUnlockStartedAtMs;

    expect(secondStart, firstStart, reason: '이미 대기 중이면 카운트다운을 다시 시작하면 안 됨');
    expect(YoutubeUsageLock.pendingPolicyDraft!['allowMinutes'], 15.0,
        reason: '초안 값 자체는 최신 값으로 갱신되어야 함');
  });
}
