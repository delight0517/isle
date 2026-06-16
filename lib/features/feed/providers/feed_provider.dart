import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/env.dart';
import '../../../core/perf/isle_heavy_work.dart';
import '../../../core/feed/feed_block_filter.dart';
import '../../../core/feed/feed_ingest_service.dart';
import '../../../core/feed/feed_ingest_store.dart';
import '../../../core/library/personal_library_store.dart';
import '../../../core/library/youtube_account_sync_service.dart';
import '../../../core/services/feed_local_cache.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/library/digest_scheduler.dart';
import '../../../core/library/interest_pipeline_service.dart';
import '../../../core/library/engagement_tracker.dart';
import '../../../core/feed/feed_boost_service.dart';
import '../../../core/feed/feed_boost_store.dart';
import '../../../core/library/feed_ranker.dart';
import '../../../core/youtube/blocked_channel_store.dart';
import '../../../core/youtube/blocked_url_store.dart';
import '../../../core/youtube/content_filter_store.dart';
import '../../archive/providers/archive_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import 'feed_search_provider.dart';
import '../../../core/insight/insight_portfolio_store.dart';
import '../../insight/providers/insight_portfolio_provider.dart';
import '../data/feed_repository.dart';
import '../data/models/feed_item.dart';

final feedRepoProvider = Provider((_) => FeedRepository());

final activeFeedFilterProvider = StateProvider<String?>((ref) => null);

class FeedNotifier extends AsyncNotifier<List<FeedItem>> {
  @override
  Future<List<FeedItem>> build() async {
    await FeedIngestService.refreshIfStale();
    ref.watch(connectedSourcesProvider);
    ref.watch(blockedChannelsProvider);
    ref.watch(blockedVideosProvider);
    ref.watch(blockedKeywordsProvider);
    ref.watch(blockedUrlsProvider);
    ref.watch(personalLibraryProvider);
    ref.watch(youtubeLibrarySyncTickProvider);
    ref.watch(feedBoostChannelsProvider);
    ref.watch(feedBoostGenresProvider);
    ref.watch(insightPortfolioRevisionProvider);
    final topic = ref.watch(activeFeedFilterProvider);
    final search = ref.watch(feedSearchQueryProvider);
    final user = ref.watch(authStateProvider).value;
    List<String> interests = [];
    if (user != null && Env.isSupabaseConfigured) {
      try {
        interests = await ref.read(settingsRepoProvider).listInterestTagNames(user.id);
      } catch (_) {
        interests = [];
      }
    }
    if (interests.isEmpty) {
      interests = IsleUserDefaults.onboardingInterestTags;
    }

    List<FeedItem> items = FeedIngestStore.load();

    if (items.isEmpty) {
      if (user == null) {
        items = await ref.read(feedRepoProvider).getFeed(
              userId: '',
              topicFilter: topic,
              userInterestTags: interests,
            );
      } else if (Env.isSupabaseConfigured) {
        try {
          items = await ref.read(feedRepoProvider).getFeed(
                userId: user.id,
                topicFilter: topic,
                userInterestTags: interests,
              );
          await FeedLocalCache.save(user.id, topic, items);
        } catch (_) {
          items = FeedLocalCache.load(user.id, topic) ?? [];
          if (topic != null && topic.isNotEmpty) {
            items = items.where((i) => i.detectedTopics.contains(topic)).toList();
          }
          items = FeedRepository.applyUserInterestRanking(items, interests);
        }
      }
    }

    items = items.where((i) => !FeedRepository.isDemoItem(i)).toList();
    if (topic != null && topic.isNotEmpty) {
      items = items.where((i) => i.detectedTopics.contains(topic)).toList();
    }

    if (items.length >= 35) {
      return IsleHeavyWork.run(
        taskId: 'feed_rank',
        userTitle: '피드 순서를 정리하는 중',
        userWhy: '관심·시청 이력·차단 규칙을 반영해 글 순서를 맞추는 작업이에요. '
            '항목이 많을수록 시간이 걸려요 — 지금은 이게 최우선이에요.',
        estimatedMs: 3500,
        work: (r) async {
          r.progress(0.25, stepLabel: '관심 태그·부스트');
          var ranked = FeedRepository.applyUserInterestRanking(items, interests);
          ranked = FeedRanker.merge(
            remote: ranked,
            library: PersonalLibraryStore.loadEntries(),
            searchQuery: search,
          );
          r.progress(0.55, stepLabel: '채널·장르 가중치');
          ranked = FeedBoostService.applyBoosts(
            ranked,
            channels: ref.read(feedBoostChannelsProvider),
            genres: ref.read(feedBoostGenresProvider),
          );
          r.progress(0.75, stepLabel: '인사이트·차단 필터');
          return _finalizeFeedItems(ranked, ref);
        },
      );
    }

    items = FeedRepository.applyUserInterestRanking(items, interests);
    items = FeedRanker.merge(
      remote: items,
      library: PersonalLibraryStore.loadEntries(),
      searchQuery: search,
    );
    items = FeedBoostService.applyBoosts(
      items,
      channels: ref.read(feedBoostChannelsProvider),
      genres: ref.read(feedBoostGenresProvider),
    );

    return _finalizeFeedItems(items, ref);
  }

