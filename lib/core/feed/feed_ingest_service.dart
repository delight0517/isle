import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../features/feed/data/feed_repository.dart';
import '../../features/feed/data/models/feed_item.dart';
import '../library/brunch_profile_fetcher.dart';
import '../library/models/connected_source.dart';
import '../library/personal_library_store.dart';
import '../perf/isle_heavy_work.dart';
import '../perf/isle_heavy_work_reporter.dart';
import '../services/isle_app_log_service.dart';
import 'feed_ingest_isolate.dart';
import 'feed_ingest_store.dart';
import 'feed_source_resolver.dart';

/// 백그라운드 피드 수집 — RSS·HTML (유료 API 없음)
class FeedIngestService {
  FeedIngestService._();

  static const refreshInterval = Duration(hours: 3);
  static const maxItemsPerSource = 15;

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 18),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (compatible; IsleFeed/1.0; +https://isle.app)',
        'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
      },
    ),
  );

  static bool get isStale {
    final last = FeedIngestStore.lastRefreshAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= refreshInterval;
  }

  static Future<FeedIngestResult> refreshIfStale({bool force = false}) async {
    await FeedIngestStore.ensureOpen();
    if (!force && !isStale) {
      return FeedIngestResult.skipped(FeedIngestStore.load().length);
    }
    return refreshNow();
  }

  static Future<FeedIngestResult> refreshNow() => IsleHeavyWork.run(
        taskId: 'feed_refresh',
        userTitle: '피드를 새로고침하는 중',
        userWhy: '구독 채널·RSS에서 새 글을 모으는 작업이에요. '
            '지금은 이게 최우선 — 끝나면 피드가 바로 업데이트돼요.',
        estimatedMs: 6000,
        work: (r) => _refreshNowBody(r),
      );

  static Future<FeedIngestResult> _refreshNowBody(IsleHeavyWorkReporter r) async {
    await FeedIngestStore.ensureOpen();
    final sources = PersonalLibraryStore.loadSources();
    if (sources.isEmpty) {
      await FeedIngestStore.setLastRefresh(DateTime.now(), status: '구독 없음');
      return const FeedIngestResult(ok: true, itemCount: 0, message: '구독을 추가해 주세요');
    }

    final all = <FeedItem>[];
    final errors = <String>[];
    final total = sources.length;

    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      r.progress(
        0.08 + (i / total) * 0.72,
        stepLabel: '${source.displayName} 수집 중 (${i + 1}/$total)',
      );
      try {
        final items = await _fetchSource(source);
        all.addAll(items);
      } catch (e) {
        errors.add('${source.displayName}: $e');
        IsleAppLogService.log('Feed ingest ${source.displayName}: $e', level: IsleLogLevel.warn);
      }
    }

    r.progress(0.88, stepLabel: '중복 제거·정렬');
    final merged = await _dedupeAndSort(all);
    await FeedIngestStore.save(merged);
    final status = errors.isEmpty
        ? '${merged.length}개 · ${sources.length}개 구독'
        : '${merged.length}개 · 오류 ${errors.length}';
    await FeedIngestStore.setLastRefresh(DateTime.now(), status: status);

    return FeedIngestResult(
      ok: true,
      itemCount: merged.length,
      message: status,
      errors: errors,
    );
  }

  /// URL 붙여넣기 → 구독 저장 + 즉시 수집
  static Future<FeedIngestResult> addSubscriptionFromUrl(String urlInput) async {
    final resolved = await FeedSourceResolver.resolve(urlInput);
    if (resolved == null) {
      return const FeedIngestResult(
        ok: false,
        itemCount: 0,
        message: 'YouTube 채널·브런치·RSS 주소를 확인해 주세요',
      );
    }

    final list = PersonalLibraryStore.loadSources();
    final existing = list.indexWhere((s) => s.profileUrl == resolved.source.profileUrl);
    if (existing >= 0) {
      list[existing] = resolved.source.copyWith(
        displayName: resolved.source.displayName,
        addedAt: list[existing].addedAt,
      );
    } else {
      list.add(resolved.source);
    }
    await PersonalLibraryStore.saveSources(list);

    return refreshNow();
  }

  static Future<List<FeedItem>> _fetchSource(ConnectedSource source) async {
    switch (source.type) {
      case 'youtube':
        var channelId = source.id.startsWith('yt_') ? source.id.replaceFirst('yt_', '') : '';
        if (!channelId.startsWith('UC')) {
          final resolved = await FeedSourceResolver.resolve(source.profileUrl);
          channelId = resolved?.youtubeChannelId ?? '';
        }
        if (!channelId.startsWith('UC')) return [];
        return _fetchRss(
          'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId',
          sourceId: channelId,
          channelName: source.displayName,
          sourceType: 'youtube',
        );
      case 'brunch':
        final articles = await BrunchProfileFetcher.fetchArticles(source.profileUrl, maxArticles: maxItemsPerSource);
        return articles.map((e) => e.toFeedItem(relevanceBoost: 0.15)).toList();
      case 'rss':
      default:
        return _fetchRss(
          source.profileUrl,
          sourceId: source.id,
          channelName: source.displayName,
          sourceType: 'article',
        );
    }
  }

  static Future<List<FeedItem>> _fetchRss(
    String rssUrl, {
    required String sourceId,
    required String channelName,
    required String sourceType,
  }) async {
    final res = await _dio.get<String>(rssUrl);
    final maps = await compute(parseRssInIsolate, {
      'body': res.data ?? '',
      'sourceId': sourceId,
      'channelName': channelName,
      'sourceType': sourceType,
      'maxItems': maxItemsPerSource,
    });
    return feedItemsFromJsonMaps(maps);
  }

  static const _dedupeIsolateThreshold = 8;

  static Future<List<FeedItem>> _dedupeAndSort(List<FeedItem> items) async {
    if (items.length < _dedupeIsolateThreshold) {
      return _dedupeAndSortSync(items);
    }
    final maps = items.map((e) => e.toJson()).toList();
    final merged = await compute(dedupeAndSortInIsolate, maps);
    return feedItemsFromJsonMaps(merged);
  }

  static List<FeedItem> _dedupeAndSortSync(List<FeedItem> items) {
    final byUrl = <String, FeedItem>{};
    for (final item in items) {
      if (FeedRepository.isDemoItem(item)) continue;
      final existing = byUrl[item.url];
      if (existing == null || item.publishedAt.isAfter(existing.publishedAt)) {
        byUrl[item.url] = item;
      }
    }
    final list = byUrl.values.toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return list;
  }

  static String? nextRefreshLabel() {
    final last = FeedIngestStore.lastRefreshAt;
    if (last == null) return null;
    final next = last.add(refreshInterval);
    final remain = next.difference(DateTime.now());
    if (remain.isNegative) return '곧 갱신';
    if (remain.inHours >= 1) return '${remain.inHours}시간 후 자동 갱신';
    return '${remain.inMinutes}분 후 자동 갱신';
  }
}

class FeedIngestResult {
  const FeedIngestResult({
    required this.ok,
    required this.itemCount,
    required this.message,
    this.errors = const [],
  });

  final bool ok;
  final int itemCount;
  final String message;
  final List<String> errors;

  factory FeedIngestResult.skipped(int cached) => FeedIngestResult(
        ok: true,
        itemCount: cached,
        message: '캐시 사용 ($cached개)',
      );
}
