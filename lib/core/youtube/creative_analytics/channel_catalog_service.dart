import 'package:dio/dio.dart';

import '../../library/youtube_library_service.dart';
import '../../utils/url_parser.dart';
import '../../utils/youtube_paste_resolver.dart';
import 'models/bench_channel.dart';
import 'models/channel_video_snapshot.dart';

/// 채널 URL → 영상 목록 (Piped 우선 · 로그인 시 YouTube Data API)
class ChannelCatalogService {
  ChannelCatalogService._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  static const _pipedHosts = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.adminforge.de',
  ];

  static const scanWindowDays = 183;

  static Future<BenchChannel> registerFromUrl(String rawUrl) async {
    final info = await YoutubePasteResolver.resolve(rawUrl);
    if (!info.valid) {
      throw StateError(info.errorMessage ?? '채널 URL을 확인해 주세요');
    }
    final channelId = info.channelId;
    final handle = info.handle;
    if ((channelId == null || channelId.isEmpty) && (handle == null || handle.isEmpty)) {
      throw StateError('채널 ID를 찾지 못했어요. /channel/UC… 또는 @핸들 URL을 넣어 주세요');
    }
    final id = channelId ?? 'h_$handle';
    final profile = handle != null
        ? 'https://www.youtube.com/@$handle'
        : 'https://www.youtube.com/channel/$channelId';
    return BenchChannel(
      id: id,
      channelId: channelId ?? id,
      handle: handle,
      name: info.channelName?.isNotEmpty == true
          ? info.channelName!
          : (handle != null ? '@$handle' : channelId ?? 'YouTube'),
      profileUrl: profile,
      addedAt: DateTime.now(),
    );
  }

  static Future<List<ChannelVideoSnapshot>> fetchRecentVideos(
    BenchChannel channel, {
    int maxItems = 48,
  }) async {
    final since = DateTime.now().subtract(const Duration(days: scanWindowDays));

    final viaApi = await _fetchYoutubeApi(channel, since: since, maxItems: maxItems);
    if (viaApi.isNotEmpty) return viaApi;

    final viaPiped = await _fetchPiped(channel, maxItems: maxItems);
    return viaPiped.where((v) => v.publishedAt.isAfter(since)).toList();
  }

  static Future<List<ChannelVideoSnapshot>> _fetchPiped(
    BenchChannel channel, {
    required int maxItems,
  }) async {
    final paths = <String>[
      if (channel.channelId.startsWith('UC')) '/channel/${channel.channelId}',
      if (channel.handle != null) '/c/${channel.handle}',
      if (channel.handle != null) '/user/${channel.handle}',
    ];

    for (final host in _pipedHosts) {
      for (final path in paths) {
        try {
          final res = await _dio.get<Map<String, dynamic>>('$host$path');
          final d = res.data;
          if (d == null) continue;
          final streams = d['relatedStreams'] as List? ??
              d['videos'] as List? ??
              d['items'] as List? ??
              [];
          final out = _parseStreams(streams, channel.name, maxItems);
          if (out.isNotEmpty) return out;
        } catch (_) {
          continue;
        }
      }
    }
    return [];
  }

  static List<ChannelVideoSnapshot> _parseStreams(
    List streams,
    String channelName,
    int maxItems,
  ) {
    final out = <ChannelVideoSnapshot>[];
    for (final raw in streams) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      var vid = map['id']?.toString() ?? '';
      if (vid.length != 11) {
        vid = UrlParser.extractYouTubeVideoId(map['url']?.toString() ?? '') ?? '';
      }
      if (vid.length != 11) continue;

      final views = (map['views'] as num?)?.toInt() ??
          (map['viewCount'] as num?)?.toInt() ??
          0;
      final uploaded = map['uploaded'] as num?;
      final uploadedDate = map['uploadedDate'] as String?;
      DateTime published = DateTime.now();
      if (uploaded != null) {
        published = DateTime.fromMillisecondsSinceEpoch(uploaded.toInt() * 1000);
      } else if (uploadedDate != null) {
        published = DateTime.tryParse(uploadedDate) ?? published;
      }

      out.add(
        ChannelVideoSnapshot(
          videoId: vid,
          title: map['title'] as String? ?? 'YouTube',
          viewCount: views,
          durationSeconds: (map['duration'] as num?)?.toInt() ?? 0,
          publishedAt: published,
          thumbnailUrl: map['thumbnail'] as String? ?? UrlParser.youTubeThumbnail(vid),
          channelName: map['uploaderName'] as String? ?? channelName,
        ),
      );
      if (out.length >= maxItems) break;
    }
    return out;
  }

  static Future<List<ChannelVideoSnapshot>> _fetchYoutubeApi(
    BenchChannel channel, {
    required DateTime since,
    required int maxItems,
  }) async {
    if (!YoutubeLibraryService.canAttemptSignIn) return [];
    final token = await YoutubeLibraryService.accessTokenForApi();
    if (token == null) return [];

    try {
      final params = <String, String>{'part': 'contentDetails'};
      if (channel.channelId.startsWith('UC')) {
        params['id'] = channel.channelId;
      } else if (channel.handle != null) {
        params['forHandle'] = channel.handle!;
      } else {
        return [];
      }
      final chRes = await _dio.get<Map<String, dynamic>>(
        'https://www.googleapis.com/youtube/v3/channels',
        queryParameters: params,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final items = chRes.data?['items'] as List? ?? [];
      if (items.isEmpty) return [];
      final uploads =
          (items.first as Map)['contentDetails']?['relatedPlaylists']?['uploads'] as String?;
      if (uploads == null) return [];

      final videoIds = <String>[];
      String? pageToken;
      while (videoIds.length < maxItems) {
        final pl = await _dio.get<Map<String, dynamic>>(
          'https://www.googleapis.com/youtube/v3/playlistItems',
          queryParameters: {
            'part': 'snippet,contentDetails',
            'playlistId': uploads,
            'maxResults': 50,
            if (pageToken != null) 'pageToken': pageToken,
          },
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        for (final raw in pl.data?['items'] as List? ?? []) {
          if (raw is! Map) continue;
          final vid = raw['contentDetails']?['videoId'] as String?;
          final published = DateTime.tryParse(
                raw['snippet']?['publishedAt'] as String? ?? '',
              ) ??
              DateTime.now();
          if (vid == null || published.isBefore(since)) continue;
          videoIds.add(vid);
          if (videoIds.length >= maxItems) break;
        }
        pageToken = pl.data?['nextPageToken'] as String?;
        if (pageToken == null || videoIds.length >= maxItems) break;
      }
      if (videoIds.isEmpty) return [];

      final stats = <String, ({int views, int duration, String title, String thumb, DateTime pub})>{};
      for (var i = 0; i < videoIds.length; i += 50) {
        final chunk = videoIds.sublist(i, i + 50 > videoIds.length ? videoIds.length : i + 50);
        final vRes = await _dio.get<Map<String, dynamic>>(
          'https://www.googleapis.com/youtube/v3/videos',
          queryParameters: {
            'part': 'statistics,contentDetails,snippet',
            'id': chunk.join(','),
          },
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        for (final raw in vRes.data?['items'] as List? ?? []) {
          if (raw is! Map) continue;
          final id = raw['id'] as String?;
          if (id == null) continue;
          stats[id] = (
            views: int.tryParse(raw['statistics']?['viewCount']?.toString() ?? '') ?? 0,
            duration: _isoDuration(raw['contentDetails']?['duration'] as String?),
            title: raw['snippet']?['title'] as String? ?? '',
            thumb: raw['snippet']?['thumbnails']?['medium']?['url'] as String? ?? '',
            pub: DateTime.tryParse(raw['snippet']?['publishedAt'] as String? ?? '') ??
                DateTime.now(),
          );
        }
      }

      return videoIds.map((id) {
        final s = stats[id];
        if (s == null) {
          return ChannelVideoSnapshot(
            videoId: id,
            title: 'YouTube',
            viewCount: 0,
            durationSeconds: 0,
            publishedAt: DateTime.now(),
            channelName: channel.name,
          );
        }
        return ChannelVideoSnapshot(
          videoId: id,
          title: s.title,
          viewCount: s.views,
          durationSeconds: s.duration,
          publishedAt: s.pub,
          thumbnailUrl: s.thumb,
          channelName: channel.name,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static int _isoDuration(String? iso) {
    if (iso == null || !iso.startsWith('PT')) return 0;
    final h = RegExp(r'(\d+)H').firstMatch(iso)?.group(1);
    final m = RegExp(r'(\d+)M').firstMatch(iso)?.group(1);
    final s = RegExp(r'(\d+)S').firstMatch(iso)?.group(1);
    return (int.tryParse(h ?? '') ?? 0) * 3600 +
        (int.tryParse(m ?? '') ?? 0) * 60 +
        (int.tryParse(s ?? '') ?? 0);
  }
}
