import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';
import 'personal_library_store.dart';
import 'youtube_library_service.dart';

class YoutubeAccountSyncResult {
  const YoutubeAccountSyncResult({
    this.watchLaterCount = 0,
    this.playlistVideosCount = 0,
    this.playlistVideosNew = 0,
    this.watchLaterUnavailable = false,
    this.skipped = false,
    this.message,
  });

  final int watchLaterCount;
  final int playlistVideosCount;
  final int playlistVideosNew;
  final bool watchLaterUnavailable;
  final bool skipped;
  final String? message;

  int get totalNew => playlistVideosNew;
}

/// 백그라운드 동기화 후 피드 재계산 트리거
final youtubeLibrarySyncTickProvider = Provider<int>(
  (_) => IsleUserDefaults.youtubeLastAccountSyncMs ?? 0,
);

/// Google 계정 — 선택한 지원 플레이리스트 → Hive 라이브러리 (앱 복귀 시 stale만)
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
      return const YoutubeAccountSyncResult(
          skipped: true, message: '자동 동기화가 꺼져 있어요');
    }
    if (YoutubeLibraryService.currentAccount == null) {
      return const YoutubeAccountSyncResult(
          skipped: true, message: 'Google 로그인이 필요해요');
    }

    await PersonalLibraryStore.ensureOpen();

    var plCount = 0;
    var plNew = 0;
    try {
      // YouTube Data API explicitly forbids listing Watch Later and watch history.
      // Do not retry an endpoint that cannot work; MOA's own playback history is local.
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

      await IsleUserDefaults.setYoutubeLastAccountSyncMs(
          DateTime.now().millisecondsSinceEpoch);
      IsleAppLogService.log(
        'YouTube account sync · supported playlists $plCount (+$plNew)',
      );

      return YoutubeAccountSyncResult(
        playlistVideosCount: plCount,
        playlistVideosNew: plNew,
        watchLaterUnavailable: true,
        message: 'YouTube 공식 API는 Watch Later와 계정 시청 기록을 제공하지 않아요. '
            'MOA 안에서 재생한 기록은 기기 내에 자동 저장되고, 선택한 일반 플레이리스트만 계정 동기화돼요.',
      );
    } catch (e, st) {
      IsleAppLogService.log('YouTube account sync failed: $e',
          level: IsleLogLevel.error, stack: st);
      return YoutubeAccountSyncResult(message: e.toString());
    }
  }

  static int watchLaterInLibraryCount() {
    return PersonalLibraryStore.loadEntries()
        .where((e) => e.origin == 'watch_later')
        .length;
  }
}
