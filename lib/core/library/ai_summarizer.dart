import '../ai/ai_client.dart';

/// 요약 카드 — [AiClient] 단일 경로 (제공자·로그·예산)
class AiSummarizer {
  AiSummarizer._();

  static Future<String> summarizeArticle({
    required String title,
    required String url,
    String sourceType = 'article',
    String channelName = '',
    String feature = 'summarize',
    String? transcriptExcerpt,
  }) async {
    final ccBlock = transcriptExcerpt != null && transcriptExcerpt.trim().length >= 40
        ? '\n\nTranscript (CC) excerpt:\n${transcriptExcerpt.trim()}'
        : '';
    final result = await AiClient.chat(
      feature: feature,
      systemPrompt:
          transcriptExcerpt != null
              ? 'You turn YouTube CC transcripts into readable Korean article prose (3-6 short paragraphs). '
                  'No hype. Preserve facts. User reads instead of watching.'
              : 'You write short Korean news-style blurbs (2-3 sentences). No clickbait. '
                  'User reads summary instead of watching full video.',
      userPrompt:
          'Source: $sourceType\nTitle: $title\nChannel/Author: $channelName\nURL: $url$ccBlock\n\n'
          '${transcriptExcerpt != null ? 'Write the article body.' : 'Write a concise summary.'}',
      maxTokens: 180,
      temperature: 0.4,
    );

    if (result.usedAi && result.content.isNotEmpty) {
      return result.content;
    }
    return _fallbackSummary(title, sourceType, channelName);
  }

  static String _fallbackSummary(String title, String sourceType, String channelName) {
    final who = channelName.isNotEmpty ? '$channelName · ' : '';
    if (sourceType == 'youtube') {
      return '$who「$title」— 시청 대신 핵심만 읽을 수 있는 카드입니다. 원본은 탭해서 열 수 있어요.';
    }
    if (sourceType == 'brunch') {
      return '$who브런치 글 「$title」을 피드에 모았습니다. 전문은 탭해서 읽을 수 있어요.';
    }
    return '$who「$title」 요약 카드입니다.';
  }
}
