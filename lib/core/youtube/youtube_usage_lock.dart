import 'dart:convert';

import '../services/isle_user_defaults.dart';

/// YouTube 한도 설정 — 느슨한 변경/모드 변경 타임락.
class YoutubeUsageLock {
  YoutubeUsageLock._();

  static const freezeChoices = [15, 30, 60, 120];

  static bool get raiseLockEnabled => IsleUserDefaults.youtubeLimitRaiseLockEnabled;

  static bool get disablePending =>
      IsleUserDefaults.youtubeLimitRaiseLockDisablePending;

  /// 타임락을 끄려면 대기 완료 후에만 가능 (스위치 우회 방지)
  static bool get canDisableRaiseLock => !raiseLockEnabled || unlockWindowOpen;

  static Future<void> setRaiseLockEnabled(bool v) async {
    await IsleUserDefaults.setYoutubeLimitRaiseLockEnabled(v);
    await IsleUserDefaults.setYoutubeLimitRaiseLockDisablePending(false);
    if (!v) {
      await clearUnlockCountdown();
    }
  }

  static int get unlockFreezeMinutes => IsleUserDefaults.youtubeLimitUnlockFreezeMinutes;

  static bool canSetUnlockFreezeMinutes(int m) {
    final next = m.clamp(15, 1440).toInt();
    if (next >= unlockFreezeMinutes) return true;
    return !raiseLockEnabled || unlockWindowOpen;
  }

  static Future<bool> setUnlockFreezeMinutes(int m) async {
    if (!canSetUnlockFreezeMinutes(m)) return false;
    await IsleUserDefaults.setYoutubeLimitUnlockFreezeMinutes(m);
    return true;
  }

  static Duration? get unlockRemaining => IsleUserDefaults.youtubeLimitUnlockRemaining;

  static bool get unlockWindowOpen => IsleUserDefaults.youtubeLimitUnlockWindowOpen;

  static Duration? get disableRemaining =>
      disablePending ? unlockRemaining : null;

  /// 지금 한도를 느슨하게 바꾸는 변경이 막혀 있는지
  static bool get raiseBlocked => IsleUserDefaults.youtubeLimitRaiseBlocked;

  static Future<void> startUnlockCountdown() =>
      IsleUserDefaults.startYoutubeLimitUnlockCountdown();

  static Future<void> clearUnlockCountdown() =>
      IsleUserDefaults.clearYoutubeLimitUnlockCountdown();

  static void finalizeExpiredUnlock() {
    if (unlockRemaining != null) return;
    if (disablePending) return;
    if (IsleUserDefaults.youtubeLimitUnlockStartedAtMs != null) {
      clearUnlockCountdown();
    }
  }

  static Future<void> requestDisableRaiseLock() async {
    if (!raiseLockEnabled) {
      await IsleUserDefaults.setYoutubeLimitRaiseLockDisablePending(false);
      await clearUnlockCountdown();
      return;
    }
    if (canDisableRaiseLock) {
      await IsleUserDefaults.setYoutubeLimitRaiseLockEnabled(false);
      await IsleUserDefaults.setYoutubeLimitRaiseLockDisablePending(false);
      await clearUnlockCountdown();
      return;
    }
    await IsleUserDefaults.setYoutubeLimitRaiseLockDisablePending(true);
    await startUnlockCountdown();
  }

  static Future<void> cancelDisableRequest() async {
    await IsleUserDefaults.setYoutubeLimitRaiseLockDisablePending(false);
    await clearUnlockCountdown();
  }

  static Future<bool> processPendingDisable() async {
    if (!disablePending) return false;
    if (!raiseLockEnabled) {
      await IsleUserDefaults.setYoutubeLimitRaiseLockDisablePending(false);
      await clearUnlockCountdown();
      return true;
    }
    if (!canDisableRaiseLock) return false;
    await IsleUserDefaults.setYoutubeLimitRaiseLockEnabled(false);
    await IsleUserDefaults.setYoutubeLimitRaiseLockDisablePending(false);
    await clearUnlockCountdown();
    return true;
  }

