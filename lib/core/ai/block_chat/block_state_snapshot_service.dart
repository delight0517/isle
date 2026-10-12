import '../../block_schedule/block_schedule_store.dart';
import '../../block_schedule/schedule_display_helper.dart';
import '../../intervention/website_block_store.dart';
import '../../youtube/blocked_channel_store.dart';
import '../../youtube/blocked_url_store.dart';
import '../../youtube/content_filter_store.dart';

/// 「현재 block하게 된 데이터」 — AI 분석용 텍스트 스냅샷 (실시간, 저장 안 함)
class BlockStateSnapshotService {
  BlockStateSnapshotService._();

  static const _maxListed = 40;

  static String buildSummary() {
    final channels = BlockedChannelStore.loadAll();
    final keywords = ContentFilterStore.loadKeywords();
    final videos = ContentFilterStore.loadVideos();
    final urls = BlockedUrlStore.loadAll();
    final domains = WebsiteBlockStore.loadDomains();
    final schedules = BlockScheduleStore.loadAll();

    final buf = StringBuffer();

    buf.writeln('# 차단 채널 (${channels.length}개)');
    buf.writeln(_bulletList(channels
        .map((c) => c.channelName.isNotEmpty ? c.channelName : c.channelId)
        .toList()));

    buf.writeln('\n# 차단 키워드 (${keywords.length}개)');
    buf.writeln(_bulletList(keywords));

    buf.writeln('\n# 차단 영상 (${videos.length}개, ID만)');
    buf.writeln(_bulletList(videos.map((v) => v.videoId).toList()));

    buf.writeln('\n# 차단 URL (${urls.length}개)');
    buf.writeln(_bulletList(urls.map((u) => u.label ?? u.canonicalUrl).toList()));

    buf.writeln('\n# 웹사이트 차단 도메인 (${domains.length}개)');
    buf.writeln(_bulletList(domains));

    buf.writeln('\n# 스케줄 (${schedules.length}개)');
    if (schedules.isEmpty) {
      buf.writeln('- 없음');
    } else {
      for (final s in schedules) {
        final times = ScheduleDisplayHelper.formatScheduleTimes(s.slots);
        final targets = ScheduleDisplayHelper.configuredSummaryLine(s);
        buf.writeln(
          '- 「${s.name}」 ${s.enabled ? '활성' : '비활성'} · $times · 대상: $targets'
          '${s.domains.isNotEmpty ? ' · 도메인: ${s.domains.join(', ')}' : ''}',
        );
      }
    }

    return buf.toString();
  }

  static String _bulletList(List<String> items) {
    final clean = items.where((s) => s.trim().isNotEmpty).toList();
    if (clean.isEmpty) return '- 없음';
    final shown = clean.take(_maxListed).map((s) => '- $s').join('\n');
    final more = clean.length > _maxListed ? '\n… 외 ${clean.length - _maxListed}개' : '';
    return '$shown$more';
  }
}
