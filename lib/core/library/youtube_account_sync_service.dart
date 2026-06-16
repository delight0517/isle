import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';
import '../share/shared_playlist_store.dart';
import '../utils/url_parser.dart';
import 'models/library_entry.dart';
import 'personal_library_store.dart';
import 'youtube_library_service.dart';

class YoutubeAccountSyncResult {
  const YoutubeAccountSyncResult({
    this.watchLaterCount = 0,
    this.watchLaterNew = 0,
    this.playlistVideosCount = 0,
    this.playlistVideosNew = 0,
    this.queueAdded = 0,
    this.skipped = false,
    this.message,
  });

  final int watchLaterCount;
  final int watchLaterNew;
  final int playlistVideosCount;
  final int playlistVideosNew;
  final int queueAdded;
  final bool skipped;
  final String? message;

  int get totalNew => watchLaterNew + playlistVideosNew;
}

/// 백그라운드 동기화 후 피드 재계산 트리거
final youtubeLibrarySyncTickProvider = Provider<int>(
  (_) => IsleUserDefaults.youtubeLastAccountSyncMs ?? 0,
);

/// Google 계정 — 나중에 볼·선택 플레이리스트 → Hive 라이브러리 (자동·수동) [Volt: stale만]
class YoutubeAccountSyncService {
  YoutubeAccountSyncService._();

  static const _staleHours = 3;

  static Future<void> refreshIfStale() async {
    if (!IsleUserDefaults.youtubeAccountAutoSync) return;
    if (YoutubeLibraryService.currentAccount == null) return;
    final last = IsleUserDefaults.youtubeLastAccountSyncMs;
    if (last != null) {
      final age = DateTime.now().millisecondsSinceEpoch - last;
      if (age < _staleHours * 3600 * 1000) return;
    }
    await syncNow();
  }

  static Future<YoutubeAccountSyncResult> syncNow({bool force = false}) async {
    if (!force && !IsleUserDefaults.youtubeAccountAutoSync) {
      return const YoutubeAccountSyncResult(skipped: true, message: '자동 동기화가 꺼져 있어요');
    }
    if (YoutubeLibraryService.currentAccount == null) {
      return const YoutubeAccountSyncResult(skipped: true, message: 'Google 로그인이 필요해요');
    }

    await PersonalLibraryStore.ensureOpen();

    var wlCount = 0;
    var wlNew = 0;
    var plCount = 0;
    var plNew = 0;
    var queueAdded = 0;

    try {
      if (IsleUserDefaults.youtubeSyncWatchLaterToLibrary) {
        final wl = await YoutubeLibraryService.fetchWatchLater(maxResults: 100);
        wlCount = wl.length;
        wlNew = await PersonalLibraryStore.upsertEntries(wl);
        if (IsleUserDefaults.shareQueueSyncWatchLater) {
          queueAdded += await _mergeWatchLaterToQueue(wl);
        }
      }

      final playlistIds = IsleUserDefaults.youtubeSyncPlaylistIds;
      for (final pid in playlistIds) {
        if (pid.isEmpty || pid == 'WL') continue;
        try {
          final items = await YoutubeLibraryService.fetchPlaylistEntries(
            playlistId: pid,
            maxResults: 80,
            origin: 'youtube_playlist',
          );
          plCount += items.length;
          plNew += await PersonalLibraryStore.upsertEntries(items);
        } catch (e, st) {
          IsleAppLogService.log(
            'Playlist sync $pid failed: $e',
            level: IsleLogLevel.warn,
            stack: st,
          );
        }
      }

      await IsleUserDefaults.setYoutubeLastAccountSyncMs(DateTime.now().millisecondsSinceEpoch);
      IsleAppLogService.log(
        'YouTube account sync · WL $wlCount (+$wlNew) · playlists $plCount (+$plNew) · queue +$queueAdded',
      );

      return YoutubeAccountSyncResult(
        watchLaterCount: wlCount,
        watchLaterNew: wlNew,
        playlistVideosCount: plCount,
        playlistVideosNew: plNew,
        queueAdded: queueAdded,
      );
    } catch (e, st) {
      IsleAppLogService.log('YouTube account sync failed: $e', level: IsleLogLevel.error, stack: st);
      return YoutubeAccountSyncResult(message: e.toString());
    }
  }

  static Future<int> _mergeWatchLaterToQueue(List<LibraryEntry> wl) async {
    await SharedPlaylistStore.ensureOpen();
    await SharedPlaylistStore.ensureIsleQueue();
    var n = 0;
    for (final e in wl) {
      final added = await SharedPlaylistStore.addItem(
        playlistId: SharedPlaylistStore.isleQueuePlaylistId,
        item: SharedPlaylistItem(
          id: 'q_${UrlParser.extractYouTubeVideoId(e.url) ?? e.id}',
          url: e.url,
          title: e.title,
          thumbnailUrl: e.thumbnailUrl,
          sourceType: 'youtube',
          channelName: e.channelName,
          addedAt: DateTime.now(),
        ),
      );
      if (added) n++;
    }
    return n;
  }

  static int watchLaterInLibraryCount() {
    return PersonalLibraryStore.loadEntries().where((e) => e.origin == 'watch_later').length;
  }
}
