import 'package:dio/dio.dart';

import 'models/youtube_focus_video.dart';

/// 영상 ID만 있을 때 제목·길이·썸네일 보강 (Piped)
class YoutubeFocusMetadataService {
  YoutubeFocusMetadataService._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  static const _hosts = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.adminforge.de',
  ];

  static Future<YoutubeFocusVideo> enrich(YoutubeFocusVideo base) async {
    if (base.title != 'YouTube' &&
        base.durationSeconds > 0 &&
        base.channelName.isNotEmpty) {
      return base;
    }
    final fetched = await fetchById(base.videoId);
    if (fetched == null) return base;
    return YoutubeFocusVideo(
      videoId: base.videoId,
      title: fetched.title != 'YouTube' ? fetched.title : base.title,
      channelName: fetched.channelName.isNotEmpty ? fetched.channelName : base.channelName,
      thumbnailUrl: fetched.thumbnailUrl ?? base.thumbnailUrl,
      durationSeconds: fetched.durationSeconds > 0 ? fetched.durationSeconds : base.durationSeconds,
    );
  }

  static Future<YoutubeFocusVideo?> fetchById(String videoId) async {
    if (videoId.length != 11) return null;
    for (final host in _hosts) {
      try {
        final res = await _dio.get<Map<String, dynamic>>('$host/streams/$videoId');
        final d = res.data;
        if (d == null) continue;
        return YoutubeFocusVideo(
          videoId: videoId,
          title: d['title'] as String? ?? 'YouTube',
          channelName: d['uploader'] as String? ?? d['uploaderName'] as String? ?? '',
          thumbnailUrl: d['thumbnailUrl'] as String? ?? d['thumbnail'] as String?,
          durationSeconds: (d['duration'] as num?)?.toInt() ?? 0,
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
