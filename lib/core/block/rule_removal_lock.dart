import '../services/isle_user_defaults.dart';

/// 키워드·URL·웹 도메인·채널·앱 목록 **제거** 전 타임락.
/// 추가는 항상 즉시 · 제거·해제는 대기 후 · 대기 시간 **늘리기**는 즉시 · **줄이기**는 해제 창에서만.
class RuleRemovalLock {
  RuleRemovalLock._();

  static bool get lockEnabled => IsleUserDefaults.ruleRemovalLockEnabled;

  static Future<void> setLockEnabled(bool v) =>
      IsleUserDefaults.setRuleRemovalLockEnabled(v);

  static int get freezeMinutes => IsleUserDefaults.ruleRemovalFreezeMinutes;

  static Duration? get unlockRemaining => IsleUserDefaults.ruleRemovalUnlockRemaining;

  static bool get unlockWindowOpen => IsleUserDefaults.ruleRemovalUnlockWindowOpen;

  static bool get removalBlocked => lockEnabled && !unlockWindowOpen;

  static bool get canRemove => !removalBlocked;

  static bool get canDisableLock =>
      !lockEnabled || unlockWindowOpen;

  static bool canSetFreezeMinutes(int newMinutes) {
    if (newMinutes >= freezeMinutes) return true;
    return unlockWindowOpen;
  }

  static Future<void> setFreezeMinutes(int minutes) async {
    if (!canSetFreezeMinutes(minutes)) return;
    await IsleUserDefaults.setRuleRemovalFreezeMinutes(minutes);
  }

  static Future<void> startUnlockCountdown() =>
      IsleUserDefaults.startRuleRemovalUnlockCountdown();

  static Future<void> clearUnlockCountdown() =>
      IsleUserDefaults.clearRuleRemovalUnlockCountdown();

  static void finalizeExpiredUnlock() {
    // 해제 창은 사용자가 「잠금 유지」를 누를 때까지 유지
  }
}
