import 'models/channel_video_snapshot.dart';
import 'models/outlier_hit.dart';

/// 채널 중앙값 대비 200% 이상 = 대박 후보
class OutlierEngine {
  OutlierEngine._();

  static const double minRatio = 2.0;
  static const int minSampleSize = 4;
  static const int maxHits = 8;

  static List<OutlierHit> detect(List<ChannelVideoSnapshot> videos) {
    final withViews = videos.where((v) => v.viewCount > 0).toList();
    if (withViews.length < minSampleSize) return [];

    final views = withViews.map((v) => v.viewCount).toList()..sort();
    final median = views[views.length ~/ 2];
    if (median <= 0) return [];

    final avg = views.reduce((a, b) => a + b) ~/ views.length;
    final threshold = (median * minRatio).round();

    final hits = <OutlierHit>[];
    for (final v in withViews) {
      if (v.viewCount < threshold) continue;
      final ratio = v.viewCount / median;
      hits.add(
        OutlierHit(
          video: v,
          ratioToMedian: ratio,
          medianViews: median,
          avgViews: avg,
        ),
      );
    }

    hits.sort((a, b) => b.ratioToMedian.compareTo(a.ratioToMedian));
    return hits.take(maxHits).toList();
  }

  static int medianViews(List<ChannelVideoSnapshot> videos) {
    final views = videos.where((v) => v.viewCount > 0).map((v) => v.viewCount).toList()
      ..sort();
    if (views.isEmpty) return 0;
    return views[views.length ~/ 2];
  }
}
