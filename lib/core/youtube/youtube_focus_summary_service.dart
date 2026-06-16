import 'dart:convert';

import '../ai/ai_client.dart';
import 'youtube_caption_fetcher.dart';
import 'youtube_focus_summary_quota_store.dart';

/// Read-first: 영상 재생 전 3줄 요약
class YoutubeFocusSummaryService {
  YoutubeFocusSummaryService._();

  static Future<List<String>> summarize({
    required String videoId,
    required String title,
    required String channelName,
    bool countTowardQuota = true,
  }) async {
    if (countTowardQuota && !YoutubeFocusSummaryQuotaStore.canRequestSummary) {
      return _quotaExceeded(title: title);
    }

    final captions = await YoutubeCaptionFetcher.fetchTranscript(videoId, maxChars: 8000);
    final usedCaptions = captions != null && captions.length >= 40;

    if (AiClient.isConfigured) {
      final lines = await _aiSummary(
        title: title,
        channelName: channelName,
        captions: captions,
        usedCaptions: usedCaptions,
      );
      if (lines != null && lines.isNotEmpty) {
        if (countTowardQuota) await YoutubeFocusSummaryQuotaStore.recordUse();
        return lines;
      }
    }

    final fb = _fallback(title: title, channelName: channelName, captions: captions);
    if (countTowardQuota && captions != null) {
      await YoutubeFocusSummaryQuotaStore.recordUse();
    }
    return fb;
  }

  static List<String> _quotaExceeded({required String title}) {
    return [
      '오늘 무료 AI 요약 ${YoutubeFocusSummaryQuotaStore.freeDailyLimit}회를 모두 썼어요.',
      '「$title」 — 자막·제목만으로 판단하거나 내일 다시 요약해 보세요.',
      'Isle 설정에서 AI 키를 넣으면 품질이 올라가요 (한도는 동일).',
    ];
  }

  static Future<List<String>?> _aiSummary({
    required String title,
    required String channelName,
    required String? captions,
    required bool usedCaptions,
  }) async {
    final captionBlock = usedCaptions
        ? '자막:\n${captions!}'
        : '자막 없음 — 제목·채널만으로 짧게 추정';

    final result = await AiClient.chat(
      feature: 'youtube_focus_read_first',
      systemPrompt:
          'You help users decide if a YouTube video is worth their time. '
          'Reply with JSON only: {"lines":["line1","line2","line3"]} — exactly 3 Korean sentences, '
          'each under 80 characters, no hype, factual, what the viewer will learn.',
      userPrompt: '''
제목: $title
채널: $channelName
$captionBlock
''',
      maxTokens: 220,
      temperature: 0.35,
      jsonObject: true,
    );

    if (!result.usedAi || result.content.isEmpty) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(result.content) as Map);
      final raw = map['lines'];
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).take(3).toList();
      }
    } catch (_) {}
    return null;
  }

  static List<String> _fallback({
    required String title,
    required String channelName,
    required String? captions,
  }) {
    if (captions != null && captions.length > 80) {
      final parts = captions.split(RegExp(r'[.!?]\s+')).where((p) => p.trim().length > 12).take(3);
      final list = parts.map((p) => p.trim()).toList();
      if (list.length >= 2) return list;
    }
    return [
      '「$title」의 핵심만 골라 볼 수 있어요.',
      '$channelName 채널 영상 — 아래 재생 전에 정말 필요한지 스스로 물어보세요.',
      'AI 키를 설정하면 자막 기반 3줄 요약이 더 정확해집니다.',
    ];
  }
}
