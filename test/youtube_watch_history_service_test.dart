import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:isle/core/library/models/library_entry.dart';
import 'package:isle/core/library/personal_library_store.dart';
import 'package:isle/core/library/watch_history_recommender.dart';
import 'package:isle/core/library/youtube_watch_history_service.dart';
import 'package:isle/core/services/isle_user_defaults.dart';
import 'package:isle/core/library/feed_ranker.dart';
import 'package:isle/core/library/engagement_tracker.dart';
import 'package:isle/features/feed/data/models/feed_item.dart';

void main() {
  late Directory directory;
  const videoId = 'dQw4w9WgXcQ';
  const videoUrl = 'https://www.youtube.com/watch?v=$videoId';

  setUpAll(() async {
    directory = Directory.systemTemp.createTempSync('moa-watch-history-');
    Hive.init(directory.path);
    await Hive.openBox<String>('isle_cache');
    await PersonalLibraryStore.ensureOpen();
    await EngagementTracker.ensureOpen();
  });

  setUp(() async {
    await Hive.box<String>('isle_cache').clear();
    await Hive.box<String>('isle_engagement').clear();
    await PersonalLibraryStore.saveEntries([]);
    YoutubeWatchHistoryService.resetForTest();
    await IsleUserDefaults.setTrackYoutubeWatchHistory(true);
  });

  tearDown(() async {
    await YoutubeWatchHistoryService.flushPending();
    YoutubeWatchHistoryService.resetForTest();
  });

  test('persists only confirmed playback seconds and keeps Watch Later intact',
      () async {
    final saved = LibraryEntry.fromWatchLater(
      videoId: videoId,
      title: 'Keep this saved title',
      channelName: 'Saved channel',
    );
    await PersonalLibraryStore.saveEntries([saved]);

    for (var i = 0; i < 5; i++) {
      await YoutubeWatchHistoryService.recordPlaybackTick(
        videoId: videoId,
        url: videoUrl,
        seconds: 3,
        channelId: 'UC-learning',
        channelName: 'Learning channel',
        title: 'Learning video',
      );
    }

    final entries = PersonalLibraryStore.loadEntries();
    final history =
        entries.singleWhere((entry) => entry.origin == 'youtube_history');
    final watchLater =
        entries.singleWhere((entry) => entry.origin == 'watch_later');
    expect(history.watchSeconds, 15);
    expect(history.lastWatchedAt, isNotNull);
    expect(history.channelId, 'UC-learning');
    expect(watchLater.title, 'Keep this saved title');
    expect(entries, hasLength(2));
  });

  test(
      'turning history off prevents new records and clear preserves Watch Later',
      () async {
    await IsleUserDefaults.setTrackYoutubeWatchHistory(false);
    await YoutubeWatchHistoryService.recordPlaybackTick(
      videoId: videoId,
      url: videoUrl,
      seconds: 5,
    );
    expect(PersonalLibraryStore.loadEntries(), isEmpty);

    await PersonalLibraryStore.saveEntries([
      LibraryEntry.fromWatchLater(videoId: videoId, title: 'Saved'),
      LibraryEntry.fromWatchHistory(
        videoId: 'abcdefghijk',
        title: 'Watched',
        watchSeconds: 45,
        lastWatchedAt: DateTime.now(),
      ),
    ]);
    expect(await YoutubeWatchHistoryService.clearHistory(), 1);
    expect(PersonalLibraryStore.loadEntries().map((e) => e.origin),
        ['watch_later']);
  });

  test(
      'recommendation signal ignores navigation-only rows and weights playback',
      () async {
    final now = DateTime.now();
    await PersonalLibraryStore.saveEntries([
      LibraryEntry.fromWatchHistory(
        videoId: videoId,
        title: 'Opened but never played',
        channelId: 'UC-opened',
        channelName: 'Opened channel',
      ),
      LibraryEntry.fromWatchHistory(
        videoId: 'abcdefghijk',
        title: 'AI 프로그래밍 강의',
        channelId: 'UC-watched',
        channelName: 'Watched channel',
        watchSeconds: 120,
        lastWatchedAt: now,
      ),
    ]);
    final boosts = WatchHistoryRecommender.channelBoosts();
    expect(boosts.containsKey('uc-opened'), isFalse);
    expect(boosts['uc-watched'], greaterThan(0.09));
    expect(WatchHistoryRecommender.channelNamesByKey().containsKey('uc-opened'),
        isFalse);
    expect(WatchHistoryRecommender.topicBoosts()['기술/IT'], greaterThan(0));

    final recommendation = FeedItem(
      id: 'candidate',
      title: 'Flutter development',
      url: 'https://example.com/flutter',
      thumbnailUrl: '',
      sourceType: 'article',
      channelId: 'UC-unrelated',
      channelName: 'Other source',
      channelAvatar: '',
      detectedTopics: const ['기술/IT'],
      relevanceScore: 0.2,
      publishedAt: now,
    );
    final ranked =
        FeedRanker.merge(remote: [recommendation], library: []).single;
    expect(ranked.relevanceScore, greaterThan(0.2));
    expect(ranked.recommendReason, contains('시청 주제'));
  });

  test('legacy library JSON safely defaults to no verified watch time', () {
    final old = LibraryEntry.fromJson({
      'id': 'yt_hist_$videoId',
      'title': 'Legacy entry',
      'url': videoUrl,
      'source_type': 'youtube',
      'channel_id': 'UC-old',
      'channel_name': 'Old channel',
      'origin': 'youtube_history',
      'imported_at': DateTime.now().toIso8601String(),
    });
    expect(old.watchSeconds, 0);
    expect(old.lastWatchedAt, isNull);
    expect(old.toJson().containsKey('watch_seconds'), isFalse);
  });
}
