import 'package:flutter/material.dart';

import '../../../../core/block_schedule/models/block_schedule.dart';
import '../../../../core/block_schedule/models/schedule_slot.dart';
import '../../../../core/block_schedule/schedule_slot_edit_policy.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/localization/schedule_strings.dart';
import '../../../../shared/widgets/isle_sheet.dart';

/// 차단 시간대 편집 — "시작 → 종료" + 요일 멀티선택 (Cold Turkey 방식).
///
/// 내부 모델은 `_Window`(요일 묶음 + 시작·종료)지만, 저장은 기존 [ScheduleSlot]
/// (요일당 1개)로 펼쳐 반환한다. 같은 시간대를 여러 요일에 한 번에 적용한다.
class ScheduleWindowSheet extends StatefulWidget {
  const ScheduleWindowSheet({
    super.key,
    required this.initialSlots,
    this.schedule,
    this.onDraftChanged,
  });

  final List<ScheduleSlot> initialSlots;
  final BlockSchedule? schedule;
  final ValueChanged<List<ScheduleSlot>>? onDraftChanged;

  static Future<List<ScheduleSlot>?> show(
    BuildContext context, {
    required List<ScheduleSlot> initialSlots,
    BlockSchedule? schedule,
  }) {
    List<ScheduleSlot> draft = [...initialSlots];
    return showIsleModalSheet<List<ScheduleSlot>>(
      context: context,
      builder: (_) => ScheduleWindowSheet(
        initialSlots: initialSlots,
        schedule: schedule,
        onDraftChanged: (slots) => draft = slots,
      ),
    ).then((result) => result ?? draft);
  }

  /// 편집 화면용 — 그룹화된 시간대 요약 줄 ("평일 · 21:00 → 23:00").
  static List<String> summarize(List<ScheduleSlot> slots) {
    return _groupSlots(slots).map((w) {
      final overnight = w.isOvernight ? ' (다음날)' : '';
      return '${_daysSummary(w.days)} · ${_fmt(w.startMin)} → ${_fmt(w.endMin)}$overnight';
    }).toList();
  }

  @override
  State<ScheduleWindowSheet> createState() => _ScheduleWindowSheetState();
}

class _ScheduleWindowSheetState extends State<ScheduleWindowSheet> {
  late List<_Window> _windows;

  @override
  void initState() {
    super.initState();
    _windows = _groupSlots(widget.initialSlots);
    widget.onDraftChanged?.call(_buildSlots());
  }

  List<ScheduleSlot> _buildSlots() {
    final out = <ScheduleSlot>[];
    for (final w in _windows) {
      for (final d in w.days) {
        out.add(ScheduleSlot(day: d, startMinute: w.startMin, endMinute: w.endMin));
      }
    }
    return out;
  }

  void _emitDraft() {
    widget.onDraftChanged?.call(_buildSlots());
  }

