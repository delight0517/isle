import '../../../features/feed/data/models/feed_item.dart';
import '../../../core/utils/topic_matcher.dart';
import '../../../core/utils/url_parser.dart';

/// 로컬에 저장된 가져온 콘텐츠 (피드·다이제스트 공용)
class LibraryEntry {
  final String id;
  final String title;
  final String url;
  final String thumbnailUrl;
  final String sourceType;
  final String channelId;
  final String channelName;
  final String? summary;
  final String
      origin; // watch_later | youtube_playlist | brunch_sync | youtube_history | digest
  final String? sourceId;
  final DateTime importedAt;
  final DateTime? publishedAt;

  /// 자막 기반 브이로그 스타일 글 (버튼 한 번으로 생성) — [summary]와 별도 보관
  final String? generatedPost;

  /// MOA 안에서 실제 재생이 확인된 YouTube 시청 시간만 누적한다.
  final int watchSeconds;
  final DateTime? lastWatchedAt;

  const LibraryEntry({
    required this.id,
    required this.title,
    required this.url,
    required this.thumbnailUrl,
    required this.sourceType,
    required this.channelId,
    required this.channelName,
    this.summary,
    required this.origin,
    this.sourceId,
    required this.importedAt,
    this.publishedAt,
    this.generatedPost,
    this.watchSeconds = 0,
    this.lastWatchedAt,
  });

  factory LibraryEntry.fromJson(Map<String, dynamic> j) => LibraryEntry(
        id: j['id'] as String,
        title: j['title'] as String,
        url: j['url'] as String,
        thumbnailUrl: j['thumbnail_url'] as String? ?? '',
        sourceType: j['source_type'] as String? ?? 'article',
        channelId: j['channel_id'] as String? ?? '',
        channelName: j['channel_name'] as String? ?? '',
        summary: j['summary'] as String?,
        origin: j['origin'] as String? ?? 'import',
        sourceId: j['source_id'] as String?,
        importedAt: DateTime.tryParse(j['imported_at'] as String? ?? '') ??
            DateTime.now(),
        publishedAt: DateTime.tryParse(j['published_at'] as String? ?? ''),
        generatedPost: j['generated_post'] as String?,
        watchSeconds: (j['watch_seconds'] as num?)?.toInt() ?? 0,
        lastWatchedAt: DateTime.tryParse(j['last_watched_at'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'thumbnail_url': thumbnailUrl,
        'source_type': sourceType,
        'channel_id': channelId,
        'channel_name': channelName,
        if (summary != null) 'summary': summary,
        'origin': origin,
        if (sourceId != null) 'source_id': sourceId,
        'imported_at': importedAt.toIso8601String(),
        if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
        if (generatedPost != null) 'generated_post': generatedPost,
        if (watchSeconds > 0) 'watch_seconds': watchSeconds,
        if (lastWatchedAt != null)
          'last_watched_at': lastWatchedAt!.toIso8601String(),
      };

  LibraryEntry copyWith({
    String? summary,
    String? generatedPost,
    String? title,
    String? channelId,
    String? channelName,
    int? watchSeconds,
    DateTime? lastWatchedAt,
  }) =>
      LibraryEntry(
        id: id,
        title: title ?? this.title,
        url: url,
        thumbnailUrl: thumbnailUrl,
        sourceType: sourceType,
        channelId: channelId ?? this.channelId,
        channelName: channelName ?? this.channelName,
        summary: summary ?? this.summary,
        origin: origin,
        sourceId: sourceId,
        importedAt: importedAt,
        publishedAt: publishedAt,
        generatedPost: generatedPost ?? this.generatedPost,
        watchSeconds: watchSeconds ?? this.watchSeconds,
        lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      );

  FeedItem toFeedItem({double relevanceBoost = 0.15}) {
    final topics = TopicMatcher.detectTopics('$title $channelName');
    return FeedItem(
      id: 'lib_$id',
      title: title,
      url: url,
      thumbnailUrl: thumbnailUrl,
      sourceType: sourceType,
      channelId: channelId,
      channelName: channelName,
      channelAvatar: '',
      detectedTopics: topics,
      relevanceScore: (0.55 + relevanceBoost).clamp(0.0, 1.0),
      publishedAt: publishedAt ?? importedAt,
      summary: summary,
    );
  }

  static LibraryEntry fromWatchLater({
    required String videoId,
    required String title,
    String channelName = '',
    String channelId = '',
  }) {
    final url = 'https://www.youtube.com/watch?v=$videoId';
    return LibraryEntry(
      id: 'yt_$videoId',
      title: title,
      url: url,
      thumbnailUrl: UrlParser.youTubeThumbnail(videoId),
      sourceType: 'youtube',
      channelId: channelId,
      channelName: channelName,
      origin: 'watch_later',
      importedAt: DateTime.now(),
      publishedAt: DateTime.now(),
    );
  }

  static LibraryEntry fromYoutubePlaylist({
    required String videoId,
    required String title,
    String channelName = '',
    String channelId = '',
    String playlistId = '',
    DateTime? publishedAt,
  }) {
    final url = 'https://www.youtube.com/watch?v=$videoId';
    return LibraryEntry(
      id: 'yt_pl_${playlistId}_$videoId',
      title: title,
      url: url,
      thumbnailUrl: UrlParser.youTubeThumbnail(videoId),
      sourceType: 'youtube',
      channelId: channelId,
      channelName: channelName,
      origin: 'youtube_playlist',
      sourceId: playlistId.isEmpty ? null : playlistId,
      importedAt: DateTime.now(),
      publishedAt: publishedAt ?? DateTime.now(),
    );
  }

  static LibraryEntry fromWatchHistory({
    required String videoId,
    required String title,
    String channelName = '',
    String channelId = '',
    int watchSeconds = 0,
    DateTime? lastWatchedAt,
  }) {
    final url = 'https://www.youtube.com/watch?v=$videoId';
    return LibraryEntry(
      id: 'yt_hist_$videoId',
      title: title,
      url: url,
      thumbnailUrl: UrlParser.youTubeThumbnail(videoId),
      sourceType: 'youtube',
      channelId: channelId,
      channelName: channelName,
      origin: 'youtube_history',
      importedAt: DateTime.now(),
      publishedAt: DateTime.now(),
      watchSeconds: watchSeconds,
      lastWatchedAt: lastWatchedAt,
    );
  }

  static LibraryEntry fromBrunch({
    required String articleUrl,
    required String title,
    String? thumbnailUrl,
    String author = '',
    String? sourceId,
  }) =>
      LibraryEntry(
        id: 'br_${articleUrl.hashCode.abs()}',
        title: title,
        url: articleUrl,
        thumbnailUrl: thumbnailUrl ?? '',
        sourceType: 'brunch',
        channelId: '',
        channelName: author,
        origin: 'brunch_sync',
        sourceId: sourceId,
        importedAt: DateTime.now(),
        publishedAt: DateTime.now(),
      );
}
