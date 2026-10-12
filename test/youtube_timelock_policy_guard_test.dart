import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/services/isle_user_defaults.dart';
import 'package:isle/core/youtube/youtube_usage_lock.dart';

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_yt_timelock_policy');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
  });

  setUp(() async {
    await Hive.box<String>('isle_cache').clear();
    await YoutubeUsageLock.setRaiseLockEnabled(true);
    await YoutubeUsageLock.setUnlockFreezeMinutes(15);
  });

  test('blocks raising the daily total before timelock wait completes', () {
    expect(
      YoutubeUsageLock.canApplyPolicyChange(
        currentlyEnabled: true,
        newEnabled: true,
        currentDailyTotalMinutes: 20,
        newDailyTotalMinutes: 40,
      ),
      isFalse,
    );
  });

  test('blocks daily to split mode changes even when total is not raised', () {
    expect(
      YoutubeUsageLock.canApplyPolicyChange(
        currentlyEnabled: true,
        newEnabled: true,
        currentDailyTotalMinutes: 40,
        newDailyTotalMinutes: 40,
        modeChanged: true,
      ),
      isFalse,
    );
  });

  test('blocks weaker refill or cooldown rules before timelock wait completes', () {
    expect(
      YoutubeUsageLock.canApplyPolicyChange(
        currentlyEnabled: true,
        newEnabled: true,
        currentDailyTotalMinutes: 60,
        newDailyTotalMinutes: 60,
        cadenceWeakened: true,
      ),
      isFalse,
    );
  });

  test('allows stricter totals immediately', () {
    expect(
      YoutubeUsageLock.canApplyPolicyChange(
        currentlyEnabled: true,
        newEnabled: true,
        currentDailyTotalMinutes: 60,
        newDailyTotalMinutes: 20,
      ),
      isTrue,
    );
  });

  test('allows longer timelock immediately but blocks shortening before wait', () {
    expect(YoutubeUsageLock.canSetUnlockFreezeMinutes(30), isTrue);
  });

  test('blocks shortening the timelock before wait completes', () async {
    await IsleUserDefaults.setYoutubeLimitUnlockFreezeMinutes(30);
    expect(YoutubeUsageLock.canSetUnlockFreezeMinutes(15), isFalse);
  });

  test('turning off the settings timelock starts a pending countdown', () async {
    await YoutubeUsageLock.requestDisableRaiseLock();

    expect(YoutubeUsageLock.raiseLockEnabled, isTrue);
    expect(IsleUserDefaults.youtubeLimitRaiseLockDisablePending, isTrue);
    expect(YoutubeUsageLock.disableRemaining, isNotNull);
  });
}
