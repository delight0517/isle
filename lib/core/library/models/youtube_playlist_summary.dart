/// YouTube Data API — 내 채널 플레이리스트 메타
class YoutubePlaylistSummary {
  const YoutubePlaylistSummary({
    required this.id,
    required this.title,
    required this.itemCount,
    this.privacyStatus,
  });

  final String id;
  final String title;
  final int itemCount;
  final String? privacyStatus;

  bool get isWatchLater => id == 'WL';
}
