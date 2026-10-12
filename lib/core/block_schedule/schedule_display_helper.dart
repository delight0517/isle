import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../intervention/schedule_screen_time_store.dart';
import 'models/block_schedule.dart';
import 'models/schedule_enforcement_mode.dart';
import 'models/schedule_slot.dart';
import 'schedule_active_service.dart';
import 'schedule_app_target_catalog.dart';
import 'schedule_app_targets_store.dart';
import '../platform/platform_block_intent.dart';

/// 스케줄 카드·히어로 — 오늘 요일·시간·차단 대상을 사람이 읽기 쉽게
class ScheduleDisplayHelper {
  ScheduleDisplayHelper._();

  static const weekdayShort = ['월', '화', '수', '목', '금', '토', '일'];
  static const weekdayLong = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

  /// 0=월 … 6=일. `7`만 레거시 ISO 일요일.
  static int normalizeDay(int day) {
    if (day == 7) return 6;
    return day.clamp(0, 6);
  }

  static int todayIndex([DateTime? at]) => (at ?? DateTime.now()).weekday - 1;

  static String todayShort([DateTime? at]) => weekdayShort[todayIndex(at)];

  static String todayHeadline([DateTime? at]) {
    final i = todayIndex(at);
    return '오늘 ${weekdayLong[i]} (${weekdayShort[i]})';
  }

  static String clockLabel([DateTime? at]) {
    final n = at ?? DateTime.now();
    final period = n.hour < 12 ? '오전' : '오후';
    final h = n.hour % 12 == 0 ? 12 : n.hour % 12;
    return '$period $h:${n.minute.toString().padLeft(2, '0')}';
  }

  static Set<int> activeDayIndexes(List<ScheduleSlot> slots) =>
      slots.map((s) => normalizeDay(s.day)).toSet();

  static bool hasSlotToday(List<ScheduleSlot> slots, [DateTime? at]) {
    final t = todayIndex(at);
    return slots.any((s) => normalizeDay(s.day) == t);
  }

  static String formatDaysPattern(Set<int> days) {
    if (days.isEmpty) return '요일 없음';
    if (days.length == 7) return '매일';
    if (days.length == 5 && !days.contains(5) && !days.contains(6)) {
      return '평일 (월–금)';
    }
    if (days.length == 2 && days.contains(5) && days.contains(6)) {
      return '주말 (토·일)';
    }
    final sorted = days.toList()..sort();
    return sorted.map((d) => weekdayShort[d]).join(' · ');
  }

  static String _timeRange(ScheduleSlot s) =>
      '${_clock(s.startMinute)}–${_clock(s.endMinute)}';

