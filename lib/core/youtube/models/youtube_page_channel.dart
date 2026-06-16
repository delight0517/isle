class YoutubePageChannel {
  final String channelId;
  final String channelName;
  final String videoTitle;
  final String videoId;

  const YoutubePageChannel({
    required this.channelId,
    required this.channelName,
    this.videoTitle = '',
    this.videoId = '',
  });

  bool get isEmpty => channelId.isEmpty && channelName.isEmpty;

  bool get isWatchPage => videoId.isNotEmpty;

  factory YoutubePageChannel.fromJson(Map<String, dynamic> j) => YoutubePageChannel(
        channelId: j['channelId'] as String? ?? '',
        channelName: j['channelName'] as String? ?? '',
        videoTitle: j['videoTitle'] as String? ?? '',
        videoId: j['videoId'] as String? ?? '',
      );
}
