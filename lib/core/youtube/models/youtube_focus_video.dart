/// 몰입 모드 검색 결과 한 건
class YoutubeFocusVideo {
  const YoutubeFocusVideo({
    required this.videoId,
    required this.title,
    required this.channelName,
    this.thumbnailUrl,
    this.durationSeconds = 0,
  });

  final String videoId;
  final String title;
  final String channelName;
  final String? thumbnailUrl;
  final int durationSeconds;

  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';

  String get durationLabel {
    if (durationSeconds <= 0) return '';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final rm = m % 60;
      return '$h시간 ${rm}분';
    }
    if (m > 0) return s > 0 ? '$m분 $s초' : '$m분';
    return '$s초';
  }
}
