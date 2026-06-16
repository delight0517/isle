import 'channel_video_snapshot.dart';

/// 채널 평균 대비 폭발한 「대박」 영상
class OutlierHit {
  const OutlierHit({
    required this.video,
    required this.ratioToMedian,
    required this.medianViews,
    required this.avgViews,
  });

  final ChannelVideoSnapshot video;
  /// 2.5 = 채널 중앙값 대비 250%
  final double ratioToMedian;
  final int medianViews;
  final int avgViews;

  int get boostPercent => ((ratioToMedian - 1) * 100).round().clamp(0, 9999);

  factory OutlierHit.fromJson(Map<String, dynamic> j) => OutlierHit(
        video: ChannelVideoSnapshot.fromJson(Map<String, dynamic>.from(j['video'] as Map)),
        ratioToMedian: (j['ratio_to_median'] as num?)?.toDouble() ?? 1,
        medianViews: (j['median_views'] as num?)?.toInt() ?? 0,
        avgViews: (j['avg_views'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'video': video.toJson(),
        'ratio_to_median': ratioToMedian,
        'median_views': medianViews,
        'avg_views': avgViews,
      };
}
