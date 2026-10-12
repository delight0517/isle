import '../../../core/localization/moa_strings.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/explorer/safari_web_config.dart';
import '../../../core/brunch/brunch_author_probe_script.dart';
import '../../../core/brunch/brunch_blocked_author_store.dart';
import '../../../core/explorer/explorer_site.dart';
import '../../../core/explorer/isle_webview_factory.dart';
import '../../../core/explorer/search_block_early_inject.dart';
import '../../../core/guard/in_app_safari_host.dart';
import '../../../core/guard/isle_block_boundary.dart';
import '../../../core/guard/isle_content_block_guard.dart';
import '../../../core/safe_browser/safe_browser_history_store.dart';
import '../../../core/safe_browser/safe_browser_temporary_allow_store.dart';
import '../../../core/guard/isle_playback_guard.dart';
import '../../../core/feed/feed_ingest_service.dart';
import '../../../core/library/engagement_tracker.dart';
import '../../../core/library/platform_watch_limit_store.dart';
import '../../../core/library/youtube_watch_history_service.dart';
import '../../../core/navigation/schedule_overlay_navigation.dart';
import '../../../core/platform/ios_screen_time_service.dart';
import '../../../core/platform/moa_four_vpn_rules_service.dart';
import '../../../core/platform/isle_web_session_persistence_service.dart';
import '../../../core/platform/passkey_login_service.dart';
import '../../../core/platform/platform_block_intent.dart';
import '../../../core/platform/passkey_web_probe_script.dart';
import '../../../core/platform/web_session_cookie_bridge.dart';
import '../../../core/services/isle_external_launch_guard.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/youtube/block_keyword_policy.dart';
import '../../../core/youtube/blocked_channel_store.dart';
import '../../../core/youtube/content_filter_store.dart';
import '../../../core/youtube/models/blocked_channel.dart';
import '../../../core/youtube/models/blocked_video.dart';
import '../../../core/youtube/models/youtube_page_channel.dart';
import '../../../core/youtube/blocked_url_guard.dart';
import '../../../core/youtube/blocked_url_store.dart';
import '../../../core/youtube/models/blocked_url.dart';
import '../../../core/utils/url_parser.dart';
import '../../feed/presentation/widgets/blocked_url_sheet.dart';
import '../../feed/presentation/widgets/keyword_filter_sheet.dart';
import '../../feed/providers/feed_provider.dart';
import '../../../core/block_schedule/url_rules/schedule_web_block_guard.dart';
import '../../../core/intervention/website_block_guard.dart';
import '../../../core/navigation/explorer_entry_guard.dart';
import 'widgets/explorer_entry_blocked_screen.dart';
import '../../../core/safety/content_safety_guard.dart';
import '../../../core/youtube/youtube_block_reapply_hub.dart';
import '../../../core/youtube/youtube_channel_block_guard.dart';
import '../../../core/youtube/youtube_channel_probe_script.dart';
import '../../../core/youtube/youtube_viewport_script.dart';
import '../../../core/youtube/youtube_playback_error_probe.dart';
import '../../../core/youtube/youtube_search_ui_probe.dart';
import '../../../core/youtube/google_auth_path_policy.dart';
import '../../../core/youtube/youtube_nav_policy.dart';
import '../../../core/social/instagram_auth_path_policy.dart';
import '../../../core/social/instagram_following_store.dart';
import '../../../core/social/instagram_web_error_recovery.dart';
import '../../../core/social/instagram_web_config.dart';
import '../../../core/social/instagram_dm_focus_script.dart';
import '../../../core/social/instagram_dm_navigation_script.dart';
import '../../../core/social/instagram_dm_path_policy.dart';
import '../../../core/social/instagram_post_comments_script.dart';
import '../../../core/social/instagram_media_viewer_script.dart';
import '../../../core/youtube/youtube_watch_probe_script.dart';
import '../../youtube/presentation/widgets/youtube_watch_pref_sheet.dart';
import '../../../core/youtube/youtube_webview_energy.dart';
import '../../../core/youtube/youtube_access_guard.dart';
import '../../../core/social/instagram_safari_launch_guard.dart';
import '../../../core/youtube/youtube_safari_launch_guard.dart';
import '../../../core/youtube/youtube_session.dart';
import '../../../core/youtube/youtube_webview_factory.dart';
import '../../youtube/presentation/widgets/isle_youtube_library_sheet.dart';
import '../../youtube/presentation/widgets/block_channel_sheet.dart';
import '../../youtube/presentation/widgets/youtube_creator_insight_sheet.dart';
import '../../youtube/presentation/widgets/platform_watch_limit_overlay.dart';
import '../../youtube/presentation/widgets/youtube_os_webview_recovery_bar.dart';
import '../../youtube/presentation/widgets/youtube_inline_mini.dart';
import '../../../core/utils/isle_keyboard.dart';
import '../../../core/services/isle_app_log_service.dart';
import '../../../shared/widgets/isle_block_snack_bar.dart';
import '../../../shared/widgets/isle_sheet.dart';
import '../../../shared/widgets/platform_time_limit_chip.dart';
import 'widgets/instagram_web_keyboard_surface.dart';
import '../../../core/block_schedule/schedule_active_service.dart';
import '../../../core/block_schedule/schedule_app_targets_store.dart';
import '../../../core/block_schedule/schedule_bundle_usage_store.dart';
import '../../../core/block_schedule/schedule_lock_service.dart';
import '../../../core/block_schedule/schedule_lock_phase.dart';
import '../../../core/youtube/youtube_clipboard_quick_actions.dart';
import '../../../core/youtube/youtube_clipboard_watch.dart';
import '../../youtube/presentation/widgets/youtube_channel_quick_bar.dart';
import '../../../core/youtube/youtube_music_route.dart';
import '../../../core/youtube/youtube_url_redirect.dart';
import '../../settings/presentation/widgets/schedule_isle_block_overlay.dart';
import 'widgets/page_link_bulk_block_sheet.dart';
import 'widgets/safe_browser_block_sheet.dart';
import '../../../shared/widgets/web_playback_recovery_overlay.dart';

class _PendingScheduleUsage {
  _PendingScheduleUsage({
    required this.scheduleId,
    required this.targetId,
    required this.windowMinutes,
  });

  final String scheduleId;
  final String targetId;
  final int windowMinutes;
  int seconds = 0;
}

/// 유튜브 시청 tick 사이 실제로 적립해야 할 초 — 순수 함수라 유닛테스트 가능.
///
/// `_onWatchTick`은 1초 `Timer.periodic`마다 WebView JS 브릿지로
/// `runJavaScriptReturningResult`를 호출해 "지금 재생 중인가"를 확인한다. 이
/// 왕복이 1초보다 오래 걸리면(유튜브 페이지가 무겁거나 광고·버퍼링 중) 다음
/// tick이 재진입 가드(`_watchTickBusy`)에 걸려 그냥 스킵되는데, 예전에는 완료된
/// tick마다 무조건 "+1초"만 적립해서 그 스킵된 시간이 통째로 사라졌다(실제
/// 시청 시간 누락의 원인). 이 함수는 마지막 적립 시각부터 지금까지의 **실제
/// 경과 시간**을 되돌려주므로, 중간 tick이 몇 번 스킵되든 적립되는 총합은
/// 실제 재생된 시간과 일치한다.
///
/// 단, 기기 잠금·앱 프리즈처럼 진짜로 오래 멈췄다 돌아온 경우까지 그 공백을
/// 통째로 "시청"으로 적립하면 안 되므로 [maxCreditSeconds]로 상한을 둔다.
int watchTickCreditSeconds({
  required DateTime? lastCreditAt,
  required DateTime now,
  int maxCreditSeconds = 5,
}) {
  if (lastCreditAt == null) return 1;
  final elapsedMs = now.difference(lastCreditAt).inMilliseconds;
  if (elapsedMs <= 0) return 1;
  final elapsedSeconds = (elapsedMs / 1000).round();
  return elapsedSeconds.clamp(1, maxCreditSeconds);
}

/// 전체 화면 WebView — 얇은 다크/라이트 크롬 (유튜브·브런치·블로그)
class WebExplorerScreen extends ConsumerStatefulWidget {
  const WebExplorerScreen({
    super.key,
    required this.site,
    this.initialUrl,
    this.title,
    this.autoLogin = false,
    this.brunchPromptLogin = false,
    this.instagramDmOnly = false,
  });

  final ExplorerSite site;
  final String? initialUrl;
  final String? title;
  final bool autoLogin;
  final bool brunchPromptLogin;
  final bool instagramDmOnly;

  @override
  ConsumerState<WebExplorerScreen> createState() => _WebExplorerScreenState();
}

