import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../core/services/isle_user_defaults.dart';
import '../../../core/youtube/youtube_url_redirect.dart';
import '../../../core/utils/url_parser.dart';
import '../../../core/youtube/blocked_channel_store.dart';
import '../../../core/youtube/blocked_url_store.dart';
import '../../../core/youtube/content_filter_store.dart';
import '../../../core/youtube/models/blocked_video.dart';
import '../../../core/youtube/models/youtube_page_channel.dart';
import '../../../core/safety/content_safety_guard.dart';
import '../../../core/guard/isle_content_block_guard.dart';
import '../../../core/services/isle_external_launch_guard.dart';
import '../../../core/youtube/youtube_access_guard.dart';
import '../../../core/youtube/youtube_block_reapply_hub.dart';
import '../../../core/youtube/youtube_limit_gate.dart';
import '../../../core/youtube/youtube_channel_block_guard.dart';
import '../../../core/youtube/youtube_content_open_guard.dart';
import '../../../core/youtube/youtube_channel_probe_script.dart';
import '../../../core/youtube/youtube_webview_energy.dart';
import '../../../core/youtube/youtube_webview_factory.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../youtube/presentation/widgets/block_channel_sheet.dart';

class ContentViewerScreen extends ConsumerStatefulWidget {
  final String url;
  final String title;
  final String channelId;
  final String channelName;

  const ContentViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.channelId = '',
    this.channelName = '',
  });

  @override
  ConsumerState<ContentViewerScreen> createState() => _ContentViewerScreenState();
}

class _ContentViewerScreenState extends ConsumerState<ContentViewerScreen> {
  WebViewController? _webController;
  YoutubePlayerController? _ytController;
  Timer? _injectDebounce;
  String _pageUrl = '';
  YoutubePageChannel _probed = const YoutubePageChannel(channelId: '', channelName: '');
  YoutubeBlockHit? _nativeBlockHit;
  ContentSafetyHit? _safetyBlockHit;
  String? _blockDenyMessage;

  bool get _isYouTube => widget.url.contains('youtube.com') || widget.url.contains('youtu.be');
  bool get _useWebShell => _isYouTube && IsleUserDefaults.useYoutubeWebShell;

