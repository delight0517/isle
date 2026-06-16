import '../ai/ai_client.dart';
import '../library/ai_summarizer.dart';
import '../utils/url_parser.dart';
import '../youtube/youtube_caption_fetcher.dart';
import '../youtube/youtube_focus_metadata_service.dart';
import '../youtube/youtube_focus_summary_service.dart';
import '../services/isle_app_log_service.dart';
import 'insight_extractor_remote_service.dart';
import 'insight_portfolio_store.dart';
import 'models/insight_card.dart';

/// 공유·URL → CC 분석 → 3줄 요약 → (옵션) 메모 다듬기 → 포트폴리오 카드
class InsightCrafterService {
  InsightCrafterService._();

  static Future<InsightCard?> craftFromUrl(
    String url, {
    String roughNote = '',
    bool preferCloud = true,
  }) async {
    final vid = UrlParser.extractYouTubeVideoId(url);
    if (vid == null || vid.length != 11) return null;

    await InsightPortfolioStore.ensureOpen();
    final existing = InsightPortfolioStore.findByUrl(url);
    if (existing != null && existing.hasArticle && roughNote.isEmpty) {
      return existing;
    }

    if (preferCloud && InsightExtractorRemoteService.canUse) {
      try {
        final remote = await InsightExtractorRemoteService.extract(
          videoUrl: url,
          userMemo: roughNote,
        );
        if (remote != null) return remote;
      } catch (e) {
        IsleAppLogService.log(
          'insight cloud fallback local: $e',
          level: IsleLogLevel.info,
        );
      }
    }

    final meta = await YoutubeFocusMetadataService.fetchById(vid);
    final title = meta?.title ?? 'YouTube';
    final channel = meta?.channelName ?? '';
    final thumb = meta?.thumbnailUrl ?? UrlParser.youTubeThumbnail(vid);

    final transcript = await YoutubeCaptionFetcher.fetchTranscript(vid);
    final lines = await YoutubeFocusSummaryService.summarize(
      videoId: vid,
      title: title,
      channelName: channel,
      countTowardQuota: false,
    );

    final keywords = _extractKeywords(title, channel, transcript, lines);
    var article = existing?.articleBody ?? '';
    if (transcript != null && transcript.length >= 40) {
      article = await AiSummarizer.summarizeArticle(
        title: title,
        url: url,
        sourceType: 'youtube',
        channelName: channel,
        feature: 'insight_portfolio',
        transcriptExcerpt: transcript.length <= 6000 ? transcript : transcript.substring(0, 6000),
      );
    } else if (article.isEmpty) {
      article = lines.join('\n\n');
    }

    var polishedNote = roughNote.trim();
    if (polishedNote.isNotEmpty) {
      polishedNote = await polishUserNote(
        roughNote: polishedNote,
        title: title,
        channelName: channel,
        contextLines: lines,
      );
    }

    final card = InsightCard(
      id: existing?.id ?? 'ins_${vid}_${DateTime.now().millisecondsSinceEpoch}',
      url: url.contains('http') ? url : 'https://www.youtube.com/watch?v=$vid',
      title: title,
      thumbnailUrl: thumb,
      channelName: channel,
      keywords: keywords,
      aiSummaryLines: lines,
      userNote: polishedNote.isNotEmpty ? polishedNote : (existing?.userNote ?? ''),
      articleBody: article,
      transcript: transcript,
      createdAt: existing?.createdAt ?? DateTime.now(),
      published: existing?.published ?? false,
      publishedAt: existing?.publishedAt,
    );
    return InsightPortfolioStore.upsert(card);
  }

  static Future<String> polishUserNote({
    required String roughNote,
    required String title,
    required String channelName,
    List<String> contextLines = const [],
  }) async {
    final rough = roughNote.trim();
    if (rough.isEmpty) return rough;

    if (AiClient.isConfigured) {
      final ctx = contextLines.isEmpty ? '' : '\n영상 요약:\n${contextLines.join('\n')}';
      final result = await AiClient.chat(
        feature: 'insight_polish_note',
        systemPrompt:
            'Turn rough Korean notes into one polished sentence (expert insight tone, under 120 chars). '
            'No hashtags. No hype.',
        userPrompt: '제목: $title\n채널: $channelName$ctx\n\n거친 메모:\n$rough',
        maxTokens: 120,
        temperature: 0.4,
      );
      if (result.usedAi && result.content.trim().isNotEmpty) {
        return result.content.trim();
      }
    }

    return rough.length <= 120 ? rough : '${rough.substring(0, 117)}…';
  }

  static List<String> _extractKeywords(
    String title,
    String channel,
    String? transcript,
    List<String> lines,
  ) {
    final blob = '$title $channel ${lines.join(' ')} ${transcript ?? ''}';
    final words = <String, int>{};
    final re = RegExp(r'[#\p{L}]{2,}', unicode: true);
    for (final m in re.allMatches(blob)) {
      final w = m.group(0)!.replaceAll('#', '').trim();
      if (w.length < 2) continue;
      final lower = w.toLowerCase();
      if (_stop.contains(lower)) continue;
      words[w] = (words[w] ?? 0) + 1;
    }
    final sorted = words.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(6).map((e) => e.key).toList();
  }

  static const _stop = {
    'the', 'and', 'for', 'that', 'this', 'with', 'from', 'youtube', 'video',
    '영상', '채널', '입니다', '합니다', '있는', '하는', '에서',
  };
}
