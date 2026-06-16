import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/isle_app_log_service.dart';
import '../youtube/youtube_nav_policy.dart';

/// YouTube·WebView 재생/로드 실패 자동 복구 (회색 빈 화면·「try again later」 방지)
class IslePlaybackGuard {
  IslePlaybackGuard({
    required this.onUrlChanged,
    required this.onPageReady,
    this.onRecoveryState,
    this.onClearOsBlock,
    this.maxAutoRetries = 3,
    this.recoveryTimeout = const Duration(seconds: 14),
  });

  final void Function(String url) onUrlChanged;
  final Future<void> Function() onPageReady;
  final void Function(IslePlaybackRecoveryState state)? onRecoveryState;

  /// 첫 복구 시도 직전 1회 호출 — 예전 버전이 남긴 OS web content 차단(youtube.com)을 해제.
  /// 재생 오류의 실제 원인(WKWebView까지 막는 ManagedSettings 필터)을 제거한다.
  final Future<void> Function()? onClearOsBlock;

  final int maxAutoRetries;
  final Duration recoveryTimeout;

  int _autoRetries = 0;
  String _lastUrl = '';
  IslePlaybackRecoveryState _state = const IslePlaybackRecoveryState.idle();
  Timer? _recoveryTimer;
  bool _recoveryInFlight = false;
  bool _osBlockCleared = false;
  DateTime? _lastDomErrorAt;

  Future<void> Function()? _domReload;
  Future<void> Function(String url)? _domLoadUrl;
  Future<void> Function()? _domLoadHome;
  Future<void> Function()? _domOpenExternal;
  Future<void> Function()? _domSwitchUserAgent;

  void bindDomRecovery({
    required Future<void> Function() reload,
    required Future<void> Function(String url) loadUrl,
    required Future<void> Function() loadHome,
    required Future<void> Function() openExternal,
    Future<void> Function()? switchUserAgent,
  }) {
    _domReload = reload;
    _domLoadUrl = loadUrl;
    _domLoadHome = loadHome;
    _domOpenExternal = openExternal;
    _domSwitchUserAgent = switchUserAgent;
  }

  IslePlaybackRecoveryState get state => _state;

  static const playbackErrorPatterns = [
    'try again later',
    'playback id',
    'an error occurred',
    'something went wrong',
    '오류가 발생',
    '다시 시도',
    'sign in to confirm',
    'not available',
  ];

  void reset() {
    _cancelRecoveryTimer();
    _autoRetries = 0;
    _recoveryInFlight = false;
    _osBlockCleared = false;
    _emit(const IslePlaybackRecoveryState.idle());
  }

  void _cancelRecoveryTimer() {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
  }

  void _emit(IslePlaybackRecoveryState next) {
    _state = next;
    onRecoveryState?.call(next);
  }

  void _startRecoveryTimeout() {
    _cancelRecoveryTimer();
    _recoveryTimer = Timer(recoveryTimeout, () {
      if (_state.phase != IslePlaybackPhase.recovering) return;
      IsleAppLogService.log('Playback recovery timeout — showing manual controls');
      _recoveryInFlight = false;
      _emit(IslePlaybackRecoveryState.error(
        message: '자동 복구가 완료되지 않았어요. 다시 시도하거나 브라우저에서 열어 보세요.',
        canRetry: true,
      ));
    });
  }

  void markPageLoadedSuccessfully(String url) {
    if (_state.phase == IslePlaybackPhase.recovering || _recoveryInFlight) {
      _cancelRecoveryTimer();
      _recoveryInFlight = false;
      _autoRetries = 0;
      _emit(const IslePlaybackRecoveryState.idle());
    } else if (_state.loading) {
      _emit(_state.copyWith(loading: false));
    }
    if (url.isNotEmpty) _lastUrl = url;
  }

  void cancelRecovery() {
    _cancelRecoveryTimer();
    _recoveryInFlight = false;
    _autoRetries = maxAutoRetries;
    _emit(IslePlaybackRecoveryState.error(
      message: '자동 복구를 건너뛰었어요.',
      canRetry: true,
    ));
  }

  static bool _shouldIgnoreError(WebResourceError err) {
    if (err.errorCode == -2 || err.errorCode == -999) return true;
    final d = err.description.toLowerCase();
    if (d.contains('cancelled') || d.contains('canceled')) return true;
    if (err.isForMainFrame == false) return true;
    return false;
  }

  bool _isYoutubeBrowseSurface(String url) =>
      YoutubeNavPolicy.isBrowseSurface(url);