  YoutubeBlockHit? _matchBlock(String url, {YoutubePageChannel? probe}) {
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

  bool get _urlExternallyBlocked =>
      IsleContentBlockGuard.denyUrl(widget.url) != null;

  Future<void> _redirectContentUnsafe(ContentSafetyHit hit) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(hit.snackMessage)),
    );
    final c = _webController;
    if (c != null) {
      final home = YoutubeWebviewFactory.homeUrl();
      await c.loadRequest(Uri.parse(home));
      if (mounted) setState(() => _pageUrl = home);
    }
  }

  Future<void> _redirectBlocked(YoutubeBlockHit hit) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(hit.snackMessage)),
    );
    final c = _webController;
    if (c != null) {
      final home = YoutubeWebviewFactory.homeUrl();
      await c.loadRequest(Uri.parse(home));
      if (mounted) setState(() => _pageUrl = home);
    }
  }

  Future<void> _reapplyBlocks() => _injectBlocks();

  @override
  void initState() {
    super.initState();
    _pageUrl = widget.url;
    if (YoutubeUrlRedirect.isYoutubeUrl(widget.url)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final deny = YoutubeContentOpenGuard.denyOpen(
          url: widget.url,
          channelId: widget.channelId,
          channelName: widget.channelName,
          videoTitle: widget.title,
        );
        if (deny != null) {
          setState(() => _blockDenyMessage = deny);
          return;
        }
        final route = YoutubeUrlRedirect.inAppRoute(widget.url);
        if (route != null) context.pushReplacement(route);
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initContent();
    });
  }

  void _initContent() {
    _safetyBlockHit = ContentSafetyGuard.matchUrl(widget.url);
    if (_safetyBlockHit != null) {
      setState(() {});
      return;
    }

    final playbackDeny = YoutubeContentOpenGuard.denyOpen(
      url: widget.url,
      channelId: widget.channelId,
      channelName: widget.channelName,
      videoTitle: widget.title,
    );
    if (playbackDeny != null) {
      _blockDenyMessage = playbackDeny;
      setState(() {});
      return;
    }

    if (_isYouTube && !_useWebShell) {
      if (YoutubeAccessGuard.shouldBlockWebView) {
        setState(() {});
        return;
      }
      _nativeBlockHit = _matchBlock(
        widget.url,
        probe: YoutubePageChannel(
          channelId: widget.channelId,
          channelName: widget.channelName,
          videoId: UrlParser.extractYouTubeVideoId(widget.url) ?? '',
          videoTitle: widget.title,
        ),
      );
      if (_nativeBlockHit == null && !_urlExternallyBlocked) {
        final videoId = UrlParser.extractYouTubeVideoId(widget.url);
        if (videoId != null) {
          _ytController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
          );
        }
      } else if (_urlExternallyBlocked && _nativeBlockHit == null) {
        _nativeBlockHit = const YoutubeBlockHit(
          kind: YoutubeBlockKind.url,
          label: '차단 URL',
        );
      }
      setState(() {});
      return;
    }
    if (_useWebShell) {
      final initialHit = _matchBlock(widget.url);
      final startUrl = initialHit != null ? YoutubeWebviewFactory.homeUrl() : widget.url;
      final controller = YoutubeWebviewFactory.create(
        initialUrl: startUrl,
        onUrlChanged: (url) {
          _pageUrl = url;
          final safety = ContentSafetyGuard.matchUrl(url);
          if (safety != null) {
            unawaited(_redirectContentUnsafe(safety));
            return;
          }
          final sanitized = ContentSafetyGuard.sanitizeUrl(url);
          if (sanitized != url) {
            unawaited(_webController?.loadRequest(Uri.parse(sanitized)));
            return;
          }
          final hit = _matchBlock(url);
          if (hit != null) {
            unawaited(_redirectBlocked(hit));
            return;
          }
          if (url.contains('youtube.com')) {
            _injectDebounce?.cancel();
            _injectDebounce = Timer(const Duration(milliseconds: 350), () {
              if (mounted) {
                _injectBlocks();
                _probeChannel();
              }
            });
          }
        },
        onPageReady: () async {
          await _injectBlocks();
          await _probeChannel();
        },
        onChannelProbe: _onChannelProbeMessage,
      );
      YoutubeWebviewEnergy.register(controller);
      YoutubeBlockReapplyHub.register(_reapplyBlocks);
      _webController = controller;
      setState(() {});
      if (initialHit != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(initialHit.snackMessage)),
        );
      }
      return;
    }
    if (widget.url.isNotEmpty) {
      _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(widget.url));
      setState(() {});
    }
  }

  void _onChannelProbeMessage(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final ch = YoutubePageChannel.fromJson(j);
      if (ch.isWatchPage) {
        final hit = _matchBlock(_pageUrl, probe: ch);
        if (hit != null) {
          unawaited(_redirectBlocked(hit));
          return;
        }
      }
      if (!ch.isEmpty && mounted) setState(() => _probed = ch);
    } catch (_) {}
  }

  Future<void> _probeChannel() async {
    final c = _webController;
    if (c == null || !_useWebShell) return;
    await c.runJavaScript(YoutubeChannelProbeScript.probeAndPost);
  }

  Future<void> _injectBlocks() async {
    final c = _webController;
    if (c == null || !_useWebShell) return;
    final vids = ref.read(blockedVideosProvider).map((e) => e.videoId).toList();
    final userKws = ref.read(blockedKeywordsProvider);
    final kws = ContentSafetyGuard.enabled
        ? {...userKws, ...ContentSafetyGuard.builtInYoutubeKeywords}.toList()
        : userKws;
    await YoutubeWebviewFactory.injectBlockScript(
      c,
      ref.read(blockedChannelsProvider),
      blockedVideoIds: vids,
      blockedKeywords: kws,
    );
  }

  Future<void> _blockChannel() async {
    await _probeChannel();
    if (!mounted) return;
    final result = await showBlockChannelSheet(
      context,
      channelId: _probed.channelId,
      channelName: _probed.channelName,
      pageUrl: _pageUrl,
    );
    if (result?.channelBlocked == true && mounted) {
      await _injectBlocks();
    }
  }

  @override
  void dispose() {
    YoutubeBlockReapplyHub.unregister(_reapplyBlocks);
    _injectDebounce?.cancel();
    _ytController?.dispose();
    final c = _webController;
    if (c != null) YoutubeWebviewEnergy.unregister(c);
    _webController = null;
    super.dispose();
  }

  Future<void> _openExternal() async {
    if (!mounted || _urlExternallyBlocked) return;
    await IsleExternalLaunchGuard.launch(context, widget.url);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(blockedChannelsProvider, (_, __) => _injectBlocks());
    ref.listen<List<BlockedVideo>>(blockedVideosProvider, (_, __) => _injectBlocks());
    ref.listen<List<String>>(blockedKeywordsProvider, (_, __) => _injectBlocks());

    if (_useWebShell && _webController != null) {
      return Scaffold(
        appBar: IsleAppBar(
          title: widget.title,
          actions: [
            IconButton(
              icon: const Icon(Icons.block),
              tooltip: '채널 차단',
              onPressed: _blockChannel,
            ),
            IconButton(icon: const Icon(Icons.open_in_browser), onPressed: _urlExternallyBlocked ? null : _openExternal),
          ],
        ),
        body: Column(
          children: [
            if (_probed.channelName.isNotEmpty)
              Material(
                color: const Color(0xFFE8F4FC),
                child: ListTile(
                  dense: true,
                  title: Text('채널: ${_probed.channelName}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: TextButton(onPressed: _blockChannel, child: const Text('차단')),
                ),
              ),
            Expanded(child: WebViewWidget(controller: _webController!)),
          ],
        ),
      );
    }

    if (_safetyBlockHit != null) {
      return Scaffold(
        appBar: IsleAppBar(title: widget.title),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, size: 48, color: IsleColors.danger),
                const SizedBox(height: 16),
                Text(
                  _safetyBlockHit!.snackMessage,
                  style: IsleText.subtitle(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('돌아가기'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isYouTube && YoutubeAccessGuard.shouldBlockWebView) {
      final locked = YoutubeLimitGate.lockedBody(context);
      if (locked != null) {
        return Scaffold(
          appBar: IsleAppBar(title: widget.title),
          body: locked,
        );
      }
    }

    if (_isYouTube && _nativeBlockHit != null) {
      return Scaffold(
        appBar: IsleAppBar(title: widget.title),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block, size: 48, color: IsleColors.danger),
                const SizedBox(height: 16),
                Text(
                  _nativeBlockHit!.snackMessage,
                  style: IsleText.subtitle(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('돌아가기'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_blockDenyMessage != null) {
      return Scaffold(
        appBar: IsleAppBar(title: widget.title),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block, size: 48, color: IsleColors.danger),
                const SizedBox(height: 16),
                Text(
                  _blockDenyMessage!,
                  style: IsleText.subtitle(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('돌아가기'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isYouTube && _ytController != null) {
      return YoutubePlayerBuilder(
        player: YoutubePlayer(controller: _ytController!),
        builder: (_, player) => Scaffold(
          appBar: IsleAppBar(title: widget.title),
          body: player,
        ),
      );
    }

    return Scaffold(
      appBar: IsleAppBar(
        title: widget.title,
        actions: [
          IconButton(icon: const Icon(Icons.open_in_browser), onPressed: _urlExternallyBlocked ? null : _openExternal),
        ],
      ),
      body: _webController != null
          ? WebViewWidget(controller: _webController!)
          : const Center(child: Text('URL을 열 수 없습니다')),
    );
  }
}
