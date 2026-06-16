import 'dart:convert';

import '../ai/ai_client.dart';
import '../services/isle_user_defaults.dart';
import '../utils/topic_matcher.dart';
import '../utils/youtube_paste_resolver.dart';
import 'models/youtube_creator_insight.dart';
import 'youtube_caption_fetcher.dart';

/// URL + CC(가능 시) + 유저 관심 분야 → 차별점·핵심·적용 아이디어
class YoutubeCreatorInsightService {
  YoutubeCreatorInsightService._();

  static Future<YoutubeCreatorInsight> analyzeUrl(
    String rawUrl, {
    List<String>? userInterests,
  }) async {
    final info = await YoutubePasteResolver.resolve(rawUrl);
    if (!info.valid || info.videoId == null) {
      throw StateError(info.errorMessage ?? 'YouTube 영상 URL을 확인해 주세요');
    }
    return analyzeVideo(
      videoId: info.videoId!,
      sourceUrl: info.sourceUrl ?? rawUrl,
      title: info.title ?? 'YouTube',
      channelName: info.channelName ?? '',
      userInterests: userInterests,
    );
  }

  static Future<YoutubeCreatorInsight> analyzeVideo({
    required String videoId,
    required String sourceUrl,
    required String title,
    required String channelName,
    List<String>? userInterests,
  }) async {
    final interests = _resolveInterests(userInterests);
    final captions = await YoutubeCaptionFetcher.fetchTranscript(videoId);
    final usedCaptions = captions != null && captions.length >= 40;

    if (AiClient.isConfigured) {
      final ai = await _analyzeWithAi(
        videoId: videoId,
        sourceUrl: sourceUrl,
        title: title,
        channelName: channelName,
        interests: interests,
        captions: captions,
        usedCaptions: usedCaptions,
      );
      if (ai != null) return ai;
    }

    return _fallback(
      videoId: videoId,
      sourceUrl: sourceUrl,
      title: title,
      channelName: channelName,
      interests: interests,
      usedCaptions: usedCaptions,
    );
  }

  static List<String> _resolveInterests(List<String>? userInterests) {
    if (userInterests != null && userInterests.isNotEmpty) return userInterests;
    final local = IsleUserDefaults.onboardingInterestTags;
    if (local.isNotEmpty) return local;
    return TopicMatcher.presetInterestTags.take(4).toList();
  }

  static Future<YoutubeCreatorInsight?> _analyzeWithAi({
    required String videoId,
    required String sourceUrl,
    required String title,
    required String channelName,
    required List<String> interests,
    required String? captions,
    required bool usedCaptions,
  }) async {
    final captionBlock = usedCaptions
        ? '자막(CC) 발췌:\n${captions!}'
        : '자막 없음 — 제목·채널명·관심 분야만으로 추론해 주세요.';

    final result = await AiClient.chat(
      feature: 'youtube_creator_insight',
      systemPrompt:
          'You are a YouTube strategist for Korean creators. Output JSON only with keys: '
          'one_liner (Korean, 1 sentence hook), '
          'differentiation_points (array of 2-4 Korean bullets: what makes THIS video/channel unique vs typical content), '
          'key_points (array of 3-6 Korean bullets: core takeaways for viewers), '
          'applicable_to_creator (array of objects with interest, application, action_idea — '
          'map each user interest tag to how THEY could apply lessons from this video). '
          'Be specific to the video. If captions exist, ground analysis in CC content.',
      userPrompt: '''
영상 제목: $title
채널: $channelName
URL: $sourceUrl
내 관심·크리에이터 분야: ${interests.join(', ')}

$captionBlock
''',
      maxTokens: 900,
      temperature: 0.45,
      jsonObject: true,
    );

    if (!result.usedAi || result.content.isEmpty) return null;

    try {
      final map = Map<String, dynamic>.from(jsonDecode(result.content) as Map);
      return YoutubeCreatorInsight(
        videoId: videoId,
        sourceUrl: sourceUrl,
        title: title,
        channelName: channelName,
        oneLiner: map['one_liner'] as String? ?? '',
        differentiationPoints: _strList(map['differentiation_points']),
        keyPoints: _strList(map['key_points']),
        applications: _parseApplications(map['applicable_to_creator']),
        usedCaptions: usedCaptions,
        usedAi: true,
        analyzedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static List<String> _strList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }

  static List<CreatorApplication> _parseApplications(dynamic raw) {
    final out = <CreatorApplication>[];
    if (raw is! List) return out;
    for (final item in raw) {
      if (item is! Map) continue;
      out.add(CreatorApplication.fromJson(Map<String, dynamic>.from(item)));
    }
    return out;
  }

  static YoutubeCreatorInsight _fallback({
    required String videoId,
    required String sourceUrl,
    required String title,
    required String channelName,
    required List<String> interests,
    required bool usedCaptions,
  }) {
    final topics = TopicMatcher.detectTopics('$title $channelName');
    final apps = interests.map((interest) {
      final match = topics.contains(interest);
      return CreatorApplication(
        interest: interest,
        application: match
            ? '「$title」 주제가 $interest 분야와 겹쳐요. 영상 구조·훅을 참고할 만합니다.'
            : '$interest 채널이라면 이 영상의 톤·편집 중 한 가지만 벤치마킹해 보세요.',
        actionIdea: match ? '비슷한 주제로 60초 핵심 요약 숏츠 제작' : '관심 분야 키워드로 검색해 경쟁 채널 3개 비교',
      );
    }).toList();

    return YoutubeCreatorInsight(
      videoId: videoId,
      sourceUrl: sourceUrl,
      title: title,
      channelName: channelName,
      oneLiner: usedCaptions
          ? '자막 기반 로컬 분석 — AI 설정 시 더 정밀해져요.'
          : '제목·채널 기준 로컬 분석입니다. AI 센터에서 API를 연결하면 CC 기반 분석이 가능해요.',
      differentiationPoints: [
        if (channelName.isNotEmpty) '「$channelName」 채널 고유의 제목·포맷',
        if (usedCaptions) '자막에서 뽑은 실제 발화 기반 (AI 미연결)',
        '같은 주제 영상 대비 훅·제목 각도를 직접 비교해 보세요',
      ],
      keyPoints: [
        '영상 핵심: $title',
        if (usedCaptions) '자막 요약은 AI 연결 후 다시 분석하는 것을 권장',
        '관심 분야: ${interests.take(3).join(', ')}',
      ],
      applications: apps,
      usedCaptions: usedCaptions,
      usedAi: false,
      analyzedAt: DateTime.now(),
    );
  }
}