  NavigationDelegate buildDelegate({
    required Future<void> Function() reload,
    required Future<void> Function(String url) loadUrl,
    required Future<void> Function() openExternal,
    required Future<void> Function() loadHome,
    Future<void> Function()? switchUserAgent,
    void Function(String url)? onPageStartedExtra,
    void Function(int progress)? onLoadProgressExtra,
  }) {
    return NavigationDelegate(
      onUrlChange: (c) {
        final url = c.url;
        if (url != null && url.isNotEmpty) {
          _lastUrl = url;
          onUrlChanged(url);
        }
      },
      onPageStarted: (url) {
        if (_isYoutubeBrowseSurface(url)) return;
        if (_state.phase != IslePlaybackPhase.recovering) {
          _emit(_state.copyWith(loading: true, message: null));
        }
        onPageStartedExtra?.call(url);
      },
      onProgress: onLoadProgressExtra,
      onPageFinished: (url) async {
        await onPageReady();
        markPageLoadedSuccessfully(url);
        if (_isYoutubeBrowseSurface(url)) return;
        await _probePageForPlaybackError(url);
      },
      onWebResourceError: (err) async {
        if (_shouldIgnoreError(err)) return;
        if (_isYoutubeBrowseSurface(_lastUrl)) return;
        IsleAppLogService.log(
          'WebView error ${err.errorCode}: ${err.description}',
          level: IsleLogLevel.warn,
        );
        await _handleFailure(
          reload: reload,
          loadUrl: loadUrl,
          loadHome: loadHome,
          openExternal: openExternal,
          switchUserAgent: switchUserAgent,
          reason: err.description,
        );
      },
      onHttpError: (err) async {
        final code = err.response?.statusCode;
        if (code == null || code < 400) return;
        if (code == 429) return;
        if (_isYoutubeBrowseSurface(_lastUrl)) return;
        await _handleFailure(
          reload: reload,
          loadUrl: loadUrl,
          loadHome: loadHome,
          openExternal: openExternal,
          switchUserAgent: switchUserAgent,
          reason: 'HTTP $code',
        );
      },
    );
  }

  Future<void> _probePageForPlaybackError(String url) async {
    if (!url.contains('youtube.com')) return;
  }

  Future<void> reportPlaybackMessage(String bodyText) async {
    if (_isYoutubeBrowseSurface(_lastUrl)) return;
    final lower = bodyText.toLowerCase();
    String? matched;
    for (final p in playbackErrorPatterns) {
      if (lower.contains(p)) {
        matched = p;
        break;
      }
    }
    if (matched == null) return;

    final now = DateTime.now();
    if (_lastDomErrorAt != null && now.difference(_lastDomErrorAt!) < const Duration(seconds: 12)) {
      return;
    }
    _lastDomErrorAt = now;

    IsleAppLogService.log('YouTube DOM playback error ($matched)', level: IsleLogLevel.warn);

    final reload = _domReload;
    final loadUrl = _domLoadUrl;
    final loadHome = _domLoadHome;
    final openExternal = _domOpenExternal;
    if (reload != null && loadUrl != null && loadHome != null && openExternal != null) {
      if (_recoveryInFlight || _state.phase == IslePlaybackPhase.recovering) return;
      await _handleFailure(
        reload: reload,
        loadUrl: loadUrl,
        loadHome: loadHome,
        openExternal: openExternal,
        switchUserAgent: _domSwitchUserAgent,
        reason: matched == 'try again later'
            ? 'YouTube가 일시적으로 재생을 거부했어요. 로그인·다시 시도를 해보세요.'
            : '재생 오류: $matched',
      );
      if (_state.phase == IslePlaybackPhase.idle) return;
      if (_state.phase == IslePlaybackPhase.recovering) return;
    }

    _emit(IslePlaybackRecoveryState.error(
      message: matched == 'try again later'
          ? 'YouTube 「Try again later」 — WebView 제한·미로그인·일시 차단일 수 있어요. '
              'Google 로그인 후 다시 시도하거나 Safari에서 열어 보세요.'
          : '재생 오류가 감지되었습니다. 아래에서 복구해 보세요.',
      errorCode: _makeErrorCode('DOM', matched),
      canRetry: true,
      suggestSignIn: matched == 'try again later' || lower.contains('sign in'),
    ));
  }

  static String _makeErrorCode(String category, String raw) {
    final now = DateTime.now();
    final ts =
        '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final detail = raw
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final trimmed = detail.length > 18 ? detail.substring(0, 18) : detail;
    return 'ISLE-YT-$category-$trimmed-$ts';
  }

