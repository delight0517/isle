import 'package:dio/dio.dart';

import '../utils/url_parser.dart';
import 'models/youtube_focus_video.dart';

/// 공개 플레이리스트 → 영상 목록 (Piped, API 키 없음)
class YoutubePlaylistIngestService {
  YoutubePlaylistIngestService._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  static const _hosts = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.adminforge.de',
  ];

  static Future<List<YoutubeFocusVideo>> fetchPlaylistVideos(
    String playlistUrlOrId, {
    int maxItems = 40,
  }) async {
    final id = playlistUrlOrId.contains('http')
        ? UrlParser.extractYouTubePlaylistId(playlistUrlOrId)
        : playlistUrlOrId;
    if (id == null || id.isEmpty) return [];
    if (id == 'WL') return [];

    for (final host in _hosts) {
      try {
        final res = await _dio.get<Map<String, dynamic>>('$host/playlists/$id');
        final d = res.data;
        if (d == null) continue;
        final streams = d['relatedStreams'] as List? ?? d['videos'] as List? ?? [];
        final out = <YoutubeFocusVideo>[];
        for (final raw in streams) {
          if (raw is! Map) continue;
          final map = Map<String, dynamic>.from(raw);
          var vid = map['id']?.toString() ?? '';
          if (vid.length != 11) {
            final url = map['url']?.toString() ?? '';
            vid = UrlParser.extractYouTubeVideoId(url) ?? '';
          }
          if (vid.length != 11) continue;
          out.add(
            YoutubeFocusVideo(
              videoId: vid,
              title: map['title'] as String? ?? 'YouTube',
              channelName: map['uploaderName'] as String? ?? map['uploader'] as String? ?? '',
              thumbnailUrl: map['thumbnail'] as String? ?? UrlParser.youTubeThumbnail(vid),
              durationSeconds: (map['duration'] as num?)?.toInt() ?? 0,
            ),
          );
          if (out.length >= maxItems) break;
        }
        if (out.isNotEmpty) return out;
      } catch (_) {
        continue;
      }
    }
    return [];
  }
}
