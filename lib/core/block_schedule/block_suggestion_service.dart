import '../intervention/external_app_shield_store.dart';
import '../library/platform_usage_stats.dart';
import 'block_schedule_store.dart';

/// 사용량 기반 차단 추천 — 최근 7일 평균을 보고 권유 (모두 로컬, API 없음)
///
/// 예: YouTube 평균 45분/일 → "21시-07시 자동 차단 스케줄 추가" 추천
class BlockSuggestion {
  const BlockSuggestion({
    required this.platform,
    required this.platformLabel,
    required this.avgMinutesPerDay,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.actionKind,
  });

  final String platform; // 'youtube' | 'instagram' | 'brunch'
  final String platformLabel; // 'YouTube' 등
  final int avgMinutesPerDay;
  final String title;
  final String body;
  final String actionLabel;
  final String actionKind; // 'add_night_schedule' | 'pick_apps' | 'lower_limit'
}

class BlockSuggestionService {
  BlockSuggestionService._();

  /// 임계치: 평균 30분/일 이상이면 야간 차단 추천
  static const _nightThresholdMinutes = 30;
  static const _heavyThresholdMinutes = 90;

  /// 최근 7일 데이터에서 가장 가치 있는 추천 1개. 없으면 null.
  static Future<BlockSuggestion?> nextSuggestion() async {
    final daily = await PlatformUsageStats.dailyByPlatform(days: 7);
    if (daily.isEmpty) return null;

    // 플랫폼별 평균 (분)
    final avg = <String, int>{};
    for (final p in PlatformUsageStats.platforms) {
      var total = 0;
      var days = 0;
      for (final e in daily.entries) {
        final sec = e.value[p] ?? 0;
        if (sec > 0) days++;
        total += sec;
      }
      if (days == 0) continue;
      avg[p] = ((total / 7) / 60).round();
    }
    if (avg.isEmpty) return null;

    // 가장 사용량 많은 플랫폼 우선
    final sorted = avg.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first;
    if (top.value < _nightThresholdMinutes) return null;

    final label = PlatformUsageStats.labelFor(top.key);
    final heavy = top.value >= _heavyThresholdMinutes;

    // 이미 스케줄이 있고 매스터 ON이면 → 앱 쉴드 추천
    final hasSchedule = BlockScheduleStore.loadAll().isNotEmpty;
    final hasAppShield = ExternalAppShieldStore.hasSelection;

    if (!hasSchedule) {
      return BlockSuggestion(
        platform: top.key,
        platformLabel: label,
        avgMinutesPerDay: top.value,
        title: heavy
            ? '$label을(를) 매일 ${top.value}분씩 보고 있어요'
            : '$label 시청이 늘고 있어요 (평균 ${top.value}분/일)',
        body: '21시–07시에 Instagram 등 앱 아이콘 자체를 막는 스케줄을 켤 수 있어요.',
        actionLabel: '야간 차단 켜기 (한 번에)',
        actionKind: 'add_night_schedule',
      );
    }

    if (!hasAppShield && top.key == 'instagram') {
      return BlockSuggestion(
        platform: top.key,
        platformLabel: label,
        avgMinutesPerDay: top.value,
        title: '$label은 앱 자체에서 막을 수 있어요',
        body: 'Screen Time으로 Instagram 앱을 잠그면 Isle 밖에서도 차단돼요.',
        actionLabel: 'Instagram 앱 잠그기',
        actionKind: 'pick_apps',
      );
    }

    if (heavy) {
      return BlockSuggestion(
        platform: top.key,
        platformLabel: label,
        avgMinutesPerDay: top.value,
        title: '$label 사용이 많아요',
        body:
            '평균 ${top.value}분/일 — 일일 한도 ${_recommendedLimit(top.value)}분을 설정해 보세요.',
        actionLabel: '일일 한도 설정',
        actionKind: 'lower_limit',
      );
    }

    return null;
  }

  static int _recommendedLimit(int currentAvg) {
    if (currentAvg >= 120) return 60;
    if (currentAvg >= 60) return 45;
    return 30;
  }
}
