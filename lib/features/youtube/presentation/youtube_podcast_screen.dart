import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/library/youtube_library_service.dart';
import '../../../core/navigation/explorer_entry_guard.dart';
import '../../../core/navigation/youtube_explorer_launch.dart';
import '../../../core/youtube/youtube_safari_launch_guard.dart';
import '../../../core/platform/isle_web_session_persistence_service.dart';
import '../../../core/platform/web_session_cookie_bridge.dart';
import '../../../core/qa/device_qa_preflight_service.dart';
import '../../../core/qa/device_qa_store.dart';
import '../../../core/services/isle_app_log_service.dart';
import '../../../core/services/isle_error_feedback.dart';
import '../../../core/youtube/youtube_system_auth_service.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/utils/url_parser.dart';
import '../../../core/youtube/models/youtube_focus_video.dart';
import '../../../core/youtube/models/youtube_page_channel.dart';
import '../../../core/youtube/youtube_clipboard_watch.dart';
import '../../../core/youtube/youtube_focus_search_service.dart';
import '../../../core/youtube/youtube_podcast_audio_script.dart';
import '../../../core/youtube/youtube_podcast_feed_service.dart';
import '../../../core/youtube/youtube_podcast_listen_store.dart';
import '../../../core/youtube/youtube_podcast_owner_service.dart';
import '../../../core/youtube/youtube_podcast_playlist_resolver.dart';
import '../../../core/youtube/youtube_podcast_saved_playlist_store.dart';
import '../../../core/youtube/youtube_podcast_session.dart';
import '../../../core/library/models/youtube_playlist_summary.dart';
import '../../../core/youtube/youtube_playback_access_guard.dart';
import '../../../core/youtube/youtube_watch_probe_script.dart';
import '../../../core/youtube/youtube_webview_energy.dart';
import '../../../core/youtube/youtube_webview_factory.dart';
import '../../../shared/widgets/youtube_podcast_offscreen_webview.dart';
import 'widgets/youtube_podcast_limit_overlay.dart';
import 'widgets/youtube_podcast_limit_sheet.dart';
import 'widgets/youtube_podcast_waveform.dart';

enum _PodcastPhase { picker, playing }

/// 유튜브 음성 — 듣기 전용 · 별도 한도 · 백그라운드 · 탐색 잠금
class YoutubePodcastScreen extends StatefulWidget {
  const YoutubePodcastScreen({
    super.key,
    this.initialUrl,
    this.videoId,
    this.qaMode = false,
  });

  final String? initialUrl;
  final String? videoId;
  final bool qaMode;

  @override
  State<YoutubePodcastScreen> createState() => _YoutubePodcastScreenState();
}

