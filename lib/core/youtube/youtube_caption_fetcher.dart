import 'package:dio/dio.dart';

/// YouTube 자막(CC) — 공개 timedtext (API 키 없음, 없으면 null)
class YoutubeCaptionFetcher {
  YoutubeCaptionFetcher._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      headers: {'User-Agent': 'Mozilla/5.0 (compatible; Isle/1.0)'},
    ),
  );

  static const _langOrder = ['ko', 'a.ko', 'en', 'a.en', 'ja'];

  static Future<String?> fetchTranscript(String videoId, {int maxChars = 12000}) async {
    if (videoId.length != 11) return null;
    for (final lang in _langOrder) {
      final text = await _fetchLang(videoId, lang);
      if (text != null && text.trim().length >= 40) {
        final t = text.trim();
        return t.length <= maxChars ? t : '${t.substring(0, maxChars)}…';
      }
    }
    return null;
  }

  static Future<String?> _fetchLang(String videoId, String lang) async {
    try {
      final res = await _dio.get<String>(
        'https://www.youtube.com/api/timedtext',
        queryParameters: {
          'v': videoId,
          'lang': lang,
          'fmt': 'srv3',
        },
        options: Options(responseType: ResponseType.plain),
      );
      final body = res.data;
      if (body == null || body.isEmpty) return null;
      return _parseTimedText(body);
    } catch (_) {
      return null;
    }
  }

  static String? _parseTimedText(String raw) {
    if (!raw.contains('<')) {
      return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    final buf = StringBuffer();
    final re = RegExp(r'>([^<]+)<');
    for (final m in re.allMatches(raw)) {
      final t = m.group(1)?.trim();
      if (t == null || t.isEmpty) continue;
      if (t == '\n') continue;
      buf.write(t);
      buf.write(' ');
    }
    final out = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return out.isEmpty ? null : out;
  }
}