  static String _clock(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  /// "매일 09:00–23:00" — 슬롯 7개 나열·`외 N개` 제거
  static String formatScheduleTimes(List<ScheduleSlot> slots) {
    if (slots.isEmpty) return '시간 슬롯 없음 — 탭해서 요일·시간 설정';

    final byRange = <String, Set<int>>{};
    for (final s in slots) {
      final key = '${s.startMinute}|${s.endMinute}';
      byRange.putIfAbsent(key, () => {}).add(normalizeDay(s.day));
    }

    if (byRange.length == 1) {
      final days = byRange.values.first;
      final parts = byRange.keys.first.split('|');
      final start = int.parse(parts[0]);
      final end = int.parse(parts[1]);
      final sample = ScheduleSlot(day: 0, startMinute: start, endMinute: end);
      return '${formatDaysPattern(days)} ${_timeRange(sample)}';
    }

    final today = todayIndex();
    final todaySlots = slots.where((s) => normalizeDay(s.day) == today).toList();
    if (todaySlots.isNotEmpty) {
      final ranges = todaySlots.map(_timeRange).toSet().join(', ');
      return '오늘(${weekdayShort[today]}) $ranges · 그 외 요일은 편집에서 확인';
    }

    return '${formatDaysPattern(activeDayIndexes(slots))} · 슬롯 ${slots.length}개';
  }

  static String todayStatusLine(BlockSchedule schedule, {DateTime? at}) {
    final now = at ?? DateTime.now();
    final t = todayIndex(now);
    final active = ScheduleActiveService.isScheduleActiveNow(schedule, now);
    final todaySlots =
        schedule.slots.where((s) => normalizeDay(s.day) == t).toList();

    if (!schedule.enabled) return '스케줄 꺼짐 — 적용 안 됨';
    if (todaySlots.isEmpty) {
      return '오늘(${weekdayShort[t]})에는 작동하지 않음';
    }
    final times = todaySlots.map(_timeRange).toSet().join(', ');
    if (active) {
      final reason = schedule.isSafetyBaseline ? ' (안전 라인으로 인한 활성화)' : '';
      return '오늘(${weekdayShort[t]}) $times · 지금 잠금$reason';
    }
    return '오늘(${weekdayShort[t]}) $times · 지금은 해제';
  }

  /// 활성 슬롯 종료 시각 — "오전 7:00까지 풀려요"
  static String? activeSlotEndsLabel(BlockSchedule schedule, {DateTime? at}) {
    final now = at ?? DateTime.now();
    if (!ScheduleActiveService.isScheduleActiveNow(schedule, now)) return null;
    final minute = now.hour * 60 + now.minute;
    final t = todayIndex(now);
    for (final slot in schedule.slots) {
      if (normalizeDay(slot.day) != t) continue;
      if (!slot.coversMinute(minute)) continue;
      final end = slot.endMinute;
      final h = end ~/ 60;
      final m = end % 60;
      final period = h < 12 ? '오전' : '오후';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '$period $h12:${m.toString().padLeft(2, '0')}까지 풀려요';
    }
    return null;
  }

  /// 현재 활성 스케줄을 칩/배너에 짧게 보여줄 때 쓰는 표기.
  /// 안전 라인이면 "안전 라인"을 우선 밝히고, 끝나는 시각을 함께 붙인다.
  static String activeScheduleChipLabel(BlockSchedule schedule, {DateTime? at}) {
    final now = at ?? DateTime.now();
    final ends = activeSlotEndsLabel(schedule, at: now);
    final conciseEnds = ends?.replaceAll(' 풀려요', '');
    if (schedule.isSafetyBaseline) {
      return conciseEnds == null ? '안전 라인' : '안전 라인 · $conciseEnds';
    }
    if (conciseEnds != null) return '스케줄 · $conciseEnds';
    return todayStatusLine(schedule, at: now);
  }

  static String targetsSummaryDetailed(BlockSchedule schedule) {
    final line = configuredSummaryLine(schedule);
    if (line.startsWith('③')) return line;
    return '막는 것: $line';
  }

  static List<ScheduleTargetVisual> targetVisualsForSchedule(BlockSchedule schedule) {
    final out = <ScheduleTargetVisual>[];
    final seen = <String>{};

    void add(IconData icon, Color color, String label, String key) {
      if (seen.contains(key)) return;
      seen.add(key);
      out.add(ScheduleTargetVisual(icon: icon, color: color, label: label, key: key));
    }

    try {
      for (final e in ScheduleAppTargetsStore.loadForSchedule(schedule.id)) {
        if (!e.blockInSlot) continue;
        final d = ScheduleAppTargetCatalog.defFor(e.targetId);
        if (d == null) continue;
        if (d.id == 'ios_youtube' || d.bundleId == 'youtube') {
          add(Icons.play_circle_filled, const Color(0xFFFF0000), 'YouTube 앱', 'yt_app');
        } else if (d.id == 'ios_youtube_music' || d.bundleId == 'youtube_music') {
          add(Icons.music_note, const Color(0xFFFF0000), 'YouTube Music', 'yt_music');
        } else if (d.id == 'isle_youtube') {
          add(Icons.play_circle_outline, const Color(0xFFFF0000), 'Isle 유튜브', 'yt_isle');
        } else if (d.bundleId == 'instagram_feed' ||
            d.bundleId == 'instagram_dm' ||
            d.bundleId == 'instagram') {
          add(Icons.camera_alt_outlined, const Color(0xFFE1306C), d.label, 'ig_${d.id}');
        } else if (d.id == 'isle_brunch') {
          add(Icons.article_outlined, IsleColors.ocean700, 'Brunch', 'brunch');
        } else {
          add(d.icon, IsleColors.ocean700, d.label, d.id);
        }
      }
    } catch (_) {
      // Hive 미오픈(테스트)
    }

    if (schedule.domains.isNotEmpty && schedule.enforcementMode.appliesShieldInSlot) {
      final yt = schedule.domains.any((d) => d.toLowerCase().contains('youtube'));
      add(
        Icons.public_off,
        const Color(0xFF0A84FF),
        yt ? 'Safari·웹 도메인' : '웹 도메인',
        'domains',
      );
    }
    if (schedule.blockIsleInApp) {
      add(Icons.phonelink_lock, IsleColors.ocean700, 'Isle 웹 전체', 'isle_inapp');
    }

    try {
      final apps = ScheduleScreenTimeStore.appCountFor(schedule.id);
      final cats = ScheduleScreenTimeStore.categoryCountFor(schedule.id);
      if (apps > 0 || cats > 0) {
        final n = apps + cats;
        add(Icons.phone_iphone, IsleColors.ocean700,
            '${PlatformBlockCopy.nativeInstalledAppLabel} $n개', 'ios_pick');
      }
    } catch (_) {}

    return out;
  }

  /// ③ 체크·도메인·Screen Time만 — 이름 추론 없음
  static bool hasIsleYoutubeTarget(BlockSchedule schedule) {
    try {
      return ScheduleAppTargetsStore.loadForSchedule(schedule.id)
          .any((e) => e.targetId == 'isle_youtube' && e.blockInSlot);
    } catch (_) {
      return false;
    }
  }

  static bool hasYoutubeDomainsOnly(BlockSchedule schedule) {
    if (schedule.domains.isEmpty) return false;
    if (!schedule.domains.any((d) => d.toLowerCase().contains('youtube'))) {
      return false;
    }
    return !hasIsleYoutubeTarget(schedule);
  }

  static String configuredSummaryLine(BlockSchedule schedule) {
    final visuals = targetVisualsForSchedule(schedule);
    if (visuals.isEmpty) {
      return '③에서 아무 것도 안 고름 — 이 스케줄은 지금 막지 않아요';
    }
    if (hasYoutubeDomainsOnly(schedule)) {
      return '웹 도메인만 (Isle 유튜브 시청과 별개) · ${visuals.map((v) => v.label).join(' · ')}';
    }
    return visuals.map((v) => v.label).join(' · ');
  }

  /// 스케줄마다 다른 대상(Safari / YouTube 등) — 전역 `applicationCount` 대신 사용
  static Set<String> uniqueTargetKeysForSchedules(Iterable<BlockSchedule> schedules) {
    final keys = <String>{};
    for (final s in schedules) {
      for (final v in targetVisualsForSchedule(s)) {
        keys.add(v.key);
      }
      try {
        final enc = ScheduleScreenTimeStore.encodedFor(s.id);
        if (enc != null && enc.isNotEmpty) {
          keys.add('ios_pick:${s.id}');
        }
      } catch (_) {}
    }
    return keys;
  }

  static List<String> uniqueTargetLabelsForSchedules(Iterable<BlockSchedule> schedules) {
    final labels = <String>[];
    final seen = <String>{};
    for (final s in schedules) {
      for (final v in targetVisualsForSchedule(s)) {
        if (seen.add(v.key)) labels.add(v.label);
      }
    }
    return labels;
  }

  /// 상단 초록 배너 — 스케줄 수 + **고유** 차단 대상 종류
  static String heroBlockingSummary({
    required int scheduleCount,
    required List<BlockSchedule> activeSchedules,
  }) {
    final labels = uniqueTargetLabelsForSchedules(activeSchedules);
    final kindCount = uniqueTargetKeysForSchedules(activeSchedules).length;
    if (labels.isEmpty) {
      return '$scheduleCount개 스케줄 · 대상 확인 필요 (편집에서 앱 선택)';
    }
    return '$scheduleCount개 스케줄 · 막는 것 $kindCount종 — ${labels.join(' · ')}';
  }

  /// 히어로 한 줄 — 활성 스케줄 이름 + 대상
  static String activeNowHeadline(List<BlockSchedule> active) {
    if (active.isEmpty) return '';
    final parts = active.map((s) {
      final targets = targetVisualsForSchedule(s).map((v) => v.label).take(2).join('+');
      return '${s.name}${targets.isEmpty ? '' : ' ($targets)'}';
    });
    return parts.join(' · ');
  }
}

class ScheduleTargetVisual {
  const ScheduleTargetVisual({
    required this.icon,
    required this.color,
    required this.label,
    required this.key,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String key;
}