class _YoutubePodcastScreenState extends State<YoutubePodcastScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  WebViewController? _controller;
  _PodcastPhase _phase = _PodcastPhase.picker;
  String _currentUrl = '';
  bool _loading = false;
  bool _dartPaused = false;
  bool _leavingParked = false;
  bool _pendingUserPlay = false;
  YoutubePageChannel _meta = const YoutubePageChannel(channelId: '', channelName: '');
  Timer? _listenTick;
  Timer? _progressPoll;
  bool _appActive = true;

  double _positionSec = 0;
  double _durationSec = 0;
  List<double> _waveform = List.filled(40, 0.06);
  DateTime? _lastWaveUi;

  List<YoutubeFocusVideo> _queue = [];
  int _queueIndex = 0;

  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  List<YoutubeFocusVideo> _searchResults = [];
  List<YoutubeFocusVideo> _subFeed = [];
  List<YoutubeFocusVideo> _myUploads = [];
  List<YoutubePodcastSavedPlaylist> _savedPlaylists = [];
  List<YoutubePlaylistSummary> _accountPlaylists = [];
  bool _searching = false;
  bool _loadingFeed = false;
  bool _loadingPlaylists = false;
  bool _loginBusy = false;
  String? _feedError;
  String? _playlistError;
  String? _expandedSavedId;
  bool _ownerPlayback = false;
  String? _myChannelId;
  Set<String> _myUploadIds = {};

  final _playlistLinkCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (!mounted) return;
    final boot = widget.initialUrl ?? widget.videoId;
    final deny = boot != null && boot.trim().isNotEmpty
        ? ExplorerEntryGuard.denyMessageForShareUrl(boot)
        : null;
    if (deny != null) {
      ExplorerEntryGuard.showDenial(context, deny, url: boot);
      context.pop();
      return;
    }

    final restored = YoutubePodcastSession.instance.takeControllerForRoute();
    if (restored != null) {
      _controller = restored;
      _currentUrl = YoutubePodcastSession.instance.currentUrl;
      _meta = YoutubePodcastSession.instance.meta;
      _dartPaused = YoutubePodcastSession.instance.dartPaused;
      YoutubeWebviewEnergy.register(restored);
      _phase = _PodcastPhase.playing;
      _startListenTick();
      _startProgressPoll();
      setState(() {});
      unawaited(_applyAudioMode());
      return;
    }

    final id = _resolveBootVideoId();
    if (id != null) {
      _pendingUserPlay = true;
      await _playVideoId(id);
      return;
    }
    final bootUrl = widget.initialUrl?.trim();
    if (bootUrl != null && bootUrl.isNotEmpty) {
      final pl = UrlParser.extractYouTubePlaylistId(bootUrl);
      if (pl != null) {
        await _playFromUrl(bootUrl);
      }
    }
    if (YoutubeLibraryService.currentAccount != null) {
      unawaited(_preloadSignedInFeeds());
    }
  }

  static const _feedLoadTimeout = Duration(seconds: 35);

  Future<void> _preloadSignedInFeeds() async {
    if (YoutubeLibraryService.currentAccount == null) return;
    try {
      _myChannelId = await YoutubePodcastOwnerService.myChannelId();
      final results = await Future.wait([
        YoutubePodcastFeedService.fetchSubscriptionFeed(maxChannels: 8, perChannel: 2),
        YoutubePodcastFeedService.fetchMyUploads(maxResults: 24),
      ]).timeout(_feedLoadTimeout);
      _subFeed = results[0];
      _myUploads = results[1];
      _myUploadIds = _myUploads.map((v) => v.videoId).toSet();
      if (mounted) setState(() {});
    } on TimeoutException {
      if (mounted) {
        setState(() => _feedError = '구독·내 영상 불러오기가 너무 오래 걸려요. 새로고침을 눌러 주세요.');
      }
    } catch (e, st) {
      IsleErrorFeedback.log('podcast_preload_feeds', e, stack: st);
      if (mounted) {
        setState(() => _feedError = IsleErrorFeedback.friendly(e));
      }
    }
  }

  Future<void> _playFromUrl(String raw, {String? snackLabel}) async {
    setState(() {
      _loadingPlaylists = true;
      _playlistError = null;
    });
    try {
      final videos = await YoutubePodcastPlaylistResolver.fromUrl(raw);
      if (!mounted) return;
      if (videos.isEmpty) {
        setState(() {
          _playlistError = '재생할 영상을 찾지 못했어요. 링크·로그인을 확인해 주세요.';
          _phase = _PodcastPhase.picker;
          _tabCtrl.index = 1;
        });
        if (snackLabel != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(snackLabel)));
        }
        return;
      }
      _pendingUserPlay = true;
      await _playVideoId(
        videos.first.videoId,
        queue: videos,
        queueIndex: 0,
      );
    } catch (e, st) {
      IsleErrorFeedback.log('podcast_playlist_boot', e, stack: st);
      if (mounted) {
        setState(() => _playlistError = IsleErrorFeedback.friendly(e));
      }
    } finally {
      if (mounted) setState(() => _loadingPlaylists = false);
    }
  }

  Future<void> _playSavedPlaylist(YoutubePodcastSavedPlaylist p) async {
    setState(() {
      _loadingPlaylists = true;
      _playlistError = null;
    });
    try {
      final videos = await YoutubePodcastPlaylistResolver.fromSavedPlaylist(p);
      if (!mounted) return;
      if (videos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('목록이 비었거나 불러올 수 없어요')),
        );
        return;
      }
      _pendingUserPlay = true;
      await _playVideoId(videos.first.videoId, queue: videos, queueIndex: 0);
    } catch (e, st) {
      if (mounted) {
        IsleErrorFeedback.logAndSnack(
          context,
          tag: 'podcast_saved_pl',
          error: e,
          stack: st,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPlaylists = false);
    }
  }

  Future<void> _playAccountPlaylist(YoutubePlaylistSummary summary) async {
    setState(() {
      _loadingPlaylists = true;
      _playlistError = null;
    });
    try {
      final videos = await YoutubePodcastPlaylistResolver.fromAccountPlaylistSummary(
        playlistId: summary.id,
        title: summary.title,
      );
      if (!mounted) return;
      if (videos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('플레이리스트를 불러오지 못했어요. 로그인·비공개 권한을 확인해 주세요.')),
        );
        return;
      }
      _pendingUserPlay = true;
      await _playVideoId(videos.first.videoId, queue: videos, queueIndex: 0);
    } catch (e, st) {
      if (mounted) {
        IsleErrorFeedback.logAndSnack(
          context,
          tag: 'podcast_account_pl',
          error: e,
          stack: st,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPlaylists = false);
    }
  }

  Future<void> _reloadPlaylistsTab() async {
    setState(() {
      _loadingPlaylists = true;
      _playlistError = null;
    });
    try {
      await YoutubePodcastSavedPlaylistStore.ensureOpen();
      _savedPlaylists = YoutubePodcastSavedPlaylistStore.loadAll();
      if (YoutubeLibraryService.currentAccount != null) {
        _accountPlaylists = await YoutubeLibraryService.fetchMyPlaylists();
      } else {
        _accountPlaylists = [];
      }
    } catch (e, st) {
      IsleErrorFeedback.log('podcast_pl_tab', e, stack: st);
      _playlistError = IsleErrorFeedback.friendly(e);
    } finally {
      if (mounted) setState(() => _loadingPlaylists = false);
    }
  }

  Future<void> _createSavedPlaylist() async {
    final nameCtrl = TextEditingController(text: '내 최애');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('비공식 재생목록 만들기'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: '이름',
            hintText: '예: 공부 BGM · YT Music에 없는 곡',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('만들기'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (name == null || !mounted) return;
    await YoutubePodcastSavedPlaylistStore.create(name);
    await _reloadPlaylistsTab();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「$name」에 영상·플레이리스트 링크를 추가해 보세요')),
    );
  }

  Future<void> _addLinkToSaved(String playlistId) async {
    final raw = _playlistLinkCtrl.text.trim();
    if (raw.isEmpty) return;
    final ok = await YoutubePodcastSavedPlaylistStore.addLink(
      playlistId: playlistId,
      url: raw,
    );
    _playlistLinkCtrl.clear();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 있거나 추가할 수 없어요')),
      );
      return;
    }
    await _reloadPlaylistsTab();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('링크 추가됨 — YT Music에 없어도 음성으로 재생돼요')),
    );
  }

  String? _resolveBootVideoId() {
    final id = widget.videoId?.trim();
    if (id != null && id.length == 11) return id;
    final raw = widget.initialUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    return UrlParser.extractYouTubeVideoId(
      YoutubeClipboardWatch.normalizeUrl(raw) ?? raw,
    );
  }

  Future<void> _pastePlaylistLink() async {
    final url = await YoutubeClipboardWatch.readClipboardUrl();
    if (!mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클립보드에 YouTube 링크가 없어요')),
      );
      return;
    }
    _playlistLinkCtrl.text = url;
  }

  void _onWaveformMessage(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      final next = list
          .map((e) => ((e as num).toDouble()).clamp(0.0, 1.0))
          .toList();
      final now = DateTime.now();
      if (_lastWaveUi != null &&
          now.difference(_lastWaveUi!).inMilliseconds < 48) {
        return;
      }
      _lastWaveUi = now;
      if (!mounted) return;
      setState(() => _waveform = next);
    } catch (_) {}
  }

  WebViewController _buildController(String watchUrl) {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF121212));

    if (Platform.isIOS || Platform.isMacOS) {
      controller.setUserAgent(kYoutubeSafariUserAgent);
    } else if (Platform.isAndroid) {
      controller.setUserAgent(kYoutubeAndroidUserAgent);
    }

    controller.addJavaScriptChannel(
      'IsleChannel',
      onMessageReceived: (msg) => _onProbe(msg.message),
    );
    controller.addJavaScriptChannel(
      'IslePodcastEnded',
      onMessageReceived: (_) => unawaited(_playNextInQueue()),
    );
    controller.addJavaScriptChannel(
      'IslePodcastWaveform',
      onMessageReceived: (msg) => _onWaveformMessage(msg.message),
    );

    controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (req) {
          if (!YoutubePodcastAudioScript.isAllowedListenUrl(req.url)) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onUrlChange: (c) {
          final url = c.url;
          if (url == null || url.isEmpty) return;
          _onUrlChanged(url);
        },
        onPageFinished: (_) => unawaited(_onPageReady()),
      ),
    );

    controller.loadRequest(Uri.parse(watchUrl));
    return controller;
  }

  Future<void> _playVideoId(
    String id, {
    List<YoutubeFocusVideo>? queue,
    int queueIndex = 0,
    bool ownerHint = false,
  }) async {
    final owner = ownerHint ||
        YoutubePodcastOwnerService.isOwnerVideo(
          videoId: id,
          myUploadVideoIds: _myUploadIds,
          myChannelId: _myChannelId,
        );
    if (!owner) {
      final deny = YoutubePlaybackAccessGuard.denyPlayback(videoId: id);
      if (deny != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(deny)));
        }
        return;
      }
    }
    if (YoutubePodcastListenStore.isLimitReached && !owner) {
      if (mounted) setState(() => _phase = _PodcastPhase.playing);
      return;
    }
    if (queue != null) {
      _queue = queue;
      _queueIndex = queueIndex;
    } else {
      _queue = [YoutubeFocusVideo(videoId: id, title: '', channelName: '')];
      _queueIndex = 0;
    }

    final url = YoutubePodcastAudioScript.watchUrlForVideoId(id);
    setState(() {
      _loading = true;
      _phase = _PodcastPhase.playing;
      _ownerPlayback = owner;
      _currentUrl = url;
      _positionSec = 0;
      _durationSec = 0;
      _waveform = List.filled(40, 0.06);
      _meta = YoutubePageChannel(
        channelId: '',
        channelName: '',
        videoId: id,
      );
    });

    final old = _controller;
    if (old != null) {
      await old.runJavaScript(YoutubePodcastAudioScript.teardown);
      await YoutubeWebviewEnergy.setPlaybackBlocked(old, false);
      YoutubeWebviewEnergy.unregister(old);
    }

    final c = _buildController(url);
    YoutubeWebviewEnergy.register(c);
    _controller = c;
    _startListenTick();
    _startProgressPoll();
    setState(() {});
  }

  void _onUrlChanged(String url) {
    if (!mounted) return;
    if (!YoutubePodcastAudioScript.isAllowedListenUrl(url)) {
      final id = _meta.videoId.isNotEmpty
          ? _meta.videoId
          : UrlParser.extractYouTubeVideoId(_currentUrl);
      if (id != null) {
        unawaited(_controller?.loadRequest(
          Uri.parse(YoutubePodcastAudioScript.watchUrlForVideoId(id)),
        ));
      }
      return;
    }
    setState(() {
      _currentUrl = url;
      _loading = true;
    });
    unawaited(_applyAudioMode());
  }

  Future<void> _onPageReady() async {
    if (!mounted) return;
    await _applyAudioMode();
    if (_pendingUserPlay && !_dartPaused) {
      await _controller?.runJavaScript(YoutubePodcastAudioScript.forcePlayJs);
      _pendingUserPlay = false;
    }
    await _probe();
    await _pollProgressOnce();
    IsleWebSessionPersistenceService.scheduleSave();
    if (mounted) setState(() => _loading = false);
  }

  void _onProbe(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final ch = YoutubePageChannel.fromJson(j);
      if (!mounted) return;
      final owner = YoutubePodcastOwnerService.isOwnerVideo(
        videoId: ch.videoId,
        channelId: ch.channelId,
        myUploadVideoIds: _myUploadIds,
        myChannelId: _myChannelId,
      );
      if (!owner) {
        final deny = YoutubePlaybackAccessGuard.denyPlayback(
          videoId: ch.videoId,
          channelId: ch.channelId,
          channelName: ch.channelName,
          videoTitle: ch.videoTitle,
          url: _currentUrl,
        );
        if (deny != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(deny)));
          unawaited(_stopBlockedPlayback());
          return;
        }
      }
      setState(() {
        _meta = ch;
        if (owner) _ownerPlayback = true;
      });
    } catch (_) {}
  }

  Future<void> _stopBlockedPlayback() async {
    _listenTick?.cancel();
    _progressPoll?.cancel();
    final c = _controller;
    if (c != null) {
      await YoutubeWebviewEnergy.setPlaybackBlocked(c, true);
      await c.runJavaScript(YoutubePodcastAudioScript.teardown);
    }
    if (mounted) {
      setState(() {
        _phase = _PodcastPhase.picker;
        _loading = false;
        _dartPaused = true;
      });
    }
  }

  Future<void> _probe() async {
    final c = _controller;
    if (c == null) return;
    await c.runJavaScript(YoutubeWatchProbeScript.probeAndPost);
  }

  Future<void> _applyAudioMode() async {
    final c = _controller;
    if (c == null) return;
    await YoutubeWebviewEnergy.setPlaybackBlocked(c, false);
    await c.runJavaScript(YoutubePodcastAudioScript.install);
    if (!_ownerPlayback && YoutubePodcastListenStore.isLimitReached) {
      await YoutubeWebviewEnergy.setPlaybackBlocked(c, true);
    } else {
      await c.runJavaScript(YoutubePodcastAudioScript.setPausedJs(_dartPaused));
      if (!_dartPaused) {
        await c.runJavaScript(YoutubePodcastAudioScript.forcePlayJs);
      }
    }
  }

  void _startListenTick() {
    _listenTick?.cancel();
    _listenTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_appActive || _phase != _PodcastPhase.playing) return;
      if (YoutubePodcastListenStore.isLimitReached) {
        unawaited(_applyAudioMode());
        setState(() {});
        return;
      }
      if (!_ownerPlayback &&
          YoutubePodcastListenStore.shouldCountListenTime &&
          !_dartPaused) {
        YoutubePodcastListenStore.addSeconds(1);
      }
      if (mounted) setState(() {});
    });
  }

  void _startProgressPoll() {
    _progressPoll?.cancel();
    _progressPoll = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || _phase != _PodcastPhase.playing) return;
      unawaited(_pollProgressOnce());
    });
  }

  Future<void> _pollProgressOnce() async {
    final c = _controller;
    if (c == null || !mounted) return;
    try {
      final raw = await c.runJavaScriptReturningResult(
        YoutubePodcastAudioScript.progressJs,
      );
      final s = raw.toString();
      final jsonStr = s.startsWith('"') ? jsonDecode(s) as String : s;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final t = (map['t'] as num?)?.toDouble() ?? 0;
      final d = (map['d'] as num?)?.toDouble() ?? 0;
      final playing = map['p'] == true;
      if (!mounted) return;
      setState(() {
        _positionSec = t;
        if (d > 0) _durationSec = d;
        if (playing && _dartPaused) _dartPaused = false;
      });
    } catch (_) {}
  }

  Future<void> _togglePlayPause() async {
    final c = _controller;
    if (c == null || YoutubePodcastListenStore.isLimitReached) return;
    HapticFeedback.lightImpact();
    setState(() => _dartPaused = !_dartPaused);
    if (_dartPaused) {
      setState(() => _waveform = List.filled(40, 0.06));
    }
    await c.runJavaScript(YoutubePodcastAudioScript.setPausedJs(_dartPaused));
    if (!_dartPaused) {
      await c.runJavaScript(YoutubePodcastAudioScript.forcePlayJs);
    }
  }

  Future<void> _skipSeconds(int delta) async {
    final c = _controller;
    if (c == null || YoutubePodcastListenStore.isLimitReached) return;
    HapticFeedback.selectionClick();
    await c.runJavaScript(YoutubePodcastAudioScript.skipJs(delta));
    await _pollProgressOnce();
  }

  Future<void> _seekTo(double sec) async {
    final c = _controller;
    if (c == null) return;
    await c.runJavaScript(YoutubePodcastAudioScript.seekJs(sec));
    await _pollProgressOnce();
  }

  Future<void> _playNextInQueue() async {
    if (_queue.isEmpty || _queueIndex >= _queue.length - 1) return;
    _pendingUserPlay = true;
    await _playVideoId(
      _queue[_queueIndex + 1].videoId,
      queue: _queue,
      queueIndex: _queueIndex + 1,
    );
  }

  Future<void> _runSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    final id = UrlParser.extractYouTubeVideoId(q);
    if (id != null) {
      _pendingUserPlay = true;
      await _playVideoId(id);
      return;
    }
    if (UrlParser.extractYouTubePlaylistId(q) != null ||
        q.contains('playlist?list=')) {
      await _playFromUrl(q);
      return;
    }
    setState(() {
      _searching = true;
      _searchResults = [];
    });
    try {
      var list = await YoutubeFocusSearchService.search(q, maxResults: 16);
      list = YoutubePodcastFeedService.filterShorts(list);
      if (mounted) setState(() => _searchResults = list);
      if (mounted && list.isEmpty) {
        IsleErrorFeedback.snack(context, '검색 결과가 없어요. 다른 키워드를 시도해 보세요.');
      }
    } catch (e, st) {
      if (mounted) {
        IsleErrorFeedback.logAndSnack(
          context,
          tag: 'podcast_search',
          error: e,
          stack: st,
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _loadFeedTab(int index) async {
    if (index == 0) return;
    if (index == 1) {
      await _reloadPlaylistsTab();
      return;
    }
    if (YoutubeLibraryService.currentAccount == null) {
      setState(() {
        _loadingFeed = false;
        _feedError = 'Google 로그인이 필요해요. 위 「Google 로그인」을 눌러 주세요.';
      });
      return;
    }
    if (_loginBusy) return;
    setState(() {
      _loadingFeed = true;
      _feedError = null;
    });
    try {
      if (index == 2) {
        _subFeed = await YoutubePodcastFeedService.fetchSubscriptionFeed(
          maxChannels: 8,
          perChannel: 2,
        ).timeout(_feedLoadTimeout);
      } else if (index == 3) {
        _myChannelId = await YoutubePodcastOwnerService.myChannelId();
        _myUploads = await YoutubePodcastFeedService.fetchMyUploads(
          maxResults: 24,
        ).timeout(_feedLoadTimeout);
        _myUploadIds = _myUploads.map((v) => v.videoId).toSet();
      }
    } on TimeoutException {
      _feedError = '불러오기 시간이 초과됐어요. 네트워크를 확인하고 다시 시도해 주세요.';
    } catch (e, st) {
      IsleErrorFeedback.log('podcast_feed_$index', e, stack: st);
      _feedError = IsleErrorFeedback.friendly(e);
    } finally {
      if (mounted) setState(() => _loadingFeed = false);
    }
  }

  Future<void> _pasteAndPlay() async {
    final url = await YoutubeClipboardWatch.readClipboardUrl();
    if (!mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클립보드에 YouTube 링크가 없어요')),
      );
      return;
    }
    final id = UrlParser.extractYouTubeVideoId(
      YoutubeClipboardWatch.normalizeUrl(url) ?? url,
    );
    if (id == null) return;
    _pendingUserPlay = true;
    await _playVideoId(id);
  }

  Future<void> _openYoutubeLogin() async {
    if (!mounted || _loginBusy) return;
    setState(() {
      _loginBusy = true;
      _feedError = null;
    });
    IsleAppLogService.log('YouTube podcast: login tapped');

    try {
      if (YoutubeLibraryService.canAttemptSignIn) {
        final r = await YoutubeSystemAuthService.signInForYoutubeApi();
        IsleAppLogService.log(
          'YouTube podcast API sign-in success=${r.success} msg=${r.message}',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.message)),
        );
        if (r.success) {
          await _refreshAfterLogin();
          return;
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Google 로그인 설정이 필요해요. ${YoutubeLibraryService.setupHint}',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }

      if (YoutubeSafariLaunchGuard.isEscapeBlocked) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '차단·한도 중에는 WebView 로그인을 쓸 수 없어요. '
              '위 「시스템 Google 로그인」을 사용하세요.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      final pushed = await YoutubeExplorerLaunch.push(context, autoLogin: true);
      if (!pushed) {
        IsleAppLogService.log(
          'YouTube podcast: browser login push failed, trying login-guide',
          level: IsleLogLevel.warn,
        );
        if (mounted) await context.push('/youtube/login-guide');
      }
      await WebSessionCookieBridge.syncSafariCookiesToWebView();
      await _refreshAfterLogin();
    } finally {
      if (mounted) setState(() => _loginBusy = false);
    }
  }

  Future<void> _refreshAfterLogin() async {
    YoutubePodcastOwnerService.clearCache();
    if (YoutubeLibraryService.currentAccount == null) return;
    await _preloadSignedInFeeds();
    if (_tabCtrl.index == 1) {
      await _reloadPlaylistsTab();
    }
    if (mounted) setState(() {});
  }

  Future<void> _onPodcastResumed() async {
    if (YoutubeLibraryService.currentAccount != null &&
        (_subFeed.isEmpty || _myUploads.isEmpty)) {
      await _preloadSignedInFeeds();
    }
    if (_tabCtrl.index > 0) {
      await _loadFeedTab(_tabCtrl.index);
    }
    if (mounted) setState(() {});
  }

  void _parkForBackground() {
    final c = _controller;
    if (c == null || _phase != _PodcastPhase.playing) return;
    _leavingParked = true;
    final title = _meta.videoTitle.isNotEmpty ? _meta.videoTitle : '유튜브 음성';
    YoutubePodcastSession.instance.park(
      controller: c,
      url: _currentUrl,
      title: title,
      channel: _meta,
      paused: _dartPaused,
    );
    _controller = null;
    _progressPoll?.cancel();
  }

  Future<void> _stopAndPick() async {
    final c = _controller;
    if (c != null) {
      await c.runJavaScript(YoutubePodcastAudioScript.teardown);
      YoutubeWebviewEnergy.unregister(c);
    }
    _controller = null;
    _listenTick?.cancel();
    _progressPoll?.cancel();
    setState(() {
      _phase = _PodcastPhase.picker;
      _meta = const YoutubePageChannel(channelId: '', channelName: '');
      _dartPaused = false;
      _loading = false;
      _positionSec = 0;
      _durationSec = 0;
      _waveform = List.filled(40, 0.06);
    });
  }

  Future<void> _handleBack() async {
    if (_phase == _PodcastPhase.playing && _controller != null) {
      _parkForBackground();
      if (mounted) context.pop();
      return;
    }
    if (mounted) context.pop();
  }

  String _formatTime(double sec) {
    if (!sec.isFinite || sec < 0) return '0:00';
    final t = sec.round();
    final m = t ~/ 60;
    final s = t % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      if (_phase == _PodcastPhase.playing) {
        unawaited(_applyAudioMode());
      } else {
        unawaited(_onPodcastResumed());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabCtrl.dispose();
    _listenTick?.cancel();
    _progressPoll?.cancel();
    _searchCtrl.dispose();
    _playlistLinkCtrl.dispose();
    if (!_leavingParked) {
      final c = _controller;
      if (c != null) {
        unawaited(c.runJavaScript(YoutubePodcastAudioScript.teardown));
        YoutubeWebviewEnergy.unregister(c);
      }
    }
    super.dispose();
  }

  String _thumbUrl(String id) => 'https://img.youtube.com/vi/$id/mqdefault.jpg';

  @override
  Widget build(BuildContext context) {
    final vid = _meta.videoId.isNotEmpty
        ? _meta.videoId
        : UrlParser.extractYouTubeVideoId(_currentUrl);
    final title = _meta.videoTitle.isNotEmpty
        ? _meta.videoTitle
        : (_queue.isNotEmpty && _queueIndex < _queue.length
            ? _queue[_queueIndex].title
            : (vid != null ? '재생 중' : '유튜브 음성'));
    final channel = _meta.channelName.isNotEmpty
        ? _meta.channelName
        : (_queue.isNotEmpty && _queueIndex < _queue.length
            ? _queue[_queueIndex].channelName
            : '');
    final limitLine = _ownerPlayback
        ? '내 영상 · 음성 한도 제외 · 영상 미표시'
        : YoutubePodcastListenStore.formatStatusLine();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handleBack());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => unawaited(_handleBack()),
          ),
          title: Text(
            _phase == _PodcastPhase.playing
                ? (_ownerPlayback ? '내 영상' : '듣는 중')
                : '유튜브 음성',
            style: IsleText.subtitle(color: Colors.white),
          ),
          actions: [
            IconButton(
              tooltip: '음성 한도',
              icon: const Icon(Icons.timer_outlined),
              onPressed: () => showYoutubePodcastLimitSheet(context),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_phase == _PodcastPhase.picker) _buildPicker(context),
            if (_phase == _PodcastPhase.playing) ...[
              if (_controller != null)
                YoutubePodcastOffscreenWebview(controller: _controller!),
              _buildPlayer(
                vid: vid,
                title: title,
                channel: channel,
                limitLine: limitLine,
              ),
              if (!_ownerPlayback) const YoutubePodcastLimitOverlay(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPicker(BuildContext context) {
    final limitLine = YoutubePodcastListenStore.formatStatusLine();
    final signedIn = YoutubeLibraryService.currentAccount != null;

    return Column(
      children: [
        if (widget.qaMode)
          _PodcastQaPanel(
            signedIn: signedIn,
            subCount: _subFeed.length,
            uploadsCount: _myUploads.length,
            playlistCount: _savedPlaylists.length,
            audioHeard: _positionSec > 1.5 && !_dartPaused && !_loading,
            waveformActive: _waveform.any((s) => s > 0.14),
            ownerPlayback: _ownerPlayback,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오디오만 · 실시간 파형 · 영상 한도와 별도',
                  style: IsleText.body(color: const Color(0xFF1DB954)),
                ),
                const SizedBox(height: 4),
                Text(limitLine, style: IsleText.caption(color: Colors.white54)),
                if (signedIn) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: Color(0xFF1DB954)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          YoutubeLibraryService.currentAccount?.email ?? '로그인됨',
                          style: IsleText.caption(color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => unawaited(_loadFeedTab(_tabCtrl.index > 0 ? _tabCtrl.index : 2)),
                        child: const Text('새로고침'),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _loginBusy ? null : _openYoutubeLogin,
                    icon: _loginBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login, size: 18),
                    label: Text(_loginBusy ? 'Google 로그인 중…' : 'YouTube 로그인 (내 영상·비공개)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF1DB954),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          onTap: (i) => unawaited(_loadFeedTab(i)),
          tabs: const [
            Tab(text: '검색'),
            Tab(text: '재생목록'),
            Tab(text: '구독'),
            Tab(text: '내 영상'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildSearchTab(),
              _buildPlaylistsTab(),
              _buildFeedTab(_subFeed, emptyHint: '구독 채널 최신 영상이 없어요'),
              _buildFeedTab(_myUploads, emptyHint: '내 업로드가 없거나 로그인이 필요해요'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistsTab() {
    if (_loadingPlaylists) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          'YT Music에 없는 영상도 링크만 있으면 음성으로 들을 수 있어요',
          style: IsleText.caption(color: Colors.white54),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('내 최애 (비공식)', style: IsleText.body(color: Colors.white)),
            const Spacer(),
            TextButton.icon(
              onPressed: _createSavedPlaylist,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('새 목록'),
            ),
          ],
        ),
        if (_savedPlaylists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '영상·플레이list URL을 모아 두는 Isle 전용 목록이에요',
              style: IsleText.caption(color: Colors.white38),
            ),
          ),
        ..._savedPlaylists.map((p) {
          final expanded = _expandedSavedId == p.id;
          return Card(
            color: const Color(0xFF1A1A1A),
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.favorite_border, color: Color(0xFF1DB954)),
                  title: Text(p.name, style: IsleText.body(color: Colors.white)),
                  subtitle: Text(
                    '${p.links.length}개 링크',
                    style: IsleText.caption(color: Colors.white54),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '전체 재생',
                        icon: const Icon(Icons.play_circle_fill, color: Color(0xFF1DB954)),
                        onPressed: p.links.isEmpty
                            ? null
                            : () => unawaited(_playSavedPlaylist(p)),
                      ),
                      IconButton(
                        icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                        onPressed: () => setState(
                          () => _expandedSavedId = expanded ? null : p.id,
                        ),
                      ),
                    ],
                  ),
                ),
                if (expanded) ...[
                  ...p.links.map(
                    (link) => ListTile(
                      dense: true,
                      title: Text(
                        link,
                        style: IsleText.caption(color: Colors.white70),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () async {
                          await YoutubePodcastSavedPlaylistStore.removeLink(
                            playlistId: p.id,
                            url: link,
                          );
                          await _reloadPlaylistsTab();
                        },
                      ),
                      onTap: () => unawaited(_playFromUrl(link)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _playlistLinkCtrl,
                            style: IsleText.body(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: '영상·playlist URL',
                              hintStyle: IsleText.caption(color: Colors.white38),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFF252525),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => unawaited(_addLinkToSaved(p.id)),
                          ),
                        ),
                        IconButton(
                          onPressed: () => unawaited(_pastePlaylistLink()),
                          icon: const Icon(Icons.content_paste, color: Colors.white54),
                        ),
                        FilledButton(
                          onPressed: () => unawaited(_addLinkToSaved(p.id)),
                          child: const Text('추가'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        if (_playlistError != null) ...[
          const SizedBox(height: 8),
          Text(_playlistError!, style: IsleText.caption(color: Colors.orange)),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Text('YouTube 계정', style: IsleText.body(color: Colors.white)),
            const Spacer(),
            if (YoutubeLibraryService.currentAccount == null)
              TextButton(onPressed: _loginBusy ? null : _openYoutubeLogin, child: const Text('로그인')),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '내 채널에 만든 공식 플레이list · 나중에 볼 동영상(WL)',
          style: IsleText.caption(color: Colors.white38),
        ),
        const SizedBox(height: 8),
        if (_accountPlaylists.isEmpty && YoutubeLibraryService.currentAccount != null)
          Text('플레이list가 없어요', style: IsleText.caption(color: Colors.white38))
        else if (_accountPlaylists.isEmpty)
          OutlinedButton.icon(
            onPressed: _loginBusy ? null : _openYoutubeLogin,
            icon: const Icon(Icons.login),
            label: const Text('로그인 후 불러오기'),
          )
        else
          ..._accountPlaylists.map(
            (pl) => ListTile(
              leading: const Icon(Icons.queue_music, color: Colors.white54),
              title: Text(pl.title, style: IsleText.body(color: Colors.white)),
              subtitle: Text(
                '${pl.itemCount}곡 · ${pl.privacyStatus ?? ''}',
                style: IsleText.caption(color: Colors.white54),
              ),
              trailing: const Icon(Icons.play_circle_outline, color: Color(0xFF1DB954)),
              onTap: () => unawaited(_playAccountPlaylist(pl)),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => unawaited(_playFromUrl(
            'https://www.youtube.com/playlist?list=WL',
          )),
          icon: const Icon(Icons.watch_later_outlined),
          label: const Text('나중에 볼 동영상 (WL)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        TextField(
          controller: _searchCtrl,
          style: IsleText.body(color: Colors.white),
          decoration: InputDecoration(
            hintText: '제목 검색 또는 링크·영상 ID',
            hintStyle: IsleText.body(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search, color: Color(0xFF1DB954)),
              onPressed: _runSearch,
            ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _runSearch(),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _pasteAndPlay,
          icon: const Icon(Icons.link, color: Colors.white70),
          label: const Text('링크 붙여넣기'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
            minimumSize: const Size(0, IsleSize.minTouchTarget),
          ),
        ),
        if (IsleUserDefaults.youtubePodcastExcludeShorts)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '숏폼(60초 이하)은 목록에서 제외됩니다',
              style: IsleText.caption(color: Colors.white38),
            ),
          ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
          ),
        ..._buildVideoTiles(_searchResults),
      ],
    );
  }

  Widget _buildFeedTab(List<YoutubeFocusVideo> items, {required String emptyHint}) {
    if (_loadingFeed || _loginBusy) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1DB954)),
            if (_loginBusy) ...[
              const SizedBox(height: 12),
              Text(
                'Google 로그인 중…',
                style: IsleText.caption(color: Colors.white54),
              ),
            ],
          ],
        ),
      );
    }
    if (_feedError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_feedError!, style: IsleText.body(color: Colors.white54), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loginBusy ? null : _openYoutubeLogin,
                child: const Text('YouTube 로그인'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/settings/youtube-account-sync'),
                child: const Text('계정·동기화 설정'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => unawaited(_loadFeedTab(_tabCtrl.index)),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }
    if (items.isEmpty) {
      final needsLogin = YoutubeLibraryService.currentAccount == null;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emptyHint, style: IsleText.body(color: Colors.white38), textAlign: TextAlign.center),
              if (needsLogin) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loginBusy ? null : _openYoutubeLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('Google 로그인'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      children: _buildVideoTiles(items),
    );
  }

  List<Widget> _buildVideoTiles(List<YoutubeFocusVideo> items) {
    return items.asMap().entries.map((e) {
      final v = e.value;
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: v.thumbnailUrl != null
              ? Image.network(v.thumbnailUrl!, width: 56, height: 56, fit: BoxFit.cover)
              : const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.music_note, color: Colors.white38),
                ),
        ),
        title: Text(
          v.title,
          style: IsleText.body(color: Colors.white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          v.durationLabel.isNotEmpty ? '${v.channelName} · ${v.durationLabel}' : v.channelName,
          style: IsleText.caption(color: Colors.white54),
        ),
        onTap: () {
          _pendingUserPlay = true;
          final fromMy = identical(items, _myUploads);
          unawaited(_playVideoId(
            v.videoId,
            queue: items,
            queueIndex: e.key,
            ownerHint: fromMy,
          ));
        },
      );
    }).toList();
  }

  Widget _buildPlayer({
    required String? vid,
    required String title,
    required String channel,
    required String limitLine,
  }) {
    final maxDur = _durationSec > 0 ? _durationSec : 1.0;
    final hasNext = _queue.isNotEmpty && _queueIndex < _queue.length - 1;
    final playing = !_dartPaused && !_loading;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            if (widget.qaMode)
              _PodcastQaPanel(
                signedIn: YoutubeLibraryService.currentAccount != null,
                subCount: _subFeed.length,
                uploadsCount: _myUploads.length,
                playlistCount: _savedPlaylists.length,
                audioHeard: _positionSec > 1.5 && !_dartPaused && !_loading,
                waveformActive: _waveform.any((s) => s > 0.14),
                ownerPlayback: _ownerPlayback,
                compact: true,
              ),
            YoutubePodcastAudioBadge(playing: playing),
            const SizedBox(height: 16),
            YoutubePodcastPlayerCard(
              child: Column(
                children: [
                  Center(
                    child: YoutubePodcastAlbumHero(
                      thumbnailUrl: vid != null ? _thumbUrl(vid) : null,
                      fallback: _albumArt(size: 200),
                      size: 220,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: IsleText.title(color: Colors.white)
                        .copyWith(fontSize: 19, height: 1.25),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (channel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      channel,
                      style: IsleText.caption(color: Colors.white54),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 18),
                  YoutubePodcastWaveformVisualizer(
                    samples: _waveform,
                    active: playing,
                    height: 68,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '실시간 오디오 파형 · 영상 재생 없음',
                    style: IsleText.caption(color: Colors.white30),
                  ),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      activeTrackColor: const Color(0xFF1DB954),
                      inactiveTrackColor: Colors.white12,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _positionSec.clamp(0, maxDur),
                      max: maxDur,
                      onChanged: _loading
                          ? null
                          : (v) => setState(() => _positionSec = v),
                      onChangeEnd: (v) => unawaited(_seekTo(v)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(_positionSec),
                          style: IsleText.caption(color: Colors.white54),
                        ),
                        Text(
                          _formatTime(_durationSec),
                          style: IsleText.caption(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const CircularProgressIndicator(color: Color(0xFF1DB954))
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 36,
                    tooltip: '30초 뒤로',
                    onPressed: () => unawaited(_skipSeconds(-30)),
                    icon: const Icon(Icons.replay_30, color: Colors.white70),
                  ),
                  IconButton(
                    iconSize: 32,
                    tooltip: '목록',
                    onPressed: _stopAndPick,
                    icon: const Icon(Icons.queue_music, color: Colors.white60),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: const Color(0xFF1DB954),
                    elevation: 6,
                    shadowColor: const Color(0xFF1DB954).withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _togglePlayPause,
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: Icon(
                          _dartPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          color: Colors.black,
                          size: 44,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    iconSize: 36,
                    tooltip: '다음 곡',
                    onPressed: hasNext ? () => unawaited(_playNextInQueue()) : null,
                    icon: Icon(
                      Icons.skip_next,
                      color: hasNext ? Colors.white70 : Colors.white24,
                    ),
                  ),
                  IconButton(
                    iconSize: 36,
                    tooltip: '30초 앞으로',
                    onPressed: () => unawaited(_skipSeconds(30)),
                    icon: const Icon(Icons.forward_30, color: Colors.white70),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Text(limitLine, style: IsleText.caption(color: Colors.white38)),
            const SizedBox(height: 4),
            Text(
              '오디오만 재생 · 나가도 소리 계속 · 영상 한도와 별도',
              style: IsleText.caption(color: Colors.white24),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _albumArt({double size = 200}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFF1DB954).withValues(alpha: 0.35),
            const Color(0xFF121212),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1DB954).withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(Icons.headphones, size: size * 0.36, color: const Color(0xFF1DB954)),
    );
  }
}

class _PodcastQaPanel extends StatefulWidget {
  const _PodcastQaPanel({
    required this.signedIn,
    required this.subCount,
    required this.uploadsCount,
    required this.playlistCount,
    required this.audioHeard,
    required this.waveformActive,
    required this.ownerPlayback,
    this.compact = false,
  });

  final bool signedIn;
  final int subCount;
  final int uploadsCount;
  final int playlistCount;
  final bool audioHeard;
  final bool waveformActive;
  final bool ownerPlayback;
  final bool compact;

  @override
  State<_PodcastQaPanel> createState() => _PodcastQaPanelState();
}

class _PodcastQaPanelState extends State<_PodcastQaPanel> {
  DeviceQaPreflightResult? _preflight;
  bool _preflightLoading = true;
  bool _markingDone = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPreflight());
  }

  @override
  void didUpdateWidget(covariant _PodcastQaPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signedIn != widget.signedIn ||
        oldWidget.subCount != widget.subCount ||
        oldWidget.uploadsCount != widget.uploadsCount ||
        oldWidget.playlistCount != widget.playlistCount) {
      unawaited(_refreshPreflight());
    }
  }

  Future<void> _refreshPreflight() async {
    if (!mounted) return;
    setState(() => _preflightLoading = true);
    final r = await DeviceQaPreflightService.runOne('youtube_voice');
    if (!mounted) return;
    setState(() {
      _preflight = r;
      _preflightLoading = false;
    });
  }

  Future<void> _markDeviceQaDone() async {
    if (_markingDone) return;
    setState(() => _markingDone = true);
    try {
      await DeviceQaStore.setChecked('youtube_voice', true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('유튜브 음성 실기기 확인을 체크했어요')),
      );
      if (context.canPop()) {
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _markingDone = false);
    }
  }

  Widget _stepRow(String label, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: done ? const Color(0xFF2E7D32) : const Color(0xFF81C784),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: IsleText.caption(
                color: done ? const Color(0xFF1B5E20) : const Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loginDone = widget.signedIn;
    final feedDone = widget.subCount > 0 || widget.uploadsCount > 0;
    final audioDone = widget.audioHeard && widget.ownerPlayback;
    final waveformDone = widget.waveformActive;
    final readyToComplete = loginDone && feedDone && audioDone && waveformDone;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16, widget.compact ? 0 : 8, 16, widget.compact ? 10 : 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.compact ? '실기기 확인 — 재생 중' : '실기기 확인 — 유튜브 음성',
            style: IsleText.subtitle(color: const Color(0xFF1B5E20)),
          ),
          if (!widget.compact) ...[
            const SizedBox(height: 8),
            _stepRow('① Google 로그인', loginDone),
            _stepRow('② 구독 (${widget.subCount}) 또는 내 영상 (${widget.uploadsCount})', feedDone),
            _stepRow('③ 재생목록 탭 (${widget.playlistCount}개 · 선택)', widget.playlistCount > 0),
            _stepRow('④ 오디오만 재생·소리', audioDone),
            _stepRow('⑤ 실시간 파형', waveformDone),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              readyToComplete
                  ? '소리·파형 확인됨 · 아래에서 완료 체크'
                  : audioDone
                      ? '재생 중 파형이 움직이는지 확인해 주세요'
                      : '내 영상에서 재생 후 소리가 나는지 확인해 주세요',
              style: IsleText.caption(color: const Color(0xFF2E7D32)),
            ),
          ],
          if (_preflightLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (_preflight != null) ...[
            const SizedBox(height: 8),
            Text(
              _preflight!.summary,
              style: IsleText.caption(color: const Color(0xFF1B5E20)),
            ),
            if (_preflight!.hint != null && _preflight!.hint!.isNotEmpty)
              Text(
                _preflight!.hint!,
                style: IsleText.caption(color: const Color(0xFF2E7D32)),
              ),
          ],
          if (!widget.compact) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _preflightLoading ? null : _refreshPreflight,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('자동 점검'),
                ),
              ],
            ),
          ],
          SizedBox(
            height: IsleSize.minTouchTarget,
            child: FilledButton.icon(
              onPressed: (_markingDone || !readyToComplete) ? null : _markDeviceQaDone,
              icon: _markingDone
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.task_alt),
              label: Text(readyToComplete ? '실기기 확인 완료' : '로그인·재생·파형 후 체크'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                disabledBackgroundColor: const Color(0xFFA5D6A7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
