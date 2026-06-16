import 'dart:async';

import '../services/isle_user_defaults.dart';
import '../utils/url_parser.dart';
import 'models/library_entry.dart';
import 'personal_library_store.dart';

/// WebView 시청 URL — 디바운스·로컬만 (백그라운드 oEmbed 금지) [Volt]
class YoutubeWatchHistoryService {
  YoutubeWatchHistoryService._();

  static String? _pendingVideoId;
  static String? _pendingUrl;
  static String? _pendingChannelId;
  static String? _pendingChannelName;
  static String? _pendingTitle;
  static Timer? _debounce;

  static void scheduleFromUrl(String url) {
    if (!IsleUserDefaults.trackYoutubeWatchHistory) return;
    if (!url.contains('youtube.com') && !url.contains('youtu.be')) return;

    final videoId = UrlParser.extractYouTubeVideoId(url);
    if (videoId == null || videoId.length != 11) return;

    // 새 영상으로 전환 시 채널 메타 초기화 (probe가 도착하면 채워짐)
    if (_pendingVideoId != videoId) {
      _pendingChannelId = null;
      _pendingChannelName = null;
      _pendingTitle = null;
    }
    _pendingVideoId = videoId;
    _pendingUrl = url;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), () {
      final id = _pendingVideoId;
      final u = _pendingUrl;
      if (id == null || u == null) return;
      unawaited(_commit(
        id,
        u,
        channelId: _pendingChannelId ?? '',
        channelName: _pendingChannelName ?? '',
        title: _pendingTitle,
      ));
    });
  }

  /// WebView 채널 probe가 도착하면 호출 — 진행 중인 항목 + 기존 이력 메타 보강
  static Future<void> attachChannelInfo({
    required String videoId,
    String channelId = '',
    String channelName = '',
    String videoTitle = '',
  }) async {
    if (videoId.length != 11) return;
    // 디바운스 중인 항목 보강
    if (_pendingVideoId == videoId) {
      if (channelId.isNotEmpty) _pendingChannelId = channelId;
      if (channelName.isNotEmpty) _pendingChannelName = channelName;
      if (videoTitle.isNotEmpty) _pendingTitle = videoTitle;
    }

    // 이미 저장된 항목이 비어있다면 보강 (채널·제목)
    final list = PersonalLibraryStore.loadEntries();
    final idx = list.indexWhere((e) => e.id == 'yt_hist_$videoId');
    if (idx < 0) return;

    final prev = list[idx];
    final needsTitle = (prev.title.isEmpty || prev.title == 'YouTube 영상') && videoTitle.isNotEmpty;
    final needsChannel =
        (prev.channelName.isEmpty && channelName.isNotEmpty) ||
            (prev.channelId.isEmpty && channelId.isNotEmpty);
    if (!needsTitle && !needsChannel) return;

    final updated = LibraryEntry(
      id: prev.id,
      title: needsTitle ? videoTitle : prev.title,
      url: prev.url,
      thumbnailUrl: prev.thumbnailUrl,
      sourceType: prev.sourceType,
      channelId: channelId.isNotEmpty ? channelId : prev.channelId,
      channelName: channelName.isNotEmpty ? channelName : prev.channelName,
      summary: prev.summary,
      origin: prev.origin,
      sourceId: prev.sourceId,
      importedAt: prev.importedAt,
      publishedAt: prev.publishedAt,
    );
    await PersonalLibraryStore.upsertEntries([updated]);
  }

  static Future<int> _commit(
    String videoId,
    String url, {
    String channelId = '',
    String channelName = '',
    String? title,
  }) async {
    final list = PersonalLibraryStore.loadEntries();
    if (list.any((e) => e.id == 'yt_hist_$videoId')) {
      final existing = list.firstWhere((e) => e.id == 'yt_hist_$videoId');
      if (DateTime.now().difference(existing.importedAt) < const Duration(minutes: 20)) {
        // 기존 항목 메타 보강만 시도
        if ((channelName.isNotEmpty && existing.channelName.isEmpty) ||
            (channelId.isNotEmpty && existing.channelId.isEmpty) ||
            (title != null && title.isNotEmpty && existing.title == 'YouTube 영상')) {
          await attachChannelInfo(
            videoId: videoId,
            channelId: channelId,
            channelName: channelName,
            videoTitle: title ?? '',
          );
        }
        return 0;
      }
    }

    final entry = LibraryEntry.fromWatchHistory(
      videoId: videoId,
      title: (title != null && title.isNotEmpty) ? title : 'YouTube 영상',
      channelName: channelName,
      channelId: channelId,
    );
    return PersonalLibraryStore.upsertEntries([entry]);
  }

  static void cancelPending() {
    _debounce?.cancel();
    _pendingVideoId = null;
    _pendingUrl = null;
    _pendingChannelId = null;
    _pendingChannelName = null;
    _pendingTitle = null;
  }
}
