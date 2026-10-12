import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// 사령관 지시·기능 플래그 — 앱 재시작 후에도 유지 (Hive `isle_cache`)
class IsleUserDefaults {
  IsleUserDefaults._();

  static Box<String> get _box => Hive.box<String>('isle_cache');

  static const _prefix = 'isle_pref_';

  static bool get useYoutubeWebShell =>
      _box.get('${_prefix}use_youtube_web_shell') != 'false';

  static Future<void> setUseYoutubeWebShell(bool v) =>
      _box.put('${_prefix}use_youtube_web_shell', v ? 'true' : 'false');

  static bool get hideBlockedInFeed =>
      _box.get('${_prefix}hide_blocked_feed') != 'false';

  static Future<void> setHideBlockedInFeed(bool v) =>
      _box.put('${_prefix}hide_blocked_feed', v ? 'true' : 'false');

  /// 성인 URL·SafeSearch·유튜브 제한 모드 (기본 ON) — [AdultProtectionService]와 동기화
  static bool get contentSafetyEnabled =>
      _box.get('${_prefix}content_safety') != 'false';

  static Future<void> setContentSafetyEnabled(bool v) =>
      _box.put('${_prefix}content_safety', v ? 'true' : 'false');

  /// 성인 보호 단일 tier: off | basic | full (null = 마이그레이션 전)
  static String? get adultProtectionTier {
    final v = _box.get('${_prefix}adult_protection_tier');
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static Future<void> setAdultProtectionTier(String tierKey) =>
      _box.put('${_prefix}adult_protection_tier', tierKey);

  static Future<void> replacePremadeBlockPackAppliedIds(Set<String> ids) =>
      _box.put('${_prefix}premade_packs_applied', jsonEncode(ids.toList()));

  /// Google 검색 SERP — 키워드 포함 결과 카드 숨김 (기본 ON)
  static bool get blockGoogleSearchKeywords =>
      _box.get('${_prefix}block_google_search_kw') != 'false';

  static Future<void> setBlockGoogleSearchKeywords(bool v) =>
      _box.put('${_prefix}block_google_search_kw', v ? 'true' : 'false');

  /// Google 검색·피드·Discover — 차단 URL 카드 숨김 (기본 ON)
  static bool get blockGoogleSearchUrls =>
      _box.get('${_prefix}block_google_search_urls') != 'false';

  static Future<void> setBlockGoogleSearchUrls(bool v) =>
      _box.put('${_prefix}block_google_search_urls', v ? 'true' : 'false');

  /// Google 검색 SERP — YouTube 인라인 미리보기 재생 차단 (기본 ON)
  static bool get blockGoogleYoutubeInlinePreview =>
      _box.get('${_prefix}block_google_yt_preview') != 'false';

  static Future<void> setBlockGoogleYoutubeInlinePreview(bool v) =>
      _box.put('${_prefix}block_google_yt_preview', v ? 'true' : 'false');

  /// iOS L3 인앱 잠금: `off` | `auto` | `always`
  static String get iosInternalLockMode =>
      _box.get('${_prefix}ios_internal_lock') ?? 'off';

  static Future<void> setIosInternalLockMode(String v) =>
      _box.put('${_prefix}ios_internal_lock', v);

  /// 4VPN Mac이 명시적으로 공유한 규칙을 MOA 내부 Safari에 적용.
  static bool get fourVpnSafariRulesEnabled =>
      _box.get('${_prefix}four_vpn_safari_rules') == 'true';

  static Future<void> setFourVpnSafariRulesEnabled(bool v) =>
      _box.put('${_prefix}four_vpn_safari_rules', v ? 'true' : 'false');

  static String? get lockdownAllowedAppsEncoded =>
      _box.get('${_prefix}lockdown_allowed_apps');

  static Future<void> setLockdownAllowedAppsEncoded(String? value) async {
    if (value == null || value.isEmpty) {
      await _box.delete('${_prefix}lockdown_allowed_apps');
    } else {
      await _box.put('${_prefix}lockdown_allowed_apps', value);
    }
  }

  static int get lockdownAllowedAppsCount =>
      int.tryParse(_box.get('${_prefix}lockdown_allowed_apps_count') ?? '') ??
      0;

  static Future<void> setLockdownAllowedAppsCount(int count) =>
      _box.put('${_prefix}lockdown_allowed_apps_count', count.toString());

  /// App-specific temporary Screen Time pause deadline (epoch milliseconds).
  static int appBlockPauseUntilMs(String bundleId) =>
      int.tryParse(
          _box.get('${_prefix}app_block_pause_${bundleId}_until_ms') ?? '') ??
      0;

  static Future<void> setAppBlockPauseUntilMs(String bundleId, int ms) =>
      _box.put('${_prefix}app_block_pause_${bundleId}_until_ms', '$ms');

  static bool get collapseBlockedDomLayout =>
      _box.get('${_prefix}collapse_blocked_dom') != 'false';

  static bool get dismissKeyboardOnBlockSheet =>
      _box.get('${_prefix}dismiss_kb_on_block') != 'false';

  static Future<void> setDismissKeyboardOnBlockSheet(bool v) =>
      _box.put('${_prefix}dismiss_kb_on_block', v ? 'true' : 'false');

  /// `both` | `block` | `archive` — 오른쪽 스와이프 기본 동작
  static String get swipeRightAction =>
      _box.get('${_prefix}swipe_right_action') ?? 'both';

  static Future<void> setSwipeRightAction(String v) =>
      _box.put('${_prefix}swipe_right_action', v);

  /// www.youtube.com vs m.youtube.com
  static bool get youtubeUseDesktopSite =>
      _box.get('${_prefix}youtube_desktop') == 'true';

  static Future<void> setYoutubeUseDesktopSite(bool v) =>
      _box.put('${_prefix}youtube_desktop', v ? 'true' : 'false');

  static bool get syncBlockedChannelsToCloud =>
      _box.get('${_prefix}sync_blocked_cloud') != 'false';

  static Future<void> setSyncBlockedChannelsToCloud(bool v) =>
      _box.put('${_prefix}sync_blocked_cloud', v ? 'true' : 'false');

  static bool get hasSeenYoutubeGuide =>
      _box.get('${_prefix}youtube_guide_seen') == 'true';

  static Future<void> setHasSeenYoutubeGuide(bool v) =>
      _box.put('${_prefix}youtube_guide_seen', v ? 'true' : 'false');

  static bool get hasSeenQuickLauncherHint =>
      _box.get('${_prefix}quick_launcher_hint') == 'true';

  static Future<void> setHasSeenQuickLauncherHint(bool v) =>
      _box.put('${_prefix}quick_launcher_hint', v ? 'true' : 'false');

  static bool get hideDefaultBrowserOnboardingHint =>
      _box.get('${_prefix}hide_default_browser_hint') == 'true';

  static Future<void> setHideDefaultBrowserOnboardingHint(bool v) =>
      _box.put('${_prefix}hide_default_browser_hint', v ? 'true' : 'false');

  /// 몰입 모드 — 홈 화면 스위칭 가이드
  static bool get hasSeenYoutubeFocusHomeSwitchGuide =>
      _box.get('${_prefix}youtube_focus_home_switch') == 'true';

  static Future<void> setHasSeenYoutubeFocusHomeSwitchGuide(bool v) =>
      _box.put('${_prefix}youtube_focus_home_switch', v ? 'true' : 'false');

  /// 섬 3D 배경 테마 — classic | midnight | sunset | aurora
  static String get islandThemeId =>
      _box.get('${_prefix}island_theme') ?? 'classic';

  static Future<void> setIslandThemeId(String id) =>
      _box.put('${_prefix}island_theme', id);

  /// YouTube http(s) · isle:// 링크 → Isle WebView (딥링크)
  static bool get openYoutubeLinksInIsle =>
      _box.get('${_prefix}open_yt_in_isle') != 'false';

  static Future<void> setOpenYoutubeLinksInIsle(bool v) =>
      _box.put('${_prefix}open_yt_in_isle', v ? 'true' : 'false');

  /// 앱 복귀 시 클립보드 YouTube → 「Isle에서 열기」 (브라우저 차단 후 복사용)
  static bool get youtubeClipboardLaunchOnResume =>
      _box.get('${_prefix}yt_clipboard_launch') != 'false';

  static Future<void> setYoutubeClipboardLaunchOnResume(bool v) =>
      _box.put('${_prefix}yt_clipboard_launch', v ? 'true' : 'false');

  static String? get lastClipboardYoutubeOfferUrl =>
      _box.get('${_prefix}last_yt_clip_offer');

  static Future<void> setLastClipboardYoutubeOfferUrl(String url) =>
      _box.put('${_prefix}last_yt_clip_offer', url);

  /// Safari·YouTube 공유 링크 → 몰입 모드 Read-first
  static bool get youtubeSharesUseFocusMode =>
      _box.get('${_prefix}youtube_shares_focus') == 'true';

  static Future<void> setYoutubeSharesUseFocusMode(bool v) async {
    await _box.put('${_prefix}youtube_shares_focus', v ? 'true' : 'false');
    if (v) await _box.put('${_prefix}youtube_shares_podcast', 'false');
  }

  /// Safari·YouTube 공유·클립보드 → 음성 모드(듣기 전용)
  static bool get youtubeSharesUsePodcastMode =>
      _box.get('${_prefix}youtube_shares_podcast') == 'true';

  static Future<void> setYoutubeSharesUsePodcastMode(bool v) async {
    await _box.put('${_prefix}youtube_shares_podcast', v ? 'true' : 'false');
    if (v) await _box.put('${_prefix}youtube_shares_focus', 'false');
  }

  /// 앱 소개 투어 (첫 실행)
  static bool get hasCompletedAppTour =>
      _box.get('${_prefix}app_tour_done') == 'true';

  static Future<void> setHasCompletedAppTour(bool v) =>
      _box.put('${_prefix}app_tour_done', v ? 'true' : 'false');

  /// iCloud·외부 백업 폴더 안내 (1회)
  static bool get survivalBackupGuideDismissed =>
      _box.get('${_prefix}survival_backup_guide_dismissed') == 'true';

  static Future<void> setSurvivalBackupGuideDismissed(bool v) => _box.put(
      '${_prefix}survival_backup_guide_dismissed', v ? 'true' : 'false');

  /// 안드로이드 그림 튜토리얼 (1회 · 업데이트마다 재표시 안 함)
  static bool get hasCompletedAndroidVisualTutorial =>
      _box.get('${_prefix}android_visual_tutorial_done') == 'true';

  static Future<void> setHasCompletedAndroidVisualTutorial(bool v) =>
      _box.put('${_prefix}android_visual_tutorial_done', v ? 'true' : 'false');

  /// 온보딩 — Safari·다른 앱 시스템 잠금 안내 완료
  static bool get hasCompletedSystemTimeLockOnboarding =>
      _box.get('${_prefix}system_time_lock_onboarding') == 'true';

  static Future<void> setHasCompletedSystemTimeLockOnboarding(bool v) =>
      _box.put('${_prefix}system_time_lock_onboarding', v ? 'true' : 'false');

  /// 3대 초점 UI (다른 앱 차단 · 브라우저 트래킹 · Isle 유튜브) — 기본 켜짐
  static bool get productFocusUi =>
      _box.get('${_prefix}product_focus_ui') != 'false';

  static Future<void> setProductFocusUi(bool v) =>
      _box.put('${_prefix}product_focus_ui', v ? 'true' : 'false');

  /// SNS·섬·AI 등 고급 메뉴 표시
  static bool get showAdvancedUi =>
      _box.get('${_prefix}show_advanced_ui') == 'true';

  static Future<void> setShowAdvancedUi(bool v) =>
      _box.put('${_prefix}show_advanced_ui', v ? 'true' : 'false');

  /// 온보딩에서 고른 관심 태그 (쉼표 구분)
  static List<String> get onboardingInterestTags {
    final raw = _box.get('${_prefix}onboarding_interests');
    if (raw == null || raw.isEmpty) return [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static Future<void> setOnboardingInterestTags(List<String> tags) =>
      _box.put('${_prefix}onboarding_interests', tags.join(','));

  /// 피드 샘플 카드 접기 (셋업 후에도 샘플 숨기기)
  static bool get hideDemoFeedCards =>
      _box.get('${_prefix}hide_demo_feed') == 'true';

  static Future<void> setHideDemoFeedCards(bool v) =>
      _box.put('${_prefix}hide_demo_feed', v ? 'true' : 'false');

  static bool get hasSeenFeedSwipeCoach =>
      _box.get('${_prefix}feed_swipe_coach_seen') == 'true';

  static Future<void> setHasSeenFeedSwipeCoach(bool v) =>
      _box.put('${_prefix}feed_swipe_coach_seen', v ? 'true' : 'false');

  /// 피드 셋업 배너 영구 숨김 (회색·가림 방지)
  static bool get hideFeedSetupBanner =>
      _box.get('${_prefix}hide_feed_setup_banner') == 'true';

  static Future<void> setHideFeedSetupBanner(bool v) =>
      _box.put('${_prefix}hide_feed_setup_banner', v ? 'true' : 'false');

  /// 마지막 크래시 안내 표시 완료
  static String? get lastAcknowledgedCrashId =>
      _box.get('${_prefix}last_ack_crash_id');

  static Future<void> setLastAcknowledgedCrashId(String id) =>
      _box.put('${_prefix}last_ack_crash_id', id);

  /// 시청·가져온 영상을 요약 뉴스 카드로 피드에 올리기
  static bool get digestToFeedEnabled =>
      _box.get('${_prefix}digest_to_feed') == 'true';

  static Future<void> setDigestToFeedEnabled(bool v) =>
      _box.put('${_prefix}digest_to_feed', v ? 'true' : 'false');

  /// 마지막으로 부팅에 성공한 앱 버전 — [AppUpdateAuditService]가 이번 부팅과
  /// 비교해 "업데이트 직후 스케줄이 사라짐" 같은 리셋 원인 분석용 로그를 남긴다.
  static String? get lastSeenAppVersion =>
      _box.get('${_prefix}last_seen_app_version');

  static Future<void> setLastSeenAppVersion(String v) =>
      _box.put('${_prefix}last_seen_app_version', v);

  /// 마지막으로 관측한 스케줄 개수 — 다음 부팅 때 급감(특히 0으로)했으면
  /// 업데이트가 스케줄을 조용히 지웠다는 신호로 감사 로그에 남긴다.
  static int? get lastKnownScheduleCount {
    final v = _box.get('${_prefix}last_known_schedule_count');
    return v == null ? null : int.tryParse(v);
  }

  static Future<void> setLastKnownScheduleCount(int v) =>
      _box.put('${_prefix}last_known_schedule_count', v.toString());

  static int get digestMaxPerWeek {
    final n = int.tryParse(_box.get('${_prefix}digest_max_week') ?? '');
    return (n == null || n < 1) ? 2 : n.clamp(1, 14);
  }

  static Future<void> setDigestMaxPerWeek(int n) =>
      _box.put('${_prefix}digest_max_week', n.clamp(1, 14).toString());

  /// 리포트·기사 생성 완료 알림
  static bool get contentReportNotificationsEnabled =>
      _box.get('${_prefix}content_report_notif_on') != 'false';

  static Future<void> setContentReportNotificationsEnabled(bool v) =>
      _box.put('${_prefix}content_report_notif_on', v ? 'true' : 'false');

  /// 유튜브 WebView에서 본 영상을 라이브러리·피드에 기록
  static bool get trackYoutubeWatchHistory =>
      _box.get('${_prefix}track_yt_history') != 'false';

  static Future<void> setTrackYoutubeWatchHistory(bool v) =>
      _box.put('${_prefix}track_yt_history', v ? 'true' : 'false');

  /// 인앱 브라우저 상·하단 바 — true: 다크(유튜브·시계 가독)
  static bool get explorerChromeDark =>
      _box.get('${_prefix}explorer_chrome_dark') != 'false';

  static Future<void> setExplorerChromeDark(bool v) =>
      _box.put('${_prefix}explorer_chrome_dark', v ? 'true' : 'false');

  /// 브런치 WebView 로그인 세션 인식 (쿠키 + 사용자 확인)
  static bool get brunchLoginRemembered =>
      _box.get('${_prefix}brunch_login_ok') == 'true';

  static Future<void> setBrunchLoginRemembered(bool v) =>
      _box.put('${_prefix}brunch_login_ok', v ? 'true' : 'false');

  static bool get instagramLoginRemembered =>
      _box.get('${_prefix}instagram_login_ok') == 'true';

  static Future<void> setInstagramLoginRemembered(bool v) =>
      _box.put('${_prefix}instagram_login_ok', v ? 'true' : 'false');

  /// YouTube WebView — 로그인 완료·쿠키 유지 인식 (업데이트 후에도 배너·가이드 생략)
  static bool get youtubeWebLoginRemembered =>
      _box.get('${_prefix}youtube_web_login_ok') == 'true';

  static Future<void> setYoutubeWebLoginRemembered(bool v) =>
      _box.put('${_prefix}youtube_web_login_ok', v ? 'true' : 'false');

  /// 유튜브 로그인 칩(상단 배너) — X·웹뷰 선택 후 재표시 안 함
  static bool get youtubeLoginChipDismissed =>
      _box.get('${_prefix}youtube_login_chip_dismissed') == 'true';

  static Future<void> setYoutubeLoginChipDismissed(bool v) =>
      _box.put('${_prefix}youtube_login_chip_dismissed', v ? 'true' : 'false');

  /// Instagram 로그인 칩 — 닫으면 재표시 안 함
  static bool get instagramLoginChipDismissed =>
      _box.get('${_prefix}instagram_login_chip_dismissed') == 'true';

  static Future<void> setInstagramLoginChipDismissed(bool v) => _box.put(
      '${_prefix}instagram_login_chip_dismissed', v ? 'true' : 'false');

  /// OS youtube.com 차단 복구 배너 — 사용자가 닫으면 재표시 안 함
  static bool get youtubeOsRecoveryBarDismissed =>
      _box.get('${_prefix}yt_os_recovery_dismissed') == 'true';

  static Future<void> setYoutubeOsRecoveryBarDismissed(bool v) =>
      _box.put('${_prefix}yt_os_recovery_dismissed', v ? 'true' : 'false');

  /// Instagram DM 집중 모드 (탐색 최소화)
  static bool get instagramDmFocusMode =>
      _box.get('${_prefix}ig_dm_focus_mode') != 'false';

  static Future<void> setInstagramDmFocusMode(bool v) =>
      _box.put('${_prefix}ig_dm_focus_mode', v ? 'true' : 'false');

  /// 차단 AI 챗이 새 스케줄을 만들 때 기본으로 거는 설정 잠금(타임락) 분 —
  /// 대부분의 사용자는 즉시 풀리는 차단만으로는 의지가 약해지므로 최소 15분은
  /// 걸어야 한다는 방침(2026-07-11). 챗에서 "타임락 기본 20분으로 해줘"로 바꿀 수 있음.
  static int get defaultScheduleLockCooldownMinutes {
    final n =
        int.tryParse(_box.get('${_prefix}default_lock_cooldown_min') ?? '');
    return (n == null || n < 15) ? 30 : n.clamp(15, 180);
  }

  static Future<void> setDefaultScheduleLockCooldownMinutes(int v) => _box.put(
      '${_prefix}default_lock_cooldown_min', v.clamp(15, 180).toString());

  /// Instagram 차단 설정 변경용 freeze 타이머 (즉시 해제 방지)
  static int get instagramBlockSettingsFreezeMinutes {
    final n = int.tryParse(_box.get('${_prefix}ig_block_freeze_min') ?? '');
    return (n == null || n < 1) ? 30 : n.clamp(5, 180);
  }

  static Future<void> setInstagramBlockSettingsFreezeMinutes(int v) =>
      _box.put('${_prefix}ig_block_freeze_min', v.clamp(5, 180).toString());

  static int? get instagramBlockSettingsUnlockStartedAtMs {
    final raw = _box.get('${_prefix}ig_block_unlock_start_ms');
    return int.tryParse(raw ?? '');
  }

  static Duration? get instagramBlockSettingsUnlockRemaining {
    final startedMs = instagramBlockSettingsUnlockStartedAtMs;
    if (startedMs == null) return null;
    final end = DateTime.fromMillisecondsSinceEpoch(startedMs)
        .add(Duration(minutes: instagramBlockSettingsFreezeMinutes));
    final left = end.difference(DateTime.now());
    if (left.isNegative || left == Duration.zero) return null;
    return left;
  }

  static bool get isInstagramBlockSettingsFrozen =>
      instagramBlockSettingsUnlockRemaining != null;

  static Future<void> startInstagramBlockSettingsFreezeCountdown() => _box.put(
        '${_prefix}ig_block_unlock_start_ms',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

  static Future<void> clearInstagramBlockSettingsFreezeCountdown() =>
      _box.delete('${_prefix}ig_block_unlock_start_ms');

  /// Instagram DM — 일일 한도 (피드와 별도)
  static bool get instagramDmDailyLimitEnabled =>
      _box.get('${_prefix}ig_dm_daily_limit_on') == 'true';

  static Future<void> setInstagramDmDailyLimitEnabled(bool v) =>
      _box.put('${_prefix}ig_dm_daily_limit_on', v ? 'true' : 'false');

  static int get instagramDmDailyLimitMinutes {
    final n = int.tryParse(_box.get('${_prefix}ig_dm_daily_limit_min') ?? '');
    return (n == null || n < 1) ? 30 : n.clamp(5, 480);
  }

  static Future<void> setInstagramDmDailyLimitMinutes(int m) =>
      _box.put('${_prefix}ig_dm_daily_limit_min', m.clamp(5, 480).toString());

  /// DM 설정 변경 대기 (피드 freeze와 분리)
  static int get instagramDmBlockSettingsFreezeMinutes {
    final n = int.tryParse(_box.get('${_prefix}ig_dm_block_freeze_min') ?? '');
    return (n == null || n < 1) ? 30 : n.clamp(5, 180);
  }

  static Future<void> setInstagramDmBlockSettingsFreezeMinutes(int v) =>
      _box.put('${_prefix}ig_dm_block_freeze_min', v.clamp(5, 180).toString());

  static int? get instagramDmBlockSettingsUnlockStartedAtMs {
    final raw = _box.get('${_prefix}ig_dm_block_unlock_start_ms');
    return int.tryParse(raw ?? '');
  }

  static Duration? get instagramDmBlockSettingsUnlockRemaining {
    final startedMs = instagramDmBlockSettingsUnlockStartedAtMs;
    if (startedMs == null) return null;
    final end = DateTime.fromMillisecondsSinceEpoch(startedMs)
        .add(Duration(minutes: instagramDmBlockSettingsFreezeMinutes));
    final left = end.difference(DateTime.now());
    if (left.isNegative || left == Duration.zero) return null;
    return left;
  }

  static Future<void> startInstagramDmBlockSettingsFreezeCountdown() =>
      _box.put(
        '${_prefix}ig_dm_block_unlock_start_ms',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

  static Future<void> clearInstagramDmBlockSettingsFreezeCountdown() =>
      _box.delete('${_prefix}ig_dm_block_unlock_start_ms');

  /// 브런치·블로그 전용 숨김 키워드 (쉼표)
  static List<String> get brunchBlockKeywords {
    final raw = _box.get('${_prefix}brunch_block_kw');
    if (raw == null || raw.isEmpty) return [];
    return raw
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static Future<void> setBrunchBlockKeywords(List<String> list) =>
      _box.put('${_prefix}brunch_block_kw', list.join(','));

  static bool get youtubeDailyLimitEnabled =>
      _box.get('${_prefix}yt_daily_limit_on') != 'false';

  static Future<void> setYoutubeDailyLimitEnabled(bool v) =>
      _box.put('${_prefix}yt_daily_limit_on', v ? 'true' : 'false');

  static int get youtubeDailyLimitMinutes {
    final n = int.tryParse(_box.get('${_prefix}yt_daily_limit_min') ?? '');
    return (n == null || n < 1) ? 20 : n.clamp(5, 480);
  }

  static Future<void> setYoutubeDailyLimitMinutes(int m) =>
      _box.put('${_prefix}yt_daily_limit_min', m.clamp(5, 480).toString());

  /// 요일별 하루 총량 오버라이드 — "일요일엔 하루 유튜브 7시간으로 늘려줘"
  /// 처럼 특정 요일만 다른 일일 한도를 쓰고 싶을 때. 키: DateTime.weekday
  /// (1=월 ~ 7=일), 값: 분. 없는 요일은 [youtubeDailyLimitMinutes] 그대로.
  static Map<int, int> get youtubeWeekdayLimitOverrides {
    final raw = _box.get('${_prefix}yt_weekday_limit_min');
    if (raw == null || raw.isEmpty) return const {};
    final out = <int, int>{};
    for (final pair in raw.split(',')) {
      final parts = pair.split(':');
      if (parts.length != 2) continue;
      final wd = int.tryParse(parts[0]);
      final min = int.tryParse(parts[1]);
      if (wd != null && min != null && wd >= 1 && wd <= 7 && min >= 1) {
        out[wd] = min;
      }
    }
    return out;
  }

  static Future<void> setYoutubeWeekdayLimitOverride(
      int weekday, int minutes) async {
    final map = Map<int, int>.from(youtubeWeekdayLimitOverrides);
    map[weekday.clamp(1, 7)] = minutes.clamp(5, 1440);
    final encoded = map.entries.map((e) => '${e.key}:${e.value}').join(',');
    await _box.put('${_prefix}yt_weekday_limit_min', encoded);
  }

  static Future<void> clearYoutubeWeekdayLimitOverride(int weekday) async {
    final map = Map<int, int>.from(youtubeWeekdayLimitOverrides);
    map.remove(weekday.clamp(1, 7));
    final encoded = map.entries.map((e) => '${e.key}:${e.value}').join(',');
    await _box.put('${_prefix}yt_weekday_limit_min', encoded);
  }

  /// 매주 반복되는 영구 주간 총량("이번주 유튜브 총량은 10시간으로 제한해줘").
  /// 0이면 꺼짐(주간 한도 없음, 일일 한도만 적용).
  static int get youtubeWeeklyLimitMinutes {
    final n = int.tryParse(_box.get('${_prefix}yt_weekly_limit_min') ?? '');
    return (n == null || n < 1) ? 0 : n.clamp(1, 10080);
  }

  static Future<void> setYoutubeWeeklyLimitMinutes(int m) =>
      _box.put('${_prefix}yt_weekly_limit_min', m.clamp(1, 10080).toString());

  static Future<void> clearYoutubeWeeklyLimitMinutes() =>
      _box.put('${_prefix}yt_weekly_limit_min', '0');

  /// "이번주만" 임시 주간 총량 — [youtubeWeeklyLimitTem[REDACTED] 현재 주와
  /// 다르면 자동으로 무시(만료)된다. 영구 한도([youtubeWeeklyLimitMinutes])
  /// 보다 우선 적용.
  static int? get youtubeWeeklyLimitTempMinutes {
    final n =
        int.tryParse(_box.get('${_prefix}yt_weekly_limit_temp_min') ?? '');
    return (n == null || n < 1) ? null : n;
  }

  static String? get youtubeWeeklyLimitTempWeek =>
      _box.get('${_prefix}yt_weekly_limit_temp_week');

  static Future<void> setYoutubeWeeklyLimitTemp(
      int minutes, String weekKey) async {
    await _box.put('${_prefix}yt_weekly_limit_temp_min',
        minutes.clamp(1, 10080).toString());
    await _box.put('${_prefix}yt_weekly_limit_temp_week', weekKey);
  }

  static Future<void> clearYoutubeWeeklyLimitTemp() async {
    await _box.delete('${_prefix}yt_weekly_limit_temp_min');
    await _box.delete('${_prefix}yt_weekly_limit_temp_week');
  }

  /// 시청 중 30/50/70/100% 잔여 알림 — 하루/임계값당 한 번만 울리게 이미
  /// 알린 임계값을 기록. 키: "yyyy-mm-dd" 형태의 오늘 날짜.
  static Set<int> get youtubeNotifiedThresholdsToday {
    final key = '${_prefix}yt_notified_thresholds_${_todayKeyForNotif()}';
    final raw = _box.get(key);
    if (raw == null || raw.isEmpty) return const {};
    return raw
        .split(',')
        .map((e) => int.tryParse(e) ?? -1)
        .where((e) => e > 0)
        .toSet();
  }

  static Future<void> addYoutubeNotifiedThresholdToday(int threshold) async {
    final key = '${_prefix}yt_notified_thresholds_${_todayKeyForNotif()}';
    final current = Set<int>.from(youtubeNotifiedThresholdsToday)
      ..add(threshold);
    await _box.put(key, current.join(','));
  }

  static String _todayKeyForNotif() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 음성 모드 전용 (영상 한도와 분리 · 기본 90분)
  static bool get youtubePodcastLimitEnabled =>
      _box.get('${_prefix}yt_podcast_limit_on') != 'false';

  static Future<void> setYoutubePodcastLimitEnabled(bool v) =>
      _box.put('${_prefix}yt_podcast_limit_on', v ? 'true' : 'false');

  static int get youtubePodcastDailyLimitMinutes {
    final n = int.tryParse(_box.get('${_prefix}yt_podcast_limit_min') ?? '');
    return (n == null || n < 1) ? 90 : n.clamp(15, 480);
  }

  static Future<void> setYoutubePodcastDailyLimitMinutes(int m) =>
      _box.put('${_prefix}yt_podcast_limit_min', m.clamp(15, 480).toString());

  /// 숏폼(≤60초) 검색·피드에서 제외
  static bool get youtubePodcastExcludeShorts =>
      _box.get('${_prefix}yt_podcast_no_shorts') != 'false';

  static Future<void> setYoutubePodcastExcludeShorts(bool v) =>
      _box.put('${_prefix}yt_podcast_no_shorts', v ? 'true' : 'false');

  /// 재생 화면 썸네일 표시 (기본 꺼짐 — 영상 미리보기 방지)
  static bool get youtubePodcastShowArtwork =>
      _box.get('${_prefix}yt_podcast_show_art') == 'true';

  static Future<void> setYoutubePodcastShowArtwork(bool v) =>
      _box.put('${_prefix}yt_podcast_show_art', v ? 'true' : 'false');

  /// `interval` = N시간마다 M분만 시청 · `daily` = 하루 총량
  static bool get youtubeLimitUsesInterval =>
      _box.get('${_prefix}yt_limit_mode') == 'interval';

  static Future<void> setYoutubeLimitUsesInterval(bool interval) =>
      _box.put('${_prefix}yt_limit_mode', interval ? 'interval' : 'daily');

  static bool get youtubeIntervalLimitEnabled =>
      _box.get('${_prefix}yt_interval_on') == 'true';

  static Future<void> setYoutubeIntervalLimitEnabled(bool v) =>
      _box.put('${_prefix}yt_interval_on', v ? 'true' : 'false');

  static int get youtubeIntervalWindowMinutes {
    final n = int.tryParse(_box.get('${_prefix}yt_interval_window_min') ?? '');
    return (n == null || n < 30) ? 180 : n.clamp(30, 720);
  }

  static Future<void> setYoutubeIntervalWindowMinutes(int m) =>
      _box.put('${_prefix}yt_interval_window_min', m.clamp(30, 720).toString());

  static int get youtubeIntervalAllowMinutes {
    final n = int.tryParse(_box.get('${_prefix}yt_interval_allow_min') ?? '');
    return (n == null || n < 1) ? 20 : n.clamp(1, 120);
  }

  static Future<void> setYoutubeIntervalAllowMinutes(int m) =>
      _box.put('${_prefix}yt_interval_allow_min', m.clamp(1, 120).toString());

  // ── 유튜브 한도 변경 잠금 (지연락) ─────────────────────────────────
  // 켜면: 한도를 느슨하게 바꾸거나, 모드/충전 규칙을 바꾸려면 먼저
  //       해제 카운트다운(지연)을 기다려야 함. 더 엄격한 변경은 즉시 적용.
  // 기본 꺼짐 — 되돌리기 어려운 잠금을 동의 없이 강제하지 않음. (IG DM freeze와 동일 패턴)

  static bool get youtubeLimitRaiseLockEnabled =>
      _box.get('${_prefix}yt_limit_raise_lock') == 'true';

  static Future<void> setYoutubeLimitRaiseLockEnabled(bool v) =>
      _box.put('${_prefix}yt_limit_raise_lock', v ? 'true' : 'false');

  static bool get youtubeLimitRaiseLockDisablePending =>
      _box.get('${_prefix}yt_limit_raise_lock_disable_pending') == 'true';

  static Future<void> setYoutubeLimitRaiseLockDisablePending(bool v) => v
      ? _box.put('${_prefix}yt_limit_raise_lock_disable_pending', 'true')
      : _box.delete('${_prefix}yt_limit_raise_lock_disable_pending');

  static int get youtubeLimitUnlockFreezeMinutes {
    final n = int.tryParse(_box.get('${_prefix}yt_limit_freeze_min') ?? '');
    return (n == null || n < 15) ? 15 : n.clamp(15, 1440);
  }

  static Future<void> setYoutubeLimitUnlockFreezeMinutes(int v) =>
      _box.put('${_prefix}yt_limit_freeze_min', v.clamp(15, 1440).toString());

  static int? get youtubeLimitUnlockStartedAtMs =>
      int.tryParse(_box.get('${_prefix}yt_limit_unlock_start_ms') ?? '');

  static Duration? get youtubeLimitUnlockRemaining {
    final s = youtubeLimitUnlockStartedAtMs;
    if (s == null) return null;
    final end = DateTime.fromMillisecondsSinceEpoch(s)
        .add(Duration(minutes: youtubeLimitUnlockFreezeMinutes));
    final left = end.difference(DateTime.now());
    if (left.isNegative || left == Duration.zero) return null;
    return left;
  }

  /// 해제 카운트다운을 시작했고, 그 시간이 다 지나 지금 한도를 늘릴 수 있는 상태인지
  static bool get youtubeLimitUnlockWindowOpen =>
      youtubeLimitUnlockStartedAtMs != null &&
      youtubeLimitUnlockRemaining == null;

  /// 지금 상향/해제가 잠금에 막혀 있는지 (true면 줄이기만 가능)
  static bool get youtubeLimitRaiseBlocked =>
      youtubeLimitRaiseLockEnabled && !youtubeLimitUnlockWindowOpen;

  static Future<void> startYoutubeLimitUnlockCountdown() => _box.put(
        '${_prefix}yt_limit_unlock_start_ms',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

  static Future<void> clearYoutubeLimitUnlockCountdown() =>
      _box.delete('${_prefix}yt_limit_unlock_start_ms');

  /// 타임락에 막혀 저장 못 한 한도 변경 초안 — 대기가 끝나면 자동 적용된다
  /// (2026-07-20 사용자 요청: "그냥 안 된다"고만 하지 말고 대기 후 자동 적용).
  static String? get youtubeLimitPendingPolicyDraftJson =>
      _box.get('${_prefix}yt_limit_pending_draft');

  static Future<void> setYoutubeLimitPendingPolicyDraftJson(String? json) =>
      json == null
          ? _box.delete('${_prefix}yt_limit_pending_draft')
          : _box.put('${_prefix}yt_limit_pending_draft', json);

  // ── 키워드·URL·앱 목록 제거 타임락 (기본 ON · 15분) ─────────────────
  // 추가는 즉시 · 제거/해제는 대기 후 · 대기 분 늘리기=즉시 · 줄이기=해제 창에서만

  static bool get ruleRemovalLockEnabled =>
      _box.get('${_prefix}rule_removal_lock') == 'true';

  static Future<void> setRuleRemovalLockEnabled(bool v) =>
      _box.put('${_prefix}rule_removal_lock', v ? 'true' : 'false');

  static int get ruleRemovalFreezeMinutes {
    final n = int.tryParse(_box.get('${_prefix}rule_removal_freeze_min') ?? '');
    return (n == null || n < 5) ? 15 : n.clamp(5, 1440);
  }

  static Future<void> setRuleRemovalFreezeMinutes(int v) => _box.put(
      '${_prefix}rule_removal_freeze_min', v.clamp(5, 1440).toString());

  static int? get ruleRemovalUnlockStartedAtMs =>
      int.tryParse(_box.get('${_prefix}rule_removal_unlock_start_ms') ?? '');

  static Duration? get ruleRemovalUnlockRemaining {
    final s = ruleRemovalUnlockStartedAtMs;
    if (s == null) return null;
    final end = DateTime.fromMillisecondsSinceEpoch(s)
        .add(Duration(minutes: ruleRemovalFreezeMinutes));
    final left = end.difference(DateTime.now());
    if (left.isNegative || left == Duration.zero) return null;
    return left;
  }

  static bool get ruleRemovalUnlockWindowOpen =>
      ruleRemovalUnlockStartedAtMs != null &&
      ruleRemovalUnlockRemaining == null;

  static Future<void> startRuleRemovalUnlockCountdown() => _box.put(
        '${_prefix}rule_removal_unlock_start_ms',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

  static Future<void> clearRuleRemovalUnlockCountdown() =>
      _box.delete('${_prefix}rule_removal_unlock_start_ms');

  /// "모든 차단 초기화" 챗 커맨드가 삭제 대기 잠금에 걸려 즉시 적용 못 하고
  /// 대기 중일 때 세우는 플래그 — 잠금 해제 창이 열리면(앱 재방문 시) 자동 적용.
  static bool get pendingFullResetRequested =>
      _box.get('${_prefix}pending_full_reset') == 'true';

  static Future<void> setPendingFullResetRequested(bool v) =>
      _box.put('${_prefix}pending_full_reset', v ? 'true' : 'false');

  // ── Premade block packs (4VPN JSON) ─────────────────────────────────────
  static Set<String> get appliedPremadeBlockPackIds {
    final raw = _box.get('${_prefix}premade_packs_applied');
    if (raw == null || raw.isEmpty) return {};
    try {
      return Set<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return {};
    }
  }

  static bool isPremadeBlockPackApplied(String packId) =>
      appliedPremadeBlockPackIds.contains(packId);

  static Future<void> markPremadeBlockPackApplied(
    String packId, {
    String? version,
  }) async {
    final set = appliedPremadeBlockPackIds..add(packId);
    await _box.put('${_prefix}premade_packs_applied', jsonEncode(set.toList()));
    if (version != null && version.isNotEmpty) {
      await _box.put('${_prefix}premade_pack_ver_$packId', version);
    }
  }

  static String? getPremadeBlockPackAppliedVersion(String packId) {
    final v = _box.get('${_prefix}premade_pack_ver_$packId');
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static Future<void> clearPremadeBlockPackAppliedVersion(String packId) async {
    await _box.delete('${_prefix}premade_pack_ver_$packId');
  }

  static Future<void> unmarkPremadeBlockPackApplied(String packId) async {
    final set = appliedPremadeBlockPackIds..remove(packId);
    await _box.put('${_prefix}premade_packs_applied', jsonEncode(set.toList()));
    await clearPremadeBlockPackAppliedVersion(packId);
  }

  /// 프리셋 카드 펼침 — 기본 접힘, 사용자가 펼친 뒤 기억
  static bool isPremadePackCardExpanded(String packId) =>
      _box.get('${_prefix}premade_pack_exp_$packId') == 'true';

  static Future<void> setPremadePackCardExpanded(
          String packId, bool expanded) =>
      _box.put(
          '${_prefix}premade_pack_exp_$packId', expanded ? 'true' : 'false');

  static String _premadePackProvenanceKey(String packId) =>
      '${_prefix}premade_pack_prov_$packId';

  static List<Map<String, dynamic>> getPremadePackProvenanceRaw(String packId) {
    final raw = _box.get(_premadePackProvenanceKey(packId));
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> appendPremadePackProvenance(
    String packId,
    List<Map<String, dynamic>> entries,
  ) async {
    if (entries.isEmpty) return;
    final existing = getPremadePackProvenanceRaw(packId);
    final seen = {
      for (final e in existing)
        '${e['storeKind']}|${(e['value'] as String?)?.toLowerCase()}',
    };
    for (final e in entries) {
      final key = '${e['storeKind']}|${(e['value'] as String?)?.toLowerCase()}';
      if (seen.add(key)) existing.add(e);
    }
    await _box.put(_premadePackProvenanceKey(packId), jsonEncode(existing));
  }

  static Future<void> clearPremadePackProvenance(String packId) async {
    await _box.delete(_premadePackProvenanceKey(packId));
  }

  static String _premadePackExclusionsKey(String packId) =>
      '${_prefix}premade_pack_excl_$packId';

  static Set<String> getPremadePackExclusions(String packId) {
    final raw = _box.get(_premadePackExclusionsKey(packId));
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  static bool isPremadePackEntryExcluded(String packId, String dedupeKey) =>
      getPremadePackExclusions(packId).contains(dedupeKey);

  static Future<void> addPremadePackExclusion(
      String packId, String dedupeKey) async {
    final key = dedupeKey.trim();
    if (key.isEmpty) return;
    final set = getPremadePackExclusions(packId)..add(key);
    await _box.put(_premadePackExclusionsKey(packId), jsonEncode(set.toList()));
  }

  static Future<void> clearPremadePackExclusions(String packId) async {
    await _box.delete(_premadePackExclusionsKey(packId));
  }

  static Future<void> removePremadePackProvenanceEntries(
    String packId,
    List<Map<String, dynamic>> toRemove,
  ) async {
    if (toRemove.isEmpty) return;
    final removeKeys = {
      for (final e in toRemove)
        '${e['storeKind']}|${(e['value'] as String?)?.toLowerCase()}',
    };
    final kept = getPremadePackProvenanceRaw(packId).where((e) {
      final k = '${e['storeKind']}|${(e['value'] as String?)?.toLowerCase()}';
      return !removeKeys.contains(k);
    }).toList();
    if (kept.isEmpty) {
      await clearPremadePackProvenance(packId);
    } else {
      await _box.put(_premadePackProvenanceKey(packId), jsonEncode(kept));
    }
  }

  /// 크리에이티브 분석 — Supabase Edge(캐시·서버 LLM). 기본 꺼짐(비용 옵트인).
  static bool get creativeAnalyticsCloudEnabled =>
      _box.get('${_prefix}creative_cloud_on') == 'true';

  static Future<void> setCreativeAnalyticsCloudEnabled(bool v) =>
      _box.put('${_prefix}creative_cloud_on', v ? 'true' : 'false');

  /// 인사이트 추출 — Supabase Edge `insight_extractor` (자막·LLM·DB). 로그인+옵트인.
  static bool get insightCloudExtractionEnabled =>
      _box.get('${_prefix}insight_cloud_on') == 'true';

  static Future<void> setInsightCloudExtractionEnabled(bool v) =>
      _box.put('${_prefix}insight_cloud_on', v ? 'true' : 'false');

  /// 하단 중앙 버튼 길게 누르기: youtube | instagram | choose
  static String get centerNavLongPressTarget =>
      _box.get('${_prefix}center_nav_long') ?? 'choose';

  static Future<void> setCenterNavLongPressTarget(String v) async {
    final allowed = {'youtube', 'instagram', 'choose'};
    await _box.put(
      '${_prefix}center_nav_long',
      allowed.contains(v) ? v : 'choose',
    );
  }

  /// YouTube WebView — Shorts·릴 선반 숨김 (기본 켜짐)
  static bool get hideYoutubeShorts =>
      _box.get('${_prefix}hide_yt_shorts') != 'false';

  static Future<void> setHideYoutubeShorts(bool v) =>
      _box.put('${_prefix}hide_yt_shorts', v ? 'true' : 'false');

  /// Instagram WebView — Reels 숨김 (기본 켜짐)
  static bool get hideInstagramReels =>
      _box.get('${_prefix}hide_ig_reels') != 'false';

  static Future<void> setHideInstagramReels(bool v) =>
      _box.put('${_prefix}hide_ig_reels', v ? 'true' : 'false');

  /// Instagram 안티-둠스크롤 — 일정 개수마다 멈춤 넛지 (기본 켜짐)
  static bool get instagramReelsGuardEnabled =>
      _box.get('${_prefix}ig_reels_guard') != 'false';

  static Future<void> setInstagramReelsGuardEnabled(bool v) =>
      _box.put('${_prefix}ig_reels_guard', v ? 'true' : 'false');

  /// 넛지를 띄우기까지 허용하는 연속 릴스/영상 개수 (기본 10, 3~50)
  static int get instagramReelsGuardThreshold =>
      int.tryParse(_box.get('${_prefix}ig_reels_guard_n') ?? '') ?? 10;

  static Future<void> setInstagramReelsGuardThreshold(int n) =>
      _box.put('${_prefix}ig_reels_guard_n', '${n.clamp(3, 50)}');

  /// Instagram 탐색(Explore) 안티-둠스크롤 — 포스트/스크롤 개수마다 멈춤 넛지 (기본 켜짐)
  static bool get instagramExploreGuardEnabled =>
      _box.get('${_prefix}ig_explore_guard') != 'false';

  static Future<void> setInstagramExploreGuardEnabled(bool v) =>
      _box.put('${_prefix}ig_explore_guard', v ? 'true' : 'false');

  /// 넛지를 띄우기까지 허용하는 탐색 포스트/스크롤 화면 수 (기본 15, 5~60)
  static int get instagramExploreGuardThreshold =>
      int.tryParse(_box.get('${_prefix}ig_explore_guard_n') ?? '') ?? 15;

  static Future<void> setInstagramExploreGuardThreshold(int n) =>
      _box.put('${_prefix}ig_explore_guard_n', '${n.clamp(5, 60)}');

  /// 크리에이티브 Top3 — 「내가 다루는 소재」 한 줄 (예: 3D·블ender 튜토리얼)
  static String get creatorNicheNote =>
      _box.get('${_prefix}creator_niche') ?? '';

  static Future<void> setCreatorNicheNote(String v) =>
      _box.put('${_prefix}creator_niche', v.trim());

  static bool get instagramDailyLimitEnabled =>
      _box.get('${_prefix}ig_daily_limit_on') != 'false';

  static Future<void> setInstagramDailyLimitEnabled(bool v) =>
      _box.put('${_prefix}ig_daily_limit_on', v ? 'true' : 'false');

  static int get instagramDailyLimitMinutes {
    final n = int.tryParse(_box.get('${_prefix}ig_daily_limit_min') ?? '');
    return (n == null || n < 1) ? 30 : n.clamp(5, 480);
  }

  static Future<void> setInstagramDailyLimitMinutes(int m) =>
      _box.put('${_prefix}ig_daily_limit_min', m.clamp(5, 480).toString());

  static bool get brunchDailyLimitEnabled =>
      _box.get('${_prefix}brunch_daily_limit_on') != 'false';

  static Future<void> setBrunchDailyLimitEnabled(bool v) =>
      _box.put('${_prefix}brunch_daily_limit_on', v ? 'true' : 'false');

  static int get brunchDailyLimitMinutes {
    final n = int.tryParse(_box.get('${_prefix}brunch_daily_limit_min') ?? '');
    return (n == null || n < 1) ? 30 : n.clamp(5, 480);
  }

  static Future<void> setBrunchDailyLimitMinutes(int m) =>
      _box.put('${_prefix}brunch_daily_limit_min', m.clamp(5, 480).toString());

  static bool get youtubeScheduleLockEnabled =>
      _box.get('${_prefix}yt_schedule_lock_on') == 'true';

  static Future<void> setYoutubeScheduleLockEnabled(bool v) =>
      _box.put('${_prefix}yt_schedule_lock_on', v ? 'true' : 'false');

  /// 스케줄 슬롯 시작·종료 로컬 알림 (기본 켜짐)
  static bool get scheduleBlockNotificationsEnabled =>
      _box.get('${_prefix}schedule_notif_on') != 'false';

  static Future<void> setScheduleBlockNotificationsEnabled(bool v) =>
      _box.put('${_prefix}schedule_notif_on', v ? 'true' : 'false');

  /// 매일 정해진 시각에 "오늘 뭐가 막히는지" 요약 알림 (기본 켜짐, 08:00)
  /// (2026-07-11 cage 요청: "아침에 일정한 시간에 늘 알림을 보내주라")
  static bool get morningNotificationEnabled =>
      _box.get('${_prefix}morning_notif_on') != 'false';

  static Future<void> setMorningNotificationEnabled(bool v) =>
      _box.put('${_prefix}morning_notif_on', v ? 'true' : 'false');

  static int get morningNotificationHour {
    final n = int.tryParse(_box.get('${_prefix}morning_notif_hour') ?? '');
    return (n == null) ? 8 : n.clamp(0, 23);
  }

  static int get morningNotificationMinute {
    final n = int.tryParse(_box.get('${_prefix}morning_notif_min') ?? '');
    return (n == null) ? 0 : n.clamp(0, 59);
  }

  static Future<void> setMorningNotificationTime(int hour, int minute) => _box
      .put(
        '${_prefix}morning_notif_hour',
        hour.clamp(0, 23).toString(),
      )
      .then((_) => _box.put(
            '${_prefix}morning_notif_min',
            minute.clamp(0, 59).toString(),
          ));

  /// 앱 첫 실행 시 알림 권한을 한 번 요청했는지 (스케줄 리마인더용)
  static bool get notificationPermissionRequested =>
      _box.get('${_prefix}notif_perm_requested') == 'true';

  static Future<void> setNotificationPermissionRequested(bool v) =>
      _box.put('${_prefix}notif_perm_requested', v ? 'true' : 'false');

  static bool get youtubeTimelockEnabled =>
      _box.get('${_prefix}yt_timelock_on') == 'true';

  static Future<void> setYoutubeTimelockEnabled(bool v) =>
      _box.put('${_prefix}yt_timelock_on', v ? 'true' : 'false');

  static bool get youtubeTimelockDisablePending =>
      _box.get('${_prefix}yt_timelock_disable_pending') == 'true';

  static Future<void> setYoutubeTimelockDisablePending(bool v) => v
      ? _box.put('${_prefix}yt_timelock_disable_pending', 'true')
      : _box.delete('${_prefix}yt_timelock_disable_pending');

  /// 차단 이유 시트 — 잠금 대기 후 자동 완화 (scheduleId|action)
  static String? get pendingBlockRelax =>
      _box.get('${_prefix}pending_block_relax');

  static Future<void> setPendingBlockRelax(String payload) =>
      _box.put('${_prefix}pending_block_relax', payload);

  static Future<void> clearPendingBlockRelax() =>
      _box.delete('${_prefix}pending_block_relax');

  static int get genreBlockMinSamples {
    final n = int.tryParse(_box.get('${_prefix}genre_min_samples') ?? '');
    return (n == null || n < 3) ? 5 : n.clamp(3, 30);
  }

  static Future<void> setGenreBlockMinSamples(int n) =>
      _box.put('${_prefix}genre_min_samples', n.clamp(3, 30).toString());

  static bool get genreBlockAutoAnalyze =>
      _box.get('${_prefix}genre_auto_analyze') != 'false';

  static Future<void> setGenreBlockAutoAnalyze(bool v) =>
      _box.put('${_prefix}genre_auto_analyze', v ? 'true' : 'false');

  /// 유형 분석 1회 최대 자동 차단 채널 수
  static int get genreMaxChannelsPerRun {
    final n = int.tryParse(_box.get('${_prefix}genre_max_channels') ?? '');
    return (n == null || n < 20) ? 120 : n.clamp(20, 300);
  }

  static Future<void> setGenreMaxChannelsPerRun(int n) =>
      _box.put('${_prefix}genre_max_channels', n.clamp(20, 300).toString());

  static int get genreSearchQueriesPerRun {
    final n = int.tryParse(_box.get('${_prefix}genre_search_queries') ?? '');
    return (n == null || n < 2) ? 8 : n.clamp(2, 12);
  }

  static int get interestArticleDays {
    final n = int.tryParse(_box.get('${_prefix}interest_article_days') ?? '');
    return (n == null || n < 1) ? 3 : n.clamp(1, 14);
  }

  static Future<void> setInterestArticleDays(int d) =>
      _box.put('${_prefix}interest_article_days', d.clamp(1, 14).toString());

  static double get apiMonthlyBudgetUsd {
    final n = double.tryParse(_box.get('${_prefix}api_budget_usd') ?? '');
    return n ?? 5.0;
  }

  static Future<void> setApiMonthlyBudgetUsd(double v) =>
      _box.put('${_prefix}api_budget_usd', v.clamp(0, 500).toString());

  static bool get apiBudgetEnforced =>
      _box.get('${_prefix}api_budget_enforced') != 'false';

  static Future<void> setApiBudgetEnforced(bool v) =>
      _box.put('${_prefix}api_budget_enforced', v ? 'true' : 'false');

  static int? get aiHubLastTestMs {
    final raw = _box.get('${_prefix}ai_hub_test_ms');
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  static bool get aiHubLastTestOk =>
      _box.get('${_prefix}ai_hub_test_ok') == 'true';

  static Future<void> setAiHubLastTest({required bool ok}) async {
    await _box.put(
        '${_prefix}ai_hub_test_ms', '${DateTime.now().millisecondsSinceEpoch}');
    await _box.put('${_prefix}ai_hub_test_ok', ok ? 'true' : 'false');
  }

  static int get digestPublishedThisWeek =>
      int.tryParse(_box.get('${_prefix}digest_count_week') ?? '') ?? 0;

  static DateTime? get digestLastPublishedAt {
    final raw = _box.get('${_prefix}digest_last_at');
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static Future<void> recordDigestPublished(int count) async {
    final now = DateTime.now();
    final last = digestLastPublishedAt;
    var weekCount = digestPublishedThisWeek;
    if (last != null) {
      final sameWeek = _isoWeek(now) == _isoWeek(last);
      if (!sameWeek) weekCount = 0;
    }
    await _box.put('${_prefix}digest_count_week', '${weekCount + count}');
    await _box.put('${_prefix}digest_last_at', now.toIso8601String());
  }

  static int _isoWeek(DateTime d) {
    final thursday = d.add(Duration(days: 4 - (d.weekday)));
    final yearStart = DateTime(thursday.year);
    return ((thursday.difference(yearStart).inDays) / 7).floor();
  }

  static Future<void> applyCommanderDefaults() async {
    await _box.put('${_prefix}use_youtube_web_shell', 'true');
    await _box.put('${_prefix}hide_blocked_feed', 'true');
    await _box.put('${_prefix}collapse_blocked_dom', 'true');
    await _box.put('${_prefix}dismiss_kb_on_block', 'true');
    await _box.put('${_prefix}swipe_right_action', 'both');
    await _box.put('${_prefix}sync_blocked_cloud', 'true');
    if (!_box.containsKey('${_prefix}youtube_desktop')) {
      await _box.put('${_prefix}youtube_desktop', 'false');
    }
    if (!_box.containsKey('${_prefix}track_yt_history')) {
      await _box.put('${_prefix}track_yt_history', 'true');
    }
    if (!_box.containsKey('${_prefix}yt_daily_limit_on')) {
      await _box.put('${_prefix}yt_daily_limit_on', 'true');
    }
    if (!_box.containsKey('${_prefix}yt_daily_limit_min')) {
      await _box.put('${_prefix}yt_daily_limit_min', '20');
    }
    if (!_box.containsKey('${_prefix}yt_limit_mode')) {
      await _box.put('${_prefix}yt_limit_mode', 'daily');
    }
    if (!_box.containsKey('${_prefix}yt_limit_raise_lock')) {
      await _box.put('${_prefix}yt_limit_raise_lock', 'true');
    }
    if (!_box.containsKey('${_prefix}yt_limit_freeze_min')) {
      await _box.put('${_prefix}yt_limit_freeze_min', '60');
    }
    if (!_box.containsKey('${_prefix}open_yt_in_isle')) {
      await _box.put('${_prefix}open_yt_in_isle', 'true');
    }
    if (!_box.containsKey('${_prefix}yt_clipboard_launch')) {
      await _box.put('${_prefix}yt_clipboard_launch', 'true');
    }
    if (!_box.containsKey('${_prefix}ig_daily_limit_on')) {
      await _box.put('${_prefix}ig_daily_limit_on', 'false');
    }
    if (!_box.containsKey('${_prefix}ig_daily_limit_min')) {
      await _box.put('${_prefix}ig_daily_limit_min', '30');
    }
    if (!_box.containsKey('${_prefix}brunch_daily_limit_on')) {
      await _box.put('${_prefix}brunch_daily_limit_on', 'false');
    }
    if (!_box.containsKey('${_prefix}brunch_daily_limit_min')) {
      await _box.put('${_prefix}brunch_daily_limit_min', '30');
    }
    if (!_box.containsKey('${_prefix}interest_article_days')) {
      await _box.put('${_prefix}interest_article_days', '3');
    }
    if (!_box.containsKey('${_prefix}api_budget_usd')) {
      await _box.put('${_prefix}api_budget_usd', '5');
    }
    if (!_box.containsKey('${_prefix}api_budget_enforced')) {
      await _box.put('${_prefix}api_budget_enforced', 'true');
    }
    if (!_box.containsKey('${_prefix}yt_schedule_lock_on')) {
      await _box.put('${_prefix}yt_schedule_lock_on', 'false');
    }
    if (!_box.containsKey('${_prefix}genre_min_samples')) {
      await _box.put('${_prefix}genre_min_samples', '5');
    }
    if (!_box.containsKey('${_prefix}genre_auto_analyze')) {
      await _box.put('${_prefix}genre_auto_analyze', 'true');
    }
    if (!_box.containsKey('${_prefix}genre_max_channels')) {
      await _box.put('${_prefix}genre_max_channels', '120');
    }
    if (!_box.containsKey('${_prefix}genre_search_queries')) {
      await _box.put('${_prefix}genre_search_queries', '8');
    }
  }

  /// 재설치·체크포인트 복원 후 피드에서 1회 안내
  static Future<void> setPendingRestoreNotice(String kind) =>
      _box.put('${_prefix}restore_notice', kind);

  static String? takePendingRestoreNotice() {
    final v = _box.get('${_prefix}restore_notice');
    if (v == null || v.isEmpty) return null;
    _box.delete('${_prefix}restore_notice');
    return v;
  }

  static bool get pendingScreenTimeReapply =>
      _box.get('${_prefix}screen_time_reapply_pending') == 'true';

  static Future<void> setPendingScreenTimeReapply(bool v) =>
      _box.put('${_prefix}screen_time_reapply_pending', v ? 'true' : 'false');

  /// 공유 탭 Isle 큐 — 플레이리스트·Watch Later URL 목록 (JSON array)
  static List<String> get shareQueueSourceUrls {
    final raw = _box.get('${_prefix}share_queue_sources');
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> setShareQueueSourceUrls(List<String> urls) =>
      _box.put('${_prefix}share_queue_sources', jsonEncode(urls));

  static Future<void> addShareQueueSourceUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    final list = [...shareQueueSourceUrls];
    if (!list.contains(u)) list.add(u);
    await setShareQueueSourceUrls(list);
  }

  static bool get shareQueueAutoSync =>
      _box.get('${_prefix}share_queue_auto') != 'false';

  static Future<void> setShareQueueAutoSync(bool v) =>
      _box.put('${_prefix}share_queue_auto', v ? 'true' : 'false');

  static bool get shareQueueSyncWatchLater =>
      _box.get('${_prefix}share_queue_wl') != 'false';

  static Future<void> setShareQueueSyncWatchLater(bool v) =>
      _box.put('${_prefix}share_queue_wl', v ? 'true' : 'false');

  static int? get shareQueueLastSyncMs {
    final v = _box.get('${_prefix}share_queue_last_sync');
    return v == null ? null : int.tryParse(v);
  }

  static Future<void> setShareQueueLastSyncMs(int ms) =>
      _box.put('${_prefix}share_queue_last_sync', '$ms');

  /// YouTube 계정 — 나중에 볼·플레이리스트 → 내 콘텐츠 자동 동기화
  static bool get youtubeAccountAutoSync =>
      _box.get('${_prefix}yt_account_auto_sync') != 'false';

  static Future<void> setYoutubeAccountAutoSync(bool v) =>
      _box.put('${_prefix}yt_account_auto_sync', v ? 'true' : 'false');

  static bool get youtubeSyncWatchLaterToLibrary =>
      _box.get('${_prefix}yt_sync_wl_library') != 'false';

  static Future<void> setYoutubeSyncWatchLaterToLibrary(bool v) =>
      _box.put('${_prefix}yt_sync_wl_library', v ? 'true' : 'false');

  static List<String> get youtubeSyncPlaylistIds {
    final raw = _box.get('${_prefix}yt_sync_playlist_ids');
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static Future<void> setYoutubeSyncPlaylistIds(List<String> ids) =>
      _box.put('${_prefix}yt_sync_playlist_ids', ids.join(','));

  static Future<void> toggleYoutubeSyncPlaylist(String id, bool on) async {
    final set = {...youtubeSyncPlaylistIds};
    if (on) {
      set.add(id);
    } else {
      set.remove(id);
    }
    await setYoutubeSyncPlaylistIds(set.toList());
  }

  static int? get youtubeLastAccountSyncMs {
    final v = _box.get('${_prefix}yt_account_last_sync');
    return v == null ? null : int.tryParse(v);
  }

  static Future<void> setYoutubeLastAccountSyncMs(int ms) =>
      _box.put('${_prefix}yt_account_last_sync', '$ms');

  /// 피드 — 타이포 인사이트 카드 (썸네일 축소·텍스트 히어로)
  static bool get insightTypographyFeed =>
      _box.get('${_prefix}insight_typography_feed') != 'false';

  static Future<void> setInsightTypographyFeed(bool v) =>
      _box.put('${_prefix}insight_typography_feed', v ? 'true' : 'false');

  /// Safari·앱 쉴드 임시 해제 만료 시각 (epoch ms, 0 = 일시해제 없음)
  static int get shieldPauseUntilMs =>
      int.tryParse(_box.get('${_prefix}shield_pause_until_ms') ?? '') ?? 0;

  static Future<void> setShieldPauseUntilMs(int ms) =>
      _box.put('${_prefix}shield_pause_until_ms', '$ms');

  /// SNS 허브 홈 화면 — 사용자가 안 쓰는 플랫폼 아이콘을 숨김(차단 대상
  /// 카탈로그에서 빼는 게 아니라 홈 화면 진입 버튼만 안 보이게).
  /// 2026-07-13: "안 쓰는 브런치·Facebook 등을 내가 골라서 뺄 수 있게 해달라"는
  /// 요청으로 신설.
  static Set<String> get hiddenSnsHubPlatformIds {
    final raw = _box.get('${_prefix}sns_hub_hidden_ids');
    if (raw == null || raw.isEmpty) return const {};
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
    } catch (_) {
      return const {};
    }
  }

  static Future<void> setHiddenSnsHubPlatformIds(Set<String> ids) =>
      _box.put('${_prefix}sns_hub_hidden_ids', jsonEncode(ids.toList()));

  /// TrustedTimeGuard — 마지막으로 네트워크로 확인한 (실제시각 - 기기시각)
  /// 오프셋(ms). 기기 시계를 앞으로 돌려 타임락을 우회하는 걸 막는 데 쓴다.
  static int get trustedTimeSkewMs =>
      int.tryParse(_box.get('${_prefix}trusted_time_skew_ms') ?? '') ?? 0;

  static Future<void> setTrustedTimeSkewMs(int ms) =>
      _box.put('${_prefix}trusted_time_skew_ms', '$ms');

  // --- 앱 켠 지 N분 트리거 ("아침에 앱 켠 지 30분은 유튜브 차단",
  // 2026-07-20 신설) — [AppOpenBlockTriggerService] 참고. ---

  static bool get appOpenTriggerEnabled =>
      _box.get('${_prefix}app_open_trigger_on') == 'true';

  static Future<void> setAppOpenTriggerEnabled(bool v) =>
      _box.put('${_prefix}app_open_trigger_on', v ? 'true' : 'false');

  static int get appOpenTriggerDurationMinutes {
    final n = int.tryParse(_box.get('${_prefix}app_open_trigger_min') ?? '');
    return (n == null) ? 30 : n.clamp(1, 24 * 60);
  }

  static Future<void> setAppOpenTriggerDurationMinutes(int minutes) => _box.put(
        '${_prefix}app_open_trigger_min',
        minutes.clamp(1, 24 * 60).toString(),
      );

  static List<String> get appOpenTriggerTargetIds {
    final raw = _box.get('${_prefix}app_open_trigger_targets');
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static Future<void> setAppOpenTriggerTargetIds(List<String> ids) =>
      _box.put('${_prefix}app_open_trigger_targets', ids.join(','));

  static bool get appOpenTriggerBlockSafari =>
      _box.get('${_prefix}app_open_trigger_safari') == 'true';

  static Future<void> setAppOpenTriggerBlockSafari(bool v) =>
      _box.put('${_prefix}app_open_trigger_safari', v ? 'true' : 'false');

  /// true면 컷오프 시각 이전 그날 첫 실행에만 발동("아침에" 명시한 경우)
  static bool get appOpenTriggerMorningOnly =>
      _box.get('${_prefix}app_open_trigger_morning_only') == 'true';

  static Future<void> setAppOpenTriggerMorningOnly(bool v) =>
      _box.put('${_prefix}app_open_trigger_morning_only', v ? 'true' : 'false');

  static int get appOpenTriggerCutoffHour {
    final n =
        int.tryParse(_box.get('${_prefix}app_open_trigger_cutoff_hour') ?? '');
    return (n == null) ? 11 : n.clamp(0, 23);
  }

  static Future<void> setAppOpenTriggerCutoffHour(int hour) => _box.put(
        '${_prefix}app_open_trigger_cutoff_hour',
        hour.clamp(0, 23).toString(),
      );

  /// 오늘 이미 발동했는지 판정용 "YYYY-MM-DD" — 하루 한 번만 발동시킨다.
  static String? get appOpenTriggerLastDateKey =>
      _box.get('${_prefix}app_open_trigger_last_date');

  /// Newest authenticated Auto Pomodoro wake/sleep event applied by MOA.
  static int get pomodoroWakeLastEventAtMs =>
      int.tryParse(
          _box.get('${_prefix}pomodoro_wake_last_event_at_ms') ?? '') ??
      0;

  static Future<void> setPomodoroWakeLastEventAtMs(int value) =>
      _box.put('${_prefix}pomodoro_wake_last_event_at_ms', value.toString());

  static const pomodoroWakeDefaultTargetIds = <String>{
    'isle_instagram',
    'isle_instagram_dm',
    'isle_youtube',
  };

  static const pomodoroWakeSelectableTargetIds = <String>{
    ...pomodoroWakeDefaultTargetIds,
    'isle_brunch',
    'isle_customweb',
  };

  /// Local MOA surfaces to block after a confirmed Auto Pomodoro wake.
  /// QR scanning is intentionally not a target; Safari/Web browsing is opt-in.
  static Set<String> get pomodoroWakeLockTargetIds {
    final raw = _box.get('${_prefix}pomodoro_wake_targets');
    if (raw == null) return pomodoroWakeDefaultTargetIds;
    try {
      final values = (jsonDecode(raw) as List).whereType<String>().toSet();
      return values.intersection(pomodoroWakeSelectableTargetIds);
    } catch (_) {
      return pomodoroWakeDefaultTargetIds;
    }
  }

  static Future<void> setPomodoroWakeLockTargetIds(Set<String> ids) => _box.put(
        '${_prefix}pomodoro_wake_targets',
        jsonEncode(
            ids.intersection(pomodoroWakeSelectableTargetIds).toList()..sort()),
      );

  static Future<void> setAppOpenTriggerLastDateKey(String key) =>
      _box.put('${_prefix}app_open_trigger_last_date', key);
}
