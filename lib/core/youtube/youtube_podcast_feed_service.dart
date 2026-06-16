import 'package:dio/dio.dart';

import '../library/youtube_library_service.dart';
import '../services/isle_user_defaults.dart';
import '../utils/url_parser.dart';
import 'models/youtube_focus_video.dart';

/// 음성 모드 피드 — 구독·내 업로드 (API · 로그인 시)
class YoutubePodcastFeedService {
  YoutubePodcastFeedService._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  static bool get excludeShorts => IsleUserDefaults.youtubePodcastExcludeShorts;

  static List<YoutubeFocusVideo> filterShorts(List<YoutubeFocusVideo> list) {
    if (!excludeShorts) return list;
    return list.where((v) {
      if (v.durationSeconds <= 0) return true;
      return v.durationSeconds > 60;
    }).toList();
  }

  static Future<List<YoutubeFocusVideo>> fetchSubscriptionFeed({
    int maxChannels = 12,
    int perChannel = 3,
  }) async {
    final entries = await YoutubeLibraryService.fetchSubscriptionFeed(
      maxChannels: maxChannels,
      perChannel: perChannel,
    );
    final out = entries
        .map(
          (e) => YoutubeFocusVideo(
            videoId: UrlParser.extractYouTubeVideoId(e.url) ?? '',
            title: e.title,
            channelName: e.channelName,
            thumbnailUrl: e.thumbnailUrl,
          ),
        )
        .where((v) => v.videoId.length == 11)
        .toList();
    return filterShorts(out);
  }

  /// 내 채널 업로드 (비공개·미등록 포함 — API 목록 · 재생은 YouTube 로그인 필요)
  static Future<List<YoutubeFocusVideo>> fetchMyUploads({int maxResults = 30}) async {
    final token = await YoutubeLibraryService.accessTokenForApi();
    if (token == null) {
      throw StateError(
        YoutubeLibraryService.canAttemptSignIn
            ? 'Google 로그인이 필요합니다.'
            : YoutubeLibraryService.setupHint,
      );
    }

    final chRes = await _dio.get<Map<String, dynamic>>(
      'https://www.googleapis.com/youtube/v3/channels',
      queryParameters: {'part': 'contentDetails', 'mine': 'true'},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final items = chRes.data?['items'] as List? ?? [];
    if (items.isEmpty) return [];
    final uploads =
        (items.first as Map)['contentDetails']?['relatedPlaylists']?['uploads'] as String?;
    if (uploads == null) return [];

    final ids = <String>[];
    String? pageToken;
    while (ids.length < maxResults) {
      final pl = await _dio.get<Map<String, dynamic>>(
        'https://www.googleapis.com/youtube/v3/playlistItems',
        queryParameters: {
          'part': 'contentDetails,snippet',
          'playlistId': uploads,
          'maxResults': 50,
          if (pageToken != null) 'pageToken': pageToken,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      for (final raw in pl.data?['items'] as List? ?? []) {
        if (raw is! Map) continue;
        final vid = raw['contentDetails']?['videoId'] as String?;
        if (vid != null && vid.length == 11) ids.add(vid);
        if (ids.length >= maxResults) break;
      }
      pageToken = pl.data?['nextPageToken'] as String?;
      if (pageToken == null) break;
    }
    if (ids.isEmpty) return [];

    final durations = <String, int>{};
    final snippets = <String, Map<String, dynamic>>{};
    for (var i = 0; i < ids.length; i += 50) {
      final chunk = ids.sublist(i, i + 50 > ids.length ? ids.length : i + 50);
      final vRes = await _dio.get<Map<String, dynamic>>(
        'https://www.googleapis.com/youtube/v3/videos',
        queryParameters: {'part': 'contentDetails,snippet', 'id': chunk.join(',')},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      for (final raw in vRes.data?['items'] as List? ?? []) {
        if (raw is! Map) continue;
        final id = raw['id'] as String?;
        final iso = raw['contentDetails']?['duration'] as String?;
        final sn = raw['snippet'] as Map?;
        if (id == null) continue;
        if (iso != null) durations[id] = _parseIso(iso);
        if (sn != null) snippets[id] = Map<String, dynamic>.from(sn);
      }
    }

    final out = <YoutubeFocusVideo>[];
    for (final id in ids) {
      final sn = snippets[id];
      if (sn == null) continue;
      out.add(
        YoutubeFocusVideo(
          videoId: id,
          title: sn['title'] as String? ?? '내 영상',
          channelName: sn['channelTitle'] as String? ?? '내 채널',
          thumbnailUrl: (sn['thumbnails'] as Map?)?['medium']?['url'] as String?,
          durationSeconds: durations[id] ?? 0,
        ),
      );
    }
    return filterShorts(out);
  }

  static int _parseIso(String iso) {
    final m = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?').firstMatch(iso);
    if (m == null) return 0;
    final h = int.tryParse(m.group(1) ?? '') ?? 0;
    final min = int.tryParse(m.group(2) ?? '') ?? 0;
    final s = int.tryParse(m.group(3) ?? '') ?? 0;
    return h * 3600 + min * 60 + s;
  }
}
