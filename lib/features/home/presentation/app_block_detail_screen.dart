import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/block_schedule/app_block_config_service.dart';
import '../../../core/block_schedule/models/block_schedule.dart';
import '../../../core/block_schedule/models/schedule_enforcement_mode.dart';
import '../../../core/block_schedule/models/schedule_slot.dart';
import '../../../core/block_schedule/schedule_app_target_catalog.dart';
import '../../../core/block_schedule/schedule_app_targets_store.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../settings/presentation/widgets/schedule_window_sheet.dart';

enum _AppBlockMode { off, always, schedule, refill }

/// 카탈로그 앱 하나(카카오톡·인스타그램·틱톡 등) 통합 차단 설정 —
/// 스위치 카드나 "내 차단 목록"을 탭하면 여기로 들어와서 [항상 차단]/[시간표]/
/// [나눠 쓰기]를 한 화면에서 전부 다룬다. 스케줄 탭으로 따로 이동할 필요 없음.
///
/// 2026-07-20: [AppBlockConfigService]가 관리하는 앱당 1스케줄로 완전히
/// 일원화 — 예전엔 유튜브/카카오/유튜브뮤직만 [항상 차단]을 별도 공유 쉴드
/// 시스템(QuickOsBlockService)으로 처리해서, 그 세 앱과 Safari가 서로 다른
/// 저장소를 쓰는 비일관성이 있었다(Safari는 애초에 이 화면과 연결도 안 돼
/// 있었음 — 실사용 제보). 이제 4개 전부 이 화면 하나로 들어와 같은 방식으로
/// 다뤄진다.
class AppBlockDetailScreen extends StatefulWidget {
  const AppBlockDetailScreen({super.key, required this.bundleId});

  final String bundleId;

  static bool isCatalogBundle(String key) =>
      ScheduleAppTargetCatalog.bundleFor(key) != null;

  @override
  State<AppBlockDetailScreen> createState() => _AppBlockDetailScreenState();
}