  Future<void> _handleFailure({
    required Future<void> Function() reload,
    required Future<void> Function(String url) loadUrl,
    required Future<void> Function() loadHome,
    required Future<void> Function() openExternal,
    Future<void> Function()? switchUserAgent,
    required String reason,
  }) async {
    if (_recoveryInFlight) return;

    if (_autoRetries < maxAutoRetries) {
      _autoRetries++;
      _recoveryInFlight = true;
      _emit(IslePlaybackRecoveryState.recovering(
        attempt: _autoRetries,
        maxAttempts: maxAutoRetries,
        message: '자동 복구 중… ($_autoRetries/$maxAutoRetries)',
      ));
      _startRecoveryTimeout();
      // 첫 복구: 예전 버전이 남긴 OS 차단(youtube.com web content filter)을 먼저 해제.
      // reload·UA 교체로는 OS 레벨 차단을 풀 수 없으므로 실제 원인부터 제거한다.
      if (!_osBlockCleared && onClearOsBlock != null) {
        _osBlockCleared = true;
        try {
          await onClearOsBlock!();
          IsleAppLogService.log('Playback recovery: cleared OS web content filter');
        } catch (e) {
          IsleAppLogService.log('Playback recovery OS clear failed: $e', level: IsleLogLevel.warn);
        }
      }
      await Future<void>.delayed(Duration(milliseconds: 350 * _autoRetries));
      try {
        if (_autoRetries == 1) {
          await reload();
        } else if (_autoRetries == 2 && switchUserAgent != null) {
          await switchUserAgent();
          await loadUrl(_lastUrl.isNotEmpty ? _lastUrl : '');
        } else {
          await loadHome();
        }
      } catch (e) {
        IsleAppLogService.log('Recovery step failed: $e', level: IsleLogLevel.warn);
        _recoveryInFlight = false;
        _emit(IslePlaybackRecoveryState.error(
          message: reason.isEmpty ? '페이지를 불러오지 못했습니다' : reason,
          errorCode: _makeErrorCode('NET', reason),
          canRetry: true,
        ));
      }
      return;
    }
    _recoveryInFlight = false;
    _emit(IslePlaybackRecoveryState.error(
      message: reason.isEmpty ? '페이지를 불러오지 못했습니다' : reason,
      errorCode: _makeErrorCode(reason.startsWith('HTTP') ? 'HTTP' : 'NET', reason),
      canRetry: true,
    ));
  }

  Future<void> manualRetry({
    required Future<void> Function() reload,
    required Future<void> Function(String url) loadUrl,
  }) async {
    _cancelRecoveryTimer();
    _autoRetries = 0;
    _recoveryInFlight = true;
    _emit(IslePlaybackRecoveryState.recovering(message: '다시 시도…', attempt: 1, maxAttempts: 1));
    _startRecoveryTimeout();
    try {
      if (_lastUrl.isNotEmpty) {
        await loadUrl(_lastUrl);
      } else {
        await reload();
      }
    } finally {
      _recoveryInFlight = false;
    }
  }
}

@immutable
class IslePlaybackRecoveryState {
  const IslePlaybackRecoveryState({
    required this.phase,
    this.loading = false,
    this.message,
    this.errorCode,
    this.attempt = 0,
    this.maxAttempts = 3,
    this.canRetry = false,
    this.suggestSignIn = false,
  });

  const IslePlaybackRecoveryState.idle() : this(phase: IslePlaybackPhase.idle);

  factory IslePlaybackRecoveryState.recovering({
    int attempt = 0,
    int maxAttempts = 3,
    String? message,
  }) =>
      IslePlaybackRecoveryState(
        phase: IslePlaybackPhase.recovering,
        loading: true,
        attempt: attempt,
        maxAttempts: maxAttempts,
        message: message,
      );

  factory IslePlaybackRecoveryState.error({
    required String message,
    String? errorCode,
    bool canRetry = true,
    bool suggestSignIn = false,
  }) =>
      IslePlaybackRecoveryState(
        phase: IslePlaybackPhase.error,
        message: message,
        errorCode: errorCode,
        canRetry: canRetry,
        suggestSignIn: suggestSignIn,
      );

  final IslePlaybackPhase phase;
  final bool loading;
  final String? message;
  final String? errorCode;
  final int attempt;
  final int maxAttempts;
  final bool canRetry;
  final bool suggestSignIn;

  bool get showOverlay => phase == IslePlaybackPhase.error;

  bool get showRecoveringOverlay => phase == IslePlaybackPhase.recovering;

  IslePlaybackRecoveryState copyWith({
    IslePlaybackPhase? phase,
    bool? loading,
    String? message,
    String? errorCode,
    int? attempt,
    int? maxAttempts,
    bool? canRetry,
    bool? suggestSignIn,
  }) =>
      IslePlaybackRecoveryState(
        phase: phase ?? this.phase,
        loading: loading ?? this.loading,
        message: message ?? this.message,
        errorCode: errorCode ?? this.errorCode,
        attempt: attempt ?? this.attempt,
        maxAttempts: maxAttempts ?? this.maxAttempts,
        canRetry: canRetry ?? this.canRetry,
        suggestSignIn: suggestSignIn ?? this.suggestSignIn,
      );
}

enum IslePlaybackPhase { idle, recovering, error }
