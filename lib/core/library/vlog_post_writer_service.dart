import '../ai/ai_client.dart';
import '../ai/ai_output_language.dart';
import '../utils/url_parser.dart';
import '../youtube/youtube_caption_fetcher.dart';
import 'models/library_entry.dart';

class VlogPostResult {
  const VlogPostResult({required this.success, this.post, this.error});

  final bool success;
  final String? post;
  final String? error;

  factory VlogPostResult.ok(String post) => VlogPostResult(success: true, post: post);
  factory VlogPostResult.fail(String error) => VlogPostResult(success: false, error: error);
}

/// 「나중에 볼」 유튜브 영상 → 자막(CC) 기반 브이로그 스타일 글 (버튼 한 번)
class VlogPostWriterService {
  VlogPostWriterService._();

  static Future<VlogPostResult> generate(LibraryEntry entry) async {
    if (entry.sourceType != 'youtube') {
      return VlogPostResult.fail('유튜브 영상만 브이로그 글로 만들 수 있어요');
    }
    final videoId = UrlParser.extractYouTubeVideoId(entry.url);
    if (videoId == null) {
      return VlogPostResult.fail('영상 주소를 확인할 수 없어요');
    }
    final transcript = await YoutubeCaptionFetcher.fetchTranscript(videoId);
    if (transcript == null || transcript.trim().length < 40) {
      return VlogPostResult.fail('이 영상은 자막(CC)이 없어서 글로 만들 수 없어요');
    }

    final post = await _write(entry: entry, transcript: transcript);
    return VlogPostResult.ok(post);
  }

  static Future<String> _write({
    required LibraryEntry entry,
    required String transcript,
  }) async {
    if (AiClient.isConfigured) {
      final excerpt = transcript.length <= 6000 ? transcript : transcript.substring(0, 6000);
      final lang = AiOutputLanguage.name;
      final result = await AiClient.chat(
        feature: 'watch_later_vlog',
        systemPrompt:
            'You are a writer who turns a YouTube video into a 1st-person vlog-style essay, '
            'as if you watched it yourself. Tone: casual, plain, no hype or promotional language. '
            'Structure: short intro (why you watched this) → 2-4 body paragraphs (retell the '
            'transcript as your own experience) → short closing thought. '
            "Don't invent facts not in the transcript. Write entirely in $lang.",
        userPrompt:
            'Video title: ${entry.title}\nChannel: ${entry.channelName}\nTranscript (CC):\n$excerpt\n\n'
            'Write a vlog-style essay based on this transcript, in $lang.',
        maxTokens: 700,
        temperature: 0.6,
      );
      if (result.usedAi && result.content.trim().isNotEmpty) {
        return result.content.trim();
      }
    }
    return _localFallback(entry: entry, transcript: transcript);
  }

  /// AI 미설정 시 로컬 대체 — 문장 4개 단위로 문단 나눔 + 브이로그 톤 인트로/아웃트로
  static String _localFallback({
    required LibraryEntry entry,
    required String transcript,
  }) {
    final channel = entry.channelName.trim();
    final who = channel.isNotEmpty ? '$channel 채널의 ' : '';
    final intro = '오늘은 $who「${entry.title}」를 자막으로 훑어봤다.';

    final sentences = transcript.split(RegExp(r'(?<=[.!?。])\s+'));
    final paras = <String>[];
    var buf = StringBuffer();
    for (var i = 0; i < sentences.length; i++) {
      final s = sentences[i].trim();
      if (s.isEmpty) continue;
      buf.write(s);
      buf.write(' ');
      if ((i + 1) % 4 == 0 || i == sentences.length - 1) {
        final p = buf.toString().trim();
        if (p.isNotEmpty) paras.add(p);
        buf = StringBuffer();
      }
    }
    const outro = '자막만 봤는데도 대충 흐름은 잡히는 것 같다 — 원본은 필요할 때 다시 열어봐야지.';
    return '$intro\n\n${paras.join('\n\n')}\n\n$outro';
  }
}
