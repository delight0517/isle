import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_client.dart';
import '../constants/env.dart';
import '../library/youtube_library_service.dart';
import '../services/isle_user_defaults.dart';
import 'blocked_channel_store.dart';
import 'channel_genre_block_store.dart';
import 'content_filter_store.dart';
import 'models/channel_genre_profile.dart';
import 'models/channel_genre_sample.dart';

class GenreApplyResult {
  final String genreLabel;
  final int keywordsAdded;
  final int channelsAdded;
  final String explanation;
  final bool usedAi;

  const GenreApplyResult({
    required this.genreLabel,
    required this.keywordsAdded,
    required this.channelsAdded,
    required this.explanation,
    required this.usedAi,
  });
}

/// 샘플 누적 → AI 유형 추론 → 키워드·유사 채널 일괄 차단
class ChannelGenreAiService {
  ChannelGenreAiService._();

  /// 분야 이름만으로 AI 차단 (예: 스타크래프트2, ASMR)
  static Future<GenreApplyResult?> applyTopicLabel(
    WidgetRef ref, {
    required String topicLabel,
    required String languageCode,
  }) async {
    final label = topicLabel.trim();
    if (label.length < 2) return null;

    final parsed = AiClient.isConfigured
        ? await _callAiForTopic(label, languageCode)
        : _fallbackParseTopic(label, languageCode);

    if (parsed == null) return null;

    final fakeSamples = [
      ChannelGenreSample(
        channelId: 'topic',
        channelName: label,
        pageUrl: '',
        recordedAt: DateTime.now(),
        reason: '분야 차단: $label',
      ),
    ];

    return _applyParsed(ref, parsed, fakeSamples, languageCode);
  }

  static Future<GenreApplyResult?> analyzeAndApply(
    WidgetRef ref, {
    required String languageCode,
    List<ChannelGenreSample>? samples,
  }) async {
    final list = samples ?? ChannelGenreBlockStore.loadSamples();
    if (list.length < IsleUserDefaults.genreBlockMinSamples) return null;

    final parsed = AiClient.isConfigured
        ? await _callAi(list, languageCode)
        : _fallbackParse(list, languageCode);

    if (parsed == null) return null;
    return _applyParsed(ref, parsed, list, languageCode);
  }

  static Future<GenreApplyResult?> _applyParsed(
    WidgetRef ref,
    Map<String, dynamic> parsed,
    List<ChannelGenreSample> list,
    String languageCode,
  ) async {
    var keywordsAdded = 0;
    var channelsAdded = 0;

    final keywords = <String>{
      ...((parsed['keywords'] as List?) ?? []).map((e) => e.toString().trim().toLowerCase()),
      ...((parsed['channel_name_substrings'] as List?) ?? [])
          .map((e) => e.toString().trim().toLowerCase()),
    }..removeWhere((s) => s.isEmpty || s.length < 2);

    final kwNotifier = ref.read(blockedKeywordsProvider.notifier);
    for (final k in keywords) {
      final before = ref.read(blockedKeywordsProvider).length;
      await kwNotifier.add(k);
      if (ref.read(blockedKeywordsProvider).length > before) keywordsAdded++;
    }

    final chNotifier = ref.read(blockedChannelsProvider.notifier);
    final suggestedNames = ((parsed['suggested_channel_names'] as List?) ?? [])
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final maxChannels = IsleUserDefaults.genreMaxChannelsPerRun;

    for (final name in suggestedNames.take(60)) {
      if (channelsAdded >= maxChannels) break;
      await chNotifier.blockChannel(channelId: name, channelName: name);
      channelsAdded++;
    }

    if (Env.isGoogleSignInConfigured && YoutubeLibraryService.currentAccount != null) {
      final queries = ((parsed['youtube_search_queries'] as List?) ?? [])
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .take(IsleUserDefaults.genreSearchQueriesPerRun)
          .toList();
      for (final q in queries) {
        if (channelsAdded >= maxChannels) break;
        try {
          final hits = await YoutubeLibraryService.searchChannels(q, maxResults: 50);
          for (final h in hits) {
            if (channelsAdded >= maxChannels) break;
            await chNotifier.blockChannel(channelId: h.channelId, channelName: h.channelName);
            channelsAdded++;
          }
        } catch (_) {}
      }
    }

    final profile = ChannelGenreProfile(
      id: 'genre_${DateTime.now().millisecondsSinceEpoch}',
      genreLabel: parsed['genre_label'] as String? ?? '차단 유형',
      keywords: keywords.toList(),
      searchQueries: List<String>.from(parsed['youtube_search_queries'] as List? ?? []),
      explanation: parsed['explanation'] as String? ?? '',
      sampleCount: list.length,
      channelsAutoBlocked: channelsAdded,
      analyzedAt: DateTime.now(),
    );
    await ChannelGenreBlockStore.addProfile(profile);

    return GenreApplyResult(
      genreLabel: profile.genreLabel,
      keywordsAdded: keywordsAdded,
      channelsAdded: channelsAdded,
      explanation: profile.explanation,
      usedAi: AiClient.isConfigured &&
          !(parsed['explanation'] as String? ?? '').contains('AI 키 없음'),
    );
  }

