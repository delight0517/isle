import 'app_usage_limit_store.dart';
import 'external_app_shield_store.dart';
import 'schedule_screen_time_store.dart';

/// 스케줄·전역 Screen Time 선택 — 인코딩 + 보조 텍스트 라벨.
class ScreenTimeSelectionSummary {
  ScreenTimeSelectionSummary._();

  /// 이 스케줄 전용 선택, 없으면 전역 폴백(동기화 켠 경우).
  static String? encodedForSchedule(String scheduleId) {
    final per = ScheduleScreenTimeStore.encodedFor(scheduleId);
    if (per != null && per.isNotEmpty) return per;
    if (ExternalAppShieldStore.syncWithBlockSchedule &&
        ExternalAppShieldStore.hasSelection) {
      return ExternalAppShieldStore.encodedSelection;
    }
    return null;
  }

  static int appCountForSchedule(String scheduleId) {
    final perApps = ScheduleScreenTimeStore.appCountFor(scheduleId);
    final perCats = ScheduleScreenTimeStore.categoryCountFor(scheduleId);
    if (perApps > 0 || perCats > 0) {
      return perApps;
    }
    if (ExternalAppShieldStore.syncWithBlockSchedule) {
      return ExternalAppShieldStore.applicationCount;
    }
    return 0;
  }

  static int categoryCountForSchedule(String scheduleId) {
    final perApps = ScheduleScreenTimeStore.appCountFor(scheduleId);
    final perCats = ScheduleScreenTimeStore.categoryCountFor(scheduleId);
    if (perApps > 0 || perCats > 0) return perCats;
    if (ExternalAppShieldStore.syncWithBlockSchedule) {
      return ExternalAppShieldStore.categoryCount;
    }
    return 0;
  }

  static bool usesGlobalFallback(String scheduleId) {
    final per = ScheduleScreenTimeStore.encodedFor(scheduleId);
    return (per == null || per.isEmpty) &&
        ExternalAppShieldStore.syncWithBlockSchedule &&
        ExternalAppShieldStore.hasSelection;
  }

  static String countLineForSchedule(String scheduleId) {
    final apps = appCountForSchedule(scheduleId);
    final cats = categoryCountForSchedule(scheduleId);
    if (apps == 0 && cats == 0) return '차단 앱 미선택';
    final fallback = usesGlobalFallback(scheduleId) ? ' · 전역 목록' : '';
    return '앱 $apps개 · 카테고리 $cats개$fallback';
  }

  /// iOS Label 미지원 시·보조 — 시간 한도 규칙 이름.
  static List<String> textLabelsForSchedule(String scheduleId) {
    return AppUsageLimitStore.loadRules()
        .where((r) => r.scheduleId == scheduleId)
        .map((r) => r.label)
        .where((l) => l.isNotEmpty)
        .toList();
  }

  static List<String> textLabelsGlobal() {
    return AppUsageLimitStore.loadRules()
        .where((r) => r.scheduleId == null || (r.scheduleId?.isEmpty ?? true))
        .map((r) => r.label)
        .where((l) => l.isNotEmpty)
        .toList();
  }
}