  Future<void> _openEditor({_Window? existing}) async {
    final others = _windows.where((w) => w != existing).toList();
    final result = await _WindowEditorSheet.show(
      context,
      initial: existing,
      otherWindows: others,
    );
    if (result == null || !mounted) return;
    final sch = widget.schedule;
    if (sch != null &&
        !ScheduleSlotEditPolicy.canAddTimeRange(
          schedule: sch,
          days: result.days,
          startMinute: result.startMin,
          endMinute: result.endMin,
        )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ScheduleSlotEditPolicy.protectedZoneLabel())),
      );
      return;
    }
    setState(() {
      if (existing != null) _windows.remove(existing);
      _windows.add(result);
      _windows.sort((a, b) => a.startMin.compareTo(b.startMin));
    });
    _emitDraft();
  }

  bool _canEditWindow(_Window w) {
    final sch = widget.schedule;
    if (sch == null) return true;
    return ScheduleSlotEditPolicy.canModifyTimeRange(
      schedule: sch,
      days: w.days,
      startMinute: w.startMin,
      endMinute: w.endMin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final sch = ScheduleStrings.of(context);
    final schedule = widget.schedule;
    final blockActive =
        schedule != null && ScheduleSlotEditPolicy.isScheduleBlockActive(schedule);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(sch.t('window_sheet_title'), style: IsleText.title()),
          const SizedBox(height: 6),
          Text(
            sch.t('window_sheet_desc'),
            style: IsleText.caption(color: IsleColors.muted),
          ),
          if (blockActive) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: IsleColors.gold500.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: IsleColors.gold500.withValues(alpha: 0.4)),
              ),
              child: Text(
                ScheduleSlotEditPolicy.protectedZoneLabel(),
                style: IsleText.caption(color: IsleColors.ocean900).copyWith(height: 1.35),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Flexible(
            child: _windows.isEmpty
                ? _EmptyState(onAdd: () => _openEditor())
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _windows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final w = _windows[i];
                      final others = _windows.where((x) => x != w).toList();
                      final editable = _canEditWindow(w);
                      return _WindowCard(
                        window: w,
                        otherWindows: others,
                        locked: !editable,
                        onTap: editable
                            ? () => _openEditor(existing: w)
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ScheduleSlotEditPolicy.protectedZoneLabel()),
                                  ),
                                );
                              },
                        onDelete: editable
                            ? () => setState(() {
                                _windows.remove(w);
                                _emitDraft();
                              })
                            : null,
                      );
                    },
                  ),
          ),
          if (_windows.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('시간대 추가'),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(context, _buildSlots()),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text('적용'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── 시간대 모델 ──────────────────────────

class _Window {
  _Window({required this.days, required this.startMin, required this.endMin});

  Set<int> days; // 0=월 … 6=일
  int startMin; // 0–1439
  int endMin; // 0–1439 (start보다 작으면 자정 넘김)

  bool get isOvernight => endMin <= startMin;
}

/// 같은 (시작,종료)인 슬롯들을 하나의 시간대로 묶는다.
List<_Window> _groupSlots(List<ScheduleSlot> slots) {
  final map = <String, _Window>{};
  for (final s in slots) {
    final key = '${s.startMinute}_${s.endMinute}';
    final w = map.putIfAbsent(
      key,
      () => _Window(days: {}, startMin: s.startMinute, endMin: s.endMinute),
    );
    w.days.add(s.day.clamp(0, 6));
  }
  return map.values.toList()..sort((a, b) => a.startMin.compareTo(b.startMin));
}

const _dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

String _fmt(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

String _daysSummary(Set<int> days) {
  if (days.length == 7) return '매일';
  if (days.length == 5 && days.containsAll({0, 1, 2, 3, 4})) return '평일';
  if (days.length == 2 && days.containsAll({5, 6})) return '주말';
  final sorted = days.toList()..sort();
  return sorted.map((d) => _dayLabels[d]).join('·');
}

// ────────────────────────── 빈 상태 ──────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Icon(Icons.schedule, size: 44, color: IsleColors.ocean500.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text(ScheduleStrings.of(context).t('window_empty'), style: IsleText.body()),
        const SizedBox(height: 4),
        Text(
          '예: 평일 밤 9시 → 11시',
          style: IsleText.caption(color: IsleColors.muted),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('첫 시간대 추가'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ────────────────────────── 시간대 카드 ──────────────────────────

class _WindowCard extends StatelessWidget {
  const _WindowCard({
    required this.window,
    required this.onTap,
    required this.onDelete,
    this.otherWindows = const [],
    this.locked = false,
  });

  final _Window window;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final List<_Window> otherWindows;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: locked ? IsleColors.sand100 : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: IsleColors.ocean100.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _daysSummary(window.days),
                            style: IsleText.caption(color: IsleColors.ocean700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_fmt(window.startMin)} → ${_fmt(window.endMin)}',
                          style: IsleText.subtitle(),
                        ),
                        if (window.isOvernight) ...[
                          const SizedBox(width: 6),
                          Text('+1일', style: IsleText.badge(color: IsleColors.gold500)),
                        ],
                        if (locked) ...[
                          const SizedBox(width: 6),
                          Text('보호', style: IsleText.badge(color: IsleColors.muted)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    _TimelineBar(
                      startMin: window.startMin,
                      endMin: window.endMin,
                      color: IsleColors.ocean500,
                      ghostWindows: otherWindows,
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: IsleColors.muted,
                  onPressed: onDelete,
                )
              else
                const Icon(Icons.lock_outline, size: 18, color: IsleColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── 24시간 타임라인 ──────────────────────────

class _TimelineBar extends StatelessWidget {
  const _TimelineBar({
    required this.startMin,
    required this.endMin,
    required this.color,
    this.ghostWindows = const [],
  });

  final int startMin;
  final int endMin;
  final Color color;

  /// 이미 추가된 다른 시간대 — 흐릿하게 겹쳐 표시
  final List<_Window> ghostWindows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        double px(int m) => (m / 1440.0) * w;

        List<Widget> segsFor(int s, int e, Color col) {
          if (s <= e) return [_seg(px(s), px(e) - px(s), col)];
          // 자정 넘김 → 두 구간
          return [_seg(px(s), w - px(s), col), _seg(0, px(e), col)];
        }

        final ghostSegs = [
          for (final g in ghostWindows)
            ...segsFor(g.startMin, g.endMin, color.withValues(alpha: 0.22)),
        ];
        final mainSegs = segsFor(startMin, endMin, color);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 10,
              child: Stack(
                children: [
                  // 트랙
                  Container(
                    decoration: BoxDecoration(
                      color: IsleColors.ocean100.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  // 정오 기준선
                  Positioned(
                    left: px(720) - 0.5,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 1, color: IsleColors.muted.withValues(alpha: 0.3)),
                  ),
                  // 다른 시간대(흐림) → 현재 시간대(선명) 순서로 그림
                  ...ghostSegs,
                  ...mainSegs,
                ],
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0시', style: IsleText.badge(color: IsleColors.muted)),
                Text('12시', style: IsleText.badge(color: IsleColors.muted)),
                Text('24시', style: IsleText.badge(color: IsleColors.muted)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _seg(double left, double width, Color col) => Positioned(
        left: left,
        top: 0,
        bottom: 0,
        child: Container(
          width: width < 2 ? 2 : width,
          decoration: BoxDecoration(
            color: col,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      );
}

// ────────────────────────── 시간대 편집(추가) 시트 ──────────────────────────

class _WindowEditorSheet extends StatefulWidget {
  const _WindowEditorSheet({
    this.initial,
    this.otherWindows = const [],
    required this.draft,
  });
  final _Window? initial;
  final _Window draft;

  /// 이미 추가된 다른 시간대 — 타임라인에 흐릿하게 표시
  final List<_Window> otherWindows;

  static Future<_Window?> show(
    BuildContext context, {
    _Window? initial,
    List<_Window> otherWindows = const [],
  }) {
    final draft = _Window(
      days: {...(initial?.days ?? {0, 1, 2, 3, 4})},
      startMin: initial?.startMin ?? 21 * 60,
      endMin: initial?.endMin ?? 23 * 60,
    );
    return showIsleModalSheet<_Window>(
      context: context,
      builder: (_) =>
          _WindowEditorSheet(initial: initial, otherWindows: otherWindows, draft: draft),
    ).then((result) => result ?? draft);
  }

  @override
  State<_WindowEditorSheet> createState() => _WindowEditorSheetState();
}

class _WindowEditorSheetState extends State<_WindowEditorSheet> {
  late Set<int> _days;
  late int _startMin;
  late int _endMin;

  @override
  void initState() {
    super.initState();
    _days = {...?widget.initial?.days};
    if (_days.isEmpty) _days = {0, 1, 2, 3, 4}; // 기본: 평일
    _startMin = widget.initial?.startMin ?? 21 * 60;
    _endMin = widget.initial?.endMin ?? 23 * 60;
    _syncDraft();
  }

  bool get _isOvernight => _endMin <= _startMin;

  void _syncDraft() {
    widget.draft.days = {..._days};
    widget.draft.startMin = _startMin;
    widget.draft.endMin = _endMin;
  }

  Future<void> _pickTime(bool isStart) async {
    final base = isStart ? _startMin : _endMin;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base ~/ 60, minute: base % 60),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final m = picked.hour * 60 + picked.minute;
      if (isStart) {
        _startMin = m;
      } else {
        _endMin = m;
      }
      _syncDraft();
    });
  }

  void _applyPreset(Set<int> days) => setState(() {
    _days = {...days};
    _syncDraft();
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.initial == null ? '시간대 추가' : '시간대 편집', style: IsleText.title()),
          const SizedBox(height: 16),

          // ── 요일 프리셋 ──
          Row(
            children: [
              _PresetChip(label: '평일', onTap: () => _applyPreset({0, 1, 2, 3, 4})),
              const SizedBox(width: 8),
              _PresetChip(label: '주말', onTap: () => _applyPreset({5, 6})),
              const SizedBox(width: 8),
              _PresetChip(label: '매일', onTap: () => _applyPreset({0, 1, 2, 3, 4, 5, 6})),
            ],
          ),
          const SizedBox(height: 10),

          // ── 요일 알약 ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (d) {
              final on = _days.contains(d);
              final weekend = d >= 5;
              return GestureDetector(
                onTap: () => setState(() {
                  if (on) {
                    _days.remove(d);
                  } else {
                    _days.add(d);
                  }
                  _syncDraft();
                }),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? IsleColors.ocean500 : Colors.transparent,
                    border: Border.all(
                      color: on ? IsleColors.ocean500 : IsleColors.muted.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _dayLabels[d],
                    style: IsleText.body().copyWith(
                      color: on
                          ? Colors.white
                          : (weekend ? IsleColors.gold500 : null),
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // ── 시작 → 종료 ──
          Row(
            children: [
              Expanded(child: _TimeBox(label: '시작', minute: _startMin, onTap: () => _pickTime(true))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward, color: IsleColors.muted),
              ),
              Expanded(
                child: _TimeBox(
                  label: '종료',
                  minute: _endMin,
                  badge: _isOvernight ? '다음날' : null,
                  onTap: () => _pickTime(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 타임라인 미리보기 (다른 시간대는 흐릿하게 함께 표시) ──
          _TimelineBar(
            startMin: _startMin,
            endMin: _endMin,
            color: IsleColors.ocean500,
            ghostWindows: widget.otherWindows,
          ),
          const SizedBox(height: 12),

          // ── 요약 ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: IsleColors.ocean100.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _days.isEmpty
                  ? '요일을 하나 이상 선택하세요.'
                  : '${_daysSummary(_days)} · ${_fmt(_startMin)} → ${_fmt(_endMin)}'
                      '${_isOvernight ? " (다음날)" : ""} 동안 잠급니다.',
              style: IsleText.body(color: IsleColors.ocean700),
            ),
          ),
          const SizedBox(height: 16),

          FilledButton(
            onPressed: _days.isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      _Window(days: {..._days}, startMin: _startMin, endMin: _endMin),
                    ),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(widget.initial == null ? '추가' : '저장'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          side: BorderSide(color: IsleColors.ocean500.withValues(alpha: 0.5)),
        ),
        child: Text(label, style: IsleText.caption(color: IsleColors.ocean700)),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({
    required this.label,
    required this.minute,
    required this.onTap,
    this.badge,
  });

  final String label;
  final int minute;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: IsleColors.ocean100.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IsleColors.ocean500.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: IsleText.caption(color: IsleColors.muted)),
                if (badge != null) ...[
                  const SizedBox(width: 4),
                  Text(badge!, style: IsleText.badge(color: IsleColors.gold500)),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _fmt(minute),
              style: IsleText.title().copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