  static Future<Map<String, dynamic>?> _callAi(
    List<ChannelGenreSample> samples,
    String languageCode,
  ) async {
    final lines = samples
        .map((s) => 'channel="${s.channelName}" id=${s.channelId} url=${s.pageUrl} reason=${s.reason ?? ""}')
        .join('\n');

    final result = await AiClient.chat(
      feature: 'genre_block',
      systemPrompt:
          'You help users block unwanted YouTube genres. Output JSON only with keys: '
          'genre_label, keywords (array, include $languageCode and English terms for titles/channels), '
          'channel_name_substrings (array), youtube_search_queries (array, 2-4 queries to find similar channels), '
          'suggested_channel_names (array, up to 20 plausible channel name fragments), '
          'explanation (short, in ${languageCode == 'ko' ? 'Korean' : 'English'}). '
          'Focus on genre/topic/language the user rejects, not politics unless samples show it.',
      userPrompt: 'User app language: $languageCode\nBlocked channel samples:\n$lines',
      maxTokens: 600,
      temperature: 0.3,
      jsonObject: true,
    );

    if (!result.usedAi || result.content.isEmpty) {
      return _fallbackParse(samples, languageCode);
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(result.content) as Map);
    } catch (_) {
      return _fallbackParse(samples, languageCode);
    }
  }

  static Future<Map<String, dynamic>?> _callAiForTopic(
    String topicLabel,
    String languageCode,
  ) async {
    final result = await AiClient.chat(
      feature: 'genre_block_topic',
      systemPrompt:
          'User wants to hide a whole topic/genre on YouTube. Output JSON only: '
          'genre_label, keywords (array, Korean+English for titles), '
          'channel_name_substrings (array), youtube_search_queries (array, 3-5), '
          'suggested_channel_names (array, up to 25), '
          'explanation (short Korean).',
      userPrompt: '차단할 분야/주제: $topicLabel\n앱 언어: $languageCode',
      maxTokens: 700,
      temperature: 0.35,
      jsonObject: true,
    );
    if (!result.usedAi || result.content.isEmpty) {
      return _fallbackParseTopic(topicLabel, languageCode);
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(result.content) as Map);
    } catch (_) {
      return _fallbackParseTopic(topicLabel, languageCode);
    }
  }

  static Map<String, dynamic> _fallbackParseTopic(String topicLabel, String languageCode) {
    final t = topicLabel.trim().toLowerCase();
    return {
      'genre_label': topicLabel,
      'keywords': [t, topicLabel],
      'channel_name_substrings': [t],
      'youtube_search_queries': [topicLabel, '$topicLabel 채널'],
      'suggested_channel_names': [],
      'explanation': languageCode == 'ko'
          ? '「$topicLabel」 관련 키워드로 숨깁니다. Google 로그인 시 유사 채널 검색 차단이 늘어납니다.'
          : 'Hiding by topic keywords for "$topicLabel".',
    };
  }

  static Map<String, dynamic> _fallbackParse(
    List<ChannelGenreSample> samples,
    String languageCode,
  ) {
    final names = samples.map((s) => s.channelName.toLowerCase()).where((s) => s.isNotEmpty);
    final words = <String>{};
    for (final n in names) {
      for (final part in n.split(RegExp(r'[\s|·\-_/]+'))) {
        if (part.length >= 3) words.add(part);
      }
    }
    return {
      'genre_label': languageCode == 'ko' ? '비슷한 유형' : 'Similar type',
      'keywords': words.take(15).toList(),
      'channel_name_substrings': words.take(8).toList(),
      'youtube_search_queries': samples.take(2).map((s) => s.channelName).toList(),
      'suggested_channel_names': [],
      'explanation': languageCode == 'ko'
          ? 'AI 키 없음 — 채널명에서 단어를 추출해 키워드로 숨깁니다.'
          : 'No AI key — extracted words from channel names as hide keywords.',
    };
  }
}
