import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../../../core/block_schedule/models/block_schedule.dart';
import '../../../../core/block_schedule/models/schedule_app_target_entry.dart';
import '../../../../core/block_schedule/schedule_app_target_catalog.dart';
import '../../../../core/block_schedule/schedule_app_targets_service.dart';
import '../../../../core/block_schedule/schedule_app_targets_store.dart';
import '../../../../core/block_schedule/schedule_edit_guard.dart';
import '../../../../core/block_schedule/schedule_pending_target_service.dart';
import '../../../../core/block_schedule/schedule_pending_target_store.dart';
import '../../../../core/block_schedule/models/pending_schedule_target_edit.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/intervention/schedule_screen_time_service.dart';
import '../../../../core/intervention/schedule_screen_time_store.dart';
import '../../../../core/intervention/screen_time_selection_summary.dart';
import '../../../../core/platform/isle_apple_platform.dart';
import '../../../../shared/widgets/screen_time_selection_preview.dart';

/// 스케줄 편집 ③ — 접이식: Isle / iPhone 잠금 / 시간 한도
class ScheduleAppTargetsSection extends StatefulWidget {
  const ScheduleAppTargetsSection({
    super.key,
    required this.schedule,
    required this.canEdit,
    this.commitmentLocked = false,
  });

  final BlockSchedule schedule;
  final bool canEdit;
  final bool commitmentLocked;

  @override
  ScheduleAppTargetsSectionState createState() => ScheduleAppTargetsSectionState();
}

