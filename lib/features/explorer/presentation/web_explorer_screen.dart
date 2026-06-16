import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
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
import '../../../core/guard/isle_content_block_guard.dart';
import '../../../core/guard/isle_playback_guard.dart';
import '../../../core/feed/feed_ingest_service.dart';
import '../../../core/library/engagement_tracker.dart';
import '../../../core/library/platform_watch_limit_store.dart';
import '../../../core/library/youtube_watch_history_service.dart';
import '../../../core/navigation/isle_routes.dart';
import '../../../core/platform/ios_screen_time_service.dart';
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
import '../../../core/safety/content_safety_guard.dart';
import '../../../core/services/isle_external_launch_guard.dart';
import '../../../core/youtube/youtube_block_reapply_hub.dart';
import '../../../core/youtube/youtube_channel_block_guard.dart';
import '../../../core/youtube/youtube_channel_probe_script.dart';
import '../../../core/youtube/youtube_viewport_script.dart';
import '../../../core/youtube/youtube_playback_error_probe.dart';
import '../../../core/youtube/youtube_search_ui_probe.dart';
import '../../../core/youtube/youtube_nav_policy.dart';
import '../../../core/social/instagram_auth_service.dart';
import '../../../core/social/instagram_following_store.dart';
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
import '../../../core/youtube/youtube_system_auth_service.dart';
import '../../../core/youtube/youtube_session.dart';
import '../../../core/youtube/youtube_webview_factory.dart';
import '../../youtube/presentation/widgets/isle_youtube_library_sheet.dart';
import '../../youtube/presentation/widgets/block_channel_sheet.dart';
import '../../youtube/presentation/widgets/youtube_creator_insight_sheet.dart';
import '../../youtube/presentation/widgets/platform_watch_limit_overlay.dart';
import '../../youtube/presentation/widgets/youtube_os_webview_recovery_bar.dart';
import '../../youtube/presentation/widgets/youtube_inline_mini.dart';
import '../../../core/services/isle_app_log_service.dart';
import '../../../shared/widgets/isle_sheet.dart';
import '../../../shared/widgets/platform_time_limit_chip.dart';
import '../../../core/block_schedule/schedule_active_service.dart';
import '../../../core/block_schedule/schedule_app_targets_store.dart';
import '../../../core/block_schedule/schedule_bundle_usage_store.dart';
import '../../../core/youtube/youtube_clipboard_quick_actions.dart';
import '../../../core/youtube/youtube_clipboard_watch.dart';
import '../../youtube/presentation/widgets/youtube_channel_quick_bar.dart';
import '../../../core/youtube/youtube_music_route.dart';
import '../../../core/youtube/youtube_url_redirect.dart';
import '../../settings/presentation/widgets/schedule_isle_block_overlay.dart';
import '../../../shared/widgets/web_playback_recovery_overlay.dart';

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
    this.loginOnly = false,
  });

  final ExplorerSite site;
  final String? initialUrl;
  final String? title;
  final bool autoLogin;
  final bool brunchPromptLogin;
  final bool instagramDmOnly;
  /// 로그인 전용 — 스케줄·시청 한도 진입 차단 우회
  final bool loginOnly;

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
  YoutubePageChannel _probed = const YoutubePageChannel(channelId: '', channelName: '');
  String _brunchHandle = '';
  String _brunchAuthorName = '';
  late final DateTime _openedAt;
  Timer? _injectDebounce;
  Timer? _watchTick;
  bool _appActive = true;
  late final IslePlaybackGuard _playbackGuard;
  IslePlaybackRecoveryState _recovery = const IslePlaybackRecoveryState.idle();
  bool _useAltUserAgent = false;
  bool _youtubeSearchUiActive = false;
  bool _pendingYoutubeLogin = false;
  bool _youtubeInlineMini = false;
  String? _lastInstagramDmDenialPath;
  Timer? _loadingFailsafe;
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

  ExplorerSite get _scheduleOverlaySite =>
      (_isSafariYoutube || (widget.site == ExplorerSite.custom && _embeddedYoutubeActive))
          ? ExplorerSite.youtube
          : widget.site;

  ExplorerSite get _injectSite =>
      _isSafariYoutube ? ExplorerSite.youtube : widget.site;

  PlatformWatchId? get _watchPlatform {
    if (_isSafariYoutube ||
        (widget.site == ExplorerSite.custom && _embeddedYoutubeActive)) {
      return PlatformWatchId.youtube;
    }
    if (_isInstagram) {
      return widget.instagramDmOnly
          ? PlatformWatchId.instagramDm
          : PlatformWatchId.instagram;
    }
    return PlatformWatchLimitStore.fromExplorerSiteName(widget.site.name);
  }
  bool get _isWatchPage =>
      (_isYoutube || _isSafariYoutube) &&
      (_currentUrl.contains('watch?v=') || _currentUrl.contains('/shorts/'));

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
    await c.runJavaScript('if(window.__isleIgSaveDmScroll)window.__isleIgSaveDmScroll();');
  }

  Future<void> _restoreInstagramDmScroll([WebViewController? target]) async {
    final c = target ?? _controller;
    if (c == null || !_isInstagram) return;
    await c.runJavaScript(InstagramDmFocusScript.restoreScrollAndViewport);
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

  Future<String> _readSavedInstagramDmThreadUrl([WebViewController? target]) async {
    final c = target ?? _controller;
    if (c == null) return '';
    final raw = await _instagramJsWithTimeout(
      c.runJavaScriptReturningResult(InstagramDmNavigationScript.readSavedThreadUrl),
    );
    if (raw == null) return '';
    return raw.toString().replaceAll('"', '').trim();
  }

  Future<bool> _tryDismissInstagramMediaViewer([WebViewController? target]) async {
    final c = target ?? _controller;
    if (c == null) return false;
    for (var attempt = 0; attempt < 2; attempt++) {
      final raw = await _instagramJsWithTimeout(
        c.runJavaScriptReturningResult(InstagramDmNavigationScript.tryDismissMediaViewer),
        timeout: const Duration(seconds: 3),
      );
      if (raw == null) continue;
      final result = raw.toString().replaceAll('"', '').trim();
      if (result == 'dismissed' ||
          result == 'history' ||
          result == 'escape') {
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
        now.difference(_instagramEdgeSwipeAt!) < const Duration(milliseconds: 500)) {
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

  bool _isYoutubeSearchUrl(String url) => YoutubeNavPolicy.isSearchResultsUrl(url);

  /// 검색·홈·채널 — 시청 페이지가 아닐 때 로딩·자동복구 오버레이 숨김
  bool get _hideYoutubeLoadingOverlay =>
      _isYoutube &&
      (YoutubeNavPolicy.isBrowseSurface(_currentUrl) ||
          _youtubeSearchUiActive ||
          _isYoutubeSearchUrl(_currentUrl));

  bool get _showBlockingLoadOverlay =>
      _loading &&
      !_hideYoutubeLoadingOverlay &&
      !_recovery.showOverlay &&
      !_recovery.showRecoveringOverlay;

  void _clearLoadingSoon() {
    _loadingFailsafe?.cancel();
    final ms = _isYoutube &&
            (YoutubeNavPolicy.isBrowseSurface(_currentUrl) ||
                _youtubeSearchUiActive ||
                _isYoutubeSearchUrl(_currentUrl))
        ? 600
        : 1200;
    _loadingFailsafe = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      if (_isYoutube &&
          (YoutubeNavPolicy.isBrowseSurface(_currentUrl) ||
              _youtubeSearchUiActive ||
              _isYoutubeSearchUrl(_currentUrl))) {
        _clearYoutubeBrowseLoading();
      }
      if (_isInstagram && widget.instagramDmOnly) {
        setState(() => _loading = false);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(hit.snackMessage)),
    );
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
    if (_applyContentSafetyUrl(url, controller: controller)) return true;
    if (_applyBlockedUrlPolicy(url, controller: controller)) return true;
    if (_applyScheduleWebBlockUrl(url, controller: controller)) return true;
    return _applyWebsiteBlockUrl(url, controller: controller);
  }

  bool _applyScheduleWebBlockUrl(String url, {WebViewController? controller}) {
    final hit = ScheduleWebBlockGuard.matchUrl(url);
    if (hit == null) return false;
    unawaited(_redirectScheduleWebBlocked(hit, controller: controller));
    return true;
  }

  Future<void> _redirectScheduleWebBlocked(
    ScheduleWebBlockHit hit, {
    WebViewController? controller,
  }) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(hit.snackMessage)),
    );
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
    unawaited(_redirectWebsiteBlocked(hit, controller: controller));
    return true;
  }

  Future<void> _redirectWebsiteBlocked(
    WebsiteBlockHit hit, {
    WebViewController? controller,
  }) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(hit.snackMessage)),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hit.snackMessage),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      ),
    );
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
    final back = _blockedYoutubeRedirectUrl();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hit.snackMessage),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      ),
    );
    IsleAppLogService.log('YouTube block redirect: ${hit.kind.name} ${hit.label}');
    await c.loadRequest(Uri.parse(back));
    if (mounted && updateCurrentUrl) setState(() => _currentUrl = back);
    if (mounted && !updateCurrentUrl) setState(() => _browseCurrentUrl = back);
  }

  Future<void> _enforceBlockedEmbed(YoutubeBlockHit hit) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hit.snackMessage),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      ),
    );
    IsleAppLogService.log('YouTube embed block: ${hit.kind.name} ${hit.label}');
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
            if (IsleUserDefaults.trackYoutubeWatchHistory) {
              YoutubeWatchHistoryService.scheduleFromUrl(
                'https://www.youtube.com/watch?v=${ch.videoId}',
              );
            }
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
      (_isWatchPage || _youtubeSearchUiActive || _isYoutubeSearchUrl(_currentUrl));

  bool get _showYoutubeQuickBlockBar =>
      _isYoutube &&
      !_showLoginBanner &&
      !_youtubeQuickBarDismissed &&
      !_youtubeInlineMini &&
      !_currentUrl.contains('accounts.google.com') &&
      !_probed.isEmpty &&
      (YoutubeNavPolicy.isChannelUrl(_currentUrl) || _isWatchPage);
  bool get _useDarkChrome => IsleUserDefaults.explorerChromeDark;

  Color get _chromeBg => _useDarkChrome ? const Color(0xFF0F0F0F) : Colors.white;
  Color get _chromeFg => _useDarkChrome ? Colors.white : IsleColors.ocean900;
  Color get _chromeMuted => _useDarkChrome ? Colors.white70 : IsleColors.muted;

  SystemUiOverlayStyle get _overlayStyle => _useDarkChrome
      ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
      : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    _chromeVisible = !_isYoutube;
    _showLoginBanner = (_isYoutube &&
            (widget.autoLogin || !IsleUserDefaults.youtubeWebLoginRemembered)) ||
        (_isBrunch &&
            widget.brunchPromptLogin &&
            !IsleUserDefaults.brunchLoginRemembered) ||
        (_isInstagram && !IsleUserDefaults.instagramLoginRemembered);
    if (widget.autoLogin && _isYoutube) _pendingYoutubeLogin = true;
    if (_isYoutube) {
      final restored = YoutubeSession.instance.takeControllerForRoute();
      if (restored != null) {
        _controller = restored;
        _currentUrl = YoutubeSession.instance.currentUrl;
        _probed = YoutubeSession.instance.probed;
        _attachRestoredYoutubeController(restored);
        YoutubeWebviewEnergy.register(restored);
        _loading = false;
        unawaited(_reapplyYoutubeBlocks());
        final restoredHit = _matchYoutubeBlock(YoutubeSession.instance.currentUrl);
        if (restoredHit != null) {
          unawaited(_redirectBlockedYoutube(restoredHit));
        }
      } else {
        _initWebView();
      }
    } else {
      _initTabbedBrowser();
    }
    _syncWatchTimer();
    if (_isYoutube || widget.site == ExplorerSite.custom) {
      YoutubeBlockReapplyHub.register(_reapplyYoutubeBlocks);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.loginOnly) return;
      final deny = ExplorerEntryGuard.denyMessageForSite(
        widget.site,
        url: _currentUrl,
      );
      if (deny != null) {
        IsleAppLogService.log(
          'WebExplorer entry denied: $deny url=$_currentUrl',
          level: IsleLogLevel.warn,
        );
        ExplorerEntryGuard.showDenial(
          context,
          deny,
          url: _currentUrl,
          site: widget.site,
        );
        if (mounted) context.pop();
      }
    });
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
      if (ContentSafetyGuard.matchUrl(u) != null ||
          WebsiteBlockGuard.matchUrl(u) != null) {
        return widget.site == ExplorerSite.custom
            ? SafariWebConfig.homeUrl
            : widget.site.defaultHomeUrl;
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
    if (_isInstagram) return widget.instagramDmOnly ? 'isle_instagram_dm' : 'isle_instagram';
    if (_isBrunch) return 'isle_brunch';
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
    }
  }

  void _tickScheduleBundleUsage() {
    final targetId = _isleTargetIdForSite();
    if (targetId == null) return;
    for (final s in ScheduleActiveService.activeSchedulesNow()) {
      final e = ScheduleAppTargetsStore.entryFor(s.id, targetId);
      if (e == null || !e.limitEnabled) continue;
      ScheduleBundleUsageStore.addIsleTargetSeconds(
        s.id,
        targetId,
        e.windowMinutes,
        1,
      );
    }
  }

  void _startWatchTimer() {
    _watchTick?.cancel();
    _watchTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_appActive) return;
      final platform = _watchPlatform;
      if (platform == null) return;
      _tickScheduleBundleUsage();
      if (platform == PlatformWatchId.youtube) {
        // 잠금(한도 도달·스케줄)이면 상주 JS 가드를 켠다. 매 tick 토글이라 전체
        // 리로드 후에도 1초 내 가드 재설치 + 플래그 재확정 → 무조건 enforce.
        _applyPlaybackBlock(YoutubeAccessGuard.shouldBlockWebView);
        if (!YoutubeAccessGuard.shouldCountWatchTime) {
          setState(() {});
          return;
        }
        PlatformWatchLimitStore.addSeconds(platform, 1);
      } else if (!PlatformWatchLimitStore.isLimitReached(platform)) {
        _applyPlaybackBlock(false);
        PlatformWatchLimitStore.addSeconds(platform, 1);
      } else {
        // 인스타·브런치 한도 도달: 릴스 등 자동재생 영상도 동일 가드로 정지
        _applyPlaybackBlock(true);
      }
      if (mounted) setState(() {});
    });
  }

  /// 상주 재생 가드 토글. 상태가 바뀔 때만 JS 호출하되, 잠금(true)일 때는 매번
  /// 호출해 전체 리로드(가드 소실) 후에도 1초 내 재설치되도록 한다.
  bool? _playbackBlocked;
  void _applyPlaybackBlock(bool blocked) {
    if (!blocked && _playbackBlocked == false) {
      final browse = _browseController;
      if (browse == null) return;
      unawaited(YoutubeWebviewEnergy.setPlaybackBlocked(browse, false));
      return;
    }
    _playbackBlocked = blocked;
    unawaited(YoutubeWebviewEnergy.setPlaybackBlocked(_controller, blocked));
    final browse = _browseController;
    if (browse != null) {
      unawaited(YoutubeWebviewEnergy.setPlaybackBlocked(browse, blocked));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _appActive = false;
      YoutubeWebviewEnergy.pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      _appActive = true;
      unawaited(YoutubeWebviewEnergy.resumeAll());
      _playbackGuard.reset();
      if (mounted) {
        setState(() => _recovery = const IslePlaybackRecoveryState.idle());
      }
      if (_isYoutube && mounted) {
        unawaited(_maybeOfferClipboardActions());
      }
    }
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
        final isLoginPage = url.contains('accounts.google.com') ||
            url.contains('ServiceLogin') ||
            url.contains('google.com/signin');
        if (isLoginPage) {
          _showLoginBanner = true;
          _chromeVisible = true;
          _youtubeSearchUiActive = false;
        } else if (url.contains('youtube.com')) {
          if (_pendingYoutubeLogin) {
            _pendingYoutubeLogin = false;
            unawaited(IsleUserDefaults.setYoutubeWebLoginRemembered(true));
            _showLoginBanner = false;
          } else if (IsleUserDefaults.youtubeWebLoginRemembered) {
            _showLoginBanner = false;
          }
          if (_isWatchPage || _isYoutubeSearchUrl(url) || _youtubeSearchUiActive) {
            _chromeVisible = false;
          }
        }
      }
      if (_isBrunch && url.contains('brunch.co.kr') && !url.contains('/login')) {
        IsleUserDefaults.setBrunchLoginRemembered(true);
        _showLoginBanner = false;
      }
      if (_isInstagram && url.contains('instagram.com') && !url.contains('/accounts/login')) {
        IsleUserDefaults.setInstagramLoginRemembered(true);
        _showLoginBanner = false;
        _maybeCaptureInstagramHandle(url);
      }
    });
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
        }
      }
      if (_isInstagram && widget.instagramDmOnly) {
        final p = Uri.tryParse(url)?.path.toLowerCase() ?? '';
        if (_isInstagramMediaPath(p)) {
          unawaited(_saveInstagramDmScroll());
        }
        if (!_instagramDmFocusAllowsPath(p)) {
          if (_lastInstagramDmDenialPath != p) {
            _lastInstagramDmDenialPath = p;
            IsleAppLogService.log(
              'Instagram DM denial: blocked path=$p url=$url → inbox',
              level: IsleLogLevel.warn,
            );
          }
          if (mounted) setState(() => _loading = false);
          if (mounted && _controller != null) {
            unawaited(_controller!.loadRequest(Uri.parse(InstagramWebConfig.dmInboxUrl)));
          }
          return;
        }
        _lastInstagramDmDenialPath = null;
      }
    if (widget.site == ExplorerSite.custom &&
        YoutubeUrlRedirect.isYoutubeUrl(url)) {
      final blockHit = _matchYoutubeBlock(url);
      if (blockHit != null) {
        unawaited(_redirectBlockedYoutube(blockHit));
        return;
      }
    }
    if ((_isYoutube || _isSafariYoutube) && url.contains('youtube.com')) {
      final blockHit = _matchYoutubeBlock(url);
      if (blockHit != null) {
        unawaited(_redirectBlockedYoutube(blockHit));
        return;
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
      if (IsleUserDefaults.trackYoutubeWatchHistory) {
        YoutubeWatchHistoryService.scheduleFromUrl(url);
      }
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
        final ua = _useAltUserAgent ? kYoutubeAndroidUserAgent : kYoutubeSafariUserAgent;
        await controller.setUserAgent(ua);
      } else {
        final ua = _useAltUserAgent
            ? (Platform.isAndroid ? kSafariUserAgent : kAndroidUserAgent)
            : (Platform.isIOS || Platform.isMacOS ? kSafariUserAgent : kAndroidUserAgent);
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
      ),
    );
  }

  /// 동일 WebViewController에 JS 채널 중복 등록 방지 (최소화→복귀 크래시)
  static final _youtubeJsChannelWired = <int>{};

  void _wireYoutubeJsChannels(WebViewController controller, {required bool attachPlayback}) {
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
      onUrlChanged: _isYoutube ? (url) => _handleUrlChanged(url) : _handleUrlChanged,
      onPageReady: _onPageReady,
      onYoutubeChannelProbe:
          (_isYoutube || widget.site == ExplorerSite.custom) ? _onChannelProbeMessage : null,
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
    final startUrl = (url?.trim().isNotEmpty ?? false) ? url!.trim() : _resolveStartUrl();
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
    );
    YoutubeWebviewEnergy.register(controller);
    if (_isInstagram) _wireInstagramJsChannels(controller);
    if (widget.site == ExplorerSite.custom) _wireEmbedSurfaceChannel(controller);
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
      final tab = _tabs[idx];
      _tabs[idx] = tab.copyWith(url: url);
      if (idx == _activeTabIndex) {
        _currentUrl = url;
      }
    });
    if (idx == _activeTabIndex) {
      _syncWatchTimer();
      if (widget.site == ExplorerSite.custom) {
        if (SafariWebConfig.isGoogleSearchUrl(url)) {
          unawaited(_injectSearchBlockEarly(source, url));
        }
        if (_applyUrlPolicy(url, controller: source)) {
          return;
        }
      }
      if (_isSafariYoutube && url.contains('youtube.com')) {
        final blockHit = _matchYoutubeBlock(url);
        if (blockHit != null) {
          unawaited(_redirectBlockedYoutube(blockHit));
          return;
        }
        if (!YoutubeNavPolicy.isWatchUrl(url) && !_isYoutubeSearchUrl(url)) {
          _preWatchBrowseUrl = url;
        }
        _scheduleContentRefresh();
        unawaited(_injectBlocks(source));
        if (YoutubeNavPolicy.isWatchUrl(url)) unawaited(_probeChannelOn(source));
      }
    }
    if (_isInstagram) {
      _trackInstagramDmUrl(url);
      final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
      if (_isInstagramMediaPath(path)) {
        if (mounted) {
          setState(() {
            _chromeVisible = false;
            _instagramMediaViewerOpen = true;
          });
        }
        unawaited(_saveInstagramDmScroll(source));
        if (_shouldInjectInstagramComments(path)) {
          unawaited(source.runJavaScript(InstagramPostCommentsScript.install));
        }
      }
    }
    if (_isInstagram && widget.instagramDmOnly) {
      final p = Uri.tryParse(url)?.path.toLowerCase() ?? '';
      if (!_instagramDmFocusAllowsPath(p)) {
        IsleAppLogService.log(
          'Instagram DM denial(tab): blocked path=$p url=$url',
          level: IsleLogLevel.warn,
        );
        if (mounted) setState(() => _loading = false);
        unawaited(source.loadRequest(Uri.parse(InstagramWebConfig.dmInboxUrl)));
      }
    }
    if (_isBrunch || url.contains('blog.naver') || url.contains('velog.io') || url.contains('tistory.com')) {
      _scheduleContentRefresh();
    }
  }

  Future<void> _onTabPageReady(WebViewController source) async {
    if (!mounted) return;
    await _injectBlocks(source);
    if (!mounted) return;
    if (_isBrunch) {
      await source.runJavaScript(BrunchAuthorProbeScript.probeAndPost);
    }
    final idx = _tabs.indexWhere((t) => identical(t.controller, source));
    if (idx == -1 || !mounted) return;
    if (idx == _activeTabIndex &&
        _isSafariYoutube &&
        YoutubeNavPolicy.isWatchUrl(_currentUrl)) {
      await _probeChannelOn(source);
    }
    setState(() {
      final tab = _tabs[idx];
      _tabs[idx] = tab.copyWith(loading: false);
      if (idx == _activeTabIndex) {
        _loading = false;
      }
    });
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
                        i == _activeTabIndex ? Icons.radio_button_checked : Icons.tab,
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
    _injectDebounce = Timer(Duration(milliseconds: browse ? 750 : 350), () {
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
        unawaited(_redirectBlockedYoutube(hit));
        return;
      }
      final ch = YoutubePageChannel.fromJson(j);
      if (_youtubeRulesApply && ch.isWatchPage) {
        final hit = _matchYoutubeBlock(_currentUrl, probe: ch);
        if (hit != null) {
          if (widget.site == ExplorerSite.custom &&
              !YoutubeUrlRedirect.isYoutubeUrl(_currentUrl)) {
            unawaited(_enforceBlockedEmbed(hit));
          } else {
            unawaited(_redirectBlockedYoutube(hit));
          }
          return;
        }
      }
      if (mounted && (!ch.isEmpty || ch.isWatchPage)) setState(() => _probed = ch);
      // 시청 이력 항목에 채널·제목 메타 자동 첨부 (피드 추천에 활용)
      if ((_isYoutube ||
              (widget.site == ExplorerSite.custom && ch.isWatchPage)) &&
          ch.videoId.length == 11) {
        unawaited(IsleUserDefaults.setYoutubeWebLoginRemembered(true));
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
    const skip = {'p', 'reel', 'reels', 'stories', 'explore', 'accounts', 'direct'};
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
    // 새 페이지/전체 리로드 직후 상주 재생 가드 즉시 재설치 (잠금 상태면 바로 정지).
    if (_watchPlatform == PlatformWatchId.youtube) {
      _applyPlaybackBlock(YoutubeAccessGuard.shouldBlockWebView);
    }
    final youtubeSearchPage =
        _isYoutube && (_isYoutubeSearchUrl(_currentUrl) || _youtubeSearchUiActive);
    if (mounted) setState(() => _loading = false);
    _clearLoadingSoon();
    if (youtubeSearchPage) {
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
      final path = Uri.tryParse(_currentUrl)?.path ?? '';
      if (_isInstagramDmThreadPath(path)) {
        await _restoreInstagramDmScroll();
      }
    }
    if (_isBrunch) await _probeBrunchAuthor();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _finishYoutubePageReady({required bool light}) async {
    if (!mounted) return;
    await _hideYoutubeOpenApp();
    await _installYoutubeSearchWatcher();
    if (mounted) await _applyYoutubeViewportPad();
    if (!light) {
      await _probeChannel();
      final c = _controller;
      if (c != null) await YoutubePlaybackErrorProbe.inject(c);
      unawaited(_injectBlocks());
      _scheduleClipboardOffer();
      return;
    }
    // 검색·탐색: 결과 DOM이 그려진 뒤 차단 스크립트 — 로드 중 reload/버퍼링 루프 방지
    _injectDebounce?.cancel();
    _injectDebounce = Timer(const Duration(milliseconds: 900), () {
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
    final c = _controller;
    if (c == null || !_isYoutube) return;
    if (_isYoutubeSearchUrl(_currentUrl) || _youtubeSearchUiActive) return;
    final topInset = MediaQuery.paddingOf(context).top;
    final chromeH = (_chromeVisible && !_youtubeImmersive) ? 44.0 : 0.0;
    final top = _youtubeImmersive ? topInset : topInset + chromeH;
    final bottom = MediaQuery.paddingOf(context).bottom;
    await c.runJavaScript(
      YoutubeViewportScript.applyPadding(topPx: top, bottomPx: bottom),
    );
  }

  Future<void> _installYoutubeSearchWatcher() async {
    final c = _controller;
    if (c == null || !_isYoutube) return;
    await c.runJavaScript(YoutubeSearchUiProbe.installWatcher);
  }

  Future<void> _injectSearchBlockEarly(
    WebViewController controller,
    String url,
  ) async {
    if (!mounted || widget.site != ExplorerSite.custom) return;
    final userKeywords = ref.read(blockedKeywordsProvider);
    final blockedKeywords = ContentSafetyGuard.enabled
        ? {
            ...userKeywords,
            ...ContentSafetyGuard.builtInYoutubeKeywords,
          }.toList()
        : userKeywords;
    final blockedUrls =
        BlockedUrlGuard.jsPayload(ref.read(blockedUrlsProvider)).urls;
    if (!SearchBlockEarlyInject.shouldInject(
      url,
      keywords: blockedKeywords,
      urls: blockedUrls,
    )) {
      return;
    }
    await SearchBlockEarlyInject.inject(
      controller,
      url,
      keywords: blockedKeywords,
      urls: blockedUrls,
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
          }.toList()
        : userKeywords;
    final blockedKeywords = BlockKeywordPolicy.forYoutubeInject(rawKeywords);
    final blockedUrls =
        BlockedUrlGuard.jsPayload(ref.read(blockedUrlsProvider)).urls;
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
    try {
      await IsleWebviewFactory.injectBlocks(
        c,
        site,
        youtubeChannels: youtubeChannels,
        blockedVideoIds: blockedVideoIds,
        blockedKeywords: blockedKeywords,
        blockedUrls: blockedUrls,
        brunchAuthors: brunchAuthors,
        instagramDmOnly: dmOnly,
        youtubeBlockLightMode: light,
        pageUrl: urlForLight,
        youtubePlaybackBlocked: YoutubeAccessGuard.shouldBlockWebView,
      );
    } finally {
      if (mounted &&
          _isYoutube &&
          (YoutubeNavPolicy.isBrowseSurface(_currentUrl) ||
              _isYoutubeSearchUrl(_currentUrl))) {
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
    if (!_isYoutube || !_isWatchPage || _controller == null || _youtubeInlineMini) return;
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
    IsleAppLogService.log('YouTube inline mini: browse=$browseStart watch=$_currentUrl');
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

  String _youtubeParkTitle() => _probed.videoTitle.isNotEmpty
      ? _probed.videoTitle
      : (_probed.channelName.isNotEmpty ? _probed.channelName : '유튜브');

  void _parkYoutubeController(WebViewController c) {
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
    _parkYoutubeController(c);
    if (mounted) context.go('/feed');
  }

  void _quitYoutube() {
    HapticFeedback.heavyImpact();
    _leavingMinimized = false;
    YoutubeSession.instance.quit();
    if (mounted) context.go('/feed');
  }

  Future<void> _showFeedBoost() async {
    if (!_isYoutube) return;
    await _probeChannel();
    if (!mounted) return;
    if (!_isWatchPage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영상을 재생 중일 때 사용할 수 있어요')),
      );
      return;
    }
    await showYoutubeWatchPrefSheet(
      context,
      watch: _probed,
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
    await _probeChannel();
    if (!mounted) return;
    final result = await showBlockChannelSheet(
      context,
      channelId: _probed.channelId,
      channelName: _probed.channelName,
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
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('저장')),
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
              ? '「${terms.first}」 포함 검색 결과를 Safari에서 숨겨요'
              : '「${terms.join(' · ')}」 포함 결과를 Safari에서 숨겨요',
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
      await ref.read(blockedVideosProvider.notifier).addVideo(vid, sourceUrl: url);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$deny · 다른 앱으로 공유할 수 없어요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    HapticFeedback.lightImpact();
    final title = _isYoutube
        ? (_probed.videoTitle.isNotEmpty
            ? _probed.videoTitle
            : (_probed.channelName.isNotEmpty ? _probed.channelName : 'YouTube'))
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
    if (ContentSafetyGuard.matchUrl(url) != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('안전 모드: 성인 사이트는 열 수 없어요')),
        );
      }
      url = SafariWebConfig.homeUrl;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blockHit.snackMessage)),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
  }

  String? _channelSubtitle() {
    if (_isYoutube && _probed.channelName.isNotEmpty) return _probed.channelName;
    if (_isBrunch && _brunchAuthorName.isNotEmpty) return _brunchAuthorName;
    if (_isBrunch && _brunchHandle.isNotEmpty) return '@$_brunchHandle';
    if (_isInstagram && widget.instagramDmOnly) {
      return InstagramDmPathPolicy.chromeHintForPath(
        Uri.tryParse(_currentUrl)?.path ?? '',
      );
    }
    return null;
  }

  Future<void> _openChromeMenu() async {
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
              title: Text('크롬 색', style: IsleText.body(color: _chromeFg)),
              subtitle: Text(
                _useDarkChrome ? '다크 (시계 잘 보임)' : '라이트',
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
                leading: Icon(Icons.video_library_outlined, color: IsleColors.gold500),
                title: Text('Isle 큐 · CC 기사', style: IsleText.body(color: _chromeFg)),
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
                  leading: Icon(Icons.picture_in_picture_alt_outlined, color: _chromeFg),
                  title: Text('탐색 모드 (미니 플레이어)', style: IsleText.body(color: _chromeFg)),
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
                leading: const Icon(Icons.stop_circle_outlined, color: IsleColors.danger),
                title: Text('유튜브 끄기', style: IsleText.body(color: _chromeFg)),
                onTap: () {
                  Navigator.pop(ctx);
                  _quitYoutube();
                },
              ),
              if (_isWatchPage)
                ListTile(
                  leading: Icon(Icons.auto_awesome, color: _chromeFg),
                  title: Text('크리에이터 분석 (CC)', style: IsleText.body(color: _chromeFg)),
                  subtitle: Text(
                    '차별점 · 핵심 · 관심 분야 적용',
                    style: IsleText.caption(color: _chromeMuted),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    showYoutubeCreatorInsightSheet(context, ref, initialUrl: _currentUrl);
                  },
                ),
              if (_isWatchPage)
                ListTile(
                  leading: const Icon(Icons.thumb_up_alt_outlined, color: IsleColors.gold500),
                  title: Text('콘텐츠 취향', style: IsleText.body(color: _chromeFg)),
                  subtitle: Text(
                    '채널 또는 스타일 선택',
                    style: IsleText.caption(color: _chromeMuted),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showFeedBoost();
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
                  context.push(IsleRoutes.blockSchedules);
                },
              ),
              ListTile(
                leading: Icon(Icons.content_paste_go, color: _chromeFg),
                title: Text('복사한 URL 보기', style: IsleText.body(color: _chromeFg)),
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
                title: Text('피드에 구독 추가', style: IsleText.body(color: _chromeFg)),
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
            if (_isInstagram && widget.instagramDmOnly) ...[
              ListTile(
                leading: const Icon(Icons.person_outline, color: Color(0xFFE1306C)),
                title: Text('상대 프로필 · 게시물', style: IsleText.body(color: _chromeFg)),
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
                  title: Text('DM 대화로 돌아가기', style: IsleText.body(color: _chromeFg)),
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
                    unawaited(c.loadRequest(Uri.parse(InstagramWebConfig.dmInboxUrl)));
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
                title: Text('차단 URL 관리', style: IsleText.body(color: _chromeFg)),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_openBlockedUrlSheet());
                },
              ),
              if (SafariWebConfig.isGoogleSearchUrl(_currentUrl)) ...[
                ListTile(
                  leading: Icon(Icons.search_off, color: _chromeFg),
                  title: Text('이 검색어 결과 숨기기', style: IsleText.body(color: _chromeFg)),
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
                  title: Text('숨길 키워드 관리', style: IsleText.body(color: _chromeFg)),
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
                title: Text('차단 URL 관리', style: IsleText.body(color: _chromeFg)),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_openBlockedUrlSheet());
                },
              ),
            ],
            if (!_isYoutube)
              ListTile(
                leading: Icon(Icons.rss_feed, color: _chromeFg),
                title: Text('피드에 구독 추가', style: IsleText.body(color: _chromeFg)),
                onTap: () {
                  Navigator.pop(ctx);
                  _subscribeCurrentSite();
                },
              ),
            ListTile(
              leading: Icon(Icons.ios_share, color: _chromeFg),
              title: Text('공유', style: IsleText.body(color: _chromeFg)),
              subtitle: Text(
                '현재 페이지 링크 보내기',
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
              title: Text('화면 최대화', style: IsleText.body(color: _chromeFg)),
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
    _instagramNavBusyTimer?.cancel();
    _instagramSoundHintTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _injectDebounce?.cancel();
    _clipboardOfferDebounce?.cancel();
    _watchTick?.cancel();
    YoutubeWatchHistoryService.cancelPending();
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
    EngagementTracker.recordScreen('web_explorer_${widget.site.name}', seconds: DateTime.now().difference(_openedAt).inSeconds.clamp(1, 3600));
    _controller = null;
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isYoutube || widget.site == ExplorerSite.custom) {
      ref.listen<List<BlockedChannel>>(blockedChannelsProvider, (_, __) {
        if (mounted &&
            _controller != null &&
            (!_isYoutube ||
                _shouldInjectYoutubeBlocks(_currentUrl) ||
                widget.site == ExplorerSite.custom)) {
          _injectBlocks();
        }
      });
      ref.listen<List<BlockedVideo>>(blockedVideosProvider, (_, __) {
        if (mounted &&
            _controller != null &&
            (!_isYoutube ||
                _shouldInjectYoutubeBlocks(_currentUrl) ||
                widget.site == ExplorerSite.custom)) {
          _injectBlocks();
        }
      });
    }
    ref.listen<List<String>>(blockedKeywordsProvider, (_, __) {
      if (mounted &&
          _controller != null &&
          (!_isYoutube ||
              _shouldInjectYoutubeBlocks(_currentUrl) ||
              widget.site == ExplorerSite.custom)) {
        _injectBlocks();
      }
    });
    ref.listen<List<BlockedUrl>>(blockedUrlsProvider, (_, __) {
      if (mounted &&
          _controller != null &&
          (_isYoutube ||
              widget.site == ExplorerSite.custom ||
              _shouldInjectYoutubeBlocks(_currentUrl))) {
        _injectBlocks();
      }
    });
    ref.listen<List<BrunchBlockedAuthor>>(brunchBlockedAuthorsProvider, (_, __) {
      if (mounted && _controller != null) _injectBlocks();
    });

    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final title = widget.title ?? widget.site.displayTitle;

    final ytChromeH = (_chromeVisible && !_youtubeImmersive && !_youtubeInlineMini) ? 44.0 : 0.0;
    final igDmThread = _instagramDmThreadActive;
    final igShowChrome = _isInstagram && !_instagramImmersive && _chromeVisible && !igDmThread;
    // Safari·브런치 등 일반 브라우저: 상단/하단 chrome 바가 페이지(구글 검색창 등)를
    // 가리지 않도록 WebView를 chrome 높이만큼 안쪽으로 배치.
    final browserChromeVisible = !_isYoutube && !_isInstagram && _chromeVisible;
    final webTop = _isYoutube
        ? topInset + (_youtubeInlineMini ? 44.0 : ytChromeH)
        : (_instagramImmersive || igDmThread
            ? 0.0
            : (igShowChrome
                ? topInset + 52.0
                : (browserChromeVisible ? topInset + 44.0 : 0.0)));
    final miniH = _youtubeInlineMini ? YoutubeInlineMiniLayout.playerHeight(context) : 0.0;
    final miniNavH = _youtubeInlineMini ? YoutubeInlineMiniLayout.navBarHeight : 0.0;
    // YouTube: 0으로 끝까지 채움 — CSS padding으로 홈 바 위 여백 확보
    final webBottom = _isYoutube
        ? (_youtubeInlineMini ? bottomInset + miniH + miniNavH : 0.0)
        : (_instagramImmersive || igDmThread
            ? bottomInset
            : (igShowChrome
                ? bottomInset + 52.0
                : (browserChromeVisible ? bottomInset + 52.0 : bottomInset)));
    final browse = _browseController;
    final miniTitle = _probed.videoTitle.isNotEmpty
        ? _probed.videoTitle
        : (_probed.channelName.isNotEmpty ? _probed.channelName : '재생 중');

    final igCanSystemPop = _isInstagram &&
        !_instagramNavBusy &&
        !_instagramImmersive &&
        (Uri.tryParse(_currentUrl)?.path.toLowerCase().startsWith('/direct/inbox') ?? false);

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
        backgroundColor: Colors.black,
        extendBody: true,
        extendBodyBehindAppBar: true,
        // Instagram: 키보드가 올라오면 WebView가 키보드 위까지 자동으로 줄어들어야 입력 필드가 가리지 않음
        resizeToAvoidBottomInset: _isInstagram,
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
                  onHome: () => unawaited(_browseLoad(YoutubeWebviewFactory.homeUrl())),
                  onSearch: () => unawaited(_browseLoad('https://m.youtube.com/results?search_query=')),
                  onWatchLater: () =>
                      unawaited(_browseLoad('https://m.youtube.com/playlist?list=WL')),
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
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
            ] else
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
                    if (d.primaryVelocity != null && d.primaryVelocity! > 280) {
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
                    if (d.primaryVelocity != null && d.primaryVelocity! > 220) {
                      unawaited(_exitInstagramToHub());
                    }
                  },
                ),
              ),
            if (_isYoutube && _isWatchPage && !_youtubeInlineMini && !_youtubeImmersive)
              Positioned(
                top: webTop + 4,
                left: 0,
                right: 0,
                height: 72,
                child: YoutubeInlineMiniSwipeHint(onSwipeDown: () => unawaited(_enterYoutubeInlineMini())),
              ),
            if (_isYoutube && !_chromeVisible && !_youtubeImmersive && !_youtubeInlineMini)
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.expand_less, color: Colors.white70, size: 20),
                    ),
                  ),
                ),
              ),
            WebPlaybackRecoveryOverlay(
              state: _recovery,
              currentUrl: _currentUrl,
              onSignIn: _isYoutube
                  ? () {
                      final c = _controller;
                      if (c == null) return;
                      setState(() {
                        _recovery = const IslePlaybackRecoveryState.idle();
                        _showLoginBanner = true;
                        _chromeVisible = true;
                      });
                      unawaited(
                        c.loadRequest(Uri.parse(YoutubeWebviewFactory.signInUrl())),
                      );
                    }
                  : null,
              onSkipRecovery: () {
                _playbackGuard.cancelRecovery();
                setState(() => _recovery = const IslePlaybackRecoveryState.idle());
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
                setState(() => _recovery = const IslePlaybackRecoveryState.idle());
                unawaited(c.loadRequest(Uri.parse(_resolveStartUrl())));
              },
            ),
            if (_showBlockingLoadOverlay)
              const Center(child: CircularProgressIndicator(color: IsleColors.gold500)),
            if (_loading && _hideYoutubeLoadingOverlay && !_recovery.showOverlay)
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
            if (_watchPlatform != null)
              PlatformWatchLimitOverlay(platform: _watchPlatform!),
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
                          await IsleUserDefaults.setBrunchLoginRemembered(true);
                          if (mounted) setState(() => _showLoginBanner = false);
                        },
                        onClose: () => setState(() => _showLoginBanner = false),
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
                            onSafariLogin: () async {
                              final ok = await InstagramAuthService.openLoginInSafari();
                              if (!mounted) return;
                              if (ok) {
                                setState(() => _loading = true);
                                await controller.loadRequest(
                                  Uri.parse(
                                    widget.instagramDmOnly
                                        ? InstagramWebConfig.dmInboxUrl
                                        : InstagramWebConfig.homeUrl,
                                  ),
                                );
                              }
                            },
                            onRemembered: () async {
                              await IsleUserDefaults.setInstagramLoginRemembered(true);
                              if (mounted) setState(() => _showLoginBanner = false);
                            },
                            onClose: () => setState(() => _showLoginBanner = false),
                          )
                        : _YoutubeLoginChip(
                        dark: _useDarkChrome,
                        onSafariLogin: () async {
                          final ok = await YoutubeSystemAuthService.openGoogleLoginInAppBrowser();
                          if (!mounted) return;
                          if (ok) {
                            await IsleUserDefaults.setYoutubeWebLoginRemembered(true);
                            setState(() {
                              _loading = true;
                              _showLoginBanner = false;
                              _pendingYoutubeLogin = false;
                            });
                            await controller.loadRequest(
                              Uri.parse(YoutubeWebviewFactory.homeUrl()),
                            );
                          }
                        },
                        onWebLogin: () async {
                          setState(() {
                            _loading = true;
                            _pendingYoutubeLogin = true;
                          });
                          await controller.loadRequest(
                            Uri.parse(
                              'https://accounts.google.com/ServiceLogin?service=youtube&continue=https://m.youtube.com/',
                            ),
                          );
                        },
                        onRemembered: () async {
                          await IsleUserDefaults.setYoutubeWebLoginRemembered(true);
                          if (mounted) {
                            setState(() {
                              _showLoginBanner = false;
                              _pendingYoutubeLogin = false;
                            });
                          }
                        },
                        onClose: () => setState(() => _showLoginBanner = false),
                      ),
              ),
            if ((_chromeVisible && !_instagramImmersive) || _youtubeInlineMini) ...[
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
                      ? (_browseCurrentUrl.isNotEmpty ? _browseCurrentUrl : _channelSubtitle())
                      : _channelSubtitle(),
                  watchPlatform: _watchPlatform,
                  onBack: _isYoutube
                      ? _handleYoutubeBack
                      : (_isInstagram ? _handleInstagramBack : _handleBrowserBack),
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
                  onBoost: _isWatchPage ? _showFeedBoost : null,
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
              if (!_isYoutube)
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
                      if (await controller.canGoForward()) await controller.goForward();
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
                      if (!_isInstagram) setState(() => _chromeVisible = false);
                    },
                  ),
                ),
            ] else ...[
              if (!_instagramImmersive)
                Positioned(
                  top: topInset + 8,
                  left: 8,
                  child: _FloatingBtn(
                    icon: Icons.arrow_back_ios_new,
                    onTap: () {
                      if (_isYoutube) {
                        unawaited(_handleYoutubeBack());
                      } else if (_isInstagram) {
                        unawaited(_handleInstagramBack());
                      } else {
                        context.pop();
                      }
                    },
                  ),
                ),
              if (_watchPlatform != null && !_youtubeImmersive)
                Positioned(
                  top: topInset + 8,
                  right: _isYoutube ? 104 : 8,
                  child: PlatformTimeLimitChip(
                    platform: _watchPlatform!,
                    compact: true,
                  ),
                ),
              if (_isYoutube && _isWatchPage && !_youtubeImmersive && !_youtubeInlineMini)
                Positioned(
                  top: topInset + 8,
                  right: 56,
                  child: _FloatingBtn(
                    icon: Icons.keyboard_arrow_down,
                    onTap: () => unawaited(_enterYoutubeInlineMini()),
                  ),
                ),
              if (_isWatchPage && !_youtubeSearchUiActive && !_youtubeInlineMini)
                Positioned(
                  top: topInset + 8,
                  right: 8,
                  child: _FloatingBtn(
                    icon: Icons.thumb_up_alt_outlined,
                    color: IsleColors.gold500,
                    onTap: _showFeedBoost,
                  ),
                ),
              if (!_youtubeImmersive && !_instagramImmersive && !igDmThread)
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
                  onDismiss: () => setState(() => _youtubeQuickBarDismissed = true),
                ),
              ),
            if (_instagramImmersive) ...[
              Positioned(
                top: topInset + 4,
                left: 8,
                child: _InstagramChromeBtn(
                  icon: Icons.arrow_back_ios_new,
                  busy: _instagramNavBusy,
                  onTap: () => unawaited(_handleInstagramBack()),
                ),
              ),
              Positioned(
                top: topInset + 4,
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.volume_up_outlined, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '소리 없음? 여기 탭하거나 🔊 버튼을 눌러 보세요',
                                style: IsleText.caption(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                              onPressed: () => setState(() => _instagramSoundHint = false),
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
    this.channelLabel,
    this.watchPlatform,
    this.onMinimize,
    this.onShare,
    this.onBoost,
    this.onBlock,
    this.onIsleQueue,
    this.onTabs,
    this.tabCount,
  });

  final double topInset;
  final Color bg;
  final Color fg;
  final Color muted;
  final String title;
  final String? channelLabel;
  final PlatformWatchId? watchPlatform;
  final VoidCallback onBack;
  final VoidCallback onMenu;
  final VoidCallback? onMinimize;
  final void Function(BuildContext anchor)? onShare;
  final VoidCallback? onBoost;
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
              tooltip: '뒤로',
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
                  Text(title, style: IsleText.caption(color: fg).copyWith(fontWeight: FontWeight.w600)),
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
              PlatformTimeLimitChip(platform: watchPlatform!, compact: true, fg: fg, bg: muted.withValues(alpha: 0.25)),
            ],
            if (onShare != null)
              IconButton(
                icon: Icon(Icons.ios_share, size: 22, color: fg),
                tooltip: '공유',
                onPressed: () => onShare!(context),
                visualDensity: VisualDensity.compact,
              ),
            if (onBoost != null)
              IconButton(
                icon: const Icon(Icons.thumb_up_alt_outlined, size: 22, color: IsleColors.gold500),
                tooltip: '콘텐츠 취향 · 더 보기/숨기기',
                onPressed: onBoost,
                visualDensity: VisualDensity.compact,
              ),
            if (onIsleQueue != null)
              GestureDetector(
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  onIsleQueue!();
                },
                child: IconButton(
                  icon: const Icon(Icons.video_library_outlined, size: 22, color: IsleColors.gold500),
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
        padding: EdgeInsets.only(left: 2, right: 2, top: 2, bottom: bottomInset + 2),
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
                              style: IsleText.caption(color: fg.withValues(alpha: 0.85)),
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
    required this.onSafariLogin,
    required this.onWebLogin,
    required this.onRemembered,
    required this.onClose,
  });

  final bool dark;
  final VoidCallback onSafariLogin;
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
                    '유튜브 로그인 — 한 번 하면 이 기기 WebView에 유지됩니다',
                    style: IsleText.caption(color: fg),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: dark ? Colors.white54 : IsleColors.muted),
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSafariLogin,
                    icon: const Icon(Icons.open_in_browser, size: 16),
                    label: const Text('Safari 로그인', style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onWebLogin,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('웹뷰', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: onRemembered,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('완료', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '자동 로그인은 「웹뷰」로 로그인할 때 가장 잘 유지됩니다. Safari는 키체인 편하지만 WebView와 쿠키가 따로일 수 있어요.',
              style: IsleText.caption(color: dark ? Colors.white38 : IsleColors.muted),
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
              style: IsleText.caption(color: dark ? Colors.white : IsleColors.ocean900),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                FilledButton(
                  onPressed: onLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00C389),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    style: IsleText.caption(color: dark ? Colors.white70 : IsleColors.ocean700),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: dark ? Colors.white54 : IsleColors.muted),
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
              'DM·메시지는 로그인 후 사용 — Safari 로그인 권장(2FA)',
              style: IsleText.caption(color: dark ? Colors.white : IsleColors.ocean900),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(
                  onPressed: onSafariLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE1306C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Safari 로그인'),
                ),
                OutlinedButton(
                  onPressed: onLogin,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('앱 안 로그인'),
                ),
                TextButton(
                  onPressed: onRemembered,
                  child: Text(
                    '로그인 완료',
                    style: IsleText.caption(color: dark ? Colors.white70 : IsleColors.ocean700),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: dark ? Colors.white54 : IsleColors.muted),
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
