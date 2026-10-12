import 'dart:async';

import '../insight/insight_crafter_service.dart';
import '../library/ai_summarizer.dart';
import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';
import '../utils/url_parser.dart';
import '../youtube/youtube_caption_fetcher.dart';
import '../youtube/youtube_playlist_ingest_service.dart';
import '../youtube/youtube_focus_metadata_service.dart';
import '../ai/ai_client.dart';
import 'shared_playlist_store.dart';

class SharedPlaylistCcSyncResult {
  const SharedPlaylistCcSyncResult({
    required this.ingested,
    required this.ccFetched,
    required this.articlesBuilt,
  });

  final int ingested;
  final int ccFetched;
  final int articlesBuilt;
}

/// 공유 큐·지원 플레이리스트 — URL·자막·기사 본문 동기화 [Volt: resume 시 stale만]
class SharedPlaylistCcService {
  SharedPlaylistCcService._();

  static const _staleHours = 6;

  static Future<void> refreshIfStale() async {
    if (!IsleUserDefaults.shareQueueAutoSync) return;
    final last = IsleUserDefaults.shareQueueLastSyncMs;
    if (last != null) {
      final age = DateTime.now().millisecondsSinceEpoch - last;
      if (age < _staleHours * 3600 * 1000) return;
    }
    await syncNow(ingestSources: true, maxCcPerRun: 8);
  }

  static Future<SharedPlaylistCcSyncResult> syncNow({
    bool ingestSources = true,
    int maxCcPerRun = 12,
  }) async {
    await SharedPlaylistStore.ensureOpen();
    await SharedPlaylistStore.ensureIsleQueue();

    var ingested = 0;
    if (ingestSources) {
      ingested = await _ingestSubscribedSources();
    }

    var ccFetched = 0;
    var articlesBuilt = 0;
    const queueId = SharedPlaylistStore.isleQueuePlaylistId;
    final playlists = SharedPlaylistStore.loadAll();
    final targets = playlists
        .where((p) =>
            p.id == queueId || p.items.any((i) => i.sourceType == 'youtube'))
        .toList();

    for (final pl in targets) {
      if (ccFetched >= maxCcPerRun) break;
      final updated = <SharedPlaylistItem>[];
      var changed = false;
      for (final item in pl.items) {
        if (ccFetched >= maxCcPerRun) {
          updated.add(item);
          continue;
        }
        final vid = UrlParser.extractYouTubeVideoId(item.url);
        if (vid == null) {
          updated.add(item);
          continue;
        }
        final needsCc = !item.hasTranscript ||
            item.ccSyncedAt == null ||
            DateTime.now().difference(item.ccSyncedAt!) >
                const Duration(hours: 72);
        if (!needsCc) {
          updated.add(item);
          continue;
        }

        var next = item;
        final transcript = await YoutubeCaptionFetcher.fetchTranscript(vid);
        if (transcript != null && transcript.length >= 40) {
          final meta = await YoutubeFocusMetadataService.fetchById(vid);
          next = item.copyWith(
            transcript: transcript,
            channelName: meta?.channelName ?? item.channelName,
            title: meta?.title != null && meta!.title != 'YouTube'
                ? meta.title
                : item.title,
            thumbnailUrl: meta?.thumbnailUrl ?? item.thumbnailUrl,
            ccSyncedAt: DateTime.now(),
          );
          ccFetched++;
          changed = true;
        }

        if (next.hasTranscript && !next.hasArticle) {
          final article = await _buildArticle(next);
          if (article.length >= 80) {
            next = next.copyWith(articleBody: article);
            articlesBuilt++;
            changed = true;
          }
        }
        if (next.hasTranscript || next.hasArticle) {
          unawaited(
            InsightCrafterService.craftFromUrl(
              next.url,
              roughNote: '',
            ),
          );
        }
        updated.add(next);
      }
      if (changed) {
        await SharedPlaylistStore.upsert(pl.copyWith(items: updated));
      }
    }

    await IsleUserDefaults.setShareQueueLastSyncMs(
        DateTime.now().millisecondsSinceEpoch);
    IsleAppLogService.log(
        'CC sync · ingest=$ingested cc=$ccFetched articles=$articlesBuilt');
    return SharedPlaylistCcSyncResult(
      ingested: ingested,
      ccFetched: ccFetched,
      articlesBuilt: articlesBuilt,
    );
  }

  static Future<int> _ingestSubscribedSources() async {
    final urls = IsleUserDefaults.shareQueueSourceUrls;
    if (urls.isEmpty) return 0;
    var n = 0;
    for (final url in urls) {
      final vids = await YoutubePlaylistIngestService.fetchPlaylistVideos(url);
      for (final v in vids) {
        final added = await _addToQueue(
          url: 'https://www.youtube.com/watch?v=${v.videoId}',
          title: v.title,
          thumbnailUrl: v.thumbnailUrl ?? UrlParser.youTubeThumbnail(v.videoId),
          channelName: v.channelName,
        );
        if (added) n++;
      }
    }
    return n;
  }

  static Future<bool> _addToQueue({
    required String url,
    required String title,
    required String thumbnailUrl,
    String channelName = '',
  }) async {
    return SharedPlaylistStore.addItem(
      playlistId: SharedPlaylistStore.isleQueuePlaylistId,
      item: SharedPlaylistItem(
        id: 'q_${UrlParser.extractYouTubeVideoId(url) ?? DateTime.now().microsecondsSinceEpoch}',
        url: url,
        title: title,
        thumbnailUrl: thumbnailUrl,
        sourceType: 'youtube',
        channelName: channelName,
        addedAt: DateTime.now(),
      ),
    );
  }

  static Future<String> _buildArticle(SharedPlaylistItem item) async {
    final t = item.transcript!.trim();
    final title = item.title;
    final channel = item.channelName;

    if (AiClient.isConfigured) {
      try {
        final excerpt = t.length <= 6000 ? t : t.substring(0, 6000);
        return await AiSummarizer.summarizeArticle(
          title: title,
          url: item.url,
          sourceType: 'youtube',
          channelName: channel,
          feature: 'share_queue_article',
          transcriptExcerpt: excerpt,
        );
      } catch (_) {}
    }

    final intro = channel.isNotEmpty ? '$channel · ' : '';
    final paras = <String>[];
    final sentences = t.split(RegExp(r'(?<=[.!?。])\s+'));
    var buf = StringBuffer();
    for (var i = 0; i < sentences.length; i++) {
      buf.write(sentences[i].trim());
      buf.write(' ');
      if ((i + 1) % 4 == 0 || i == sentences.length - 1) {
        final p = buf.toString().trim();
        if (p.isNotEmpty) paras.add(p);
        buf = StringBuffer();
      }
    }
    return '$intro$title\n\n${paras.join('\n\n')}\n\n— CC 자막 기반 (Isle)';
  }

  static List<SharedPlaylistItem> queueItems() {
    final q =
        SharedPlaylistStore.findById(SharedPlaylistStore.isleQueuePlaylistId);
    return q?.items ?? const [];
  }
}
