import '../library/youtube_library_service.dart';
import '../utils/url_parser.dart';
import 'models/youtube_focus_video.dart';
import 'youtube_clipboard_watch.dart';
import 'youtube_playlist_ingest_service.dart';
import 'youtube_podcast_feed_service.dart';
import 'youtube_podcast_saved_playlist_store.dart';

/// 비공식 링크·계정 PL·공개 PL → 음성 큐 [YoutubeFocusVideo]
class YoutubePodcastPlaylistResolver {
  YoutubePodcastPlaylistResolver._();

  static String? _normalizeLink(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return null;
    if (!t.startsWith('http')) t = 'https://$t';
    return YoutubeClipboardWatch.normalizeUrl(t) ?? t;
  }

  static Future<List<YoutubeFocusVideo>> fromSavedPlaylist(
    YoutubePodcastSavedPlaylist playlist, {
    int maxVideos = 80,
  }) async {
    final out = <YoutubeFocusVideo>[];
    final seen = <String>{};
    for (final raw in playlist.links) {
      if (out.length >= maxVideos) break;
      final batch = await fromUrl(raw, maxVideos: maxVideos - out.length);
      for (final v in batch) {
        if (seen.add(v.videoId)) out.add(v);
      }
    }
    return YoutubePodcastFeedService.filterShorts(out);
  }

  static Future<List<YoutubeFocusVideo>> fromUrl(
    String raw, {
    int maxVideos = 80,
  }) async {
    final url = _normalizeLink(raw);
    if (url == null) return [];

    final playlistId = UrlParser.extractYouTubePlaylistId(url);
    if (playlistId != null) {
      return fromPlaylistId(playlistId, maxVideos: maxVideos);
    }

    final vid = UrlParser.extractYouTubeVideoId(url);
    if (vid != null && vid.length == 11) {
      return [
        YoutubeFocusVideo(
          videoId: vid,
          title: 'YouTube',
          channelName: '',
          thumbnailUrl: UrlParser.youTubeThumbnail(vid),
        ),
      ];
    }
    return [];
  }

  static Future<List<YoutubeFocusVideo>> fromPlaylistId(
    String playlistId, {
    int maxVideos = 80,
  }) async {
    if (playlistId == 'WL' || playlistId == 'LM' || playlistId == 'LL') {
      return _fromAccountPlaylist(playlistId, maxVideos: maxVideos);
    }

    final piped = await YoutubePlaylistIngestService.fetchPlaylistVideos(
      playlistId,
      maxItems: maxVideos,
    );
    if (piped.isNotEmpty) {
      return YoutubePodcastFeedService.filterShorts(piped);
    }

    return _fromAccountPlaylist(playlistId, maxVideos: maxVideos);
  }

  static Future<List<YoutubeFocusVideo>> fromPlaylistUrl(
    String url, {
    int maxVideos = 80,
  }) async {
    final id = UrlParser.extractYouTubePlaylistId(url);
    if (id == null) return fromUrl(url, maxVideos: maxVideos);
    return fromPlaylistId(id, maxVideos: maxVideos);
  }

  static Future<List<YoutubeFocusVideo>> fromAccountPlaylistSummary({
    required String playlistId,
    required String title,
    int maxVideos = 80,
  }) async {
    final list = await _fromAccountPlaylist(playlistId, maxVideos: maxVideos);
    if (list.isEmpty && title.isNotEmpty) {
      return [];
    }
    return list;
  }

  static Future<List<YoutubeFocusVideo>> _fromAccountPlaylist(
    String playlistId, {
    int maxVideos = 80,
  }) async {
    try {
      final entries = await YoutubeLibraryService.fetchPlaylistEntries(
        playlistId: playlistId,
        maxResults: maxVideos,
        origin: 'podcast_playlist',
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
      return YoutubePodcastFeedService.filterShorts(out);
    } catch (_) {
      return [];
    }
  }
}
