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
    return fetched;
  }

  /// Piped uploaderUrl → UC… / @handle (채널 ID-only 차단 매칭용)
  static Future<String> channelIdFor(String videoId) async {
    if (videoId.length != 11) return '';
    for (final host in _hosts) {
      try {
        final res = await _dio.get<Map<String, dynamic>>('$host/streams/$videoId');
        final d = res.data;
        if (d == null) continue;
        return _channelIdFromPiped(d);
      } catch (_) {
        continue;
      }
    }
    return '';
  }

  static String _channelIdFromPiped(Map<String, dynamic> d) {
    final raw = (d['uploaderUrl'] as String? ?? '').trim();
    if (raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    final channel = RegExp(r'/channel/(uc[\w-]+)', caseSensitive: false).firstMatch(lower);
    if (channel != null) return channel.group(1)!;
    final handle = RegExp(r'/@([\w.\-]+)').firstMatch(lower);
    if (handle != null) return '@${handle.group(1)!}';
    return '';
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
