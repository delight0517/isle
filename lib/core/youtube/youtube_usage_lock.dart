import '../services/isle_user_defaults.dart';

/// YouTube 일일/주기 한도 — 상향·해제 타임락 (Instagram 설정 타임락과 동일 패턴)
class YoutubeUsageLock {
  YoutubeUsageLock._();

  static bool get raiseLockEnabled => IsleUserDefaults.youtubeLimitRaiseLockEnabled;

  /// 타임락을 끄려면 대기 완료 후에만 가능 (스위치 우회 방지)
  static bool get canDisableRaiseLock => !raiseLockEnabled || unlockWindowOpen;

  static Future<void> setRaiseLockEnabled(bool v) =>
      IsleUserDefaults.setYoutubeLimitRaiseLockEnabled(v);

  static int get unlockFreezeMinutes => IsleUserDefaults.youtubeLimitUnlockFreezeMinutes;

  static Future<void> setUnlockFreezeMinutes(int m) =>
      IsleUserDefaults.setYoutubeLimitUnlockFreezeMinutes(m);

  static Duration? get unlockRemaining => IsleUserDefaults.youtubeLimitUnlockRemaining;

  static bool get unlockWindowOpen => IsleUserDefaults.youtubeLimitUnlockWindowOpen;

  /// 지금 한도를 늘리거나 끄는 변경이 막혀 있는지
  static bool get raiseBlocked => IsleUserDefaults.youtubeLimitRaiseBlocked;

  static Future<void> startUnlockCountdown() =>
      IsleUserDefaults.startYoutubeLimitUnlockCountdown();

  static Future<void> clearUnlockCountdown() =>
      IsleUserDefaults.clearYoutubeLimitUnlockCountdown();

  static void finalizeExpiredUnlock() {
    if (unlockRemaining != null) return;
    if (IsleUserDefaults.youtubeLimitUnlockStartedAtMs != null) {
      clearUnlockCountdown();
    }
  }

  /// `newMinutes`가 현재보다 크거나, 한도를 끄려는 경우 상향락 검사
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
}
