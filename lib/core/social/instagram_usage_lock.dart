import '../services/isle_user_defaults.dart';

/// Instagram 피드 vs DM — 일일 한도·설정 변경 대기(타임락) 분리
enum InstagramUsageScope {
  feed,
  dm,
}

extension InstagramUsageScopeX on InstagramUsageScope {
  String get label => switch (this) {
        InstagramUsageScope.feed => 'Instagram',
        InstagramUsageScope.dm => 'Instagram DM',
      };

  String get shortLabel => switch (this) {
        InstagramUsageScope.feed => '피드',
        InstagramUsageScope.dm => 'DM',
      };

  bool get dailyLimitEnabled => switch (this) {
        InstagramUsageScope.feed => IsleUserDefaults.instagramDailyLimitEnabled,
        InstagramUsageScope.dm => IsleUserDefaults.instagramDmDailyLimitEnabled,
      };

  Future<void> setDailyLimitEnabled(bool v) => switch (this) {
        InstagramUsageScope.feed => IsleUserDefaults.setInstagramDailyLimitEnabled(v),
        InstagramUsageScope.dm => IsleUserDefaults.setInstagramDmDailyLimitEnabled(v),
      };

  int get dailyLimitMinutes => switch (this) {
        InstagramUsageScope.feed => IsleUserDefaults.instagramDailyLimitMinutes,
        InstagramUsageScope.dm => IsleUserDefaults.instagramDmDailyLimitMinutes,
      };

  Future<void> setDailyLimitMinutes(int m) => switch (this) {
        InstagramUsageScope.feed => IsleUserDefaults.setInstagramDailyLimitMinutes(m),
        InstagramUsageScope.dm => IsleUserDefaults.setInstagramDmDailyLimitMinutes(m),
      };

  int get freezeMinutes => switch (this) {
        InstagramUsageScope.feed => IsleUserDefaults.instagramBlockSettingsFreezeMinutes,
        InstagramUsageScope.dm => IsleUserDefaults.instagramDmBlockSettingsFreezeMinutes,
      };

  Future<void> setFreezeMinutes(int m) => switch (this) {
        InstagramUsageScope.feed =>
          IsleUserDefaults.setInstagramBlockSettingsFreezeMinutes(m),
        InstagramUsageScope.dm =>
          IsleUserDefaults.setInstagramDmBlockSettingsFreezeMinutes(m),
      };

  Duration? get unlockRemaining => switch (this) {
        InstagramUsageScope.feed =>
          IsleUserDefaults.instagramBlockSettingsUnlockRemaining,
        InstagramUsageScope.dm => IsleUserDefaults.instagramDmBlockSettingsUnlockRemaining,
      };

  bool get isSettingsFrozen => unlockRemaining != null;

  Future<void> startFreezeCountdown() => switch (this) {
        InstagramUsageScope.feed =>
          IsleUserDefaults.startInstagramBlockSettingsFreezeCountdown(),
        InstagramUsageScope.dm =>
          IsleUserDefaults.startInstagramDmBlockSettingsFreezeCountdown(),
      };

  Future<void> clearFreezeCountdown() => switch (this) {
        InstagramUsageScope.feed =>
          IsleUserDefaults.clearInstagramBlockSettingsFreezeCountdown(),
        InstagramUsageScope.dm =>
          IsleUserDefaults.clearInstagramDmBlockSettingsFreezeCountdown(),
      };

  void finalizeExpiredFreeze() {
    final left = unlockRemaining;
    if (left != null) return;
    switch (this) {
      case InstagramUsageScope.feed:
        if (IsleUserDefaults.instagramBlockSettingsUnlockStartedAtMs != null) {
          IsleUserDefaults.clearInstagramBlockSettingsFreezeCountdown();
        }
      case InstagramUsageScope.dm:
        if (IsleUserDefaults.instagramDmBlockSettingsUnlockStartedAtMs != null) {
          IsleUserDefaults.clearInstagramDmBlockSettingsFreezeCountdown();
        }
    }
  }
}
