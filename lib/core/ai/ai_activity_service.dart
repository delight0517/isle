import '../library/interest_pipeline_store.dart';
import '../services/isle_user_defaults.dart';
import 'ai_config_store.dart';
import 'ai_usage_log_store.dart';

/// UI에 보여줄 「AI가 지금/곧 하는 일」
enum AiActivityKind {
  waiting,
  processing,
  ready,
  idle,
}

class AiActivityItem {
  const AiActivityItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.feature,
    this.dueAt,
    this.progress = 0,
  });

  final String id;
  final AiActivityKind kind;
  final String title;
  final String subtitle;
  final String feature;
  final DateTime? dueAt;
  final double progress; // 0..1

  Duration? get remaining {
    final d = dueAt;
    if (d == null) return null;
    final r = d.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }
}

class AiActivityService {
  AiActivityService._();

  static List<AiActivityItem> currentActivities() {
    final out = <AiActivityItem>[];
    final now = DateTime.now();

    for (final item in InterestPipelineStore.loadAll()) {
      if (item.status == 'queued' && item.publishArticleAt.isAfter(now)) {
        final days = item.publishArticleAt.difference(now).inDays;
        final hours = item.publishArticleAt.difference(now).inHours % 24;
        out.add(
          AiActivityItem(
            id: 'pipe_${item.id}',
            kind: AiActivityKind.waiting,
            title: item.title,
            subtitle: days > 0
                ? '$days일 $hours시간 후 → 읽기 카드 (피드·내 콘텐츠)'
                : '$hours시간 후 → 읽기 카드',
            feature: 'interest_article',
            dueAt: item.publishArticleAt,
            progress: _progressToward(item.markedAt, item.publishArticleAt, now),
          ),
        );
      } else if (item.status == 'processing') {
        out.add(
          AiActivityItem(
            id: 'pipe_${item.id}',
            kind: AiActivityKind.processing,
            title: item.title,
            subtitle: '육각 워커 → AI 전송 · 3~5문단 기사 작성 중',
            feature: 'interest_article',
            progress: 0.95,
          ),
        );
      } else if (item.status == 'article_ready') {
        out.add(
          AiActivityItem(
            id: 'pipe_${item.id}',
            kind: AiActivityKind.ready,
            title: item.title,
            subtitle: '기사 준비됨 · 피드 반영 대기',
            feature: 'interest_article',
            progress: 1,
          ),
        );
      }
    }

    if (IsleUserDefaults.digestToFeedEnabled) {
      out.add(
        AiActivityItem(
          id: 'digest_weekly',
          kind: AiActivityKind.idle,
          title: '요약 뉴스 카드',
          subtitle: '주 ${IsleUserDefaults.digestMaxPerWeek}회 · '
              '${AiConfigStore.isConfigured ? 'AI' : '로컬'} 요약',
          feature: 'digest',
        ),
      );
    }

    return out;
  }

  static bool get hasActiveWork =>
      currentActivities().any((a) => a.kind == AiActivityKind.waiting || a.kind == AiActivityKind.processing);

  static int get waitingPipelineCount =>
      InterestPipelineStore.loadAll().where((e) => e.status == 'queued').length;

  static double _progressToward(DateTime start, DateTime end, DateTime now) {
    final total = end.difference(start).inMilliseconds;
    if (total <= 0) return 1;
    final elapsed = now.difference(start).inMilliseconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  static String get statusHeadline {
    if (!AiConfigStore.isConfigured) {
      return 'AI 꺼짐 — 로컬 처리만';
    }
    final waiting = waitingPipelineCount;
    if (waiting > 0) {
      return 'AI 대기 $waiting건 · 네트워크는 예정일에만';
    }
    final monthCalls = AiUsageLogStore.successCountThisMonth;
    if (monthCalls > 0) {
      return '이번 달 AI 호출 $monthCalls회 · \$${AiUsageLogStore.usdThisMonth.toStringAsFixed(2)}';
    }
    return 'AI 준비됨 · 아직 이번 달 호출 없음';
  }
}