class _AppBlockDetailScreenState extends State<AppBlockDetailScreen> {
  List<BlockSchedule> _schedules = const [];
  BlockSchedule? _schedule;
  _AppBlockMode _mode = _AppBlockMode.off;
  List<ScheduleSlot> _slots = const [
    ScheduleSlot(day: 0, startMinute: 21 * 60, endMinute: 23 * 60),
    ScheduleSlot(day: 1, startMinute: 21 * 60, endMinute: 23 * 60),
    ScheduleSlot(day: 2, startMinute: 21 * 60, endMinute: 23 * 60),
    ScheduleSlot(day: 3, startMinute: 21 * 60, endMinute: 23 * 60),
    ScheduleSlot(day: 4, startMinute: 21 * 60, endMinute: 23 * 60),
  ];
  int _sessionMinutes = 3;
  int _windowMinutes = 10;
  bool _loading = true;
  bool _busy = false;
  String get _label =>
      ScheduleAppTargetCatalog.bundleFor(widget.bundleId)
          ?.label
          .split(' · ')
          .first ??
      widget.bundleId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final schedules = await AppBlockConfigService.schedulesFor(widget.bundleId);
    if (!mounted) return;
    final selected = _schedule != null
        ? schedules.where((s) => s.id == _schedule!.id).firstOrNull
        : schedules.firstOrNull;
    if (schedules.isEmpty ||
        selected == null ||
        !selected.enabled ||
        selected.slots.isEmpty) {
      setState(() {
        _schedules = schedules;
        _schedule = selected;
        _mode = _AppBlockMode.off;
        _loading = false;
      });
      return;
    }
    if (selected.slots.length >= 7 &&
        selected.slots
            .every((s) => s.startMinute == 0 && s.endMinute == 1439)) {
      setState(() {
        _schedules = schedules;
        _schedule = selected;
        _mode = _AppBlockMode.always;
        _loading = false;
      });
      return;
    }
    setState(() {
      _schedules = schedules;
      _schedule = selected;
      _slots = selected.slots;
      _mode = selected.enforcementMode == ScheduleEnforcementMode.limitInSlot
          ? _AppBlockMode.refill
          : _AppBlockMode.schedule;
      final targetIds = AppBlockConfigService.targetIdsFor(widget.bundleId);
      final entry = ScheduleAppTargetsStore.entryFor(
        selected.id,
        targetIds.isEmpty ? '' : targetIds.first,
      );
      if (entry != null && entry.limitEnabled) {
        _sessionMinutes = entry.limitMinutes;
        _windowMinutes = entry.windowMinutes;
      }
      _loading = false;
    });
  }

  Future<void> _applyMode(_AppBlockMode mode) async {
    final schedule = _schedule;
    if (schedule == null) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      switch (mode) {
        case _AppBlockMode.off:
          await AppBlockConfigService.applyOff(
            widget.bundleId,
            scheduleId: schedule.id,
          );
        case _AppBlockMode.always:
          await AppBlockConfigService.applyAlwaysBlock(
            widget.bundleId,
            true,
            scheduleId: schedule.id,
          );
        case _AppBlockMode.schedule:
          await AppBlockConfigService.applyTimeWindow(
            widget.bundleId,
            slots: _slots,
            scheduleId: schedule.id,
          );
        case _AppBlockMode.refill:
          await AppBlockConfigService.applyRefill(
            widget.bundleId,
            slots: _slots,
            sessionMinutes: _sessionMinutes,
            windowMinutes: _windowMinutes,
            scheduleId: schedule.id,
          );
      }
      if (!mounted) return;
      setState(() => _mode = mode);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editSlots() async {
    final result =
        await ScheduleWindowSheet.show(context, initialSlots: _slots);
    if (result == null || !mounted) return;
    setState(() => _slots = result);
    if (_mode == _AppBlockMode.schedule || _mode == _AppBlockMode.refill) {
      await _applyMode(_mode);
    }
  }

  Future<void> _addRule() async {
    final schedule = _schedule;
    if (schedule == null || _busy) return;
    setState(() => _busy = true);
    try {
      final created = await AppBlockConfigService.createAdditionalRule(
        widget.bundleId,
        template: schedule,
      );
      if (!mounted) return;
      setState(() => _schedule = created);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('새 규칙을 추가했어요. 시간대를 바꿔서 다른 시간창으로 쓸 수 있어요.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectSchedule(BlockSchedule schedule) async {
    if (_busy) return;
    setState(() {
      _schedule = schedule;
      _loading = true;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return Scaffold(
      backgroundColor: IsleColors.sand100,
      appBar: IsleAppBar(
        title: _label,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: '전체 시간표 보기',
            onPressed: () => context.go('/block/schedules'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('어떻게 막을까요?',
              style: IsleText.subtitle(color: IsleColors.ocean900)),
          const SizedBox(height: 10),
          if (_schedules.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final schedule in _schedules)
                  ChoiceChip(
                    label: Text(schedule.name),
                    selected: _schedule?.id == schedule.id,
                    onSelected: (_) => _selectSchedule(schedule),
                  ),
                ActionChip(
                  label: const Text('새 규칙 추가'),
                  avatar: const Icon(Icons.add, size: 18),
                  onPressed: _busy ? null : _addRule,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_schedule != null)
            Text(
              '현재 규칙: ${_schedule!.name}',
              style: IsleText.caption(color: IsleColors.muted)
                  .copyWith(height: 1.35),
            ),
          if (_schedule != null) const SizedBox(height: 8),
          _ModeSegment(
            mode: _mode,
            busy: _busy,
            onSelect: _applyMode,
          ),
          const SizedBox(height: 20),
          if (_mode == _AppBlockMode.always) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: IsleColors.ocean100),
              ),
              child: Text(
                '$_label을 하루 24시간 계속 막아요.',
                style: IsleText.body(color: IsleColors.ocean900),
              ),
            ),
          ],
          if (_mode == _AppBlockMode.schedule ||
              _mode == _AppBlockMode.refill) ...[
            _TimeWindowCard(
              slots: _slots,
              onEdit: _editSlots,
            ),
            if (_mode == _AppBlockMode.refill) ...[
              const SizedBox(height: 12),
              _RefillCard(
                sessionMinutes: _sessionMinutes,
                windowMinutes: _windowMinutes,
                onChanged: (session, window) {
                  setState(() {
                    _sessionMinutes = session;
                    _windowMinutes = window;
                  });
                  unawaited(_applyMode(_AppBlockMode.refill));
                },
              ),
            ],
          ],
          if (_mode == _AppBlockMode.off) ...[
            Text(
              '지금은 $_label을 막고 있지 않아요.',
              style: IsleText.caption(color: IsleColors.muted)
                  .copyWith(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment(
      {required this.mode, required this.busy, required this.onSelect});

  final _AppBlockMode mode;
  final bool busy;
  final ValueChanged<_AppBlockMode> onSelect;

  static const _labels = {
    _AppBlockMode.off: '끄기',
    _AppBlockMode.always: '항상 차단',
    _AppBlockMode.schedule: '시간표',
    _AppBlockMode.refill: '나눠 쓰기',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _labels.entries.map((entry) {
        final selected = entry.key == mode;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: OutlinedButton(
              onPressed: busy ? null : () => onSelect(entry.key),
              style: OutlinedButton.styleFrom(
                backgroundColor: selected ? IsleColors.ocean700 : Colors.white,
                foregroundColor: selected ? Colors.white : IsleColors.ocean900,
                side: BorderSide(
                  color: selected ? IsleColors.ocean700 : IsleColors.ocean100,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                entry.value,
                style: IsleText.caption(
                  color: selected ? Colors.white : IsleColors.ocean900,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TimeWindowCard extends StatelessWidget {
  const _TimeWindowCard({required this.slots, required this.onEdit});

  final List<ScheduleSlot> slots;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final summary = ScheduleWindowSheet.summarize(slots);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('시간대', style: IsleText.subtitle(color: IsleColors.ocean900)),
          const SizedBox(height: 8),
          if (summary.isEmpty)
            Text('설정된 시간대가 없어요',
                style: IsleText.caption(color: IsleColors.muted))
          else
            ...summary.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child:
                    Text(s, style: IsleText.body(color: IsleColors.ocean700)),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.schedule, size: 18),
            label: const Text('시간대 편집'),
          ),
        ],
      ),
    );
  }
}

class _RefillCard extends StatefulWidget {
  const _RefillCard({
    required this.sessionMinutes,
    required this.windowMinutes,
    required this.onChanged,
  });

  final int sessionMinutes;
  final int windowMinutes;
  final void Function(int session, int window) onChanged;

  @override
  State<_RefillCard> createState() => _RefillCardState();
}

class _RefillCardState extends State<_RefillCard> {
  late int _session = widget.sessionMinutes;
  late int _window = widget.windowMinutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('나눠 쓰기', style: IsleText.subtitle(color: IsleColors.ocean900)),
          const SizedBox(height: 4),
          Text(
            '$_window분마다 $_session분만 쓸 수 있어요',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 8),
          Text('한 번에 쓰는 시간: $_session분', style: IsleText.body()),
          Slider(
            value: _session.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            label: '$_session분',
            onChanged: (v) => setState(() => _session = v.round()),
            onChangeEnd: (_) => widget.onChanged(_session, _window),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ScheduleAppTargetCatalog.windowPresets.map((p) {
              final selected = p.minutes == _window;
              return ChoiceChip(
                label: Text(p.label),
                selected: selected,
                onSelected: (_) {
                  setState(() => _window = p.minutes);
                  widget.onChanged(_session, _window);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