  /// `newMinutes`가 현재보다 크거나, 한도를 끄려는 경우 설정 타임락 검사.
  static bool canApplyChange({
    required int currentMinutes,
    required int newMinutes,
    required bool currentlyEnabled,
    required bool newEnabled,
  }) {
    if (!raiseLockEnabled) return true;
    if (!currentlyEnabled && newEnabled) return true;
    if (newMinutes < currentMinutes) return true;
    if (!newEnabled && currentlyEnabled) return !raiseBlocked;
    if (newMinutes > currentMinutes) return !raiseBlocked;
    return true;
  }

  /// 일일/주기/나눠쓰기 모드 전환, 총량 상향, 충전 규칙 완화 여부를
  /// 한 번에 판정한다. 저장 경로와 AI 챗 경로가 같은 규칙을 쓰도록
  /// 화면 밖에 둔다.
  static bool canApplyPolicyChange({
    required bool currentlyEnabled,
    required bool newEnabled,
    required int currentDailyTotalMinutes,
    required int newDailyTotalMinutes,
    bool modeChanged = false,
    bool cadenceWeakened = false,
  }) {
    if (!raiseLockEnabled) return true;
    if (!currentlyEnabled && newEnabled) return true;
    if (!newEnabled && currentlyEnabled) return !raiseBlocked;
    if (modeChanged && (currentlyEnabled || newEnabled)) return !raiseBlocked;
    if (newDailyTotalMinutes > currentDailyTotalMinutes) return !raiseBlocked;
    if (cadenceWeakened) return !raiseBlocked;
    return true;
  }

  // ── 예약 저장(대기 후 자동 적용) ─────────────────────────────────────
  // 타임락에 막혀 저장할 수 없는 변경을, "안 된다"고만 말하고 끝내는 대신
  // 대기가 끝나면 자동으로 적용해준다. 사용자가 원치 않으면 언제든
  // clearPendingPolicyDraft()로 취소할 수 있다(2026-07-20 사용자 요청).

  static Map<String, dynamic>? get pendingPolicyDraft {
    final raw = IsleUserDefaults.youtubeLimitPendingPolicyDraftJson;
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static bool get hasPendingPolicyDraft => pendingPolicyDraft != null;

  /// 초안을 저장하고 (아직 시작 안 됐으면) 해제 카운트다운을 시작한다.
  static Future<void> reserveDraftUntilUnlocked(
    Map<String, dynamic> draft,
  ) async {
    await IsleUserDefaults.setYoutubeLimitPendingPolicyDraftJson(
      jsonEncode(draft),
    );
    if (!unlockWindowOpen && IsleUserDefaults.youtubeLimitUnlockStartedAtMs == null) {
      await startUnlockCountdown();
    }
  }

  /// 사용자가 예약을 취소 — 초안을 버리고 카운트다운도 정리한다(디스에이블
  /// 대기 등 다른 용도로 걸린 카운트다운까지 건드리지 않도록, 초안이 있을
  /// 때만 카운트다운을 같이 정리한다).
  static Future<void> clearPendingPolicyDraft() async {
    final hadDraft = hasPendingPolicyDraft;
    await IsleUserDefaults.setYoutubeLimitPendingPolicyDraftJson(null);
    if (hadDraft && !disablePending) {
      await clearUnlockCountdown();
    }
  }

  /// 대기 창이 열렸으면 예약된 초안을 꺼내 반환하고 비운다(호출자가 적용).
  /// 아직 대기 중이면 null.
  static Map<String, dynamic>? takeReadyPolicyDraft() {
    final draft = pendingPolicyDraft;
    if (draft == null) return null;
    if (!unlockWindowOpen) return null;
    IsleUserDefaults.setYoutubeLimitPendingPolicyDraftJson(null);
    if (!disablePending) {
      clearUnlockCountdown();
    }
    return draft;
  }
}