class _WebExplorerScreenState extends ConsumerState<WebExplorerScreen>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  final List<_BrowserTabState> _tabs = [];
  int _activeTabIndex = 0;
  late String _currentUrl;
  bool _loading = true;
  bool _showLoginBanner = false;
  bool _chromeVisible = true;
  bool _leavingMinimized = false;
  YoutubePageChannel _probed =
      const YoutubePageChannel(channelId: '', channelName: '');
  String _brunchHandle = '';
  String _brunchAuthorName = '';
  late final DateTime _openedAt;
  Timer? _injectDebounce;
  Timer? _watchTick;
  Timer? _watchBlockProbeTimer;
  bool _appActive = true;
  bool _watchTickBusy = false;
  DateTime? _lastWatchTickCreditAt;
  DateTime? _lastYoutubeHistoryTickAt;
  late final IslePlaybackGuard _playbackGuard;
  IslePlaybackRecoveryState _recovery = const IslePlaybackRecoveryState.idle();
  bool _useAltUserAgent = false;
  bool _youtubeSearchUiActive = false;
  bool _pendingYoutubeLogin = false;
  bool _youtubeInlineMini = false;
  String? _lastInstagramDmDenialPath;
  Timer? _loadingFailsafe;
  // 성인 프리셋 등 실제로 얼리 클록이 주입될 때만(=SearchBlockEarlyInject.shouldInject
  // 가 true일 때만) 로딩 오버레이를 살짝 연장 — 무관한 검색까지 느려지면 안 된다는
  // 요구사항 때문에 `_loading`이 아니라 별도 플래그로 분리한다(2026-07-20).
  bool _searchCloakOverlayActive = false;
  Timer? _searchCloakOverlayTimer;
  WebViewController? _browseController;
  String _browseCurrentUrl = '';
  String _preWatchBrowseUrl = '';
  String _lastInstagramDmUrl = '';
  bool _instagramNavBusy = false;
  bool _instagramMediaViewerOpen = false;
  bool _instagramSoundHint = false;
  Timer? _instagramNavBusyTimer;
  Timer? _instagramSoundHintTimer;
  final Set<WebViewController> _instagramJsChannelWired = {};
  DateTime? _instagramEdgeSwipeAt;
  bool _youtubeQuickBarDismissed = false;
  Timer? _clipboardOfferDebounce;
  bool _embeddedYoutubeActive = false;
  final Set<WebViewController> _embedSurfaceChannelWired = {};
  bool _pendingSafariPasskeySync = false;
  String _safariPasskeyReturnUrl = '';
  final Set<int> _passkeyProbeWired = {};
  DateTime? _passkeyInterceptAt;
  bool _entryBlocked = false;
  String? _entryDenyMessage;
  DateTime? _lastYoutubeLightInjectAt;
  String? _lastYoutubeInjectSignature;
  final ValueNotifier<int> _watchUiPulse = ValueNotifier<int>(0);
  final Map<String, int> _pendingUsageStatSeconds = {};
  final Map<PlatformWatchId, int> _pendingWatchLimitSeconds = {};
  final Map<String, _PendingScheduleUsage> _pendingScheduleUsage = {};

  bool get _isYoutube => widget.site.isYoutube;
  bool get _isBrunch => widget.site.isBrunch;
  bool get _isInstagram => widget.site.isInstagram;
  bool get _supportsTabs => !_isYoutube;

  /// Safari(custom) 안에서 YouTube 도메인 — Isle 유튜브와 동일 한도·타임락 적용
  bool get _isSafariYoutube =>
      widget.site == ExplorerSite.custom &&
      YoutubeUrlRedirect.isYoutubeUrl(_currentUrl);

  /// 인앱 Safari·유튜브 탭 — 차단 규칙·한도·시청 시간 공통 적용
  bool get _youtubeRulesApply =>
      _isYoutube || _isSafariYoutube || widget.site == ExplorerSite.custom;

  ExplorerSite get _scheduleOverlaySite {
    if (_isSafariYoutube ||
        (widget.site == ExplorerSite.custom && _embeddedYoutubeActive)) {
      return ExplorerSite.youtube;
    }
    if (widget.site == ExplorerSite.custom) {
      return IsleContentBlockGuard.scheduleOverlaySiteForCustomUrl(_currentUrl);
    }
    return widget.site;
  }

  ExplorerSite get _injectSite {
    if (_isSafariYoutube) return ExplorerSite.youtube;
    if (widget.site == ExplorerSite.custom) {
      return InAppSafariHostResolver.explorerSiteFor(
        InAppSafariHostResolver.hostForUrl(_currentUrl),
      );
    }
    return widget.site;
  }

  PlatformWatchId? get _watchPlatform {
    if (_isSafariYoutube ||
        (widget.site == ExplorerSite.custom && _embeddedYoutubeActive)) {
      return PlatformWatchId.youtube;
    }
    if (_isInstagram) {
      // DM 전용 WebView — 시간 한도 없음(피드·릴스는 별도 진입)
      if (widget.instagramDmOnly) return null;
      return PlatformWatchId.instagram;
    }
    if (widget.site == ExplorerSite.custom &&
        InAppSafariHostResolver.hostForUrl(_currentUrl) ==
            InAppSafariHost.instagram) {
      return PlatformWatchId.instagram;
    }
    return PlatformWatchLimitStore.fromExplorerSiteName(widget.site.name);
  }

  String _usageStatKeyFor(PlatformWatchId platform) {
    switch (platform) {
      case PlatformWatchId.youtube:
        return 'youtube';
      case PlatformWatchId.instagram:
      case PlatformWatchId.instagramDm:
        return 'instagram';
      case PlatformWatchId.brunch:
        return 'brunch';
    }
  }

  void _recordUsageStatSecond(PlatformWatchId platform, [int seconds = 1]) {
    final key = _usageStatKeyFor(platform);
    final next = (_pendingUsageStatSeconds[key] ?? 0) + seconds;
    if (next < 5) {
      _pendingUsageStatSeconds[key] = next;
      return;
    }
    _pendingUsageStatSeconds.remove(key);
    unawaited(EngagementTracker.recordScreen('platform_$key', seconds: next));
  }

  void _flushUsageStatSeconds() {
    if (_pendingUsageStatSeconds.isEmpty) return;
    final pending = Map<String, int>.from(_pendingUsageStatSeconds);
    _pendingUsageStatSeconds.clear();
    for (final e in pending.entries) {
      if (e.value <= 0) continue;
      unawaited(EngagementTracker.recordScreen('platform_${e.key}',
          seconds: e.value));
    }
  }

  void _recordWatchLimitSecond(PlatformWatchId platform, [int seconds = 1]) {
    final next = (_pendingWatchLimitSeconds[platform] ?? 0) + seconds;
    final nearLimit = PlatformWatchLimitStore.isEnabled(platform) &&
        PlatformWatchLimitStore.secondsRemaining(platform) <= next;
    if (next < 5 && !nearLimit) {
      _pendingWatchLimitSeconds[platform] = next;
      return;
    }
    _pendingWatchLimitSeconds.remove(platform);
    PlatformWatchLimitStore.addSeconds(platform, next);
  }

  void _flushWatchLimitSeconds() {
    if (_pendingWatchLimitSeconds.isEmpty) return;
    final pending = Map<PlatformWatchId, int>.from(_pendingWatchLimitSeconds);
    _pendingWatchLimitSeconds.clear();
    for (final e in pending.entries) {
      if (e.value <= 0) continue;
      PlatformWatchLimitStore.addSeconds(e.key, e.value);
    }
  }

  String _pendingScheduleUsageKey(
    String scheduleId,
    String targetId,
    int windowMinutes,
  ) =>
      '$scheduleId\x1f$targetId\x1f$windowMinutes';

  void _recordScheduleBundleUsageSecond([int seconds = 1]) {
    final targetId = _isleTargetIdForSite();
    if (targetId == null) return;
    for (final s in ScheduleActiveService.activeSchedulesNow()) {
      final e = ScheduleAppTargetsStore.entryFor(s.id, targetId);
      if (e == null || !e.limitEnabled) continue;
      final key = _pendingScheduleUsageKey(s.id, targetId, e.windowMinutes);
      final pending = _pendingScheduleUsage.putIfAbsent(
        key,
        () => _PendingScheduleUsage(
          scheduleId: s.id,
          targetId: targetId,
          windowMinutes: e.windowMinutes,
        ),
      );
      pending.seconds += seconds;
      if (pending.seconds >= 5) {
        _flushScheduleBundleUsageForKey(key);
      }
    }
  }

  void _flushScheduleBundleUsageForKey(String key) {
    final pending = _pendingScheduleUsage.remove(key);
    if (pending == null || pending.seconds <= 0) return;
    ScheduleBundleUsageStore.addIsleTargetSeconds(
      pending.scheduleId,
      pending.targetId,
      pending.windowMinutes,
      pending.seconds,
    );
  }

  void _flushScheduleBundleUsage() {
    if (_pendingScheduleUsage.isEmpty) return;
    for (final key in _pendingScheduleUsage.keys.toList()) {
      _flushScheduleBundleUsageForKey(key);
    }
  }

  void _notifyWatchUi() {
    _watchUiPulse.value += 1;
  }

  void _flushWatchCounters() {
    _flushUsageStatSeconds();
    _flushWatchLimitSeconds();
    _flushScheduleBundleUsage();
  }

  bool get _isWatchPage =>
      (_isYoutube || _isSafariYoutube) &&
      (_currentUrl.contains('watch?v=') || _currentUrl.contains('/shorts/'));

  bool get _shouldCountYoutubeUsageSeconds {
    if (!_isYoutube && !_isSafariYoutube && !_embeddedYoutubeActive) {
      return false;
    }
    final path = Uri.tryParse(_currentUrl)?.path.toLowerCase() ?? '';
    return path == '/watch' || path.startsWith('/shorts/');
  }

  bool _isInstagramDmThreadPath(String path) =>
      InstagramDmPathPolicy.isDmThreadPath(path);

  bool get _instagramDmThreadActive {
    if (!_isInstagram) return false;
    final path = Uri.tryParse(_currentUrl)?.path ?? '';
    return _isInstagramDmThreadPath(path);
  }

  bool _isInstagramMediaPath(String path) =>
      InstagramDmPathPolicy.isSharedMediaPath(path);

  /// DM 스레드 URL 유지 + SPA 릴스·포스트 오버레이
  bool get _instagramImmersive =>
      _isInstagram &&
      (_isInstagramMediaPath(Uri.tryParse(_currentUrl)?.path ?? '') ||
          _instagramMediaViewerOpen);

  bool _instagramDmFocusAllowsPath(String path) =>
      InstagramDmPathPolicy.isAllowedInDmFocusMode(path);

  bool get _isInstagramAuthFlow {
    if (!_isInstagram) return false;
    return InstagramAuthPathPolicy.isAuthFlowUrl(_currentUrl);
  }

  bool get _isYoutubeGoogleAuthFlow =>
      _isYoutube && GoogleAuthPathPolicy.isAuthFlowUrl(_currentUrl);

  void _clearGoogleAuthLoading() {
    if (!mounted) return;
    _loadingFailsafe?.cancel();
    _playbackGuard.cancelRecovery();
    setState(() {
      _loading = false;
      if (_recovery.showOverlay || _recovery.showRecoveringOverlay) {
        _recovery = const IslePlaybackRecoveryState.idle();
      }
    });
  }

  void _trackInstagramDmUrl(String url) {
    if (!_isInstagram) return;
    final path = Uri.tryParse(url)?.path ?? '';
    if (_isInstagramDmThreadPath(path)) {
      _lastInstagramDmUrl = url;
    }
  }

  Future<void> _saveInstagramDmScroll([WebViewController? target]) async {
    final c = target ?? _controller;
    if (c == null || !_isInstagram) return;
    await c.runJavaScript(
        'if(window.__isleIgSaveDmScroll)window.__isleIgSaveDmScroll();');
  }

  Future<void> _restoreInstagramDmScroll([WebViewController? target]) async {
    final c = target ?? _controller;
    if (c == null || !_isInstagram) return;
    await c.runJavaScript(InstagramDmFocusScript.restoreScrollAndViewport);
  }

  Future<void> _dismissInstagramKeyboard() async {
    final c = _controller;
    if (c != null && _isInstagram) {
      await c.runJavaScript('''
        (function() {
          var ae = document.activeElement;
          if (ae && ae.blur) ae.blur();
          if (window.__isleIgClearKeyboardPadding) window.__isleIgClearKeyboardPadding();
        })();
      ''');
    }
    IsleKeyboard.hide();
  }

  Future<T?> _instagramJsWithTimeout<T>(
    Future<T> future, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      return await future.timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  Future<String> _readSavedInstagramDmThreadUrl(
      [WebViewController? target]) async {
    final c = target ?? _controller;
    if (c == null) return '';
    final raw = await _instagramJsWithTimeout(
      c.runJavaScriptReturningResult(
          InstagramDmNavigationScript.readSavedThreadUrl),
    );
    if (raw == null) return '';
    return raw.toString().replaceAll('"', '').trim();
  }

  Future<bool> _tryDismissInstagramMediaViewer(
      [WebViewController? target]) async {
    final c = target ?? _controller;
    if (c == null) return false;
    for (var attempt = 0; attempt < 2; attempt++) {
      final raw = await _instagramJsWithTimeout(
        c.runJavaScriptReturningResult(
            InstagramDmNavigationScript.tryDismissMediaViewer),
        timeout: const Duration(seconds: 3),
      );
      if (raw == null) continue;
      final result = raw.toString().replaceAll('"', '').trim();
      if (result == 'dismissed' || result == 'history' || result == 'escape') {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  void _wireInstagramJsChannels(WebViewController controller) {
    if (!_isInstagram || _instagramJsChannelWired.contains(controller)) return;
    _instagramJsChannelWired.add(controller);
    controller.addJavaScriptChannel(
      InstagramMediaViewerScript.jsChannelName,
      onMessageReceived: (m) => _onInstagramMediaProbe(m.message),
    );
  }

  Future<void> _tryUnmuteInstagramVideo() async {
    final c = _controller;
    if (c == null || !_isInstagram) return;
    HapticFeedback.lightImpact();
    await c.runJavaScript(InstagramMediaViewerScript.forceUnmute);
    if (mounted) setState(() => _instagramSoundHint = false);
  }

  void _onInstagramMediaProbe(String raw) {
    if (!_isInstagram || !mounted) return;
    final open = raw.trim() == 'open';
    if (open == _instagramMediaViewerOpen) return;
    setState(() {
      _instagramMediaViewerOpen = open;
      if (open) {
        _chromeVisible = false;
        _instagramSoundHint = true;
      } else if (_isInstagram) {
        _chromeVisible = true;
        _instagramSoundHint = false;
      }
    });
    _instagramSoundHintTimer?.cancel();
    if (open) {
      unawaited(_tryUnmuteInstagramVideo());
      _instagramSoundHintTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _instagramSoundHint = false);
      });
    }
  }

  bool _shouldInjectInstagramComments(String path) {
    if (!widget.instagramDmOnly) return true;
    return path.startsWith('/p/');
  }

  void _setInstagramNavBusy(bool busy) {
    _instagramNavBusyTimer?.cancel();
    if (mounted) {
      setState(() => _instagramNavBusy = busy);
    } else {
      _instagramNavBusy = busy;
    }
    if (busy) {
      _instagramNavBusyTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _instagramNavBusy) {
          setState(() => _instagramNavBusy = false);
        }
      });
    }
  }

  Future<void> _exitInstagramToHub() async {
    if (_instagramNavBusy) return;
    final now = DateTime.now();
    if (_instagramEdgeSwipeAt != null &&
        now.difference(_instagramEdgeSwipeAt!) <
            const Duration(milliseconds: 500)) {
      return;
    }
    _instagramEdgeSwipeAt = now;
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home/my-isle');
    }
  }

  String _resolveInstagramDmReturnUrl(String savedFromWeb) {
    if (_lastInstagramDmUrl.isNotEmpty) return _lastInstagramDmUrl;
    if (savedFromWeb.isNotEmpty && savedFromWeb.startsWith('http')) {
      return savedFromWeb;
    }
    return '';
  }

  bool _isYoutubeSearchUrl(String url) =>
      YoutubeNavPolicy.isSearchResultsUrl(url);

  /// 검색·홈·채널 — 시청 페이지가 아닐 때 로딩·자동복구 오버레이 숨김
  bool get _hideYoutubeLoadingOverlay =>
      _isYoutube &&
      (YoutubeNavPolicy.isBrowseSurface(_currentUrl) ||
          _youtubeSearchUiActive ||
          _isYoutubeSearchUrl(_currentUrl) ||
          _isYoutubeGoogleAuthFlow);

  bool get _showBlockingLoadOverlay =>
      (_loading || _searchCloakOverlayActive) &&
      !_hideYoutubeLoadingOverlay &&
      !_recovery.showOverlay &&
      !_recovery.showRecoveringOverlay;

  /// 성인 프리셋/키워드 필터가 실제로 걸리는 구글 검색에서만(=주입이 실제로
  /// 일어났을 때만) 로딩 오버레이를 살짝 더 유지 — 필터링 전 콘텐츠가 화면에
  /// 노출됐다 사라지는 ~1초 플래시 방지(07-13 제보). 얼리 클록(600ms 세이프티
  /// 타이머)보다 짧게 잡아 무관한 콘텐츠까지 계속 숨겨두는 일이 없게 한다.
  void _extendLoadOverlayForSearchCloak() {
    if (!mounted) return;
    _searchCloakOverlayTimer?.cancel();
    setState(() => _searchCloakOverlayActive = true);
    _searchCloakOverlayTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _searchCloakOverlayActive = false);
    });
  }

  void _clearLoadingSoon() {
    _loadingFailsafe?.cancel();
    final ms = _isYoutube &&
            (YoutubeNavPolicy.isBrowseSurface(_currentUrl) ||
                _youtubeSearchUiActive ||
                _isYoutubeSearchUrl(_currentUrl) ||
                _isYoutubeGoogleAuthFlow)
        ? 600
        : widget.site == ExplorerSite.custom
            ? 1500
            : 1200;
    _loadingFailsafe = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      if (_isYoutube &&
          (YoutubeNavPolicy.isBrowseSurface(_currentUrl) ||
              _youtubeSearchUiActive ||
              _isYoutubeSearchUrl(_currentUrl) ||
              _isYoutubeGoogleAuthFlow)) {
        _clearYoutubeBrowseLoading();
      }
      if (_isInstagram && widget.instagramDmOnly) {
        setState(() => _loading = false);
      } else if (_isInstagram) {
        setState(() => _loading = false);
      } else if (widget.site == ExplorerSite.custom) {
        setState(() => _loading = false);
        final idx = _activeTabIndex;
        if (idx >= 0 && idx < _tabs.length) {
          _tabs[idx] = _tabs[idx].copyWith(loading: false);
        }
      }
    });
  }

  bool _shouldInjectYoutubeBlocks(String url) {
    if (!YoutubeNavPolicy.hostIsYoutube(url)) return false;
    return true;
  }

  /// 검색면 — debounced sentry 사용 (light는 주기만 늘림)
  bool _youtubeBlockLightMode(String url) =>
      YoutubeNavPolicy.isSearchResultsUrl(url) ||
      (_youtubeSearchUiActive && YoutubeNavPolicy.isBrowseSurface(url));

  Future<void> _reapplyYoutubeBlocks() async {
    if (!mounted) return;
    if (!_youtubeRulesApply) return;
    await _injectBlocks();
    if (_browseController != null) await _injectBlocks(_browseController);
  }

  YoutubeBlockHit? _matchYoutubeBlock(
    String url, {
    YoutubePageChannel? probe,
  }) {
    if (!_youtubeRulesApply) return null;
    final channels = ref.read(blockedChannelsProvider);
    final videos = ref.read(blockedVideosProvider);
    final keywords = ref.read(blockedKeywordsProvider);
    final blockedUrls = ref.read(blockedUrlsProvider);
    if (channels.isEmpty &&
        videos.isEmpty &&
        keywords.isEmpty &&
        blockedUrls.isEmpty) {
      return null;
    }
    if (probe != null) {
      return YoutubeChannelBlockGuard.matchProbe(
        channels: channels,
        videos: videos,
        keywords: keywords,
        blockedUrls: blockedUrls,
        channelId: probe.channelId,
        channelName: probe.channelName,
        videoId: probe.videoId,
        videoTitle: probe.videoTitle,
        url: url,
      );
    }
    return YoutubeChannelBlockGuard.matchUrl(
      url,
      channels: channels,
      videos: videos,
      keywords: keywords,
      blockedUrls: blockedUrls,
    );
  }

  bool _applyBlockedUrlPolicy(String url, {WebViewController? controller}) {
    final hit = BlockedUrlGuard.match(url, ref.read(blockedUrlsProvider));
    if (hit == null) return false;
    unawaited(_redirectBlockedUrl(hit, controller: controller));
    return true;
  }

  Future<void> _redirectBlockedUrl(
    BlockedUrlHit hit, {
    WebViewController? controller,
  }) async {
    if (!mounted) return;
    _showBlockSnack(hit.snackMessage, url: _currentUrl);
    final c = controller ?? _controller;
    if (c == null) return;
    final back = _blockedYoutubeRedirectUrl();
    await c.loadRequest(Uri.parse(back));
    if (mounted && identical(c, _controller)) {
      setState(() => _currentUrl = back);
    }
  }

  Future<void> _redirectBlockedYoutube(YoutubeBlockHit hit) async {
    await _redirectBlockedYoutubeOn(_controller, hit, updateCurrentUrl: true);
  }

  bool _applyUrlPolicy(String url, {WebViewController? controller}) {
    if (GoogleAuthPathPolicy.isAuthFlowUrl(url)) return false;
    if (_applyContentSafetyUrl(url, controller: controller)) return true;
    if (_applyMoaFourVpnRules(url, controller: controller)) return true;
    if (widget.site == ExplorerSite.custom) {
      final deny = IsleContentBlockGuard.denyInAppSafariNavigation(url);
      if (deny != null) {
        unawaited(_redirectInAppSafariDenied(
          deny,
          controller: controller,
          blockedUrl: url,
        ));
        return true;
      }
      return false;
    }
    if (_applyBlockedUrlPolicy(url, controller: controller)) return true;
    if (_applyScheduleWebBlockUrl(url, controller: controller)) return true;
    return _applyWebsiteBlockUrl(url, controller: controller);
  }

  bool _applyMoaFourVpnRules(String url, {WebViewController? controller}) {
    if (!MoaFourVpnRulesService.enabled ||
        !(MoaFourVpnRulesService.current()?.blocksUrl(url) ?? false)) {
      return false;
    }
    unawaited(_redirectInAppSafariDenied(
      MoaStrings.of(context).t('four_vpn_safari_blocked'),
      controller: controller,
      blockedUrl: url,
    ));
    return true;
  }

  /// 지금 활성 중인 스케줄 중 「설정 잠금」이 실제로 걸려 있는(해제 대기·편집
  /// 창이 아니라 완전히 잠긴) 것이 있는지 — 있으면 "15분만 허용" 같은 임시
  /// 우회를 안 보여준다. 잠금의 목적 자체가 "쉽게 못 풀게"인데, 차단 시트에서
  /// 우회 버튼을 그냥 눌러버릴 수 있으면 잠금이 무의미해지는 문제
  /// (2026-07-10 제보 "의도치 않은 우회").
  bool _anyActiveScheduleLocked() {
    return ScheduleActiveService.activeSchedulesNow().any(
      (s) => ScheduleLockService.phase(s) == ScheduleLockPhase.locked,
    );
  }

  /// custom Safe Browser — 차단 시트 + 임시 허용. true면 네비게이션 처리 완료.
  Future<bool> _handleSafeBrowserBlockNavigation(
    String url,
    String message, {
    WebViewController? controller,
  }) async {
    if (widget.site != ExplorerSite.custom || !mounted) return false;
    await SafeBrowserHistoryStore.recordBlocked(url, message);
    if (!mounted) return true;
    final host = Uri.tryParse(url)?.host;
    final allowBypass = !_anyActiveScheduleLocked();
    final action = await showSafeBrowserBlockSheet(
      context,
      url: url,
      message: message,
      domainLabel: host,
      allowTemporaryBypass: allowBypass,
    );
    final c = controller ?? _controller;
    if (allowBypass && action == SafeBrowserBlockAction.allow15m) {
      if (host != null) {
        await SafeBrowserTemporaryAllowStore.grantHost(
          host,
          const Duration(minutes: 15),
        );
      }
      if (c != null) await c.loadRequest(Uri.parse(url));
      if (mounted) setState(() => _currentUrl = url);
      return true;
    }
    if (allowBypass && action == SafeBrowserBlockAction.allowToday) {
      if (host != null) {
        await SafeBrowserTemporaryAllowStore.grantUntilEndOfDay(host);
      }
      if (c != null) await c.loadRequest(Uri.parse(url));
      if (mounted) setState(() => _currentUrl = url);
      return true;
    }
    if (c != null) {
      const back = SafariWebConfig.homeUrl;
      await c.loadRequest(Uri.parse(back));
      if (mounted) setState(() => _currentUrl = back);
    }
    return true;
  }

  Future<void> _redirectInAppSafariDenied(
    String message, {
    WebViewController? controller,
    String? blockedUrl,
  }) async {
    final url = blockedUrl ?? _currentUrl;
    if (widget.site == ExplorerSite.custom &&
        await _handleSafeBrowserBlockNavigation(
          url,
          message,
          controller: controller,
        )) {
      _syncWatchTimer();
      return;
    }
    if (!mounted) return;
    _showBlockSnack(message, url: url);
    final c = controller ?? _controller;
    if (c == null) return;
    const back = SafariWebConfig.homeUrl;
    await c.loadRequest(Uri.parse(back));
    if (mounted && identical(c, _controller)) {
      setState(() => _currentUrl = back);
    }
    _syncWatchTimer();
  }

  bool _applyScheduleWebBlockUrl(String url, {WebViewController? controller}) {
    if (!IsleBlockBoundary.appliesScheduleDomainShield(widget.site, url: url)) {
      return false;
    }
    final hit = ScheduleWebBlockGuard.matchUrl(url);
    if (hit == null) return false;
    unawaited(_redirectScheduleWebBlocked(
      hit,
      controller: controller,
      blockedUrl: url,
    ));
    return true;
  }

  Future<void> _redirectScheduleWebBlocked(
    ScheduleWebBlockHit hit, {
    WebViewController? controller,
    String? blockedUrl,
  }) async {
    final url = blockedUrl ?? _currentUrl;
    if (widget.site == ExplorerSite.custom &&
        await _handleSafeBrowserBlockNavigation(
          url,
          hit.snackMessage,
          controller: controller,
        )) {
      return;
    }
    if (!mounted) return;
    _showBlockSnack(hit.snackMessage, url: url);
    final c = controller ?? _controller;
    if (c == null) return;
    final back = widget.site == ExplorerSite.custom
        ? SafariWebConfig.homeUrl
        : widget.site.defaultHomeUrl;
    await c.loadRequest(Uri.parse(back));
  }

  bool _applyContentSafetyUrl(String url, {WebViewController? controller}) {
    if (!ContentSafetyGuard.enabled) return false;
    final hit = ContentSafetyGuard.matchUrl(url);
    if (hit != null) {
      unawaited(_redirectContentUnsafe(hit, controller: controller));
      return true;
    }
    final sanitized = ContentSafetyGuard.sanitizeUrl(url);
    if (sanitized != url) {
      final c = controller ?? _controller;
      if (c != null) unawaited(c.loadRequest(Uri.parse(sanitized)));
      if (mounted) setState(() => _currentUrl = sanitized);
      return true;
    }
    return false;
  }

  bool _applyWebsiteBlockUrl(String url, {WebViewController? controller}) {
    final hit = WebsiteBlockGuard.matchUrl(url);
    if (hit == null) return false;
    unawaited(_redirectWebsiteBlocked(
      hit,
      controller: controller,
      blockedUrl: url,
    ));
    return true;
  }

  Future<void> _redirectWebsiteBlocked(
    WebsiteBlockHit hit, {
    WebViewController? controller,
    String? blockedUrl,
  }) async {
    final url = blockedUrl ?? _currentUrl;
    if (widget.site == ExplorerSite.custom &&
        await _handleSafeBrowserBlockNavigation(
          url,
          hit.snackMessage,
          controller: controller,
        )) {
      return;
    }
    if (!mounted) return;
    _showBlockSnack(hit.snackMessage, url: url);
    final c = controller ?? _controller;
    if (c == null) return;
    final back = widget.site == ExplorerSite.custom
        ? SafariWebConfig.homeUrl
        : widget.site.defaultHomeUrl;
    await c.loadRequest(Uri.parse(back));
    if (mounted) setState(() => _currentUrl = back);
  }

  Future<void> _redirectContentUnsafe(
    ContentSafetyHit hit, {
    WebViewController? controller,
  }) async {
    if (!mounted) return;
    final c = controller ?? _controller;
    if (c == null) return;
    final back = widget.site == ExplorerSite.custom
        ? SafariWebConfig.homeUrl
        : (_isYoutube || _isSafariYoutube
            ? YoutubeWebviewFactory.homeUrl()
            : widget.site.defaultHomeUrl);
    _showBlockSnack(hit.snackMessage, url: _currentUrl);
    IsleAppLogService.log('Content safety block: ${hit.label}');
    await c.loadRequest(Uri.parse(back));
    if (mounted) setState(() => _currentUrl = back);
  }

  String _blockedYoutubeRedirectUrl() {
    if (widget.site == ExplorerSite.custom) {
      final pre = _preWatchBrowseUrl.trim();
      if (pre.isNotEmpty && !YoutubeUrlRedirect.isYoutubeUrl(pre)) return pre;
      if (!YoutubeUrlRedirect.isYoutubeUrl(_currentUrl)) return _currentUrl;
      return SafariWebConfig.homeUrl;
    }
    return _preWatchBrowseUrl.isNotEmpty &&
            YoutubeNavPolicy.hostIsYoutube(_preWatchBrowseUrl) &&
            !YoutubeNavPolicy.isWatchUrl(_preWatchBrowseUrl)
        ? _preWatchBrowseUrl
        : YoutubeWebviewFactory.homeUrl();
  }

  Future<void> _redirectBlockedYoutubeOn(
    WebViewController? c,
    YoutubeBlockHit hit, {
    bool updateCurrentUrl = false,
  }) async {
    if (!mounted || c == null) return;
    // 재생 즉시 차단 — loadRequest 완료 전 풀스크린 연타 등으로 우회 방지
    await YoutubeWebviewEnergy.setPlaybackBlocked(c, true);
    final back = _blockedYoutubeRedirectUrl();
    _showBlockSnack(hit.snackMessage, url: _currentUrl);
    IsleAppLogService.log(
        'YouTube block redirect: ${hit.kind.name} ${hit.label}');
    await c.loadRequest(Uri.parse(back));
    if (mounted && updateCurrentUrl) setState(() => _currentUrl = back);
    if (mounted && !updateCurrentUrl) setState(() => _browseCurrentUrl = back);
    // 리다이렉트 완료 후 가드 상태를 시간 한도 기준으로 재동기화
    if (!YoutubeAccessGuard.shouldBlockWebView) {
      await YoutubeWebviewEnergy.setPlaybackBlocked(c, false);
    }
  }

  DateTime? _lastEmbedBlockAt;
  String? _lastEmbedBlockKey;

  Future<void> _enforceBlockedEmbed(YoutubeBlockHit hit) async {
    if (!mounted) return;
    // 같은 임베드가 sweep 주기(0.9~2.2s)마다 반복 감지돼도 스낵바는 한 번만 —
    // 그렇지 않으면 페이지에 남아있는 미리보기 영상 하나 때문에 알림이 안
    // 사라지는 것처럼 계속 다시 뜬다.
    final key = '${hit.kind.name}:${hit.label}';
    final now = DateTime.now();
    final isRepeat = _lastEmbedBlockKey == key &&
        _lastEmbedBlockAt != null &&
        now.difference(_lastEmbedBlockAt!) < const Duration(seconds: 8);
    _lastEmbedBlockKey = key;
    _lastEmbedBlockAt = now;
    if (!isRepeat) {
      _showBlockSnack(hit.snackMessage, url: _currentUrl);
      IsleAppLogService.log(
          'YouTube embed block: ${hit.kind.name} ${hit.label}');
    }
    setState(() => _embeddedYoutubeActive = false);
    _syncWatchTimer();
    await _injectBlocks();
    _applyPlaybackBlock(YoutubeAccessGuard.shouldBlockWebView);
  }

  void _wireEmbedSurfaceChannel(WebViewController controller) {
    if (widget.site != ExplorerSite.custom) return;
    if (_embedSurfaceChannelWired.contains(controller)) return;
    _embedSurfaceChannelWired.add(controller);
    controller.addJavaScriptChannel(
      'IsleEmbedSurface',
      onMessageReceived: (m) => _onEmbedSurfaceMessage(m.message),
    );
  }

  void _onEmbedSurfaceMessage(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final type = j['type'] as String? ?? '';
      if (type == 'blocked' || type == 'blockedNav') {
        final href = j['href'] as String? ?? _currentUrl;
        final hit = _matchYoutubeBlock(href) ??
            YoutubeBlockHit(
              kind: YoutubeBlockKind.channel,
              label: j['channelName'] as String? ?? '차단',
            );
        unawaited(_enforceBlockedEmbed(hit));
        return;
      }
      if (type == 'heartbeat') {
        final playing = j['playing'] == true;
        if (playing) {
          final ch = YoutubePageChannel.fromJson(j);
          final hit = _matchYoutubeBlock(_currentUrl, probe: ch);
          if (hit != null) {
            unawaited(_enforceBlockedEmbed(hit));
            return;
          }
          if (ch.videoId.length == 11) {
            unawaited(YoutubeWatchHistoryService.attachChannelInfo(
              videoId: ch.videoId,
              channelId: ch.channelId,
              channelName: ch.channelName,
              videoTitle: ch.videoTitle,
            ));
          }
        }
        if (playing != _embeddedYoutubeActive) {
          setState(() => _embeddedYoutubeActive = playing);
          _syncWatchTimer();
          if (playing) {
            _applyPlaybackBlock(YoutubeAccessGuard.shouldBlockWebView);
          }
        }
      }
    } catch (_) {}
  }

  void _clearYoutubeBrowseLoading() {
    if (!mounted || !_isYoutube) return;
    _loadingFailsafe?.cancel();
    _playbackGuard.cancelRecovery();
    setState(() {
      _loading = false;
      if (_recovery.showOverlay || _recovery.showRecoveringOverlay) {
        _recovery = const IslePlaybackRecoveryState.idle();
      }
    });
  }

  /// 시청·검색 중 — Isle 크롬·배너 최소화
  bool get _youtubeImmersive =>
      _isYoutube &&
      (_isWatchPage ||
          _youtubeSearchUiActive ||
          _isYoutubeSearchUrl(_currentUrl));

  bool _isYoutubeLoginUrl(String url) =>
      GoogleAuthPathPolicy.isAuthFlowUrl(url);

  bool get _shouldOfferYoutubeLoginChip =>
      _isYoutube &&
      !IsleUserDefaults.youtubeWebLoginRemembered &&
      !IsleUserDefaults.youtubeLoginChipDismissed &&
      !_isYoutubeLoginUrl(_currentUrl) &&
      !_pendingYoutubeLogin;

  bool get _showYoutubeQuickBlockBar =>
      _isYoutube &&
      !_showLoginBanner &&
      !_youtubeQuickBarDismissed &&
      !_youtubeInlineMini &&
      !_currentUrl.contains('accounts.google.com') &&
      !_probed.isEmpty &&
      (YoutubeNavPolicy.isChannelUrl(_currentUrl) || _isWatchPage);
  bool get _useDarkChrome => IsleUserDefaults.explorerChromeDark;

  void _showBlockSnack(String message, {String? url}) {
    if (!mounted) return;
    showIsleBlockSnackBar(
      context,
      message: message,
      site: widget.site,
      url: url ?? _currentUrl,
      inAppExplorer: true,
    );
  }

  Color get _chromeBg =>
      _useDarkChrome ? const Color(0xFF0F0F0F) : Colors.white;
  Color get _chromeFg => _useDarkChrome ? Colors.white : IsleColors.ocean900;
  Color get _chromeMuted => _useDarkChrome ? Colors.white70 : IsleColors.muted;

  SystemUiOverlayStyle get _overlayStyle => _useDarkChrome
      ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
      : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(MoaFourVpnRulesService.refresh());
    _openedAt = DateTime.now();
    _playbackGuard = IslePlaybackGuard(
      onUrlChanged: _handleUrlChanged,
      onPageReady: _onPageReady,
      onRecoveryState: (s) {
        if (mounted) setState(() => _recovery = s);
      },
      // YouTube 재생 오류의 실제 원인 — 예전 버전이 남긴 OS web content 차단을 복구 시 해제.
      onClearOsBlock: _isYoutube
          ? () => IosScreenTimeService.ensureIsleYoutubeWebViewUnblocked()
          : null,
    );
    _currentUrl = _resolveStartUrl();
    _entryDenyMessage = ExplorerEntryGuard.denyMessageForSite(
      widget.site,
      url: _currentUrl,
    );
    _entryBlocked = _entryDenyMessage != null;
    _chromeVisible = !_isYoutube;
    _showLoginBanner = (_shouldOfferYoutubeLoginChip && !widget.autoLogin) ||
        (_isBrunch &&
            widget.brunchPromptLogin &&
            !IsleUserDefaults.brunchLoginRemembered) ||
        (_isInstagram &&
            !IsleUserDefaults.instagramLoginRemembered &&
            !IsleUserDefaults.instagramLoginChipDismissed);
    if (widget.autoLogin && _isYoutube) _pendingYoutubeLogin = true;
    if (!_entryBlocked && _isYoutube) {
      final restored = YoutubeSession.instance.takeControllerForRoute();
      if (restored != null) {
        _controller = restored;
        _currentUrl = YoutubeSession.instance.currentUrl;
        _probed = YoutubeSession.instance.probed;
        _attachRestoredYoutubeController(restored);
        YoutubeWebviewEnergy.register(restored);
        _loading = false;
        unawaited(_reapplyYoutubeBlocks());
        final restoredHit = _matchYoutubeBlock(
          YoutubeSession.instance.currentUrl,
          probe: YoutubeSession.instance.probed,
        );
        if (restoredHit != null) {
          unawaited(_redirectBlockedYoutube(restoredHit));
        } else {
          _scheduleWatchPageBlockCheck();
        }
      } else {
        _initWebView();
      }
    } else if (!_entryBlocked) {
      _initTabbedBrowser();
    }
    if (!_entryBlocked) {
      _syncWatchTimer();
    }
    if (!_entryBlocked && (_isYoutube || widget.site == ExplorerSite.custom)) {
      YoutubeBlockReapplyHub.register(_reapplyYoutubeBlocks);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  String _resolveStartUrl() {
    if (widget.autoLogin && _isYoutube) {
      return YoutubeWebviewFactory.signInUrl();
    }
    if (_isInstagram && widget.instagramDmOnly) {
      return 'https://www.instagram.com/direct/inbox/';
    }
    final u = widget.initialUrl?.trim();
    if (u != null && u.isNotEmpty && u.startsWith('http')) {
      if (widget.site == ExplorerSite.custom) {
        if (IsleContentBlockGuard.denyInAppSafariNavigation(u) != null ||
            ContentSafetyGuard.matchUrl(u) != null) {
          return SafariWebConfig.homeUrl;
        }
        return ContentSafetyGuard.sanitizeUrl(u);
      }
      if (ContentSafetyGuard.matchUrl(u) != null ||
          WebsiteBlockGuard.matchUrl(u) != null) {
        return widget.site.defaultHomeUrl;
      }
      return ContentSafetyGuard.sanitizeUrl(u);
    }
    return widget.site.defaultHomeUrl;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    SystemChrome.setSystemUIOverlayStyle(_overlayStyle);
  }

  String? _isleTargetIdForSite() {
    if (_isYoutube ||
        _isSafariYoutube ||
        (widget.site == ExplorerSite.custom && _embeddedYoutubeActive)) {
      return 'isle_youtube';
    }
    if (_isInstagram) {
      return widget.instagramDmOnly ? 'isle_instagram_dm' : 'isle_instagram';
    }
    if (_isBrunch) return 'isle_brunch';
    if (widget.site == ExplorerSite.custom) {
      return switch (InAppSafariHostResolver.hostForUrl(_currentUrl)) {
        InAppSafariHost.youtube => 'isle_youtube',
        InAppSafariHost.instagram => 'isle_instagram',
        InAppSafariHost.brunch => 'isle_brunch',
        _ => null,
      };
    }
    return null;
  }

  void _syncWatchTimer() {
    if (_watchPlatform != null) {
      if (_watchTick == null) {
        unawaited(ScheduleAppTargetsStore.ensureOpen());
        unawaited(ScheduleBundleUsageStore.ensureOpen());
        _startWatchTimer();
      }
    } else {
      _watchTick?.cancel();
      _watchTick = null;
      _flushWatchCounters();
    }
  }

  void _startWatchTimer() {
    _watchTick?.cancel();
    _watchTick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_onWatchTick()),
    );
  }

  Future<void> _onWatchTick() async {
    if (_watchTickBusy) return;
    _watchTickBusy = true;
    try {
      if (!mounted || !_appActive) {
        _lastWatchTickCreditAt = null;
        return;
      }
      if (_isInstagram && _isInstagramAuthFlow) {
        _lastWatchTickCreditAt = null;
        return;
      }
      if (_isYoutubeGoogleAuthFlow) {
        _lastWatchTickCreditAt = null;
        return;
      }
      final platform = _watchPlatform;
      if (platform == null) {
        _lastWatchTickCreditAt = null;
        return;
      }
      if (platform == PlatformWatchId.youtube) {
        final tickStartedAt = DateTime.now();
        final canCountUsage = YoutubeAccessGuard.shouldCountWatchTime;
        final isBlocked = YoutubeAccessGuard.shouldBlockWebView;
        _applyPlaybackBlock(isBlocked);
        final embeddedPlayback =
            widget.site == ExplorerSite.custom && _embeddedYoutubeActive;
        final playbackSurface = _isWatchPage || embeddedPlayback;
        bool? playing;
        if (IsleUserDefaults.trackYoutubeWatchHistory &&
            playbackSurface &&
            !isBlocked) {
          playing = await _isYoutubeVideoActivelyPlayingForLimit();
          if (!mounted || !_appActive) {
            _lastYoutubeHistoryTickAt = null;
            _lastWatchTickCreditAt = null;
            await YoutubeWatchHistoryService.flushPending();
            return;
          }
          if (playing) {
            final videoId = _probed.videoId.length == 11
                ? _probed.videoId
                : UrlParser.extractYouTubeVideoId(_currentUrl);
            if (videoId != null) {
              final seconds = watchTickCreditSeconds(
                lastCreditAt: _lastYoutubeHistoryTickAt,
                now: tickStartedAt,
              );
              _lastYoutubeHistoryTickAt = tickStartedAt;
              await YoutubeWatchHistoryService.recordPlaybackTick(
                videoId: videoId,
                url: 'https://www.youtube.com/watch?v=$videoId',
                seconds: seconds,
                channelId: _probed.channelId,
                channelName: _probed.channelName,
                title: _probed.videoTitle,
              );
            }
          } else {
            _lastYoutubeHistoryTickAt = null;
            await YoutubeWatchHistoryService.flushPending();
          }
        } else {
          _lastYoutubeHistoryTickAt = null;
          await YoutubeWatchHistoryService.flushPending();
        }
        if (!_shouldCountYoutubeUsageSeconds) {
          _lastWatchTickCreditAt = null;
          _notifyWatchUi();
          return;
        }
        if (!canCountUsage) {
          _lastWatchTickCreditAt = null;
          _notifyWatchUi();
          return;
        }
        // 이 호출은 WebView JS 브릿지 왕복(runJavaScriptReturningResult)이라
        // 유튜브 페이지가 무겁거나(광고·버퍼링) 기기가 느리면 1초 tick보다
        // 오래 걸릴 수 있다. 그러면 그 사이 Timer.periodic이 다시 발화해도
        // 위 재진입 가드(_watchTickBusy)에 막혀 스킵되는데, 예전에는 완료된
        // tick마다 무조건 "+1초"만 적립해서 스킵된 시간이 그대로 유실됐다
        // (2026-07-20 제보 "재생 시간을 제대로 못 잡는다"의 원인). 이제는
        // 마지막 적립 시각부터 실제 경과한 시간을 되돌려 적립한다.
        playing ??= await _isYoutubeVideoActivelyPlayingForLimit();
        if (!mounted || !_appActive) {
          _lastWatchTickCreditAt = null;
          return;
        }
        if (!playing) {
          _lastWatchTickCreditAt = null;
          _notifyWatchUi();
          return;
        }
        final creditSeconds = watchTickCreditSeconds(
          lastCreditAt: _lastWatchTickCreditAt,
          now: tickStartedAt,
        );
        _lastWatchTickCreditAt = tickStartedAt;
        _recordScheduleBundleUsageSecond(creditSeconds);
        _recordUsageStatSecond(platform, creditSeconds);
        _recordWatchLimitSecond(platform, creditSeconds);
      } else if (!PlatformWatchLimitStore.isLimitReached(platform)) {
        _applyPlaybackBlock(false);
        _recordScheduleBundleUsageSecond();
        _recordUsageStatSecond(platform);
        _recordWatchLimitSecond(platform);
      } else {
        // 인스타·브런치 한도 도달: 릴스 등 자동재생 영상도 동일 가드로 정지
        _applyPlaybackBlock(true);
      }
      _notifyWatchUi();
    } finally {
      _watchTickBusy = false;
    }
  }

  Future<bool> _isYoutubeVideoActivelyPlayingForLimit() async {
    if (!_appActive) return false;
    if (_isSafariYoutube || _isYoutube) {
      if (!_isWatchPage) return false;
      return YoutubeWebviewEnergy.isVideoActivelyPlaying(_controller);
    }
    if (widget.site == ExplorerSite.custom && _embeddedYoutubeActive) {
      return _embeddedYoutubeActive;
    }
    return false;
  }

  /// 상주 재생 가드 토글. 상태가 바뀔 때만 JS 호출하되, 잠금(true)일 때는 매번
  /// 호출해 전체 리로드(가드 소실) 후에도 1초 내 재설치되도록 한다.
  bool? _playbackBlocked;
  void _applyPlaybackBlock(bool blocked) {
    // 이미 해제 상태면 매 tick(1초)마다 JS eval을 또 던지지 않는다 — 주석의
    // "상태가 바뀔 때만 JS 호출" 의도와 달리 여기서 무조건 재호출하던 게
    // 인스타 브라우징 중 체감 렉 원인 중 하나였음(Cage 쪽 동일 버그 07-07 진단,
    // 같은 코드가 복붙돼 있어 여기도 포팅).
    if (!blocked && _playbackBlocked == false) return;
    _playbackBlocked = blocked;
    unawaited(YoutubeWebviewEnergy.setPlaybackBlocked(_controller, blocked));
    final browse = _browseController;
    if (browse != null) {
      unawaited(YoutubeWebviewEnergy.setPlaybackBlocked(browse, blocked));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _appActive = false;
      _lastYoutubeHistoryTickAt = null;
      unawaited(YoutubeWatchHistoryService.flushPending());
      _flushWatchCounters();
      YoutubeWebviewEnergy.pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      _appActive = true;
      unawaited(MoaFourVpnRulesService.refresh());
      unawaited(YoutubeWebviewEnergy.resumeAll());
      _playbackGuard.reset();
      if (mounted) {
        setState(() => _recovery = const IslePlaybackRecoveryState.idle());
      }
      if (_isYoutube && mounted) {
        unawaited(_maybeOfferClipboardActions());
      }
      if (_pendingSafariPasskeySync) {
        unawaited(_finishSafariPasskeySync());
      }
    }
  }

  Future<void> _openPasskeyLoginInSafari(
      {String? url, required bool youtube}) async {
    if (!PasskeyLoginService.canOfferSafariPasskey(youtube: youtube)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                PasskeyLoginService.passkeyDeniedMessage(youtube: youtube)),
          ),
        );
      }
      return;
    }
    final loginUrl =
        url?.isNotEmpty == true ? url! : InstagramWebConfig.loginUrl;
    _pendingSafariPasskeySync = true;
    _safariPasskeyReturnUrl = widget.instagramDmOnly
        ? InstagramWebConfig.dmInboxUrl
        : InstagramWebConfig.homeUrl;
    final ok = await IsleExternalLaunchGuard.launchAllowed(
      loginUrl,
      mode: LaunchMode.inAppBrowserView,
      context: context,
    );
    if (!ok) {
      _pendingSafariPasskeySync = false;
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(PlatformBlockCopy.passkeyLoginSnackMessage()),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _finishSafariPasskeySync() async {
    if (!_pendingSafariPasskeySync) return;
    _pendingSafariPasskeySync = false;
    final n = await WebSessionCookieBridge.syncSafariCookiesToWebView();
    IsleWebSessionPersistenceService.scheduleSave();
    await IsleUserDefaults.setInstagramLoginRemembered(true);
    await IsleUserDefaults.setInstagramLoginChipDismissed(true);
    final c = _controller;
    if (c != null && mounted) {
      setState(() {
        _showLoginBanner = false;
        _loading = true;
      });
      await c.loadRequest(Uri.parse(_safariPasskeyReturnUrl));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n > 0
              ? '패스키 로그인 세션을 WebView에 연결했어요'
              : '쿠키 연결이 비어 있어요. ${PlatformBlockCopy.externalPasskeyBrowserName}에서 로그인했는지 확인해 주세요',
        ),
      ),
    );
  }

  void _maybeInterceptPasskeyNavigation(String url) {
    if (!PasskeyLoginService.shouldInterceptInWebView(url)) return;
    if (_isYoutube) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PasskeyLoginService.passkeyDeniedMessage(youtube: true),
          ),
        ),
      );
      return;
    }
    final now = DateTime.now();
    if (_passkeyInterceptAt != null &&
        now.difference(_passkeyInterceptAt!) < const Duration(seconds: 20)) {
      return;
    }
    _passkeyInterceptAt = now;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final useSafari = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('패스키 로그인', style: IsleText.subtitle()),
          content: Text(
            '앱 WebView에서는 패스키가 지원되지 않아요.\n'
            '${PlatformBlockCopy.passkeyLoginDialogMessage()}',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(PlatformBlockCopy.passkeyLoginButtonLabel())),
          ],
        ),
      );
      if (useSafari == true && mounted) {
        await _openPasskeyLoginInSafari(url: url, youtube: _isYoutube);
      }
    });
  }

  void _wirePasskeyProbe(WebViewController controller) {
    final key = identityHashCode(controller);
    if (_passkeyProbeWired.contains(key)) return;
    _passkeyProbeWired.add(key);
    controller.addJavaScriptChannel(
      PasskeyWebProbeScript.channelName,
      onMessageReceived: (m) => _onPasskeyProbe(m.message),
    );
  }

  void _onPasskeyProbe(String msg) {
    if (msg == 'available' || !mounted) return;
    if (_isYoutube) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PasskeyLoginService.passkeyDeniedMessage(youtube: true),
          ),
        ),
      );
      return;
    }
    final now = DateTime.now();
    if (_passkeyInterceptAt != null &&
        now.difference(_passkeyInterceptAt!) < const Duration(seconds: 30)) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'WebView에서는 패스키가 안 돼요 · ${PlatformBlockCopy.externalPasskeyBrowserName}로 로그인하세요'),
        action: SnackBarAction(
          label: PlatformBlockCopy.externalPasskeyBrowserName,
          onPressed: () => unawaited(
            _openPasskeyLoginInSafari(
              url: _currentUrl,
              youtube: _isYoutube,
            ),
          ),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _injectPasskeyProbeIfNeeded([WebViewController? target]) async {
    final c = target ?? _controller;
    if (c == null ||
        !PasskeyLoginService.shouldProbePasskeyOnPage(_currentUrl)) {
      return;
    }
    _wirePasskeyProbe(c);
    await c.runJavaScript(PasskeyWebProbeScript.install);
  }

  Future<void> _maybeMarkInstagramLoggedIn() async {
    if (!WebSessionCookieBridge.supported) return;
    final cookies = await WebSessionCookieBridge.exportCookies();
    final loggedIn = cookies.any((c) {
      final name = (c['name'] as String? ?? '').toUpperCase();
      final domain = (c['domain'] as String? ?? '').toLowerCase();
      return domain.contains('instagram') &&
          (name == 'SESSIONID' || name == 'DS_USER_ID');
    });
    if (!loggedIn || !mounted) return;
    await IsleUserDefaults.setInstagramLoginRemembered(true);
    IsleWebSessionPersistenceService.scheduleSave();
    _maybeCaptureInstagramHandle(_currentUrl);
    if (mounted) setState(() => _showLoginBanner = false);
  }

  void _bindYoutubeSessionHandlers() {
    final session = YoutubeSession.instance;
    session.onUrlChanged = _handleUrlChanged;
    session.onPageReady = () {
      if (mounted) _onPageReady();
    };
    session.onChannelProbe = _onChannelProbeMessage;
  }

  void _handleUrlChanged(String url) {
    if (!mounted) return;
    setState(() {
      _currentUrl = url;
      _youtubeQuickBarDismissed = false;
      if (_isYoutube) {
        final isLoginPage = _isYoutubeLoginUrl(url);
        if (isLoginPage) {
          // Google 로그인·2FA — 오버레이·차단 스크립트 없이 폼만 표시
          _showLoginBanner = false;
          _chromeVisible = true;
          _youtubeSearchUiActive = false;
          _loading = false;
        } else if (url.contains('youtube.com')) {
          if (_pendingYoutubeLogin) {
            _pendingYoutubeLogin = false;
            unawaited(IsleUserDefaults.setYoutubeWebLoginRemembered(true));
            IsleWebSessionPersistenceService.scheduleSave();
            _showLoginBanner = false;
          } else if (IsleUserDefaults.youtubeWebLoginRemembered ||
              IsleUserDefaults.youtubeLoginChipDismissed) {
            _showLoginBanner = false;
          } else {
            _showLoginBanner = _shouldOfferYoutubeLoginChip;
          }
          if (_isWatchPage ||
              _isYoutubeSearchUrl(url) ||
              _youtubeSearchUiActive) {
            _chromeVisible = false;
          }
        }
      }
      if (_isBrunch &&
          url.contains('brunch.co.kr') &&
          !url.contains('/login')) {
        IsleUserDefaults.setBrunchLoginRemembered(true);
        _showLoginBanner = false;
      }
      if (_isInstagram) {
        final igPath = Uri.tryParse(url)?.path.toLowerCase() ?? '';
        if (InstagramAuthPathPolicy.isAuthFlowPath(igPath)) {
          _showLoginBanner = false;
        } else if (url.contains('instagram.com')) {
          unawaited(_maybeMarkInstagramLoggedIn());
        }
      }
    });
    if (_isYoutubeGoogleAuthFlow) {
      _clearGoogleAuthLoading();
    }
    _maybeInterceptPasskeyNavigation(url);
    // YouTube Music → 영상 한도 대신 음성 모드
    if (YoutubeMusicRoute.isMusicHost(url)) {
      final route = YoutubeMusicRoute.podcastRouteFor(url);
      if (route != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('YouTube Music은 Isle 음성 모드로 열어요 (영상 한도와 별도)'),
          ),
        );
        context.push(route);
      }
      return;
    }
    // 안전 모드: 성인 도메인 차단 + 구글/Bing/DDG SafeSearch
    if (_applyUrlPolicy(url)) return;
    _syncWatchTimer();
    if (widget.site == ExplorerSite.custom && url.startsWith('http')) {
      unawaited(SafeBrowserHistoryStore.recordOpened(url));
    }
    if (widget.site == ExplorerSite.custom) {
      if (!YoutubeUrlRedirect.isYoutubeUrl(url)) {
        _preWatchBrowseUrl = url;
        if (SafariWebConfig.isGoogleSearchUrl(url)) {
          final c = _controller;
          if (c != null) unawaited(_injectSearchBlockEarly(c, url));
        }
        unawaited(_injectBlocks());
      }
    }
    if (_isSafariYoutube) {
      unawaited(_injectBlocks());
    }
    if (_isInstagram) {
      _trackInstagramDmUrl(url);
      final _igPath = Uri.tryParse(url)?.path.toLowerCase() ?? '';
      if (_isInstagramMediaPath(_igPath)) {
        if (mounted) {
          setState(() {
            _chromeVisible = false;
            _instagramMediaViewerOpen = true;
          });
        }
        unawaited(_saveInstagramDmScroll());
        final c = _controller;
        if (c != null && _shouldInjectInstagramComments(_igPath)) {
          unawaited(c.runJavaScript(InstagramPostCommentsScript.install));
        }
      } else if (_isInstagramDmThreadPath(_igPath)) {
        if (mounted) {
          setState(() {
            _chromeVisible = false;
            _instagramMediaViewerOpen = false;
            _instagramSoundHint = false;
          });
        }
      } else if (widget.instagramDmOnly &&
          !InstagramAuthPathPolicy.isAuthFlowPath(_igPath) &&
          !_instagramDmFocusAllowsPath(_igPath)) {
        if (_lastInstagramDmDenialPath != _igPath) {
          _lastInstagramDmDenialPath = _igPath;
          IsleAppLogService.log(
            'Instagram DM denial: blocked path=$_igPath url=$url → inbox',
            level: IsleLogLevel.warn,
          );
        }
        if (mounted) setState(() => _loading = false);
        if (mounted && _controller != null) {
          unawaited(_controller!
              .loadRequest(Uri.parse(InstagramWebConfig.dmInboxUrl)));
        }
        return;
      } else {
        _lastInstagramDmDenialPath = null;
        if (mounted) {
          setState(() {
            _instagramMediaViewerOpen = false;
            _instagramSoundHint = false;
            _chromeVisible = true;
          });
        }
      }
    }
    if (widget.site == ExplorerSite.custom &&
        YoutubeUrlRedirect.isYoutubeUrl(url)) {
      final blockHit = _matchYoutubeBlock(url);
      if (blockHit != null) {
        _applyPlaybackBlock(true); // URL 감지 즉시 차단 — redirect 완료 전 우회 방지
        unawaited(_redirectBlockedYoutube(blockHit));
        return;
      }
    }
    if ((_isYoutube || _isSafariYoutube) && url.contains('youtube.com')) {
      final blockHit = _matchYoutubeBlock(url);
      if (blockHit != null) {
        _applyPlaybackBlock(true); // URL 감지 즉시 차단
        unawaited(_redirectBlockedYoutube(blockHit));
        return;
      }
      if (YoutubeNavPolicy.isWatchUrl(url)) {
        final newVid = UrlParser.extractYouTubeVideoId(url);
        if (newVid != null && newVid != _probed.videoId) {
          _probed = const YoutubePageChannel(channelId: '', channelName: '');
          _applyPlaybackBlock(true);
        }
        _scheduleWatchPageBlockCheck();
      }
      if (YoutubeNavPolicy.isBrowseSurface(url) ||
          _isYoutubeSearchUrl(url) ||
          _youtubeSearchUiActive) {
        _clearYoutubeBrowseLoading();
      }
      final onWatch = YoutubeNavPolicy.isWatchUrl(url);
      if (YoutubeNavPolicy.isBrowseSurface(url) &&
          (_recovery.showRecoveringOverlay || _recovery.showOverlay)) {
        _playbackGuard.cancelRecovery();
        if (mounted) {
          setState(() => _recovery = const IslePlaybackRecoveryState.idle());
        }
      }
      if (!onWatch && !_isYoutubeSearchUrl(url)) {
        _preWatchBrowseUrl = url;
      }
      _scheduleContentRefresh();
      if (_youtubeImmersive) unawaited(_applyYoutubeViewportPad());
    } else if (url.contains('brunch.co.kr') ||
        url.contains('blog.naver') ||
        url.contains('velog.io') ||
        url.contains('tistory.com')) {
      _scheduleContentRefresh();
    }
  }

  void _wirePlaybackGuard(WebViewController controller) {
    _playbackGuard.reset();
    Future<void> switchUa() async {
      _useAltUserAgent = !_useAltUserAgent;
      if (_isYoutube) {
        final ua = _useAltUserAgent
            ? kYoutubeAndroidUserAgent
            : kYoutubeSafariUserAgent;
        await controller.setUserAgent(ua);
      } else {
        final ua = _useAltUserAgent
            ? (Platform.isAndroid ? kSafariUserAgent : kAndroidUserAgent)
            : (Platform.isIOS || Platform.isMacOS
                ? kSafariUserAgent
                : kAndroidUserAgent);
        await controller.setUserAgent(ua);
      }
    }

    _playbackGuard.bindDomRecovery(
      reload: () => controller.reload(),
      loadUrl: (url) async {
        if (url.isEmpty) {
          await controller.reload();
        } else {
          await controller.loadRequest(Uri.parse(url));
        }
      },
      loadHome: () => controller.loadRequest(Uri.parse(_resolveStartUrl())),
      openExternal: () async {
        if (!mounted) return;
        await IsleExternalLaunchGuard.launch(context, _currentUrl);
      },
      switchUserAgent: switchUa,
    );
    controller.setNavigationDelegate(
      _playbackGuard.buildDelegate(
        reload: () => controller.reload(),
        loadUrl: (url) async {
          if (url.isEmpty) {
            await controller.reload();
          } else {
            await controller.loadRequest(Uri.parse(url));
          }
        },
        loadHome: () => controller.loadRequest(Uri.parse(_resolveStartUrl())),
        openExternal: () async {
          if (!mounted) return;
          await IsleExternalLaunchGuard.launch(context, _currentUrl);
        },
        switchUserAgent: switchUa,
        onPageStartedExtra: (url) {
          unawaited(_injectSearchBlockEarly(controller, url));
        },
        onLoadProgressExtra: (progress) {
          if (progress <= 25) {
            unawaited(_injectSearchBlockEarly(controller, _currentUrl));
          }
        },
        onNavigationRequest: _isYoutube ? _youtubeNavigationDecision : null,
      ),
    );
  }

  /// 동일 WebViewController에 JS 채널 중복 등록 방지 (최소화→복귀 크래시)
  static final _youtubeJsChannelWired = <int>{};

  void _wireYoutubeJsChannels(WebViewController controller,
      {required bool attachPlayback}) {
    final key = identityHashCode(controller);
    if (_youtubeJsChannelWired.contains(key)) {
      _wirePlaybackGuard(controller);
      return;
    }
    _youtubeJsChannelWired.add(key);
    if (attachPlayback) {
      controller.addJavaScriptChannel(
        YoutubePlaybackErrorProbe.jsChannelName,
        onMessageReceived: (m) => _onPlaybackProbeMessage(m.message),
      );
    }
    controller.addJavaScriptChannel(
      YoutubeSearchUiProbe.jsChannelName,
      onMessageReceived: (m) => _onYoutubeSearchUiMessage(m.message),
    );
    _wirePlaybackGuard(controller);
  }

  void _initWebView() {
    final controller = IsleWebviewFactory.create(
      site: widget.site,
      initialUrl: _currentUrl,
      onUrlChanged:
          _isYoutube ? (url) => _handleUrlChanged(url) : _handleUrlChanged,
      onPageReady: _onPageReady,
      onYoutubeChannelProbe: (_isYoutube || widget.site == ExplorerSite.custom)
          ? _onChannelProbeMessage
          : null,
      onBrunchAuthorProbe: _isBrunch ? _onBrunchAuthorProbe : null,
      onPlaybackProbe: _isYoutube ? _onPlaybackProbeMessage : null,
    );
    if (_isYoutube) {
      _bindYoutubeSessionHandlers();
      YoutubeSession.instance.wireController(controller);
    }
    YoutubeWebviewEnergy.register(controller);
    _controller = controller;
    if (_isYoutube) {
      _wireYoutubeJsChannels(controller, attachPlayback: false);
    } else {
      _wirePlaybackGuard(controller);
      if (widget.site == ExplorerSite.custom) {
        _wireEmbedSurfaceChannel(controller);
      }
    }
  }

  void _initTabbedBrowser() {
    _tabs.clear();
    _activeTabIndex = 0;
    _openNewTab(url: _currentUrl, switchToNew: true);
  }

  Future<void> _openNewTab({String? url, bool switchToNew = true}) async {
    final startUrl =
        (url?.trim().isNotEmpty ?? false) ? url!.trim() : _resolveStartUrl();
    final tab = _createTab(startUrl);
    setState(() {
      _tabs.add(tab);
      if (switchToNew) {
        _activeTabIndex = _tabs.length - 1;
        _controller = tab.controller;
        _currentUrl = tab.url;
        _loading = tab.loading;
      }
    });
  }

  _BrowserTabState _createTab(String startUrl) {
    late final WebViewController controller;
    var tabUrl = startUrl;
    controller = IsleWebviewFactory.create(
      site: widget.site,
      initialUrl: startUrl,
      onUrlChanged: (url) {
        tabUrl = url;
        _handleTabUrlChanged(controller, url);
      },
      onPageStarted: (url) {
        unawaited(_injectSearchBlockEarly(controller, url));
      },
      onLoadProgress: (progress) {
        if (progress <= 25) {
          unawaited(_injectSearchBlockEarly(controller, tabUrl));
        }
      },
      onPageReady: () async {
        if (!mounted) return;
        await _onTabPageReady(controller);
      },
      onYoutubeChannelProbe:
          widget.site == ExplorerSite.custom ? _onChannelProbeMessage : null,
      onNavigationRequest: widget.site == ExplorerSite.custom
          ? (req) => _customSiteNavigationDecision(req, controller: controller)
          : null,
    );
    YoutubeWebviewEnergy.register(controller);
    if (_isInstagram) _wireInstagramJsChannels(controller);
    if (widget.site == ExplorerSite.custom)
      _wireEmbedSurfaceChannel(controller);
    return _BrowserTabState(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      controller: controller,
      url: startUrl,
      loading: true,
    );
  }

  void _handleTabUrlChanged(WebViewController source, String url) {
    final idx = _tabs.indexWhere((t) => identical(t.controller, source));
    if (idx == -1 || !mounted) return;
    setState(() {
      _tabs[idx] = _tabs[idx].copyWith(url: url);
    });
    if (idx != _activeTabIndex) return;
    _handleUrlChanged(url);
    if (_isSafariYoutube &&
        url.contains('youtube.com') &&
        YoutubeNavPolicy.isWatchUrl(url)) {
      unawaited(_probeChannelOn(source));
    }
    if (_isBrunch ||
        url.contains('blog.naver') ||
        url.contains('velog.io') ||
        url.contains('tistory.com')) {
      _scheduleContentRefresh();
    }
  }

  Future<void> _onTabPageReady(WebViewController source) async {
    if (!mounted) return;
    final idx = _tabs.indexWhere((t) => identical(t.controller, source));
    if (_isInstagram) {
      final recovered =
          await InstagramWebErrorRecovery.probeAndRecoverIfNeeded(source);
      if (recovered && mounted) {
        if (mounted) {
          setState(() {
            _showLoginBanner = true;
            if (idx >= 0 && idx < _tabs.length) {
              _tabs[idx] = _tabs[idx]
                  .copyWith(loading: false, url: InstagramWebConfig.loginUrl);
              if (idx == _activeTabIndex) {
                _loading = false;
                _currentUrl = InstagramWebConfig.loginUrl;
              }
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Instagram 세션이 만료됐어요 · 다시 로그인해 주세요'),
            ),
          );
        }
        return;
      }
    }
    if (idx != -1 && mounted) {
      setState(() {
        final tab = _tabs[idx];
        _tabs[idx] = tab.copyWith(loading: false);
        if (idx == _activeTabIndex) {
          _loading = false;
        }
      });
      _clearLoadingSoon();
    }
    unawaited(_injectBlocks(source));
    if (!mounted) return;
    if (_isBrunch) {
      await source.runJavaScript(BrunchAuthorProbeScript.probeAndPost);
    }
    if (_isInstagram) {
      await _restoreInstagramDmScroll(source);
      await _injectPasskeyProbeIfNeeded(source);
    }
    if (idx == -1 || !mounted) return;
    if (idx == _activeTabIndex &&
        _isSafariYoutube &&
        YoutubeNavPolicy.isWatchUrl(_currentUrl)) {
      await _probeChannelOn(source);
    }
    if (idx == _activeTabIndex &&
        _isInstagram &&
        !InstagramAuthPathPolicy.isAuthFlowUrl(_currentUrl)) {
      unawaited(_maybeMarkInstagramLoggedIn());
    }
  }

  void _switchTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    final tab = _tabs[index];
    setState(() {
      _activeTabIndex = index;
      _controller = tab.controller;
      _currentUrl = tab.url;
      _loading = tab.loading;
    });
  }

  void _closeTab(int index) {
    if (_tabs.length <= 1) return;
    if (index < 0 || index >= _tabs.length) return;
    final closing = _tabs[index];
    YoutubeWebviewEnergy.unregister(closing.controller);
    setState(() {
      _tabs.removeAt(index);
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      } else if (index <= _activeTabIndex && _activeTabIndex > 0) {
        _activeTabIndex -= 1;
      }
      final active = _tabs[_activeTabIndex];
      _controller = active.controller;
      _currentUrl = active.url;
      _loading = active.loading;
    });
  }

  Future<void> _showTabSheet() async {
    if (!_supportsTabs || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('새 탭'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_openNewTab(switchToNew: true));
                },
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _tabs.length,
                  itemBuilder: (_, i) {
                    final t = _tabs[i];
                    final host = Uri.tryParse(t.url)?.host ?? t.url;
                    return ListTile(
                      leading: Icon(
                        i == _activeTabIndex
                            ? Icons.radio_button_checked
                            : Icons.tab,
                      ),
                      title: Text(
                        host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _switchTab(i);
                      },
                      trailing: _tabs.length > 1
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => _closeTab(i),
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleBrowserBack() async {
    if (_isInstagram) {
      await _handleInstagramBack();
      return;
    }
    final c = _controller;
    if (c != null && await c.canGoBack()) {
      await c.goBack();
      return;
    }
    if (_tabs.length > 1) {
      _closeTab(_activeTabIndex);
      return;
    }
    if (mounted) context.pop();
  }

  void _exitBrowserToHome() {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    context.go('/home/sns');
  }

  Future<void> _handleInstagramBack() async {
    if (_instagramNavBusy) return;
    _setInstagramNavBusy(true);
    HapticFeedback.selectionClick();
    try {
      await Future<void>.delayed(Duration.zero);
      final c = _controller;
      if (c == null) {
        if (mounted) context.pop();
        return;
      }
      final path = Uri.tryParse(_currentUrl)?.path.toLowerCase() ?? '';
      final onMediaOrProfile = _isInstagramMediaPath(path) ||
          InstagramDmPathPolicy.isProfileOrStoriesPath(path);
      final onDmThread = _isInstagramDmThreadPath(path);
      final overlayOpen = _instagramMediaViewerOpen || onMediaOrProfile;

      // 1) SPA 오버레이(릴스·포스트) — Instagram 자체 닫기·history.back
      if (overlayOpen) {
        final dismissed = await _tryDismissInstagramMediaViewer(c);
        if (dismissed) {
          if (mounted) {
            setState(() {
              _instagramMediaViewerOpen = false;
              _instagramSoundHint = false;
            });
          }
          await Future<void>.delayed(const Duration(milliseconds: 550));
          if (mounted) await _restoreInstagramDmScroll(c);
          return;
        }
      }

      // 2) 명시적 미디어 URL → 저장된 DM 스레드로 복귀
      if (onMediaOrProfile) {
        final saved = await _readSavedInstagramDmThreadUrl(c);
        final returnUrl = _resolveInstagramDmReturnUrl(saved);
        if (returnUrl.isNotEmpty) {
          await c.loadRequest(Uri.parse(returnUrl));
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (mounted) await _restoreInstagramDmScroll(c);
          return;
        }
      }

      // 3) WebView 히스토리
      if (await c.canGoBack()) {
        await c.goBack();
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (mounted) await _restoreInstagramDmScroll(c);
        return;
      }

      // 4) DM 스레드(오버레이 없음) → 받은편지함
      if (onDmThread) {
        await c.loadRequest(Uri.parse(InstagramWebConfig.dmInboxUrl));
        return;
      }

      if (mounted) context.pop();
    } finally {
      _setInstagramNavBusy(false);
    }
  }

  void _attachRestoredYoutubeController(WebViewController controller) {
    _bindYoutubeSessionHandlers();
    YoutubeSession.instance.wireController(controller);
    _wireYoutubeJsChannels(controller, attachPlayback: true);
  }

  void _onYoutubeSearchUiMessage(String raw) {
    if (!_isYoutube || !mounted) return;
    final active = raw.trim() == '1';
    if (active == _youtubeSearchUiActive) return;
    setState(() {
      _youtubeSearchUiActive = active;
      if (active) {
        _chromeVisible = false;
        _loading = false;
      }
    });
    unawaited(_applyYoutubeViewportPad());
  }

  void _scheduleContentRefresh() {
    _injectDebounce?.cancel();
    final isYt = _isYoutube || _isSafariYoutube;
    final browse = isYt && YoutubeNavPolicy.isBrowseSurface(_currentUrl);
    final searchLike =
        browse && (_isYoutubeSearchUrl(_currentUrl) || _youtubeSearchUiActive);
    final debounceMs = searchLike ? 280 : (browse ? 480 : 350);
    _injectDebounce = Timer(Duration(milliseconds: debounceMs), () {
      if (!mounted) return;
      if (isYt) {
        if (_isYoutube) unawaited(_installYoutubeSearchWatcher());
        if (YoutubeNavPolicy.isWatchUrl(_currentUrl)) {
          _injectBlocks();
          _probeChannel();
        } else if (_shouldInjectYoutubeBlocks(_currentUrl)) {
          unawaited(_injectBlocks());
        }
      } else {
        _injectBlocks();
        if (_isBrunch) {
          _probeBrunchAuthor();
        }
      }
    });
  }

  void _onChannelProbeMessage(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['blockedNav'] == true) {
        final href = j['href'] as String? ?? _currentUrl;
        final hit = _matchYoutubeBlock(href) ??
            const YoutubeBlockHit(kind: YoutubeBlockKind.channel, label: '차단');
        _applyPlaybackBlock(true); // JS 내부 차단 감지 즉시 재생 정지
        unawaited(_redirectBlockedYoutube(hit));
        return;
      }
      final ch = YoutubePageChannel.fromJson(j);
      if (_youtubeRulesApply && ch.isWatchPage) {
        final hit = _matchYoutubeBlock(_currentUrl, probe: ch);
        if (hit != null) {
          // 채널·영상·키워드 프로브 감지 즉시 재생 차단 — redirect 전 풀스크린 연타 우회 방지
          _applyPlaybackBlock(true);
          if (widget.site == ExplorerSite.custom &&
              !YoutubeUrlRedirect.isYoutubeUrl(_currentUrl)) {
            unawaited(_enforceBlockedEmbed(hit));
          } else {
            unawaited(_redirectBlockedYoutube(hit));
          }
          return;
        }
      }
      if (mounted && (!ch.isEmpty || ch.isWatchPage))
        setState(() => _probed = ch);
      // 시청 이력 항목에 채널·제목 메타 자동 첨부 (피드 추천에 활용)
      if ((_isYoutube ||
              (widget.site == ExplorerSite.custom && ch.isWatchPage)) &&
          ch.videoId.length == 11) {
        unawaited(IsleUserDefaults.setYoutubeWebLoginRemembered(true));
        IsleWebSessionPersistenceService.scheduleSave();
        unawaited(YoutubeWatchHistoryService.attachChannelInfo(
          videoId: ch.videoId,
          channelId: ch.channelId,
          channelName: ch.channelName,
          videoTitle: ch.videoTitle,
        ));
      }
    } catch (_) {}
  }

  void _onBrunchAuthorProbe(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final h = (j['handle'] as String? ?? '').trim();
      final n = (j['name'] as String? ?? '').trim();
      if (mounted && (h.isNotEmpty || n.isNotEmpty)) {
        setState(() {
          _brunchHandle = h;
          _brunchAuthorName = n;
        });
      }
    } catch (_) {}
  }

  void _onPlaybackProbeMessage(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['type'] == 'playback_error') {
        final snippet = j['snippet'] as String? ?? '';
        unawaited(_playbackGuard.reportPlaybackMessage(snippet));
      }
    } catch (_) {
      unawaited(_playbackGuard.reportPlaybackMessage(raw));
    }
  }

  void _maybeCaptureInstagramHandle(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.contains('instagram.com')) return;
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return;
    final first = parts.first.toLowerCase();
    const skip = {
      'p',
      'reel',
      'reels',
      'stories',
      'explore',
      'accounts',
      'direct'
    };
    if (skip.contains(first)) return;
    unawaited(InstagramFollowingStore.addHandle(first));
  }

  Future<void> _hideYoutubeOpenApp([WebViewController? target]) async {
    final c = target ?? _controller;
    if (c == null || !_isYoutube) return;
    await YoutubeWebviewFactory.hideOpenAppPrompt(c);
  }

  Future<void> _onPageReady() async {
    if (!mounted) return;
    if (_isYoutubeGoogleAuthFlow) {
      setState(() => _loading = false);
      _clearLoadingSoon();
      await _injectPasskeyProbeIfNeeded();
      return;
    }
    // 새 페이지/전체 리로드 직후 상주 재생 가드 즉시 재설치 (잠금 상태면 바로 정지).
    if (_watchPlatform == PlatformWatchId.youtube) {
      _applyPlaybackBlock(YoutubeAccessGuard.shouldBlockWebView);
    }
    final youtubeSearchPage = _isYoutube &&
        (_isYoutubeSearchUrl(_currentUrl) || _youtubeSearchUiActive);
    final youtubeBrowsePage = _isYoutube &&
        YoutubeNavPolicy.isBrowseSurface(_currentUrl) &&
        !_isWatchPage;
    if (mounted) setState(() => _loading = false);
    _clearLoadingSoon();
    if (youtubeSearchPage || youtubeBrowsePage) {
      _clearYoutubeBrowseLoading();
      unawaited(_finishYoutubePageReady(light: true));
      return;
    }
    if (widget.site == ExplorerSite.custom && !_isSafariYoutube) {
      await _injectBlocks();
      if (_watchPlatform == PlatformWatchId.youtube) {
        _applyPlaybackBlock(YoutubeAccessGuard.shouldBlockWebView);
      }
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (_isSafariYoutube) {
      await _injectBlocks();
      if (YoutubeNavPolicy.isWatchUrl(_currentUrl)) await _probeChannel();
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (_isYoutube) {
      await _injectBlocks();
      if (!mounted) return;
      await _finishYoutubePageReady(light: false);
      return;
    }
    await _injectBlocks();
    if (!mounted) return;
    if (_isInstagram) {
      await _restoreInstagramDmScroll();
    }
    if (_isBrunch) await _probeBrunchAuthor();
    if (mounted) setState(() => _loading = false);
    await _injectPasskeyProbeIfNeeded();
    if (_isYoutube && IsleUserDefaults.youtubeWebLoginRemembered) {
      IsleWebSessionPersistenceService.scheduleSave();
    } else if (_isInstagram && IsleUserDefaults.instagramLoginRemembered) {
      IsleWebSessionPersistenceService.scheduleSave();
    }
  }

  Future<void> _finishYoutubePageReady({required bool light}) async {
    if (!mounted) return;
    await _hideYoutubeOpenApp();
    if (!mounted) return;
    await _installYoutubeSearchWatcher();
    if (!mounted) return;
    await _applyYoutubeViewportPad();
    if (!mounted) return;
    if (!light) {
      await _probeChannel();
      if (!mounted) return;
      final c = _controller;
      if (c != null) await YoutubePlaybackErrorProbe.inject(c);
      if (!mounted) return;
      unawaited(_injectBlocks());
      _scheduleClipboardOffer();
      return;
    }
    // 검색·탐색: 결과 DOM이 그려진 뒤 차단 스크립트 — 로드 중 reload/버퍼링 루프 방지
    _injectDebounce?.cancel();
    _injectDebounce = Timer(const Duration(milliseconds: 380), () {
      if (!mounted || !_isYoutube) return;
      if (YoutubeNavPolicy.isWatchUrl(_currentUrl)) return;
      if (!_shouldInjectYoutubeBlocks(_currentUrl)) {
        _clearYoutubeBrowseLoading();
        return;
      }
      unawaited(_injectBlocks());
    });
  }

  Future<void> _applyYoutubeViewportPad() async {
    if (!mounted || !context.mounted) return;
    final c = _controller;
    if (c == null || !_isYoutube) return;
    if (_isYoutubeSearchUrl(_currentUrl) || _youtubeSearchUiActive) return;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return;
    // The Flutter WebView already starts below the camera/chrome area.
    // Extra body padding duplicates that space on both browse and watch pages.
    const top = 0.0;
    const bottom = 0.0;
    if (!mounted) return;
    try {
      await c.runJavaScript(
        YoutubeViewportScript.applyPadding(topPx: top, bottomPx: bottom),
      );
    } catch (e, st) {
      IsleAppLogService.log(
        'youtube viewport pad skipped: $e',
        level: IsleLogLevel.debug,
        stack: st,
      );
    }
  }

  Future<void> _installYoutubeSearchWatcher() async {
    final c = _controller;
    if (c == null || !_isYoutube) return;
    if (!mounted) return;
    try {
      await c.runJavaScript(YoutubeSearchUiProbe.installWatcher);
    } catch (e, st) {
      IsleAppLogService.log(
        'youtube search watcher skipped: $e',
        level: IsleLogLevel.debug,
        stack: st,
      );
    }
  }

  Future<void> _injectSearchBlockEarly(
    WebViewController controller,
    String url,
  ) async {
    if (!mounted || widget.site != ExplorerSite.custom) return;
    final userKeywords = ref.read(blockedKeywordsProvider);
    final rawKeywords = ContentSafetyGuard.enabled
        ? {
            ...userKeywords,
            ...ContentSafetyGuard.builtInYoutubeKeywords,
            ...ContentSafetyGuard.builtInAdultSearchKeywords, // 이미지 검색 필터 포함
          }.toList()
        : userKeywords;
    final googleSurfaceUrls =
        BlockedUrlGuard.googleSurfaceJsUrls(ref.read(blockedUrlsProvider));
    if (!SearchBlockEarlyInject.shouldInject(
      url,
      keywords: rawKeywords,
      urls: googleSurfaceUrls,
    )) {
      return;
    }
    _extendLoadOverlayForSearchCloak();
    await SearchBlockEarlyInject.inject(
      controller,
      url,
      keywords: rawKeywords,
      urls: googleSurfaceUrls,
    );
  }

  Future<void> _injectBlocks([WebViewController? target]) async {
    if (!mounted) return;
    final c = target ?? _controller;
    if (c == null) return;
    final youtubeChannels = BlockKeywordPolicy.capYoutubeChannels(
      ref.read(blockedChannelsProvider),
    );
    final blockedVideoIds =
        ref.read(blockedVideosProvider).map((e) => e.videoId).toList();
    final userKeywords = ref.read(blockedKeywordsProvider);
    final rawKeywords = ContentSafetyGuard.enabled
        ? {
            ...userKeywords,
            ...ContentSafetyGuard.builtInYoutubeKeywords,
            ...ContentSafetyGuard.builtInAdultSearchKeywords, // 구글 이미지 필터 포함
          }.toList()
        : userKeywords;
    final blockedKeywords = BlockKeywordPolicy.forYoutubeInject(rawKeywords);
    final urlEntries = ref.read(blockedUrlsProvider);
    final blockedUrls = BlockedUrlGuard.jsPayload(urlEntries).urls;
    final googleSurfaceUrls = BlockedUrlGuard.googleSurfaceJsUrls(urlEntries);
    final brunchAuthors = ref.read(brunchBlockedAuthorsProvider);
    final site = _injectSite;
    final dmOnly = widget.instagramDmOnly;
    if (!mounted) return;
    final urlForLight = (target != null && identical(target, _browseController))
        ? _browseCurrentUrl
        : _currentUrl;
    var light = _injectSite.isYoutube && _youtubeBlockLightMode(urlForLight);
    if (youtubeChannels.length > 80 || blockedKeywords.length > 48) {
      light = true;
    }
    if (light) {
      final signature =
          '${youtubeChannels.length}|${blockedVideoIds.length}|${blockedKeywords.length}|${blockedUrls.length}';
      final now = DateTime.now();
      if (_lastYoutubeInjectSignature == signature &&
          _lastYoutubeLightInjectAt != null &&
          now.difference(_lastYoutubeLightInjectAt!) <
              const Duration(milliseconds: 1800)) {
        return;
      }
      _lastYoutubeInjectSignature = signature;
      _lastYoutubeLightInjectAt = now;
    }
    try {
      await IsleWebviewFactory.injectBlocks(
        c,
        site,
        youtubeChannels: youtubeChannels,
        blockedVideoIds: blockedVideoIds,
        blockedKeywords: blockedKeywords,
        blockedUrls: blockedUrls,
        googleSurfaceBlockedUrls: googleSurfaceUrls,
        brunchAuthors: brunchAuthors,
        instagramDmOnly: dmOnly,
        instagramMinimalScripts:
            _isInstagram && !IsleUserDefaults.instagramLoginRemembered,
        youtubeBlockLightMode: light,
        pageUrl: urlForLight,
        youtubePlaybackBlocked: YoutubeAccessGuard.shouldBlockWebView,
      );
    } catch (e, st) {
      IsleAppLogService.log(
        'injectBlocks skipped: $e',
        level: IsleLogLevel.debug,
        stack: st,
      );
    } finally {
      if (mounted &&
          _isYoutube &&
          (YoutubeNavPolicy.isBrowseSurface(_currentUrl) ||
              _isYoutubeSearchUrl(_currentUrl) ||
              _isYoutubeGoogleAuthFlow)) {
        _clearYoutubeBrowseLoading();
      }
    }
  }

  void _handleBrowseUrlChanged(String url) {
    if (!mounted || !_youtubeInlineMini) return;
    final blockHit = _matchYoutubeBlock(url);
    if (blockHit != null) {
      unawaited(_redirectBlockedYoutubeOn(_browseController, blockHit));
      return;
    }
    if (url.contains('watch?v=') || url.contains('/shorts/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            YoutubeAccessGuard.shouldBlockWebView
                ? '한도에 도달해 재생할 수 없어요'
                : '다른 영상은 「크게 보기」로 미니를 접은 뒤 시청해 주세요',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      unawaited(_browseLoad(YoutubeWebviewFactory.homeUrl()));
      return;
    }
    setState(() => _browseCurrentUrl = url);
  }

  Future<void> _browseLoad(String url) async {
    final c = _browseController;
    if (c == null) return;
    setState(() => _browseCurrentUrl = url);
    await c.loadRequest(Uri.parse(url));
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _enterYoutubeInlineMini() async {
    if (!_isYoutube ||
        !_isWatchPage ||
        _controller == null ||
        _youtubeInlineMini) return;

    final probed = await _ensureChannelProbed();
    if (!mounted) return;
    final blockHit = _matchYoutubeBlock(_currentUrl, probe: probed);
    if (blockHit != null) {
      _applyPlaybackBlock(true);
      unawaited(_redirectBlockedYoutube(blockHit));
      return;
    }

    HapticFeedback.mediumImpact();
    final browseStart = _preWatchBrowseUrl.isNotEmpty &&
            !_preWatchBrowseUrl.contains('watch?v=') &&
            !_preWatchBrowseUrl.contains('/shorts/')
        ? _preWatchBrowseUrl
        : YoutubeWebviewFactory.homeUrl();
    final browse = IsleWebviewFactory.create(
      site: widget.site,
      initialUrl: browseStart,
      onUrlChanged: _handleBrowseUrlChanged,
      onPageReady: () async {
        if (mounted) setState(() => _loading = false);
        final b = _browseController;
        if (b != null) await _hideYoutubeOpenApp(b);
      },
    );
    YoutubeWebviewEnergy.register(browse);
    await _injectBlocks(browse);
    await _hideYoutubeOpenApp(browse);
    setState(() {
      _youtubeInlineMini = true;
      _browseController = browse;
      _browseCurrentUrl = browseStart;
      _loading = false;
    });
    _scheduleWatchPageBlockCheck();
    IsleAppLogService.log(
        'YouTube inline mini: browse=$browseStart watch=$_currentUrl');
  }

  void _exitYoutubeInlineMini() {
    if (!_youtubeInlineMini) return;
    final browse = _browseController;
    if (browse != null) {
      YoutubeWebviewEnergy.unregister(browse);
    }
    HapticFeedback.lightImpact();
    setState(() {
      _youtubeInlineMini = false;
      _browseController = null;
      _browseCurrentUrl = '';
    });
  }

  Future<void> _probeBrunchAuthor() async {
    final c = _controller;
    if (c == null) return;
    await c.runJavaScript(BrunchAuthorProbeScript.probeAndPost);
  }

  Future<void> _probeChannel() async {
    final c = _controller;
    if (c == null || (!_isYoutube && !_isSafariYoutube)) return;
    await _probeChannelOn(c);
  }

  Future<void> _probeChannelOn(WebViewController c) async {
    final script = _isWatchPage
        ? YoutubeWatchProbeScript.probeAndPost
        : YoutubeChannelProbeScript.probeAndPost;
    await c.runJavaScript(script);
  }

  /// JS 프로브 콜백이 올 때까지 짧게 대기 — 즉시 시트를 열면 채널 ID가 비어 차단이 무시됨
  Future<YoutubePageChannel> _ensureChannelProbed() async {
    if (!_probed.isEmpty) return _probed;
    for (var i = 0; i < 12; i++) {
      await _probeChannel();
      await Future<void>.delayed(Duration(milliseconds: i < 3 ? 120 : 220));
      if (!_probed.isEmpty) return _probed;
    }
    return _probed;
  }

  /// watch?v= — URL만으로는 채널 차단 불가 → probe 반복 + JS 시청 차단
  void _scheduleWatchPageBlockCheck() {
    if (!mounted || !_youtubeRulesApply) return;
    if (!YoutubeNavPolicy.isWatchUrl(_currentUrl)) return;
    _watchBlockProbeTimer?.cancel();

    void probeOnce(int attempt) async {
      if (!mounted || !YoutubeNavPolicy.isWatchUrl(_currentUrl)) return;
      final c = _controller;
      if (c != null) await _probeChannelOn(c);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      final hit = _matchYoutubeBlock(_currentUrl, probe: _probed);
      if (hit != null) {
        _applyPlaybackBlock(true); // 지연 프로브에서 차단 감지 즉시 정지
        if (widget.site == ExplorerSite.custom &&
            !YoutubeUrlRedirect.isYoutubeUrl(_currentUrl)) {
          unawaited(_enforceBlockedEmbed(hit));
        } else {
          unawaited(_redirectBlockedYoutube(hit));
        }
        return;
      }
      const nextDelays = [400, 600, 1000, 1500];
      if (attempt < nextDelays.length) {
        _watchBlockProbeTimer =
            Timer(Duration(milliseconds: nextDelays[attempt]), () {
          probeOnce(attempt + 1);
        });
      }
    }

    probeOnce(0);
  }

  /// Safe Browser(커스텀 사이트)는 예전엔 `onNavigationRequest`가 아예 안 걸려
  /// 있어서, 차단 판정이 `onPageStarted`/`onUrlChanged`(페이지가 이미 로드를
  /// 시작한 뒤)에서만 반응형으로 일어났다 — 그 사이 짧은 시간 동안 실제 차단
  /// 대상 페이지의 콘텐츠가 이미 네트워크 요청을 마치고 렌더링을 시작해,
  /// "15분만 허용" 시트가 뜨기 전에 순간적으로 실제 페이지가 비칠 수 있었다
  /// (2026-07-13 제보 — 구글 검색 결과에서 차단된 사이트를 클릭했을 때 특히
  /// 눈에 띔). 요청 자체를 native 레벨에서 막아 네트워크 요청이 나가기 전에
  /// 차단하도록 `_applyUrlPolicy`(커스텀 사이트 분기)와 동일한 판정을
  /// 동기적으로 먼저 건다.
  NavigationDecision _customSiteNavigationDecision(
    NavigationRequest req, {
    required WebViewController controller,
  }) {
    final url = req.url;
    if (GoogleAuthPathPolicy.isAuthFlowUrl(url)) {
      return NavigationDecision.navigate;
    }
    if (_applyContentSafetyUrl(url, controller: controller)) {
      return NavigationDecision.prevent;
    }
    final deny = IsleContentBlockGuard.denyInAppSafariNavigation(url);
    if (deny != null) {
      // 구글 검색결과 페이지의 "AI 개요"가 배경에 유튜브 embed iframe(예:
      // youtube.com/embed?...)을 몰래 로드하는 것처럼, 사용자가 실제로 보려는
      // 페이지(구글 검색)와 무관한 서브프레임 리소스 요청까지 메인 프레임
      // 네비게이션과 똑같이 취급해 전체화면 차단 시트를 띄우고 홈으로
      // 리다이렉트하던 실사용 버그(2026-07-13 제보 — "도도독"만 검색했는데
      // 유튜브 차단 시트가 뜸). 서브프레임(iframe)은 그 리소스 로드만 조용히
      // 막고, 사용자가 보고 있는 메인 페이지는 그대로 둔다 — 시트·리다이렉트는
      // 메인 프레임 네비게이션일 때만 띄운다.
      if (!req.isMainFrame) {
        return NavigationDecision.prevent;
      }
      unawaited(_redirectInAppSafariDenied(
        deny,
        controller: controller,
        blockedUrl: url,
      ));
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  NavigationDecision _youtubeNavigationDecision(NavigationRequest req) {
    final u = req.url.toLowerCase();
    if (u.startsWith('vnd.youtube:') ||
        u.startsWith('youtube://') ||
        u.contains('itms-apps://') && u.contains('youtube')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Isle 안에서만 시청해요 · 차단·한도가 적용됩니다'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _handleYoutubeBack() async {
    HapticFeedback.selectionClick();
    if (_youtubeInlineMini) {
      final b = _browseController;
      if (b != null && await b.canGoBack()) {
        await b.goBack();
        return;
      }
      _exitYoutubeInlineMini();
      return;
    }
    final c = _controller;
    if (c != null && await c.canGoBack()) {
      await c.goBack();
      return;
    }
    await _minimizeToFeed();
  }

  YoutubeBlockHit? _currentYoutubeBlockHit() =>
      _matchYoutubeBlock(_currentUrl, probe: _probed);

  bool _shouldDenyYoutubePark() {
    if (_currentYoutubeBlockHit() != null) return true;
    if (!YoutubeNavPolicy.isWatchUrl(_currentUrl)) return false;
    return _probed.isEmpty;
  }

  void _stopYoutubeController(WebViewController c) {
    unawaited(YoutubeWebviewEnergy.setPlaybackBlocked(c, true));
    YoutubeWebviewEnergy.unregister(c);
    try {
      c.runJavaScript(
        "document.querySelectorAll('video').forEach(function(v){try{v.pause();}catch(e){}});",
      );
    } catch (_) {}
  }

  String _youtubeParkTitle() => _probed.videoTitle.isNotEmpty
      ? _probed.videoTitle
      : (_probed.channelName.isNotEmpty ? _probed.channelName : '유튜브');

  void _parkYoutubeController(WebViewController c) {
    if (_shouldDenyYoutubePark()) {
      _stopYoutubeController(c);
      IsleAppLogService.log('YouTube park denied: blocked or unprobed watch');
      return;
    }
    HapticFeedback.mediumImpact();
    _leavingMinimized = true;
    YoutubeSession.instance.park(
      controller: c,
      url: _currentUrl,
      title: _youtubeParkTitle(),
      channel: _probed,
    );
    if (YoutubeAccessGuard.shouldBlockWebView) {
      unawaited(YoutubeWebviewEnergy.setPlaybackBlocked(c, true));
    }
    YoutubeSession.instance.clearHandlers();
    _controller = null;
  }

  bool _shouldParkYoutubeOnExit() {
    if (!_isYoutube || _leavingMinimized) return false;
    final url = _currentUrl.toLowerCase();
    if (url.isEmpty) return false;
    return url.contains('youtube.com') ||
        url.contains('youtu.be') ||
        url.contains('googlevideo.com');
  }

  Future<void> _minimizeToFeed() async {
    if (!_isYoutube) {
      if (mounted) context.pop();
      return;
    }
    final c = _controller;
    if (c == null) {
      if (mounted) context.go('/feed');
      return;
    }
    final probed = await _ensureChannelProbed();
    if (!mounted) return;
    final hit = _matchYoutubeBlock(_currentUrl, probe: probed);
    if (hit != null) {
      _applyPlaybackBlock(true);
      unawaited(_redirectBlockedYoutube(hit));
      if (mounted) context.go('/feed');
      return;
    }
    if (_shouldDenyYoutubePark()) {
      _stopYoutubeController(c);
      if (mounted) context.go('/feed');
      return;
    }
    _parkYoutubeController(c);
    if (mounted) context.go('/feed');
  }

  void _quitYoutube() {
    HapticFeedback.heavyImpact();
    _leavingMinimized = false;
    YoutubeSession.instance.quit();
    if (mounted) context.go('/feed');
  }

  Future<void> _showYoutubeBlockPrefs() async {
    if (!_isYoutube) return;
    if (!mounted) return;
    if (!_isWatchPage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영상을 재생 중일 때 사용할 수 있어요')),
      );
      return;
    }
    final probed = await _ensureChannelProbed();
    if (!mounted) return;
    await showYoutubeWatchPrefSheet(
      context,
      watch: probed,
      pageUrl: _currentUrl,
    );
  }

  Future<void> _blockBrunchAuthor() async {
    await _probeBrunchAuthor();
    if (!mounted) return;
    final handle = _brunchHandle.isNotEmpty
        ? _brunchHandle
        : RegExp(r'/@([\w.-]+)').firstMatch(_currentUrl)?.group(1) ?? '';
    final name = _brunchAuthorName.isNotEmpty ? _brunchAuthorName : handle;
    if (handle.isEmpty && name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('작가를 찾지 못했어요. 프로필·글 페이지에서 시도해 주세요')),
      );
      return;
    }
    await ref.read(brunchBlockedAuthorsProvider.notifier).block(
          handle: handle,
          displayName: name,
        );
    await _injectBlocks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$name」 글·목록에서 숨깁니다')),
      );
    }
  }

  Future<void> _blockCurrentChannel() async {
    if (!_isYoutube) return;
    final probed = await _ensureChannelProbed();
    if (!mounted) return;
    final result = await showBlockChannelSheet(
      context,
      channelId: probed.channelId,
      channelName: probed.channelName,
      pageUrl: _currentUrl,
    );
    if (result?.channelBlocked == true) {
      await _injectBlocks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('채널을 차단 목록에 추가했습니다')),
      );
    }
  }

  Future<void> _editBrunchKeywords(BuildContext ctx) async {
    final ctrl = TextEditingController(
      text: IsleUserDefaults.brunchBlockKeywords.join(', '),
    );
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: Text('브런치·블로그 숨김 키워드', style: IsleText.subtitle()),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: '쉼표로 구분 — 제목·목록에서 숨김',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true), child: const Text('저장')),
        ],
      ),
    );
    if (ok == true) {
      final raw = ctrl.text;
      final list = raw
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();
      await IsleUserDefaults.setBrunchBlockKeywords(list);
      await _injectBlocks();
    }
    ctrl.dispose();
  }

  Future<void> _blockGoogleSearchTerms() async {
    final q = SafariWebConfig.searchQueryFromUrl(_currentUrl);
    if (q == null || q.trim().length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구글 검색 페이지에서만 사용할 수 있어요')),
      );
      return;
    }
    final terms = q
        .split(RegExp(r'\s+'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.length >= 2)
        .toList();
    if (terms.isEmpty) {
      terms.add(q.trim().toLowerCase());
    }
    final notifier = ref.read(blockedKeywordsProvider.notifier);
    for (final t in terms) {
      await notifier.add(t);
    }
    ref.invalidate(feedProvider);
    await _injectBlocks();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          terms.length == 1
              ? PlatformBlockCopy.googleSearchHideSnack(terms.first)
              : PlatformBlockCopy.googleSearchHideSnack(terms.join(' · ')),
        ),
      ),
    );
  }

  Future<void> _openKeywordFilterSheet() async {
    await showKeywordFilterSheet(context);
    if (!mounted) return;
    await _injectBlocks();
  }

  Future<void> _openBlockedUrlSheet() async {
    await showBlockedUrlSheet(context);
    if (!mounted) return;
    await _injectBlocks();
  }

  Future<void> _openPageLinkBulkBlock() async {
    final c = _controller;
    if (c == null || !mounted) return;
    final result = await showPageLinkBulkBlockSheet(
      context: context,
      controller: c,
      pageUrl: _currentUrl,
    );
    if (!mounted) return;
    if (result != null) {
      await _injectBlocks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('페이지 링크 차단 — ${result.summary()}')),
      );
    }
  }

  Future<void> _blockCurrentPageUrl() async {
    final url = _currentUrl.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('차단할 URL이 없어요')),
      );
      return;
    }
    final vid = UrlParser.extractYouTubeVideoId(url);
    if (vid != null) {
      await ref
          .read(blockedVideosProvider.notifier)
          .addVideo(vid, sourceUrl: url);
    }
    final ok = await ref.read(blockedUrlsProvider.notifier).add(url);
    ref.invalidate(feedProvider);
    await _injectBlocks();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '이 URL을 차단 목록에 추가했어요' : 'URL 형식을 확인해 주세요'),
      ),
    );
  }

  /// iPad popover — (0,0,0,0) 이면 PlatformException
  Rect _sharePopoverOrigin([BuildContext? anchor]) {
    if (anchor != null && anchor.mounted) {
      final ro = anchor.findRenderObject();
      if (ro is RenderBox && ro.hasSize) {
        final size = ro.size;
        if (size.width > 1 && size.height > 1) {
          return ro.localToGlobal(Offset.zero) & size;
        }
      }
    }
    if (!mounted) return const Rect.fromLTWH(0, 0, 44, 44);
    final sz = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    return Rect.fromLTWH(sz.width - 56, top + 4, 48, 48);
  }

  Future<void> _shareCurrentPage([BuildContext? anchorContext]) async {
    if (_currentUrl.isEmpty || !_currentUrl.startsWith('http')) return;
    if (!mounted) return;
    final deny = IsleContentBlockGuard.denyUrl(_currentUrl);
    if (deny != null) {
      _showBlockSnack('$deny · 다른 앱으로 공유할 수 없어요', url: _currentUrl);
      return;
    }
    HapticFeedback.lightImpact();
    final title = _isYoutube
        ? (_probed.videoTitle.isNotEmpty
            ? _probed.videoTitle
            : (_probed.channelName.isNotEmpty
                ? _probed.channelName
                : 'YouTube'))
        : (widget.title ?? widget.site.displayTitle);
    final text = '$title\n$_currentUrl';
    final origin = Platform.isIOS ? _sharePopoverOrigin(anchorContext) : null;
    await Share.share(
      text,
      subject: title,
      sharePositionOrigin: origin,
    );
  }

  String _urlBarLabel(String url) {
    if (url.isEmpty || !url.startsWith('http')) return '주소 입력';
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isNotEmpty ? host : url;
  }

  String _normalizeBrowserUrl(String raw) {
    // URL이면 그대로(구글 검색은 SafeSearch 강제), 아니면 구글 검색어로 처리.
    return SafariWebConfig.resolveQueryOrUrl(raw);
  }

  Future<void> _navigateBrowserTo(String raw) async {
    var url = _normalizeBrowserUrl(raw);
    if (widget.site == ExplorerSite.custom) {
      final deny = IsleContentBlockGuard.denyInAppSafariNavigation(url);
      if (deny != null) {
        if (mounted) _showBlockSnack(deny, url: url);
        url = SafariWebConfig.homeUrl;
      } else if (ContentSafetyGuard.matchUrl(url) != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('안전 모드: 성인 콘텐츠 사이트는 열 수 없어요')),
          );
        }
        url = SafariWebConfig.homeUrl;
      } else {
        url = ContentSafetyGuard.sanitizeUrl(url);
      }
    } else if (ContentSafetyGuard.matchUrl(url) != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('안전 모드: 성인 콘텐츠 사이트는 열 수 없어요')),
        );
      }
      url = widget.site.defaultHomeUrl;
    } else {
      url = ContentSafetyGuard.sanitizeUrl(url);
    }
    setState(() {
      _loading = true;
      _currentUrl = url;
    });
    _syncWatchTimer();
    final c = _controller;
    if (c != null) {
      await c.loadRequest(Uri.parse(url));
    }
    if (mounted) {
      setState(() => _loading = false);
      if (_isSafariYoutube) unawaited(_injectBlocks());
    }
  }

  /// 하단 주소창 탭 → URL 편집 (Safari·브런치 등)
  Future<void> _showBrowserUrlSheet() async {
    if (!mounted) return;
    final ctrl = TextEditingController(text: _currentUrl);
    final isSafari = widget.site == ExplorerSite.custom;

    final choice = await showIsleModalSheet<String>(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('주소 · 검색', style: IsleText.subtitle()),
            const SizedBox(height: 8),
            Text(
              isSafari
                  ? '주소(google.com)를 넣으면 바로 열고, 검색어를 넣으면 구글에서 검색해요.\n'
                      '구글 검색은 SafeSearch(유해 결과 차단)가 항상 켜져요.'
                  : '주소를 붙여넣거나 검색어를 입력하세요',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: '구글 검색 또는 주소',
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.pop(ctx, 'go'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'go'),
              child: Text(isSafari ? '열기 · 검색' : '이동'),
            ),
            if (isSafari) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'yt'),
                child: const Text('Isle 유튜브에서 열기'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || choice == null) {
      ctrl.dispose();
      return;
    }
    final target = _normalizeBrowserUrl(ctrl.text);
    ctrl.dispose();
    if (choice == 'yt' && YoutubeUrlRedirect.isYoutubeUrl(target)) {
      final route = YoutubeUrlRedirect.inAppRoute(target);
      if (route != null) {
        context.push(route);
        return;
      }
    }
    await _navigateBrowserTo(target);
  }

  Future<void> _pasteClipboardAndPlay() async {
    final url = await YoutubeClipboardWatch.readClipboardUrl();
    if (!mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클립보드에 YouTube 링크가 없어요')),
      );
      return;
    }
    final blockHit = _matchYoutubeBlock(url);
    if (blockHit != null) {
      _showBlockSnack(blockHit.snackMessage, url: url);
      return;
    }
    await _openYoutubeUrlInPlace(url);
  }

  Future<void> _openYoutubeUrlInPlace(String url) async {
    _playbackGuard.reset();
    setState(() {
      _recovery = const IslePlaybackRecoveryState.idle();
      _loading = true;
      _currentUrl = url;
      _youtubeQuickBarDismissed = false;
    });
    final c = _controller;
    if (c != null) {
      await c.loadRequest(Uri.parse(url));
    }
    if (mounted) setState(() => _loading = false);
  }

  void _scheduleClipboardOffer() {
    if (!_isYoutube) return;
    _clipboardOfferDebounce?.cancel();
    _clipboardOfferDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      unawaited(_maybeOfferClipboardActions());
    });
  }

  Future<void> _maybeOfferClipboardActions() async {
    if (!_isYoutube || !mounted) return;
    await YoutubeClipboardQuickActions.maybeOffer(
      context,
      currentPageUrl: _currentUrl,
      onOpenInPlace: _openYoutubeUrlInPlace,
    );
  }

  Future<void> _subscribeCurrentSite() async {
    final r = await FeedIngestService.addSubscriptionFromUrl(_currentUrl);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(r.message)));
  }

  String? _channelSubtitle() {
    if (_isYoutube && _probed.channelName.isNotEmpty)
      return _probed.channelName;
    if (_isBrunch && _brunchAuthorName.isNotEmpty) return _brunchAuthorName;
    if (_isBrunch && _brunchHandle.isNotEmpty) return '@$_brunchHandle';
    if (_isInstagram && widget.instagramDmOnly) {
      return InstagramDmPathPolicy.chromeHintForPath(
            Uri.tryParse(_currentUrl)?.path ?? '',
          ) ??
          '무제한 · DM';
    }
    return null;
  }

  Future<void> _openChromeMenu() async {
    final copy = MoaStrings.of(context);
    if (_isYoutube && mounted) setState(() => _chromeVisible = false);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _chromeBg,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.palette_outlined, color: _chromeFg),
              title: Text(copy.t('chrome_color'),
                  style: IsleText.body(color: _chromeFg)),
              subtitle: Text(
                _useDarkChrome ? copy.t('chrome_dark') : copy.t('chrome_light'),
                style: IsleText.caption(color: _chromeMuted),
              ),
              onTap: () async {
                await IsleUserDefaults.setExplorerChromeDark(!_useDarkChrome);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
              },
            ),
            if (_isYoutube) ...[
              ListTile(
                leading: Icon(Icons.video_library_outlined,
                    color: IsleColors.gold500),
                title: Text('Isle 큐 · CC 기사',
                    style: IsleText.body(color: _chromeFg)),
                subtitle: Text(
                  '공유·저장한 영상 목록 (미니 플레이어에서 Isle 길게 누르기와 동일)',
                  style: IsleText.caption(color: _chromeMuted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  showIsleYoutubeLibrarySheet(context);
                },
              ),
              if (_isWatchPage && !_youtubeInlineMini)
                ListTile(
                  leading: Icon(Icons.picture_in_picture_alt_outlined,
                      color: _chromeFg),
                  title: Text('탐색 모드 (미니 플레이어)',
                      style: IsleText.body(color: _chromeFg)),
                  subtitle: Text(
                    '재생 유지 · 홈·검색·나중에 볼',
                    style: IsleText.caption(color: _chromeMuted),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(_enterYoutubeInlineMini());
                  },
                ),
              ListTile(
                leading: Icon(Icons.home_outlined, color: _chromeFg),
                title: Text('피드로 나가기', style: IsleText.body(color: _chromeFg)),
                subtitle: Text(
                  '재생 유지 · 다시 보기 표시',
                  style: IsleText.caption(color: _chromeMuted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _minimizeToFeed();
                },
              ),
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined,
                    color: IsleColors.danger),
                title: Text('유튜브 끄기', style: IsleText.body(color: _chromeFg)),
                onTap: () {
                  Navigator.pop(ctx);
                  _quitYoutube();
                },
              ),
              if (_isWatchPage)
                ListTile(
                  leading: Icon(Icons.auto_awesome, color: _chromeFg),
                  title: Text('크리에이터 분석 (CC)',
                      style: IsleText.body(color: _chromeFg)),
                  subtitle: Text(
                    '차별점 · 핵심 · 관심 분야 적용',
                    style: IsleText.caption(color: _chromeMuted),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    showYoutubeCreatorInsightSheet(context, ref,
                        initialUrl: _currentUrl);
                  },
                ),
              if (_isWatchPage)
                ListTile(
                  leading:
                      Icon(Icons.thumb_down_alt_outlined, color: _chromeFg),
                  title: Text('추천 줄이기', style: IsleText.body(color: _chromeFg)),
                  subtitle: Text(
                    '채널·장르·영상 숨기기',
                    style: IsleText.caption(color: _chromeMuted),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showYoutubeBlockPrefs();
                  },
                ),
              ListTile(
                leading: Icon(Icons.block, color: _chromeFg),
                title: Text('이 채널 차단', style: IsleText.body(color: _chromeFg)),
                onTap: () {
                  Navigator.pop(ctx);
                  _blockCurrentChannel();
                },
              ),
              ListTile(
                leading: Icon(Icons.schedule, color: _chromeFg),
                title: Text('차단 스케줄', style: IsleText.body(color: _chromeFg)),
                onTap: () {
                  Navigator.pop(ctx);
                  pushBlockScheduleList(ctx);
                },
              ),
              ListTile(
                leading: Icon(Icons.content_paste_go, color: _chromeFg),
                title:
                    Text('복사한 URL 보기', style: IsleText.body(color: _chromeFg)),
                subtitle: Text(
                  '클립보드 링크로 바로 재생',
                  style: IsleText.caption(color: _chromeMuted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_pasteClipboardAndPlay());
                },
              ),
              ListTile(
                leading: Icon(Icons.rss_feed, color: _chromeFg),
                title: Text(copy.t('subscribe_feed'),
                    style: IsleText.body(color: _chromeFg)),
                subtitle: Text(
                  '이 채널·RSS',
                  style: IsleText.caption(color: _chromeMuted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _subscribeCurrentSite();
                },
              ),
            ],
            if (_isInstagram) ...[
              if (_supportsTabs)
                ListTile(
                  leading: Icon(Icons.tab, color: _chromeFg),
                  title: Text(
                      copy.t('tabs', args: {'count': '${_tabs.length}'}),
                      style: IsleText.body(color: _chromeFg)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showTabSheet();
                  },
                ),
            ],
            if (_isInstagram && widget.instagramDmOnly) ...[
              ListTile(
                leading:
                    const Icon(Icons.person_outline, color: Color(0xFFE1306C)),
                title: Text('상대 프로필 · 게시물',
                    style: IsleText.body(color: _chromeFg)),
                subtitle: Text(
                  'DM에서 상대 이름·프로필 사진을 탭하면 프로필·스토리·그리드 게시물을 볼 수 있어요',
                  style: IsleText.caption(color: _chromeMuted),
                ),
                onTap: () => Navigator.pop(ctx),
              ),
              if (_lastInstagramDmUrl.isNotEmpty &&
                  !InstagramDmPathPolicy.isDmThreadPath(
                    Uri.tryParse(_currentUrl)?.path ?? '',
                  ))
                ListTile(
                  leading: Icon(Icons.forum_outlined, color: _chromeFg),
                  title: Text('DM 대화로 돌아가기',
                      style: IsleText.body(color: _chromeFg)),
                  onTap: () {
                    Navigator.pop(ctx);
                    final c = _controller;
                    if (c != null) {
                      unawaited(c.loadRequest(Uri.parse(_lastInstagramDmUrl)));
                    }
                  },
                ),
              ListTile(
                leading: Icon(Icons.inbox_outlined, color: _chromeFg),
                title: Text('DM 받은편지함', style: IsleText.body(color: _chromeFg)),
                onTap: () {
                  Navigator.pop(ctx);
                  final c = _controller;
                  if (c != null) {
                    unawaited(c
                        .loadRequest(Uri.parse(InstagramWebConfig.dmInboxUrl)));
                  }
                },
              ),
            ],
            if (_isBrunch) ...[
              ListTile(
                leading: Icon(Icons.person_off_outlined, color: _chromeFg),
                title: Text('이 작가 숨기기', style: IsleText.body(color: _chromeFg)),
                onTap: () {
                  Navigator.pop(ctx);
                  _blockBrunchAuthor();
                },
              ),
              ListTile(
                leading: Icon(Icons.tag, color: _chromeFg),
                title: Text('숨길 키워드', style: IsleText.body(color: _chromeFg)),
                onTap: () {
                  Navigator.pop(ctx);
                  _editBrunchKeywords(ctx);
                },
              ),
            ],
            if (widget.site == ExplorerSite.custom) ...[
              ListTile(
                leading: Icon(Icons.home_outlined, color: _chromeFg),
                title: Text('홈으로 나가기', style: IsleText.body(color: _chromeFg)),
                subtitle: Text(
                  '브라우저 기록 대신 Isle 홈으로 돌아가기',
                  style: IsleText.caption(color: _chromeMuted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _exitBrowserToHome();
                },
              ),
              ListTile(
                leading: Icon(Icons.dataset_linked_outlined, color: _chromeFg),
                title: Text('이 페이지 링크 일괄 차단',
                    style: IsleText.body(color: _chromeFg)),
                subtitle: Text(
                  '주소 모음·게시판 — 링크 전부 읽어서 Safari·URL 차단',
                  style: IsleText.caption(color: _chromeMuted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_openPageLinkBulkBlock());
                },
              ),
              ListTile(
                leading: Icon(Icons.link_off, color: _chromeFg),
                title: Text('이 URL 차단', style: IsleText.body(color: _chromeFg)),
                subtitle: Text(
                  'YouTube·구글 검색·피드 카드에서 숨김',
                  style: IsleText.caption(color: _chromeMuted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_blockCurrentPageUrl());
                },
              ),
              ListTile(
                leading: Icon(Icons.list_alt, color: _chromeFg),
                title:
                    Text('차단 URL 관리', style: IsleText.body(color: _chromeFg)),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_openBlockedUrlSheet());
                },
              ),
              if (SafariWebConfig.isGoogleSearchUrl(_currentUrl)) ...[
                ListTile(
                  leading: Icon(Icons.search_off, color: _chromeFg),
                  title: Text('이 검색어 결과 숨기기',
                      style: IsleText.body(color: _chromeFg)),
                  subtitle: Text(
                    SafariWebConfig.searchQueryFromUrl(_currentUrl) ?? '',
                    style: IsleText.caption(color: _chromeMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(_blockGoogleSearchTerms());
                  },
                ),
                ListTile(
                  leading: Icon(Icons.tag, color: _chromeFg),
                  title:
                      Text('숨길 키워드 관리', style: IsleText.body(color: _chromeFg)),
                  subtitle: Text(
                    '구글 검색·피드·YouTube에 공통 적용',
                    style: IsleText.caption(color: _chromeMuted),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(_openKeywordFilterSheet());
                  },
                ),
              ],
            ],
            if (_isYoutube || _isSafariYoutube) ...[
              ListTile(
                leading: Icon(Icons.link_off, color: _chromeFg),
                title: Text('이 URL 차단', style: IsleText.body(color: _chromeFg)),
                subtitle: Text(
                  '검색·피드·추천에서 이 링크 숨김',
                  style: IsleText.caption(color: _chromeMuted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_blockCurrentPageUrl());
                },
              ),
              ListTile(
                leading: Icon(Icons.list_alt, color: _chromeFg),
                title:
                    Text('차단 URL 관리', style: IsleText.body(color: _chromeFg)),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_openBlockedUrlSheet());
                },
              ),
            ],
            if (!_isYoutube)
              ListTile(
                leading: Icon(Icons.rss_feed, color: _chromeFg),
                title: Text(copy.t('subscribe_feed'),
                    style: IsleText.body(color: _chromeFg)),
                onTap: () {
                  Navigator.pop(ctx);
                  _subscribeCurrentSite();
                },
              ),
            ListTile(
              leading: Icon(Icons.ios_share, color: _chromeFg),
              title:
                  Text(copy.t('share'), style: IsleText.body(color: _chromeFg)),
              subtitle: Text(
                copy.t('share_page'),
                style: IsleText.caption(color: _chromeMuted),
              ),
              onTap: () {
                final anchor = ctx;
                Navigator.pop(ctx);
                unawaited(_shareCurrentPage(anchor));
              },
            ),
            ListTile(
              leading: Icon(Icons.fullscreen, color: _chromeFg),
              title: Text(copy.t('maximize'),
                  style: IsleText.body(color: _chromeFg)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _chromeVisible = false);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    YoutubeBlockReapplyHub.unregister(_reapplyYoutubeBlocks);
    _loadingFailsafe?.cancel();
    _searchCloakOverlayTimer?.cancel();
    _instagramNavBusyTimer?.cancel();
    _instagramSoundHintTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _injectDebounce?.cancel();
    _clipboardOfferDebounce?.cancel();
    _watchTick?.cancel();
    _lastYoutubeHistoryTickAt = null;
    _flushWatchCounters();
    _watchBlockProbeTimer?.cancel();
    unawaited(YoutubeWatchHistoryService.flushPending());
    final browse = _browseController;
    if (browse != null) {
      YoutubeWebviewEnergy.unregister(browse);
    }
    final c = _controller;
    if (_isYoutube) {
      if (_leavingMinimized) {
        // WebView는 YoutubeSessionHost가 유지
      } else if (c != null && _shouldParkYoutubeOnExit()) {
        _parkYoutubeController(c);
      } else if (c != null) {
        YoutubeWebviewEnergy.unregister(c);
        if (!YoutubeSession.instance.hasParkedSession) {
          YoutubeSession.instance.quit();
        }
      }
    } else if (c != null) {
      YoutubeWebviewEnergy.unregister(c);
      for (final t in _tabs) {
        YoutubeWebviewEnergy.unregister(t.controller);
      }
      _tabs.clear();
    }
    _browseController = null;
    if (_watchPlatform == null) {
      unawaited(EngagementTracker.recordScreen(
          'web_explorer_${widget.site.name}',
          seconds:
              DateTime.now().difference(_openedAt).inSeconds.clamp(1, 3600)));
    }
    _controller = null;
    _watchUiPulse.dispose();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_entryBlocked) {
      return ExplorerEntryBlockedScreen(
        site: widget.site,
        url: _currentUrl,
        legacyMessage: _entryDenyMessage,
      );
    }
    if (_isYoutube || widget.site == ExplorerSite.custom) {
      ref.listen<List<BlockedChannel>>(blockedChannelsProvider, (_, __) {
        if (mounted &&
            _controller != null &&
            (!_isYoutube ||
                _shouldInjectYoutubeBlocks(_currentUrl) ||
                widget.site == ExplorerSite.custom)) {
          unawaited(_reapplyYoutubeBlocks());
          if (_isYoutube || _isSafariYoutube) {
            _scheduleWatchPageBlockCheck();
          }
        }
      });
      ref.listen<List<BlockedVideo>>(blockedVideosProvider, (_, __) {
        if (mounted &&
            _controller != null &&
            (!_isYoutube ||
                _shouldInjectYoutubeBlocks(_currentUrl) ||
                widget.site == ExplorerSite.custom)) {
          unawaited(_reapplyYoutubeBlocks());
        }
      });
    }
    ref.listen<List<String>>(blockedKeywordsProvider, (_, __) {
      if (mounted &&
          _controller != null &&
          (!_isYoutube ||
              _shouldInjectYoutubeBlocks(_currentUrl) ||
              widget.site == ExplorerSite.custom)) {
        unawaited(_reapplyYoutubeBlocks());
      }
    });
    ref.listen<List<BlockedUrl>>(blockedUrlsProvider, (_, __) {
      if (mounted &&
          _controller != null &&
          (_isYoutube ||
              widget.site == ExplorerSite.custom ||
              _shouldInjectYoutubeBlocks(_currentUrl))) {
        unawaited(_reapplyYoutubeBlocks());
      }
    });
    ref.listen<List<BrunchBlockedAuthor>>(brunchBlockedAuthorsProvider,
        (_, __) {
      if (mounted && _controller != null) _injectBlocks();
    });

    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Use the clear sides of the camera area for compact media controls.
    final youtubeCornerTop = (topInset - 40.0) / 2.0;
    final cornerTop = (_isYoutube || _isInstagram) && topInset >= 40.0
        ? youtubeCornerTop
        : topInset + 8.0;
    final title = widget.title ?? widget.site.displayTitle;

    final ytChromeH =
        (_chromeVisible && !_youtubeImmersive && !_youtubeInlineMini)
            ? 44.0
            : 0.0;
    final igDmThread = _instagramDmThreadActive;
    // Safari·브런치 등 일반 브라우저: 상단/하단 chrome 바가 페이지(구글 검색창 등)를
    // 가리지 않도록 WebView를 chrome 높이만큼 안쪽으로 배치.
    final browserChromeVisible = !_isYoutube && !_isInstagram && _chromeVisible;
    final webTop = _isYoutube
        ? topInset + (_youtubeInlineMini ? 44.0 : ytChromeH)
        : (_isInstagram
            ? topInset
            : (browserChromeVisible ? topInset + 44.0 : 0.0));
    final miniH = _youtubeInlineMini
        ? YoutubeInlineMiniLayout.playerHeight(context)
        : 0.0;
    final miniNavH =
        _youtubeInlineMini ? YoutubeInlineMiniLayout.navBarHeight : 0.0;
    // YouTube: 0으로 끝까지 채움 — CSS padding으로 홈 바 위 여백 확보
    // Instagram: 키보드 올라올 때 Scaffold가 줄어들게 resize (DM 입력 검은 빈칸 방지)
    final webBottom = _isYoutube
        ? (_youtubeInlineMini ? bottomInset + miniH + miniNavH : 0.0)
        : (_isInstagram
            ? bottomInset
            : (browserChromeVisible ? bottomInset + 52.0 : bottomInset));
    final browse = _browseController;
    final miniTitle = _probed.videoTitle.isNotEmpty
        ? _probed.videoTitle
        : (_probed.channelName.isNotEmpty ? _probed.channelName : '재생 중');

    final igCanSystemPop = _isInstagram &&
        !_instagramNavBusy &&
        !_instagramImmersive &&
        (Uri.tryParse(_currentUrl)
                ?.path
                .toLowerCase()
                .startsWith('/direct/inbox') ??
            false);

    return PopScope(
      canPop: igCanSystemPop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isYoutube) {
          await _handleYoutubeBack();
        } else if (_isInstagram) {
          await _handleInstagramBack();
        } else {
          await _handleBrowserBack();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _overlayStyle,
        child: Scaffold(
          backgroundColor: _isInstagram ? Colors.white : Colors.black,
          extendBody: !_isYoutube,
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: !_isYoutube,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (_youtubeInlineMini && browse != null) ...[
                Positioned(
                  top: webTop,
                  left: 0,
                  right: 0,
                  bottom: webBottom,
                  child: WebViewWidget(controller: browse),
                ),
                Positioned(
                  bottom: bottomInset + miniH,
                  left: 0,
                  right: 0,
                  height: miniNavH,
                  child: YoutubeInlineMiniNavBar(
                    onHome: () =>
                        unawaited(_browseLoad(YoutubeWebviewFactory.homeUrl())),
                    onSearch: () => unawaited(_browseLoad(
                        'https://m.youtube.com/results?search_query=')),
                    onWatchLater: () => unawaited(
                        _browseLoad('https://m.youtube.com/playlist?list=WL')),
                    onIsleLibrary: () {
                      if (mounted) context.push('/library/sources');
                    },
                    onIsleLongPress: () {
                      if (mounted) {
                        showIsleYoutubeLibrarySheet(context);
                      }
                    },
                    onExpand: _exitYoutubeInlineMini,
                  ),
                ),
                Positioned(
                  bottom: bottomInset,
                  left: 0,
                  right: 0,
                  height: miniH,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(10)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        WebViewWidget(controller: controller),
                        YoutubeInlineMiniPlayerChrome(
                          title: miniTitle,
                          onExpand: _exitYoutubeInlineMini,
                          onClose: _exitYoutubeInlineMini,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (_isInstagram)
                InstagramWebKeyboardSurface(
                  controller: controller,
                  top: webTop,
                  bottomSafe: webBottom,
                  onDismissKeyboard: _dismissInstagramKeyboard,
                )
              else
                Positioned(
                  top: webTop,
                  left: 0,
                  right: 0,
                  bottom: webBottom,
                  child: WebViewWidget(controller: controller),
                ),
              if (_isYoutube && !_youtubeInlineMini)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: YoutubeOsWebviewRecoveryBar(
                    onRecovered: () {
                      final c = _controller;
                      if (c != null) unawaited(c.reload());
                    },
                  ),
                ),
              if (_isYoutube && !_youtubeInlineMini)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 28,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: (d) {
                      if (d.primaryVelocity != null &&
                          d.primaryVelocity! > 280) {
                        _minimizeToFeed();
                      }
                    },
                  ),
                ),
              if (_isInstagram && !_instagramImmersive)
                Positioned(
                  left: 0,
                  top: webTop,
                  bottom: webBottom,
                  width: 24,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: (d) {
                      if (d.primaryVelocity != null &&
                          d.primaryVelocity! > 220) {
                        unawaited(_exitInstagramToHub());
                      }
                    },
                  ),
                ),
              if (widget.site == ExplorerSite.custom)
                Positioned(
                  left: 0,
                  top: webTop,
                  bottom: webBottom,
                  width: 28,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: (d) {
                      if (d.primaryVelocity != null &&
                          d.primaryVelocity! > 260) {
                        _exitBrowserToHome();
                      }
                    },
                  ),
                ),
              if (_isYoutube &&
                  _isWatchPage &&
                  !_youtubeInlineMini &&
                  !_youtubeImmersive)
                Positioned(
                  top: webTop + 4,
                  left: 0,
                  right: 0,
                  height: 72,
                  child: YoutubeInlineMiniSwipeHint(
                      onSwipeDown: () => unawaited(_enterYoutubeInlineMini())),
                ),
              if (_isYoutube &&
                  !_chromeVisible &&
                  !_youtubeImmersive &&
                  !_youtubeInlineMini)
                Positioned(
                  top: topInset + 4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _chromeVisible = true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.expand_less,
                            color: Colors.white70, size: 20),
                      ),
                    ),
                  ),
                ),
              WebPlaybackRecoveryOverlay(
                state: _recovery,
                currentUrl: _currentUrl,
                onSignIn: _isYoutube &&
                        !YoutubeSafariLaunchGuard.isEscapeBlocked
                    ? () {
                        final c = _controller;
                        if (c == null) return;
                        setState(() {
                          _recovery = const IslePlaybackRecoveryState.idle();
                          _showLoginBanner = false;
                          _chromeVisible = true;
                          _pendingYoutubeLogin = true;
                        });
                        unawaited(
                          c.loadRequest(
                              Uri.parse(YoutubeWebviewFactory.signInUrl())),
                        );
                      }
                    : null,
                onSkipRecovery: () {
                  _playbackGuard.cancelRecovery();
                  setState(
                      () => _recovery = const IslePlaybackRecoveryState.idle());
                },
                onRetry: () {
                  final c = _controller;
                  if (c == null) return;
                  unawaited(
                    _playbackGuard.manualRetry(
                      reload: () => c.reload(),
                      loadUrl: (url) async {
                        if (url.isEmpty) {
                          await c.reload();
                        } else {
                          await c.loadRequest(Uri.parse(url));
                        }
                      },
                    ),
                  );
                },
                onGoHome: () {
                  final c = _controller;
                  if (c == null) return;
                  setState(
                      () => _recovery = const IslePlaybackRecoveryState.idle());
                  unawaited(c.loadRequest(Uri.parse(_resolveStartUrl())));
                },
              ),
              if (_showBlockingLoadOverlay)
                const Center(
                    child:
                        CircularProgressIndicator(color: IsleColors.gold500)),
              if (_loading &&
                  _hideYoutubeLoadingOverlay &&
                  !_recovery.showOverlay)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: IsleColors.gold500,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ScheduleIsleBlockOverlay(
                site: _scheduleOverlaySite,
                instagramDmOnly: widget.instagramDmOnly,
              ),
              if (_watchPlatform != null &&
                  !_isInstagramAuthFlow &&
                  !_isYoutubeGoogleAuthFlow)
                ValueListenableBuilder<int>(
                  valueListenable: _watchUiPulse,
                  builder: (_, __, ___) =>
                      PlatformWatchLimitOverlay(platform: _watchPlatform!),
                ),
              if (_showLoginBanner && _chromeVisible)
                Positioned(
                  top: topInset + (_chromeVisible ? 52 : 0),
                  left: 8,
                  right: 8,
                  child: _isBrunch
                      ? _BrunchLoginChip(
                          dark: _useDarkChrome,
                          onLogin: () async {
                            setState(() => _loading = true);
                            await controller.loadRequest(
                              Uri.parse(IsleWebviewFactory.brunchLoginUrl()),
                            );
                          },
                          onRemembered: () async {
                            await IsleUserDefaults.setBrunchLoginRemembered(
                                true);
                            if (mounted)
                              setState(() => _showLoginBanner = false);
                          },
                          onClose: () =>
                              setState(() => _showLoginBanner = false),
                        )
                      : _isInstagram
                          ? _InstagramLoginChip(
                              dark: _useDarkChrome,
                              onLogin: () async {
                                setState(() => _loading = true);
                                await controller.loadRequest(
                                  Uri.parse(InstagramWebConfig.loginUrl),
                                );
                              },
                              onSafariLogin: () => unawaited(
                                _openPasskeyLoginInSafari(youtube: false),
                              ),
                              onRemembered: () async {
                                await IsleUserDefaults
                                    .setInstagramLoginRemembered(true);
                                IsleWebSessionPersistenceService.scheduleSave();
                                if (mounted)
                                  setState(() => _showLoginBanner = false);
                              },
                              onClose: () async {
                                await IsleUserDefaults
                                    .setInstagramLoginChipDismissed(true);
                                if (mounted)
                                  setState(() => _showLoginBanner = false);
                              },
                            )
                          : _YoutubeLoginChip(
                              dark: _useDarkChrome,
                              onWebLogin: () async {
                                await IsleUserDefaults
                                    .setYoutubeLoginChipDismissed(true);
                                if (!mounted) return;
                                setState(() {
                                  _loading = true;
                                  _pendingYoutubeLogin = true;
                                  _showLoginBanner = false;
                                });
                                await controller.loadRequest(
                                  Uri.parse(
                                    'https://accounts.google.com/ServiceLogin?service=youtube&continue=https://m.youtube.com/',
                                  ),
                                );
                              },
                              onRemembered: () async {
                                await IsleUserDefaults
                                    .setYoutubeWebLoginRemembered(true);
                                await IsleUserDefaults
                                    .setYoutubeLoginChipDismissed(true);
                                IsleWebSessionPersistenceService.scheduleSave();
                                if (mounted) {
                                  setState(() {
                                    _showLoginBanner = false;
                                    _pendingYoutubeLogin = false;
                                  });
                                }
                              },
                              onClose: () async {
                                await IsleUserDefaults
                                    .setYoutubeLoginChipDismissed(true);
                                if (mounted)
                                  setState(() => _showLoginBanner = false);
                              },
                            ),
                ),
              if ((_chromeVisible && !_instagramImmersive && !_isInstagram) ||
                  _youtubeInlineMini) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _TopChrome(
                    topInset: topInset,
                    bg: _chromeBg,
                    fg: _chromeFg,
                    muted: _chromeMuted,
                    title: _youtubeInlineMini ? '탐색 · 재생 유지' : title,
                    channelLabel: _youtubeInlineMini
                        ? (_browseCurrentUrl.isNotEmpty
                            ? _browseCurrentUrl
                            : _channelSubtitle())
                        : _channelSubtitle(),
                    watchPlatform: _watchPlatform,
                    watchPulse: _watchUiPulse,
                    onBack: _isYoutube
                        ? _handleYoutubeBack
                        : (_isInstagram
                            ? _handleInstagramBack
                            : (widget.site == ExplorerSite.custom
                                ? _exitBrowserToHome
                                : _handleBrowserBack)),
                    backTooltip:
                        widget.site == ExplorerSite.custom ? '홈으로 나가기' : '뒤로',
                    onMinimize: _isYoutube
                        ? (_youtubeInlineMini
                            ? _exitYoutubeInlineMini
                            : (_isWatchPage
                                ? () => unawaited(_enterYoutubeInlineMini())
                                : _minimizeToFeed))
                        : null,
                    onMenu: _openChromeMenu,
                    onTabs: _supportsTabs ? _showTabSheet : null,
                    tabCount: _supportsTabs ? _tabs.length : null,
                    onShare: (ctx) => unawaited(_shareCurrentPage(ctx)),
                    onBlockPrefs: _isWatchPage ? _showYoutubeBlockPrefs : null,
                    onBlock: _isYoutube
                        ? _blockCurrentChannel
                        : (_isBrunch ? _blockBrunchAuthor : null),
                    onIsleQueue: _isYoutube
                        ? () {
                            if (mounted) showIsleYoutubeLibrarySheet(context);
                          }
                        : null,
                  ),
                ),
                if (!_isYoutube && !_isInstagram)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomChrome(
                      bottomInset: bottomInset,
                      bg: _chromeBg,
                      fg: _chromeFg,
                      muted: _chromeMuted,
                      urlLabel: _urlBarLabel(_currentUrl),
                      onUrlTap: _showBrowserUrlSheet,
                      onBack: () async {
                        await _handleBrowserBack();
                      },
                      onForward: () async {
                        if (await controller.canGoForward())
                          await controller.goForward();
                      },
                      onReload: () {
                        setState(() => _loading = true);
                        controller.reload();
                      },
                      onNewTab: _supportsTabs
                          ? () => unawaited(_openNewTab(switchToNew: true))
                          : null,
                      onTabs: _supportsTabs ? _showTabSheet : null,
                      tabCount: _supportsTabs ? _tabs.length : null,
                      onCollapse: () {
                        if (!_isInstagram)
                          setState(() => _chromeVisible = false);
                      },
                    ),
                  ),
              ] else ...[
                if ((_isYoutube && !_isWatchPage) ||
                    (_isInstagram && !_instagramImmersive))
                  Positioned(
                    top: cornerTop,
                    right: 8,
                    child: _FloatingBtn(
                      icon: Icons.more_vert,
                      onTap: _openChromeMenu,
                    ),
                  ),
                if (!_instagramImmersive)
                  Positioned(
                    top: cornerTop,
                    left: 8,
                    child: _FloatingBtn(
                      icon: Icons.arrow_back_ios_new,
                      onTap: () {
                        if (_isYoutube) {
                          unawaited(_handleYoutubeBack());
                        } else if (_isInstagram) {
                          unawaited(_handleInstagramBack());
                        } else if (widget.site == ExplorerSite.custom) {
                          _exitBrowserToHome();
                        } else {
                          context.pop();
                        }
                      },
                    ),
                  ),
                if (_watchPlatform != null &&
                    !_youtubeImmersive &&
                    !_isInstagram)
                  Positioned(
                    top: topInset + 8,
                    right: _isYoutube ? 104 : 8,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _watchUiPulse,
                      builder: (_, __, ___) => PlatformTimeLimitChip(
                        platform: _watchPlatform!,
                        compact: true,
                      ),
                    ),
                  ),
                if (_isYoutube &&
                    _isWatchPage &&
                    !_youtubeImmersive &&
                    !_youtubeInlineMini)
                  Positioned(
                    top: topInset + 8,
                    right: 56,
                    child: _FloatingBtn(
                      icon: Icons.keyboard_arrow_down,
                      onTap: () => unawaited(_enterYoutubeInlineMini()),
                    ),
                  ),
                if (_isWatchPage &&
                    !_youtubeSearchUiActive &&
                    !_youtubeInlineMini)
                  Positioned(
                    top: cornerTop,
                    right: 8,
                    child: _FloatingBtn(
                      icon: Icons.thumb_down_alt_outlined,
                      color: IsleColors.danger,
                      onTap: _showYoutubeBlockPrefs,
                    ),
                  ),
                if (!_isInstagram &&
                    !_youtubeImmersive &&
                    !_instagramImmersive &&
                    !igDmThread)
                  Positioned(
                    bottom: bottomInset + 12,
                    right: 12,
                    child: _FloatingBtn(
                      icon: Icons.unfold_more,
                      onTap: () => setState(() => _chromeVisible = true),
                    ),
                  ),
              ],
              if (_showYoutubeQuickBlockBar)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: YoutubeChannelQuickBar(
                    channelLabel: _probed.channelName.isNotEmpty
                        ? _probed.channelName
                        : _probed.channelId,
                    bottomInset: bottomInset,
                    onBlock: () => unawaited(_blockCurrentChannel()),
                    onSubscribe: () => unawaited(_subscribeCurrentSite()),
                    onDismiss: () =>
                        setState(() => _youtubeQuickBarDismissed = true),
                  ),
                ),
              if (_instagramImmersive) ...[
                Positioned(
                  top: cornerTop,
                  left: 8,
                  child: _InstagramChromeBtn(
                    icon: Icons.arrow_back_ios_new,
                    busy: _instagramNavBusy,
                    onTap: () => unawaited(_handleInstagramBack()),
                  ),
                ),
                Positioned(
                  top: cornerTop,
                  right: 8,
                  child: _InstagramChromeBtn(
                    icon: Icons.volume_up_rounded,
                    onTap: () => unawaited(_tryUnmuteInstagramVideo()),
                  ),
                ),
                if (_instagramSoundHint)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: bottomInset + 12,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => unawaited(_tryUnmuteInstagramVideo()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.volume_up_outlined,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '소리 없음? 여기 탭하거나 🔊 버튼을 눌러 보세요',
                                  style: IsleText.caption(color: Colors.white),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white70, size: 18),
                                onPressed: () =>
                                    setState(() => _instagramSoundHint = false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.topInset,
    required this.bg,
    required this.fg,
    required this.muted,
    required this.title,
    required this.onBack,
    required this.onMenu,
    required this.watchPulse,
    this.channelLabel,
    this.watchPlatform,
    this.onMinimize,
    this.onShare,
    this.onBlockPrefs,
    this.onBlock,
    this.onIsleQueue,
    this.onTabs,
    this.tabCount,
    this.backTooltip = '뒤로',
  });

  final double topInset;
  final Color bg;
  final Color fg;
  final Color muted;
  final String title;
  final String? channelLabel;
  final PlatformWatchId? watchPlatform;
  final ValueListenable<int> watchPulse;
  final VoidCallback onBack;
  final String backTooltip;
  final VoidCallback onMenu;
  final VoidCallback? onMinimize;
  final void Function(BuildContext anchor)? onShare;
  final VoidCallback? onBlockPrefs;
  final VoidCallback? onBlock;
  final VoidCallback? onIsleQueue;
  final VoidCallback? onTabs;
  final int? tabCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg.withValues(alpha: 0.94),
      child: Padding(
        padding: EdgeInsets.only(top: topInset, left: 4, right: 4, bottom: 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new, size: 20, color: fg),
              onPressed: onBack,
              tooltip: backTooltip,
              visualDensity: VisualDensity.compact,
            ),
            if (onMinimize != null)
              IconButton(
                icon: Icon(Icons.keyboard_arrow_down, size: 24, color: fg),
                tooltip: '탐색 모드 / 피드로',
                onPressed: onMinimize,
                visualDensity: VisualDensity.compact,
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: IsleText.caption(color: fg)
                          .copyWith(fontWeight: FontWeight.w600)),
                  if (channelLabel != null)
                    Text(
                      channelLabel!,
                      style: IsleText.caption(color: muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (watchPlatform != null) ...[
              const SizedBox(width: 4),
              ValueListenableBuilder<int>(
                valueListenable: watchPulse,
                builder: (_, __, ___) => PlatformTimeLimitChip(
                  platform: watchPlatform!,
                  compact: true,
                  fg: fg,
                  bg: muted.withValues(alpha: 0.25),
                ),
              ),
            ],
            if (onShare != null)
              IconButton(
                icon: Icon(Icons.ios_share, size: 22, color: fg),
                tooltip: '공유',
                onPressed: () => onShare!(context),
                visualDensity: VisualDensity.compact,
              ),
            if (onBlockPrefs != null)
              IconButton(
                icon: Icon(Icons.thumb_down_alt_outlined,
                    size: 22, color: IsleColors.danger),
                tooltip: '추천 줄이기',
                onPressed: onBlockPrefs,
                visualDensity: VisualDensity.compact,
              ),
            if (onIsleQueue != null)
              GestureDetector(
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  onIsleQueue!();
                },
                child: IconButton(
                  icon: const Icon(Icons.video_library_outlined,
                      size: 22, color: IsleColors.gold500),
                  tooltip: 'Isle 큐 · CC (길게 눌러도 열림)',
                  onPressed: onIsleQueue,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (onBlock != null)
              IconButton(
                icon: Icon(Icons.block_flipped, size: 22, color: fg),
                onPressed: onBlock,
                visualDensity: VisualDensity.compact,
              ),
            if (onTabs != null)
              IconButton(
                icon: Badge(
                  label: Text('${tabCount ?? 1}'),
                  isLabelVisible: (tabCount ?? 1) > 1,
                  child: Icon(Icons.tab, color: fg),
                ),
                onPressed: onTabs,
                visualDensity: VisualDensity.compact,
                tooltip: '탭',
              ),
            IconButton(
              icon: Icon(Icons.more_vert, color: fg),
              onPressed: onMenu,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.bottomInset,
    required this.bg,
    required this.fg,
    required this.muted,
    required this.urlLabel,
    required this.onUrlTap,
    required this.onBack,
    required this.onForward,
    required this.onReload,
    this.onNewTab,
    this.onTabs,
    this.tabCount,
    required this.onCollapse,
  });

  final double bottomInset;
  final Color bg;
  final Color fg;
  final Color muted;
  final String urlLabel;
  final VoidCallback onUrlTap;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;
  final VoidCallback? onNewTab;
  final VoidCallback? onTabs;
  final int? tabCount;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg.withValues(alpha: 0.94),
      child: Padding(
        padding:
            EdgeInsets.only(left: 2, right: 2, top: 2, bottom: bottomInset + 2),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: fg, size: 22),
              onPressed: onBack,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(Icons.arrow_forward, color: fg, size: 22),
              onPressed: onForward,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: fg, size: 22),
              onPressed: onReload,
              visualDensity: VisualDensity.compact,
            ),
            if (onNewTab != null)
              IconButton(
                icon: Icon(Icons.add_box_outlined, color: fg, size: 22),
                onPressed: onNewTab,
                visualDensity: VisualDensity.compact,
                tooltip: '새 탭',
              ),
            if (onTabs != null)
              IconButton(
                icon: Badge(
                  label: Text('${tabCount ?? 1}'),
                  isLabelVisible: (tabCount ?? 1) > 1,
                  child: Icon(Icons.tab, color: fg, size: 22),
                ),
                onPressed: onTabs,
                visualDensity: VisualDensity.compact,
                tooltip: '탭 목록',
              ),
            Expanded(
              child: Semantics(
                button: true,
                label: '주소창, $urlLabel',
                child: Material(
                  color: fg.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onUrlTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: IsleSize.minTouchTarget - 6,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 16, color: muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              urlLabel,
                              style: IsleText.caption(
                                  color: fg.withValues(alpha: 0.85)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.keyboard_arrow_down, color: fg),
              onPressed: onCollapse,
              visualDensity: VisualDensity.compact,
              tooltip: '숨기기',
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingBtn extends StatelessWidget {
  const _FloatingBtn({
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Colors.white;
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: accent, size: 22),
        ),
      ),
    );
  }
}

