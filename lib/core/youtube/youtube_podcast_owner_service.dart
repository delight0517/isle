import 'package:dio/dio.dart';

import '../library/youtube_library_service.dart';

/// 음성 모드 — 내 채널 영상은 한도·오디오-only 예외
class YoutubePodcastOwnerService {
  YoutubePodcastOwnerService._();

  static final _dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 12)),
  );

  static String? _cachedChannelId;

  static Future<String?> myChannelId({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedChannelId != null) return _cachedChannelId;
    final token = await YoutubeLibraryService.accessTokenForApi();
    if (token == null) {
      _cachedChannelId = null;
      return null;
    }
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://www.googleapis.com/youtube/v3/channels',
        queryParameters: {'part': 'id', 'mine': 'true'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final items = res.data?['items'] as List? ?? [];
      if (items.isEmpty) return null;
      final id = (items.first as Map)['id'] as String?;
      _cachedChannelId = id;
      return id;
    } catch (_) {
      return _cachedChannelId;
    }
  }

  static void clearCache() => _cachedChannelId = null;

  static bool isOwnerVideo({
    required String videoId,
    String? channelId,
    required Set<String> myUploadVideoIds,
    String? myChannelId,
  }) {
    if (myUploadVideoIds.contains(videoId)) return true;
    final ch = channelId?.trim();
    final mine = myChannelId?.trim();
    if (ch != null && ch.isNotEmpty && mine != null && ch == mine) return true;
    return false;
  }
}