  Future<List<FeedItem>> _finalizeFeedItems(
    List<FeedItem> items,
    Ref ref,
  ) async {
    final insights = InsightPortfolioStore.publishedAsFeedItems();
    if (insights.isNotEmpty) {
      final seen = items.map((e) => e.url).toSet();
      for (final ins in insights) {
        if (!seen.contains(ins.url)) {
          items.insert(0, ins);
          seen.add(ins.url);
        }
      }
    }

    if (IsleUserDefaults.hideBlockedInFeed) {
      final blocked = ref.read(blockedChannelsProvider);
      final videos = ref.read(blockedVideosProvider);
      final kws = ref.read(blockedKeywordsProvider);
      final blockedUrls = ref.read(blockedUrlsProvider);
      items = await FeedBlockFilter.apply(
        items: items,
        channels: blocked,
        videoIds: videos.map((v) => v.videoId).toList(),
        keywords: kws,
        blockedUrls: blockedUrls,
        enabled: true,
      );
    }
    return items;
  }

  /// 차단 목록 변경 후 피드에서 해당 채널 항목 제거
  Future<void> removeBlockedFromFeed() async {
    final list = state.value;
    if (list == null) return;
    final blocked = ref.read(blockedChannelsProvider);
    final videos = ref.read(blockedVideosProvider);
    final kws = ref.read(blockedKeywordsProvider);
    final blockedUrls = ref.read(blockedUrlsProvider);
    final filtered = await FeedBlockFilter.apply(
      items: list,
      channels: blocked,
      videoIds: videos.map((v) => v.videoId).toList(),
      keywords: kws,
      blockedUrls: blockedUrls,
      enabled: IsleUserDefaults.hideBlockedInFeed,
    );
    state = AsyncData(filtered);
  }

  /// 원격 저장이 필요한 경우 삽입 성공 후에만 목록에서 제거합니다. 실패 시 `false`.
  Future<bool> archiveItem(FeedItem item) async {
    final user = ref.read(authStateProvider).value;
    final list = state.value;
    if (list == null) return false;

    if (user != null && Env.isSupabaseConfigured) {
      try {
        await ref.read(archiveRepoProvider).insertFromFeedItem(userId: user.id, item: item);
        state = AsyncData(list.where((i) => i.id != item.id).toList());
        return true;
      } catch (_) {
        return false;
      }
    }

    state = AsyncData(list.where((i) => i.id != item.id).toList());
    return true;
  }

  Future<void> dismissItem(FeedItem item) async {
    final user = ref.read(authStateProvider).value;
    final list = state.value;
    if (list == null) return;
    state = AsyncData(list.where((i) => i.id != item.id).toList());
    if (user != null) {
      await ref.read(feedRepoProvider).dismissItem(user.id, item.url);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    await FeedIngestService.refreshNow();
    if (IsleUserDefaults.digestToFeedEnabled) {
      await DigestScheduler.runIfAllowed();
    }
    await InterestPipelineService.processDueItems();
    state = await AsyncValue.guard(() => build());
  }
}

/// 피드·검색 가중치용 — 콘텐츠 열람 기록
Future<void> recordFeedEngagement(FeedItem item) async {
  await EngagementTracker.recordContentOpen(item.url, sourceType: item.sourceType);
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, List<FeedItem>>(FeedNotifier.new);
