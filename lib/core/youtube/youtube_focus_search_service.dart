import 'package:dio/dio.dart';

import '../library/youtube_library_service.dart';
import 'models/youtube_focus_video.dart';

/// 알고리즘 없는 순수 검색 — Piped(키 없음) · 로그인 시 YouTube Data API
class YoutubeFocusSearchService {
  YoutubeFocusSearchService._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'User-Agent': 'IsleYoutubeFocus/1.0'},
    ),
  );

  static const _pipedHosts = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.adminforge.de',
  ];

  static Future<List<YoutubeFocusVideo>> search(String query, {int maxResults = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final viaApi = await _searchYoutubeApi(q, maxResults: maxResults);
    if (viaApi.isNotEmpty) return viaApi;

    return _searchPiped(q, maxResults: maxResults);
  }

  static Future<List<YoutubeFocusVideo>> _searchYoutubeApi(String q, {required int maxResults}) async {
    if (!YoutubeLibraryService.canAttemptSignIn) return [];
    final token = await YoutubeLibraryService.accessTokenForApi();
    if (token == null) return [];

    try {
      final searchRes = await _dio.get<Map<String, dynamic>>(
        'https://www.googleapis.com/youtube/v3/search',
        queryParameters: {
          'part': 'snippet',
          'type': 'video',
          'q': q,
          'maxResults': maxResults.clamp(1, 25),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final ids = <String>[];
      final snippets = <String, Map<String, dynamic>>{};
      for (final raw in searchRes.data?['items'] as List? ?? []) {
        if (raw is! Map) continue;
        final id = raw['id']?['videoId'] as String?;
        final sn = raw['snippet'] as Map?;
        if (id == null || id.length != 11 || sn == null) continue;
        ids.add(id);
        snippets[id] = Map<String, dynamic>.from(sn);
      }
      if (ids.isEmpty) return [];

      final durRes = await _dio.get<Map<String, dynamic>>(
        'https://www.googleapis.com/youtube/v3/videos',
        queryParameters: {
          'part': 'contentDetails,snippet',
          'id': ids.join(','),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final durations = <String, int>{};
      for (final raw in durRes.data?['items'] as List? ?? []) {
        if (raw is! Map) continue;
        final id = raw['id'] as String?;
        final iso = raw['contentDetails']?['duration'] as String?;
        if (id != null && iso != null) {
          durations[id] = _parseIso8601Duration(iso);
        }
      }

      return ids.map((id) {
        final sn = snippets[id]!;
        return YoutubeFocusVideo(
          videoId: id,
          title: sn['title'] as String? ?? 'YouTube',
          channelName: sn['channelTitle'] as String? ?? '',
          thumbnailUrl: (sn['thumbnails'] as Map?)?['medium']?['url'] as String?,
          durationSeconds: durations[id] ?? 0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<YoutubeFocusVideo>> _searchPiped(String q, {required int maxResults}) async {
    for (final host in _pipedHosts) {
      try {
        final res = await _dio.get<List<dynamic>>(
          '$host/search',
          queryParameters: {'q': q, 'filter': 'videos'},
        );
        final items = res.data ?? [];
        final out = <YoutubeFocusVideo>[];
        for (final raw in items) {
          if (raw is! Map) continue;
          final type = raw['type']?.toString();
          if (type != 'stream' && type != 'video') continue;
          var id = raw['id']?.toString() ?? '';
          if (id.length != 11) {
            final url = raw['url']?.toString() ?? '';
            final m = RegExp(r'(?:v=|/)([a-zA-Z0-9_-]{11})').firstMatch(url);
            id = m?.group(1) ?? url.split('v=').last.split('&').first;
          }
          final vid = id.length >= 11 ? id.substring(0, 11) : id;
          if (vid.length != 11) continue;
          out.add(
            YoutubeFocusVideo(
              videoId: vid,
              title: raw['title'] as String? ?? 'YouTube',
              channelName: raw['uploaderName'] as String? ?? raw['uploader'] as String? ?? '',
              thumbnailUrl: raw['thumbnail'] as String?,
              durationSeconds: (raw['duration'] as num?)?.toInt() ?? 0,
            ),
          );
          if (out.length >= maxResults) break;
        }
        if (out.isNotEmpty) return out;
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  static int _parseIso8601Duration(String iso) {
    final m = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?').firstMatch(iso);
    if (m == null) return 0;
    final h = int.tryParse(m.group(1) ?? '') ?? 0;
    final min = int.tryParse(m.group(2) ?? '') ?? 0;
    final s = int.tryParse(m.group(3) ?? '') ?? 0;
    return h * 3600 + min * 60 + s;
  }
}
