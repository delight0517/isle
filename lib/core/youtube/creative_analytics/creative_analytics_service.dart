import 'models/bench_channel.dart';
import 'models/channel_video_snapshot.dart';
import 'models/narrative_report.dart';
import 'models/outlier_hit.dart';
import 'channel_catalog_service.dart';
import 'creative_analytics_store.dart';
import 'narrative_analysis_service.dart';
import 'outlier_engine.dart';

/// 스캔 · 아웃라이어 · 내러티브 오케스트레이션
class CreativeAnalyticsService {
  CreativeAnalyticsService._();

  static Future<BenchChannel> addChannel(String url) async {
    await CreativeAnalyticsStore.ensureOpen();
    final ch = await ChannelCatalogService.registerFromUrl(url);
    await CreativeAnalyticsStore.upsertChannel(ch);
    return ch;
  }

  static Future<({List<ChannelVideoSnapshot> videos, List<OutlierHit> hits})> scanChannel(
    BenchChannel channel,
  ) async {
    await CreativeAnalyticsStore.ensureOpen();
    final videos = await ChannelCatalogService.fetchRecentVideos(channel);
    if (videos.isEmpty) {
      throw StateError(
        '영상 목록을 가져오지 못했어요. 네트워크·채널 공개 여부를 확인하거나 '
        'YouTube 로그인 후 Data API를 켜 보세요.',
      );
    }
    final hits = OutlierEngine.detect(videos);
    await CreativeAnalyticsStore.saveVideos(channel.id, videos);
    await CreativeAnalyticsStore.saveOutliers(channel.id, hits);
    await CreativeAnalyticsStore.upsertChannel(
      channel.copyWith(lastScannedAt: DateTime.now()),
    );
    return (videos: videos, hits: hits);
  }

  static Future<NarrativeReport> analyzeNarrative({
    required ChannelVideoSnapshot video,
    String? channelName,
  }) async {
    final report = await NarrativeAnalysisService.analyze(
      videoId: video.videoId,
      title: video.title,
      channelName: channelName ?? video.channelName,
      durationSeconds: video.durationSeconds,
    );
    await CreativeAnalyticsStore.saveNarrative(report);
    return report;
  }

  static MatchupMetrics? matchupMetrics(String channelId) {
    final base = matchupSummary(channelId);
    if (base == null) return null;
    final hits = CreativeAnalyticsStore.loadOutliers(channelId);
    if (hits.isEmpty) return null;
    final narrative = CreativeAnalyticsStore.narrativeFor(hits.first.video.videoId);
    var bodyRatio = 0.55;
    if (narrative != null && narrative.acts.isNotEmpty) {
      final end = narrative.acts.last.endSec;
      if (end > 0) {
        var bodySec = 0;
        for (final a in narrative.acts) {
          if (a.phase == 'body' || a.phase == 'twist') {
            bodySec += a.endSec - a.startSec;
          }
        }
        bodyRatio = (bodySec / end).clamp(0.1, 0.95);
      }
    }
    return MatchupMetrics(
      hookSec: base.hookSec,
      wpm: base.wpm,
      formula: base.formula,
      bodyRatio: bodyRatio,
    );
  }

  static ({int hookSec, int wpm, String formula})? matchupSummary(String channelId) {
    final hits = CreativeAnalyticsStore.loadOutliers(channelId);
    if (hits.isEmpty) return null;
    final top = hits.first.video;
    final narrative = CreativeAnalyticsStore.narrativeFor(top.videoId);
    if (narrative != null && narrative.acts.isNotEmpty) {
      final hook = narrative.acts.firstWhere(
        (a) => a.phase == 'hook',
        orElse: () => narrative.acts.first,
      );
      return (
        hookSec: hook.endSec - hook.startSec,
        wpm: narrative.wordsPerMinute,
        formula: narrative.storyFormula,
      );
    }
    return (hookSec: 7, wpm: 0, formula: '— (시나리오 해부실에서 분석)');
  }
}

class MatchupMetrics {
  const MatchupMetrics({
    required this.hookSec,
    required this.wpm,
    required this.formula,
    required this.bodyRatio,
  });

  final int hookSec;
  final int wpm;
  final String formula;
  final double bodyRatio;
}
