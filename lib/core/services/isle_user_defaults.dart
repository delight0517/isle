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

  /// 성인 URL·SafeSearch·유튜브 제한 모드 (기본 ON)
  static bool get contentSafetyEnabled =>
      _box.get('${_prefix}content_safety') != 'false';

  static Future<void> setContentSafetyEnabled(bool v) =>
      _box.put('${_prefix}content_safety', v ? 'true' : 'false');

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
      _box.get('${_prefix}ios_internal_lock') ?? 'auto';

  static Future<void> setIosInternalLockMode(String v) =>
      _box.put('${_prefix}ios_internal_lock', v);

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

  /// 몰입 모드 — 홈 화면 스위칭 가이드
  static bool get hasSeenYoutubeFocusHomeSwitchGuide =>
      _box.get('${_prefix}youtube_focus_home_switch') == 'true';

  static Future<void> setHasSeenYoutubeFocusHomeSwitchGuide(bool v) =>
      _box.put('${_prefix}youtube_focus_home_switch', v ? 'true' : 'false');

  /// 섬 3D 배경 테마 — classic | midnight | sunset | aurora
  static String get islandThemeId => _box.get('${_prefix}island_theme') ?? 'classic';

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
  static bool get productFocusUi => _box.get('${_prefix}product_focus_ui') != 'false';

  static Future<void> setProductFocusUi(bool v) =>
      _box.put('${_prefix}product_focus_ui', v ? 'true' : 'false');

  /// SNS·섬·AI 등 고급 메뉴 표시
  static bool get showAdvancedUi => _box.get('${_prefix}show_advanced_ui') == 'true';

  static Future<void> setShowAdvancedUi(bool v) =>
      _box.put('${_prefix}show_advanced_ui', v ? 'true' : 'false');

  /// 온보딩에서 고른 관심 태그 (쉼표 구분)
  static List<String> get onboardingInterestTags {
    final raw = _box.get('${_prefix}onboarding_interests');
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
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

  static int get digestMaxPerWeek {
    final n = int.tryParse(_box.get('${_prefix}digest_max_week') ?? '');
    return (n == null || n < 1) ? 2 : n.clamp(1, 14);
  }

  static Future<void> setDigestMaxPerWeek(int n) =>
      _box.put('${_prefix}digest_max_week', n.clamp(1, 14).toString());

  /// 유튜브 WebView에서 본 영상을 라이브러리·피드에 기록
  static bool get trackYoutubeWatchHistory =>
      _box.get('${_prefix}track_yt_history') != 'false';

  static Future<void> setTrackYoutubeWatchHistory(bool v) =>
      _box.put('${_prefix}track_yt_history', v ? 'true' : 'false');

  /// 인앱 브라우저 상·하단 바 — true: 다크(유튜브·시계 가독)
  static bool get explorerChromeDark => _box.get('${_prefix}explorer_chrome_dark') != 'false';

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

  static Future<void> startInstagramDmBlockSettingsFreezeCountdown() => _box.put(
        '${_prefix}ig_dm_block_unlock_start_ms',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

  static Future<void> clearInstagramDmBlockSettingsFreezeCountdown() =>
      _box.delete('${_prefix}ig_dm_block_unlock_start_ms');

  /// 브런치·블로그 전용 숨김 키워드 (쉼표)
  static List<String> get brunchBlockKeywords {
    final raw = _box.get('${_prefix}brunch_block_kw');
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
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

  // ── 유튜브 한도 상향 잠금 (지연락) ─────────────────────────────────
  // 켜면: 한도를 '늘리거나' 끄려면 먼저 해제 카운트다운(지연)을 기다려야 함.
  //       '줄이는' 변경은 항상 즉시 적용. (충동적 상향 시청 방지)
  // 기본 꺼짐 — 되돌리기 어려운 잠금을 동의 없이 강제하지 않음. (IG DM freeze와 동일 패턴)

  static bool get youtubeLimitRaiseLockEnabled =>
      _box.get('${_prefix}yt_limit_raise_lock') == 'true';

  static Future<void> setYoutubeLimitRaiseLockEnabled(bool v) =>
      _box.put('${_prefix}yt_limit_raise_lock', v ? 'true' : 'false');

  static int get youtubeLimitUnlockFreezeMinutes {
    final n = int.tryParse(_box.get('${_prefix}yt_limit_freeze_min') ?? '');
    return (n == null || n < 5) ? 60 : n.clamp(5, 1440);
  }

  static Future<void> setYoutubeLimitUnlockFreezeMinutes(int v) =>
      _box.put('${_prefix}yt_limit_freeze_min', v.clamp(5, 1440).toString());

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
      youtubeLimitUnlockStartedAtMs != null && youtubeLimitUnlockRemaining == null;

  /// 지금 상향/해제가 잠금에 막혀 있는지 (true면 줄이기만 가능)
  static bool get youtubeLimitRaiseBlocked =>
      youtubeLimitRaiseLockEnabled && !youtubeLimitUnlockWindowOpen;

  static Future<void> startYoutubeLimitUnlockCountdown() => _box.put(
        '${_prefix}yt_limit_unlock_start_ms',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

  static Future<void> clearYoutubeLimitUnlockCountdown() =>
      _box.delete('${_prefix}yt_limit_unlock_start_ms');

  // ── 키워드·URL·앱 목록 제거 타임락 (기본 ON · 15분) ─────────────────
  // 추가는 즉시 · 제거/해제는 대기 후 · 대기 분 늘리기=즉시 · 줄이기=해제 창에서만

  static bool get ruleRemovalLockEnabled =>
      _box.get('${_prefix}rule_removal_lock') != 'false';

  static Future<void> setRuleRemovalLockEnabled(bool v) =>
      _box.put('${_prefix}rule_removal_lock', v ? 'true' : 'false');

  static int get ruleRemovalFreezeMinutes {
    final n = int.tryParse(_box.get('${_prefix}rule_removal_freeze_min') ?? '');
    return (n == null || n < 5) ? 15 : n.clamp(5, 1440);
  }

  static Future<void> setRuleRemovalFreezeMinutes(int v) =>
      _box.put('${_prefix}rule_removal_freeze_min', v.clamp(5, 1440).toString());

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
      ruleRemovalUnlockStartedAtMs != null && ruleRemovalUnlockRemaining == null;

  static Future<void> startRuleRemovalUnlockCountdown() => _box.put(
        '${_prefix}rule_removal_unlock_start_ms',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

  static Future<void> clearRuleRemovalUnlockCountdown() =>
      _box.delete('${_prefix}rule_removal_unlock_start_ms');

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

  static Future<void> markPremadeBlockPackApplied(String packId) async {
    final set = appliedPremadeBlockPackIds..add(packId);
    await _box.put('${_prefix}premade_packs_applied', jsonEncode(set.toList()));
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

  /// 크리에이티브 Top3 — 「내가 다루는 소재」 한 줄 (예: 3D·블ender 튜토리얼)
  static String get creatorNicheNote => _box.get('${_prefix}creator_niche') ?? '';

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

  /// 앱 첫 실행 시 알림 권한을 한 번 요청했는지 (스케줄 리마인더용)
  static bool get notificationPermissionRequested =>
      _box.get('${_prefix}notif_perm_requested') == 'true';

  static Future<void> setNotificationPermissionRequested(bool v) =>
      _box.put('${_prefix}notif_perm_requested', v ? 'true' : 'false');

  static bool get youtubeTimelockEnabled =>
      _box.get('${_prefix}yt_timelock_on') == 'true';

  static Future<void> setYoutubeTimelockEnabled(bool v) =>
      _box.put('${_prefix}yt_timelock_on', v ? 'true' : 'false');

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

  static bool get apiBudgetEnforced => _box.get('${_prefix}api_budget_enforced') != 'false';

  static Future<void> setApiBudgetEnforced(bool v) =>
      _box.put('${_prefix}api_budget_enforced', v ? 'true' : 'false');

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

  static bool get shareQueueAutoSync => _box.get('${_prefix}share_queue_auto') != 'false';

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
    return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
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
}
