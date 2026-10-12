import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/block_schedule/block_schedule_store.dart';
import '../../../core/block_schedule/models/block_schedule.dart';
import '../../../core/block_schedule/quick_block_service.dart';
import '../../../core/block_schedule/schedule_display_helper.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/navigation/isle_routes.dart';
import '../../../shared/widgets/isle_app_bar.dart';

enum _CalendarEntryKind { reservation, weekly }

class _CalendarEntry {
  const _CalendarEntry(this.schedule, this.kind);
  final BlockSchedule schedule;
  final _CalendarEntryKind kind;
}

/// 이름 붙인 스케줄을 달력으로 확인 — 예약(scheduledActivationAtMs~
/// scheduledDeactivationAtMs)은 해당 날짜 구간에, 매주 반복 스케줄은
/// 요일이 일치하는 날마다 점으로 표시한다(2026-07-20 신설).
class ScheduleCalendarScreen extends ConsumerStatefulWidget {
  const ScheduleCalendarScreen({super.key});

  @override
  ConsumerState<ScheduleCalendarScreen> createState() =>
      _ScheduleCalendarScreenState();
}

class _ScheduleCalendarScreenState
    extends ConsumerState<ScheduleCalendarScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<DateTime, List<_CalendarEntry>> _entriesForVisibleMonth(
    List<BlockSchedule> schedules,
  ) {
    final firstOfMonth = _visibleMonth;
    final firstOfNextMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    final out = <DateTime, List<_CalendarEntry>>{};

    void addEntry(DateTime day, _CalendarEntry entry) {
      final key = _dateOnly(day);
      out.putIfAbsent(key, () => []).add(entry);
    }

    for (final s in schedules) {
      if (!s.enabled && !s.reservationLocked) continue;
      if (s.reservationLocked) {
        // 예약 스케줄은 24시간 전체 슬롯을 채워두는 내부 구현이라(항상
        // 요일 매칭됨) weekly 갈래로 새지 않게 별도 처리한다.
        final activationMs = s.scheduledActivationAtMs;
        final deactivationMs = s.scheduledDeactivationAtMs;
        if (deactivationMs == null) continue;
        final end = _dateOnly(DateTime.fromMillisecondsSinceEpoch(deactivationMs));
        // 활성화 시각이 이미 지나 초기화된(=이미 진행 중인) 예약은 시작일
        // 정보가 없으니 오늘부터로 근사한다 — 지난 날짜 표시는 불가.
        final start = activationMs != null
            ? _dateOnly(DateTime.fromMillisecondsSinceEpoch(activationMs))
            : _dateOnly(DateTime.now());
        var d = start.isBefore(firstOfMonth) ? firstOfMonth : start;
        final rangeEndExclusive = end.isBefore(firstOfNextMonth) ? end : firstOfNextMonth;
        while (d.isBefore(rangeEndExclusive)) {
          addEntry(d, _CalendarEntry(s, _CalendarEntryKind.reservation));
          d = d.add(const Duration(days: 1));
        }
        continue;
      }
      if (s.slots.isEmpty) continue;
      final weekdays = ScheduleDisplayHelper.activeDayIndexes(s.slots);
      var d = firstOfMonth;
      while (d.isBefore(firstOfNextMonth)) {
        if (weekdays.contains(d.weekday - 1)) {
          addEntry(d, _CalendarEntry(s, _CalendarEntryKind.weekly));
        }
        d = d.add(const Duration(days: 1));
      }
    }
    return out;
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final schedules = ref
        .watch(blockSchedulesProvider)
        .where((s) => s.id != QuickBlockService.presetScheduleId)
        .toList();
    final entriesByDay = _entriesForVisibleMonth(schedules);
    final today = _dateOnly(DateTime.now());

    return Scaffold(
      appBar: IsleAppBar(title: '스케줄 캘린더'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  final now = DateTime.now();
                  _visibleMonth = DateTime(now.year, now.month);
                }),
                child: Text(
                  '${_visibleMonth.year}년 ${_visibleMonth.month}월',
                  style: IsleText.subtitle(color: IsleColors.ocean900),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _legend(),
          const SizedBox(height: 12),
          _weekdayHeader(),
          const SizedBox(height: 4),
          _monthGrid(entriesByDay, today),
          const SizedBox(height: 20),
          if (schedules.where((s) => s.reservationLocked).isNotEmpty) ...[
            Text('예약 스케줄', style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...schedules.where((s) => s.reservationLocked).map(_reservationSummaryTile),
          ],
        ],
      ),
    );
  }

  Widget _legend() {
    Widget dot(Color c) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        );
    return Row(
      children: [
        dot(IsleColors.purple500),
        Text('예약 차단', style: IsleText.caption(color: IsleColors.muted)),
        const SizedBox(width: 16),
        dot(IsleColors.ocean500),
        Text('반복 스케줄', style: IsleText.caption(color: IsleColors.muted)),
      ],
    );
  }

  Widget _weekdayHeader() {
    return Row(
      children: [
        for (final w in ScheduleDisplayHelper.weekdayShort)
          Expanded(
            child: Center(
              child: Text(w, style: IsleText.caption(color: IsleColors.muted)),
            ),
          ),
      ],
    );
  }

  Widget _monthGrid(Map<DateTime, List<_CalendarEntry>> entriesByDay, DateTime today) {
    final firstOfMonth = _visibleMonth;
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // weekdayShort는 월요일 시작(0=월)이라 그리드도 월요일 시작으로 맞춘다.
    final leadingBlanks = firstOfMonth.weekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++) ...[
                Builder(builder: (context) {
                  final cellIndex = r * 7 + c;
                  final dayNum = cellIndex - leadingBlanks + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 48));
                  }
                  final date = DateTime(_visibleMonth.year, _visibleMonth.month, dayNum);
                  final entries = entriesByDay[date] ?? const [];
                  final isToday = date == today;
                  return Expanded(
                    child: GestureDetector(
                      onTap: entries.isEmpty ? null : () => _showDaySheet(date, entries),
                      child: Container(
                        height: 48,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isToday ? IsleColors.ocean100 : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayNum',
                              style: IsleText.caption(
                                color: isToday ? IsleColors.ocean900 : IsleColors.ocean700,
                              ).copyWith(fontWeight: isToday ? FontWeight.w700 : FontWeight.w400),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (entries.any((e) => e.kind == _CalendarEntryKind.reservation))
                                  _smallDot(IsleColors.purple500),
                                if (entries.any((e) => e.kind == _CalendarEntryKind.weekly))
                                  _smallDot(IsleColors.ocean500),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
      ],
    );
  }

  Widget _smallDot(Color c) => Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  void _showDaySheet(DateTime date, List<_CalendarEntry> entries) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${date.month}월 ${date.day}일',
                style: IsleText.subtitle(color: IsleColors.ocean900),
              ),
              const SizedBox(height: 12),
              for (final e in entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    e.kind == _CalendarEntryKind.reservation
                        ? Icons.event_busy
                        : Icons.repeat,
                    color: e.kind == _CalendarEntryKind.reservation
                        ? IsleColors.purple500
                        : IsleColors.ocean500,
                  ),
                  title: Text(e.schedule.name),
                  subtitle: Text(
                    e.kind == _CalendarEntryKind.reservation
                        ? _reservationPeriodLabel(e.schedule)
                        : ScheduleDisplayHelper.formatScheduleTimes(e.schedule.slots),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(IsleRoutes.blockScheduleEdit(e.schedule.id));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _reservationPeriodLabel(BlockSchedule s) {
    final startMs = s.scheduledActivationAtMs;
    final endMs = s.scheduledDeactivationAtMs;
    final startLabel = startMs != null
        ? _shortDate(DateTime.fromMillisecondsSinceEpoch(startMs))
        : '진행 중';
    final endLabel =
        endMs != null ? _shortDate(DateTime.fromMillisecondsSinceEpoch(endMs)) : '?';
    return '예약 차단 · $startLabel ~ $endLabel · 기간 중엔 타임락 대기로도 해제 불가';
  }

  String _shortDate(DateTime d) => '${d.month}/${d.day}';

  Widget _reservationSummaryTile(BlockSchedule s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.event_busy, color: IsleColors.purple500),
        title: Text(s.name),
        subtitle: Text(_reservationPeriodLabel(s)),
        onTap: () => context.push(IsleRoutes.blockScheduleEdit(s.id)),
      ),
    );
  }
}
