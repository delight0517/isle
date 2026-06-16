import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/env.dart';
import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';
import '../utils/url_parser.dart';
import '../youtube/youtube_focus_metadata_service.dart';
import 'insight_portfolio_store.dart';
import 'models/insight_card.dart';

/// Supabase Edge `insight_extractor` — 자막·LLM·DB (API 키는 서버만)
class InsightExtractorRemoteService {
  InsightExtractorRemoteService._();

  static bool get canUse =>
      Env.isSupabaseConfigured &&
      IsleUserDefaults.insightCloudExtractionEnabled &&
      Supabase.instance.client.auth.currentUser != null;

  static Future<InsightCard?> extract({
    required String videoUrl,
    String userMemo = '',
  }) async {
    if (!canUse) return null;

    final vid = UrlParser.extractYouTubeVideoId(videoUrl);
    if (vid == null || vid.length != 11) return null;

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'insight_extractor',
        body: {
          'videoUrl': videoUrl,
          'userMemo': userMemo,
        },
      );

      if (res.status == 401) {
        throw StateError('로그인이 필요합니다.');
      }
      if (res.status == 422) {
        final map = _parseData(res.data);
        throw StateError(map['message'] as String? ?? '자막(CC)이 없어요.');
      }
      if (res.status != 200) {
        IsleAppLogService.log(
          'insight_extractor ${res.status} ${res.data}',
          level: IsleLogLevel.warn,
        );
        return null;
      }

      final map = _parseData(res.data);
      if (map['error'] != null) {
        IsleAppLogService.log('insight_extractor error: ${map['error']}', level: IsleLogLevel.warn);
        return null;
      }

      return _mapToInsightCard(map, videoUrl, vid);
    } catch (e, st) {
      IsleAppLogService.log('insight_extractor failed: $e\n$st', level: IsleLogLevel.warn);
      rethrow;
    }
  }

  static Map<String, dynamic> _parseData(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) return Map<String, dynamic>.from(jsonDecode(data) as Map);
    return {};
  }

  static Future<InsightCard> _mapToInsightCard(
    Map<String, dynamic> row,
    String videoUrl,
    String videoId,
  ) async {
    final linesRaw = row['ai_summary_lines'];
    List<String> lines;
    if (linesRaw is List) {
      lines = linesRaw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    } else {
      final summary = row['ai_summary'] as String? ?? '';
      lines = summary.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }

    final core = (row['core_keyword'] as String? ?? '').trim();
    final keywords = <String>[
      if (core.isNotEmpty) core.replaceFirst('#', ''),
    ];

    var title = row['title'] as String? ?? '';
    var channel = row['channel_name'] as String? ?? '';
    var thumb = row['thumbnail_url'] as String? ?? '';
    if (title.isEmpty) {
      final meta = await YoutubeFocusMetadataService.fetchById(videoId);
      title = meta?.title ?? 'YouTube';
      channel = channel.isEmpty ? (meta?.channelName ?? '') : channel;
      thumb = thumb.isEmpty ? (meta?.thumbnailUrl ?? UrlParser.youTubeThumbnail(videoId)) : thumb;
    }

    final memo = row['user_memo'] as String? ?? '';
    final excerpt = row['transcript_excerpt'] as String?;
    final nodeId = row['id'] as String? ?? 'ins_${videoId}_${DateTime.now().millisecondsSinceEpoch}';

    await InsightPortfolioStore.ensureOpen();
    final existing = InsightPortfolioStore.findByUrl(videoUrl);

    final card = InsightCard(
      id: existing?.id ?? nodeId,
      url: row['video_url'] as String? ?? videoUrl,
      title: title,
      thumbnailUrl: thumb,
      channelName: channel,
      keywords: keywords.isNotEmpty ? keywords : (existing?.keywords ?? const []),
      aiSummaryLines: lines.isNotEmpty ? lines : (existing?.aiSummaryLines ?? const []),
      userNote: memo.isNotEmpty ? memo : (existing?.userNote ?? ''),
      articleBody: existing?.articleBody ?? lines.join('\n\n'),
      transcript: excerpt ?? existing?.transcript,
      createdAt: existing?.createdAt ?? DateTime.now(),
      published: existing?.published ?? false,
      publishedAt: existing?.publishedAt,
    );

    return InsightPortfolioStore.upsert(card);
  }
}