/// Instagram 릴스·DM 미디어 — 44pt 터치 + busy 표시
class _InstagramChromeBtn extends StatelessWidget {
  const _InstagramChromeBtn({
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: IsleSize.minTouchTarget,
          height: IsleSize.minTouchTarget,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _BrowserTabState {
  const _BrowserTabState({
    required this.id,
    required this.controller,
    required this.url,
    required this.loading,
  });

  final String id;
  final WebViewController controller;
  final String url;
  final bool loading;

  _BrowserTabState copyWith({
    String? url,
    bool? loading,
  }) {
    return _BrowserTabState(
      id: id,
      controller: controller,
      url: url ?? this.url,
      loading: loading ?? this.loading,
    );
  }
}

class _YoutubeLoginChip extends StatelessWidget {
  const _YoutubeLoginChip({
    required this.dark,
    required this.onWebLogin,
    required this.onRemembered,
    required this.onClose,
  });

  final bool dark;
  final VoidCallback onWebLogin;
  final VoidCallback onRemembered;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : IsleColors.ocean900;
    final accent = dark ? Colors.white : IsleColors.ocean700;
    return Material(
      color: dark ? const Color(0xFF272727) : IsleColors.ocean100,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.login, size: 16, color: IsleColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '유튜브 로그인 — Isle WebView에서만',
                    style: IsleText.caption(color: fg),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 18,
                      color: dark ? Colors.white54 : IsleColors.muted),
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onWebLogin,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child:
                        const Text('비밀번호로 로그인', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onRemembered,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('완료', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              PasskeyLoginService.passkeyDeniedMessage(youtube: true),
              style: IsleText.caption(
                  color: dark ? Colors.white38 : IsleColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrunchLoginChip extends StatelessWidget {
  const _BrunchLoginChip({
    required this.dark,
    required this.onLogin,
    required this.onRemembered,
    required this.onClose,
  });

  final bool dark;
  final VoidCallback onLogin;
  final VoidCallback onRemembered;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark ? const Color(0xFF1A3D32) : const Color(0xFFE8F8F2),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '브런치 로그인 — 이 기기에 세션이 유지됩니다',
              style: IsleText.caption(
                  color: dark ? Colors.white : IsleColors.ocean900),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                FilledButton(
                  onPressed: onLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00C389),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('로그인'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onRemembered,
                  child: Text(
                    '완료',
                    style: IsleText.caption(
                        color: dark ? Colors.white70 : IsleColors.ocean700),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 18,
                      color: dark ? Colors.white54 : IsleColors.muted),
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InstagramLoginChip extends StatelessWidget {
  const _InstagramLoginChip({
    required this.dark,
    required this.onLogin,
    required this.onSafariLogin,
    required this.onRemembered,
    required this.onClose,
  });

  final bool dark;
  final VoidCallback onLogin;
  final VoidCallback onSafariLogin;
  final VoidCallback onRemembered;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final safariBlocked = InstagramSafariLaunchGuard.isEscapeBlocked;
    return Material(
      color: dark ? const Color(0xFF3D1A2E) : const Color(0xFFFDF2F7),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              safariBlocked
                  ? '차단·한도 중에는 ${PlatformBlockCopy.externalPasskeyBrowserName}가 막혀 있어요. 「앱 안 로그인」만 사용하세요.'
                  : '패스키·2FA는 ${PlatformBlockCopy.externalPasskeyBrowserName} 권장 — 로그인 후 WebView로 연결',
              style: IsleText.caption(
                  color: dark ? Colors.white : IsleColors.ocean900),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!safariBlocked)
                  FilledButton(
                    onPressed: onSafariLogin,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE1306C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                        '패스키 (${PlatformBlockCopy.externalPasskeyBrowserName})'),
                  ),
                OutlinedButton(
                  onPressed: onLogin,
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('앱 안 로그인'),
                ),
                TextButton(
                  onPressed: onRemembered,
                  child: Text(
                    '로그인 완료',
                    style: IsleText.caption(
                        color: dark ? Colors.white70 : IsleColors.ocean700),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 18,
                      color: dark ? Colors.white54 : IsleColors.muted),
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
