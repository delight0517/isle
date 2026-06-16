import 'dart:convert';

import 'package:dio/dio.dart';

import 'url_parser.dart';

/// oEmbed + URL 파싱으로 "붙여넣은 링크"에서 채널·영상 정보 추출
class YoutubePasteResolver {
  YoutubePasteResolver._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
      headers: {'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15'},
    ),
  );

  static Future<YoutubePasteInfo> resolve(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) {
      return const YoutubePasteInfo(valid: false, errorMessage: 'URL을 입력하세요');
    }
    if (!url.contains('youtube.com') && !url.contains('youtu.be')) {
      return const YoutubePasteInfo(valid: false, errorMessage: 'YouTube 링크만 붙여넣을 수 있어요');
    }

    final videoId = UrlParser.extractYouTubeVideoId(url);
    String? channelIdFromPath;
    String? handleFromPath;

    final ch = RegExp(r'youtube\.com/channel/(UC[\w-]+)', caseSensitive: false).firstMatch(url);
    if (ch != null) channelIdFromPath = ch.group(1);

    final at = RegExp(r'youtube\.com/@([\w.-]+)', caseSensitive: false).firstMatch(url);
    if (at != null) handleFromPath = at.group(1);

    final cslug = RegExp(r'youtube\.com/c/([\w.-]+)', caseSensitive: false).firstMatch(url);
    if (cslug != null && channelIdFromPath == null && handleFromPath == null) {
      handleFromPath = cslug.group(1);
    }

    String? title;
    String? authorName;
    String? authorUrl;

    if (videoId != null || url.contains('youtube.com') || url.contains('youtu.be')) {
      try {
        final oembed = Uri.parse('https://www.youtube.com/oembed').replace(
          queryParameters: {'url': url, 'format': 'json'},
        );
        final res = await _dio.get<dynamic>(oembed.toString());
        final body = res.data;
        final map = body is Map<String, dynamic>
            ? body
            : jsonDecode(body as String) as Map<String, dynamic>;
        title = map['title'] as String?;
        authorName = map['author_name'] as String?;
        authorUrl = map['author_url'] as String?;
      } catch (_) {
        /* oEmbed 실패해도 URL만으로 진행 */
      }
    }

    final parsedFromAuthor = _parseAuthorUrl(authorUrl);

    var channelId = channelIdFromPath ?? parsedFromAuthor.$1;
    if (channelId != null && channelId.startsWith('uc')) {
      channelId = 'UC${channelId.substring(2)}';
    }
    final handle = handleFromPath ?? parsedFromAuthor.$2;
    final channelName = authorName ?? '';

    final hasChannel =
        (channelId != null && channelId.isNotEmpty) || (handle != null && handle.isNotEmpty);
    if (videoId == null && !hasChannel) {
      return const YoutubePasteInfo(
        valid: false,
        errorMessage: 'YouTube 링크가 아니거나 인식할 수 없습니다',
      );
    }

    return YoutubePasteInfo(
      valid: true,
      videoId: videoId,
      channelId: channelId,
      handle: handle,
      channelName: channelName,
      title: title ?? url,
      sourceUrl: url,
    );
  }

  /// (UC… , @handle 없이 handle 문자열)
  static (String?, String?) _parseAuthorUrl(String? authorUrl) {
    if (authorUrl == null || authorUrl.isEmpty) return (null, null);
    final uc = RegExp(r'/channel/(UC[\w-]+)', caseSensitive: false).firstMatch(authorUrl);
    if (uc != null) return (uc.group(1), null);
    final h = RegExp(r'/@([\w.-]+)', caseSensitive: false).firstMatch(authorUrl);
    if (h != null) return (null, h.group(1));
    return (null, null);
  }
}

class YoutubePasteInfo {
  final bool valid;
  final String? errorMessage;
  final String? videoId;
  final String? channelId;
  final String? handle;
  final String? channelName;
  final String? title;
  final String? sourceUrl;

  const YoutubePasteInfo({
    required this.valid,
    this.errorMessage,
    this.videoId,
    this.channelId,
    this.handle,
    this.channelName,
    this.title,
    this.sourceUrl,
  });

  /// 차단 저장용 채널 ID (UC… 또는 @handle 또는 c/slug)
  String get channelIdForStore {
    if (channelId != null && channelId!.isNotEmpty) return channelId!;
    if (handle != null && handle!.isNotEmpty) return '@$handle';
    return '';
  }

  bool get canBlockChannel =>
      channelIdForStore.isNotEmpty || (channelName != null && channelName!.trim().isNotEmpty);

  bool get canBlockThisVideo => videoId != null && videoId!.length == 11;
}