class ScheduleAppTargetsSectionState extends State<ScheduleAppTargetsSection> {
  List<ScheduleAppTargetEntry> _entries = ScheduleAppTargetsStore.defaultEntries();
  List<ScheduleAppTargetEntry> _persistedEntries = ScheduleAppTargetsStore.defaultEntries();
  bool _iosPickBusy = false;
  int _iosApps = 0;
  int _iosCats = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ScheduleAppTargetsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedule.id != widget.schedule.id ||
        oldWidget.commitmentLocked != widget.commitmentLocked ||
        oldWidget.canEdit != widget.canEdit) {
      unawaited(_load());
    }
  }

  bool get _canModifyTargets =>
      widget.canEdit || (widget.commitmentLocked && ScheduleEditGuard.canQueueTargetEdits(widget.schedule));

  ScheduleAppTargetEntry _persistedEntry(String targetId) {
    for (final e in _persistedEntries) {
      if (e.targetId == targetId) return e;
    }
    return ScheduleAppTargetEntry(targetId: targetId);
  }

  PendingScheduleTargetEdit? _pendingFor(String targetId) =>
      SchedulePendingTargetService.pendingEntry(widget.schedule.id, targetId);

  List<ScheduleAppTargetEntry> _displayEntries(List<ScheduleAppTargetEntry> persisted) {
    if (!widget.commitmentLocked) return persisted;
    final out = [...persisted];
    for (final p in SchedulePendingTargetStore.loadForSchedule(widget.schedule.id)) {
      if (p.kind != PendingScheduleTargetKind.entry || p.entry == null) continue;
      final i = out.indexWhere((e) => e.targetId == p.targetId);
      if (i >= 0) {
        out[i] = p.entry!;
      } else {
        out.add(p.entry!);
      }
    }
    return out;
  }

  void _showTargetOutcomeSnack(ScheduleTargetChangeOutcome outcome, String action) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    switch (outcome.kind) {
      case ScheduleTargetChangeOutcomeKind.immediate:
        messenger.showSnackBar(SnackBar(content: Text('「$action」적용했어요')));
      case ScheduleTargetChangeOutcomeKind.scheduled:
        final when = outcome.remaining == null
            ? '잠금 해제 후'
            : SchedulePendingTargetService.formatRemaining(outcome.remaining!);
        final extra = outcome.startedCountdown ? ' · 잠금 해제 대기 시작' : '';
        messenger.showSnackBar(
          SnackBar(content: Text('「$action」$when 자동 적용 예약$extra')),
        );
      case ScheduleTargetChangeOutcomeKind.alreadyPending:
        final when = outcome.remaining == null
            ? '예약됨'
            : SchedulePendingTargetService.formatRemaining(outcome.remaining!);
        messenger.showSnackBar(SnackBar(content: Text('이미 예약됨 — $when')));
      case ScheduleTargetChangeOutcomeKind.cancelled:
        messenger.showSnackBar(const SnackBar(content: Text('변경 예약을 취소했어요')));
    }
  }

  Future<void> _applyEntryChange(ScheduleAppTargetEntry desired) async {
    final current = _persistedEntry(desired.targetId);
    final outcome = await SchedulePendingTargetService.requestEntryChange(
      schedule: widget.schedule,
      desired: desired,
      currentPersisted: current,
    );
    if (!mounted) return;
    await _load();
    if (outcome.kind == ScheduleTargetChangeOutcomeKind.immediate) return;
    _showTargetOutcomeSnack(
      outcome,
      SchedulePendingTargetService.actionLabel(desired, current),
    );
  }

  Future<void> _load() async {
    await ScheduleAppTargetsStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    await SchedulePendingTargetStore.ensureOpen();
    final list = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(widget.schedule.id),
    );
    if (!mounted) return;
    setState(() {
      _persistedEntries = list;
      _entries = _displayEntries(list);
      _iosApps = ScheduleScreenTimeStore.appCountFor(widget.schedule.id);
      _iosCats = ScheduleScreenTimeStore.categoryCountFor(widget.schedule.id);
    });
  }

  Future<void> persist({bool sync = true}) async {
    final merged = ScheduleAppTargetsStore.mergeWithCatalog(_entries);
    if (sync) {
      await ScheduleAppTargetsService.saveAndSync(
        scheduleId: widget.schedule.id,
        entries: merged,
        schedule: widget.schedule,
      );
    } else {
      await ScheduleAppTargetsStore.saveForSchedule(widget.schedule.id, merged);
    }
    if (mounted) {
      setState(() {
        _persistedEntries = merged;
        _entries = _displayEntries(merged);
      });
    }
  }

  ScheduleAppTargetEntry _entry(String targetId) {
    for (final e in _entries) {
      if (e.targetId == targetId) return e;
    }
    return ScheduleAppTargetEntry(targetId: targetId);
  }

  void _setEntry(ScheduleAppTargetEntry e) {
    if (widget.canEdit) {
      setState(() {
        final i = _entries.indexWhere((x) => x.targetId == e.targetId);
        if (i >= 0) {
          _entries = [..._entries]..[i] = e;
        } else {
          _entries = [..._entries, e];
        }
      });
      unawaited(persist());
      return;
    }
    if (!widget.commitmentLocked) return;
    setState(() {
      final i = _entries.indexWhere((x) => x.targetId == e.targetId);
      if (i >= 0) {
        _entries = [..._entries]..[i] = e;
      } else {
        _entries = [..._entries, e];
      }
    });
    unawaited(_applyEntryChange(e));
  }

  void _setBundleLimit(String bundleId, {bool? enabled, int? minutes, int? window}) {
    ScheduleAppTargetEntry? changed;
    setState(() {
      _entries = _entries.map((e) {
        final d = ScheduleAppTargetCatalog.defFor(e.targetId);
        if (d?.bundleId != bundleId) return e;
        final next = e.copyWith(
          limitEnabled: enabled ?? e.limitEnabled,
          limitMinutes: minutes ?? e.limitMinutes,
          windowMinutes: window ?? e.windowMinutes,
        );
        changed = next;
        return next;
      }).toList();
    });
    if (widget.canEdit) {
      unawaited(persist());
    } else if (widget.commitmentLocked && changed != null) {
      unawaited(_applyEntryChange(changed!));
    }
  }

  ScheduleAppTargetEntry? _bundleRef(String bundleId) {
    for (final e in _entries) {
      final d = ScheduleAppTargetCatalog.defFor(e.targetId);
      if (d?.bundleId == bundleId && e.limitEnabled) return e;
    }
    for (final e in _entries) {
      final d = ScheduleAppTargetCatalog.defFor(e.targetId);
      if (d?.bundleId == bundleId) return e;
    }
    return null;
  }

  int _iosCheckedCount() {
    final iosIds = ScheduleAppTargetCatalog.iosTargets().map((d) => d.id).toSet();
    return _entries.where((e) => e.blockInSlot && iosIds.contains(e.targetId)).length;
  }

  int _limitEnabledCount() =>
      _entries.where((e) => e.limitEnabled).length;

  Future<void> _pickIos() async {
    if (!IsleApplePlatform.isNativeBlockHost) return;
    setState(() => _iosPickBusy = true);
    final additive = ScheduleScreenTimeService.shouldUseAdditiveOnly(widget.schedule.id);
    final ok = await ScheduleScreenTimeService.pickForSchedule(
      widget.schedule.id,
      additiveOnly: additive,
      deferEnforcement: widget.commitmentLocked,
    );
    if (!mounted) return;
    setState(() {
      _iosPickBusy = false;
      _iosApps = ScheduleScreenTimeStore.appCountFor(widget.schedule.id);
      _iosCats = ScheduleScreenTimeStore.categoryCountFor(widget.schedule.id);
    });
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('앱 선택이 취소되었거나 권한이 없어요.')),
      );
      return;
    }
    if (widget.commitmentLocked && ok) {
      await SchedulePendingTargetService.queueIosPickSync(widget.schedule);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('앱 선택 저장됨 — 잠금 해제 후 Screen Time에 반영돼요'),
        ),
      );
    }
    if (widget.canEdit) unawaited(persist());
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    final isle = ScheduleAppTargetCatalog.isleTargets();
    final ios = ScheduleAppTargetCatalog.iosTargets();
    final hasIosSel = _iosApps > 0 || _iosCats > 0;
    final iosN = _iosCheckedCount();
    final limitN = _limitEnabledCount();
    final pendingCount = widget.commitmentLocked
        ? SchedulePendingTargetStore.loadForSchedule(schedule.id).length
        : 0;
    final iosPickPending = SchedulePendingTargetService.pendingIosPick(schedule.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pendingCount > 0)
          Card(
            color: Colors.orange.shade50,
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                iosPickPending != null
                    ? '앱 변경 $pendingCount건 예약됨 · ${SchedulePendingTargetService.formatRemaining(iosPickPending.remaining())}\n'
                        '알림이 오면 탭해서 편집 화면으로 들어올 수 있어요.'
                    : '앱 변경 $pendingCount건 예약됨 — 잠금 해제 후 자동 적용돼요.\n'
                        '알림이 오면 탭해서 확인하세요.',
                style: IsleText.caption(color: Colors.orange.shade900).copyWith(height: 1.4),
              ),
            ),
          ),
        // "지금 뭘 막고 있는지" 요약은 상위 화면의 준비 상태 스트립에서 한 번만 보여줌 —
        // 여기서 다시 배너로 반복하지 않는다(중복 제거).
        _TargetExpansion(
          title: 'Isle 앱 안에서 막기',
          subtitle: '체크 = 완전 차단',
          initiallyExpanded: true,
          child: Column(
            children: isle.map((d) => _targetTile(d)).toList(),
          ),
        ),
        if (IsleApplePlatform.isScreenTimeHost || Platform.isAndroid) ...[
          const SizedBox(height: 6),
          _TargetExpansion(
            title: Platform.isAndroid ? 'Android 앱 잠금' : 'iPhone 앱 잠금',
            subtitle: 'Safari·YouTube 앱 — 체크 후 Screen Time에서 선택',
            initiallyExpanded: iosN > 0 || hasIosSel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasIosSel) ...[
                  ScreenTimeSelectionPreview(
                    encoded: ScreenTimeSelectionSummary.encodedForSchedule(schedule.id),
                    textFallbackLabels:
                        ScreenTimeSelectionSummary.textLabelsForSchedule(schedule.id),
                    height: 36,
                  ),
                  const SizedBox(height: 8),
                ],
                ...ios.map((d) => _targetTile(d)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: IsleSize.minTouchTarget,
                  child: FilledButton.icon(
                    onPressed: !_canModifyTargets || _iosPickBusy ? null : _pickIos,
                    icon: _iosPickBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.apps_outage),
                    label: Text(hasIosSel ? '앱 다시 선택' : 'Screen Time에서 앱 선택'),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 6),
        _TargetExpansion(
          title: '시간 한도만 (잠금 아님)',
          subtitle: '완전 차단 대신 N분만 허용 — 선택 사항 · 체크박스와는 별개예요',
          initiallyExpanded: limitN > 0,
          child: Column(
            children: ScheduleAppTargetCatalog.bundles.map(_bundleLimitCard).toList(),
          ),
        ),
      ],
    );
  }

  Widget _targetTile(ScheduleAppTargetDef d) {
    final e = _entry(d.id);
    final pending = _pendingFor(d.id);
    final persisted = _persistedEntry(d.id);
    final hasPending = pending != null && pending.entry != null;
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(d.icon, color: IsleColors.ocean500, size: 22),
      title: Text(d.label, style: IsleText.body()),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ScheduleAppTargetCatalog.displaySubtitle(d), style: IsleText.caption(color: IsleColors.muted)),
          if (hasPending)
            Text(
              '적용 예약 · ${SchedulePendingTargetService.formatRemaining(pending.remaining())} '
              '(${SchedulePendingTargetService.actionLabel(pending.entry!, persisted)})',
              style: IsleText.caption(color: Colors.orange.shade800),
            ),
        ],
      ),
      value: e.blockInSlot,
      onChanged: _canModifyTargets
          ? (v) => _setEntry(e.copyWith(blockInSlot: v ?? false))
          : null,
    );
  }

  Widget _bundleLimitCard(ScheduleAppBundleDef bundle) {
    final ref = _bundleRef(bundle.id);
    final enabled = ref?.limitEnabled ?? false;
    final minutes = ref?.limitMinutes ?? 30;
    final window = ref?.windowMinutes ?? 60;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(bundle.label, style: IsleText.body()),
              value: enabled,
              onChanged: _canModifyTargets
                  ? (v) => _setBundleLimit(bundle.id, enabled: v)
                  : null,
            ),
            if (enabled) ...[
              Text(
                window == 5
                    ? '5분마다 $minutes분 허용 ($minutes분 사용 → ${5 - minutes}분 차단 반복)'
                    : '${window}분마다 ${minutes}분 허용',
                style: IsleText.caption(color: window == 5 ? IsleColors.ocean700 : null),
              ),
              Slider(
                value: minutes.toDouble().clamp(1, (window == 5 ? 4 : 180).toDouble()),
                min: 1,
                max: (window == 5 ? 4 : 180).toDouble(),
                divisions: window == 5 ? 3 : 35,
                label: '${minutes}분',
                onChanged: _canModifyTargets
                    ? (v) => _setBundleLimit(bundle.id, minutes: v.round())
                    : null,
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in ScheduleAppTargetCatalog.windowPresets)
                    Tooltip(
                      message: p.hint ?? '',
                      child: ChoiceChip(
                        label: Text(p.label, style: IsleText.caption()),
                        selected: window == p.minutes,
                        onSelected: _canModifyTargets
                            ? (_) => _setBundleLimit(bundle.id, window: p.minutes)
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TargetExpansion extends StatelessWidget {
  const _TargetExpansion({
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(title, style: IsleText.subtitle()),
          subtitle: Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
          children: [child],
        ),
      ),
    );
  }
}
