import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../../../core/block_schedule/models/block_schedule.dart';
import '../../../../core/block_schedule/models/schedule_app_target_entry.dart';
import '../../../../core/block_schedule/schedule_app_target_catalog.dart';
import '../../../../core/block_schedule/schedule_app_targets_service.dart';
import '../../../../core/block_schedule/schedule_app_targets_store.dart';
import '../../../../core/block_schedule/schedule_active_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/intervention/schedule_screen_time_service.dart';
import '../../../../core/intervention/schedule_screen_time_store.dart';
import '../../../../core/intervention/screen_time_selection_summary.dart';
import '../../../../core/platform/isle_apple_platform.dart';
import '../../../../shared/widgets/screen_time_selection_preview.dart';

/// 스케줄 편집 — Isle 타깃 + iPhone Screen Time + 번들 시간 한도
class ScheduleAppTargetsSection extends StatefulWidget {
  const ScheduleAppTargetsSection({
    super.key,
    required this.schedule,
    required this.canEdit,
  });

  final BlockSchedule schedule;
  final bool canEdit;

  @override
  ScheduleAppTargetsSectionState createState() => ScheduleAppTargetsSectionState();
}

class ScheduleAppTargetsSectionState extends State<ScheduleAppTargetsSection> {
  /// Hive 로드 전에도 카탈로그 전체를 표시 (firstWhere 크래시 방지)
  List<ScheduleAppTargetEntry> _entries = ScheduleAppTargetsStore.defaultEntries();
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
    if (oldWidget.schedule.id != widget.schedule.id) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    await ScheduleAppTargetsStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    var list = ScheduleAppTargetsStore.loadForSchedule(widget.schedule.id);
    if (widget.schedule.blockIsleInApp &&
        !list.any((e) => e.targetId == 'isle_youtube' && e.blockInSlot)) {
      list = list
          .map((e) => e.targetId == 'isle_youtube' ? e.copyWith(blockInSlot: true) : e)
          .toList();
    }
    list = ScheduleAppTargetsStore.mergeWithCatalog(list);
    if (!mounted) return;
    setState(() {
      _entries = list;
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
    if (mounted) setState(() => _entries = merged);
  }

  ScheduleAppTargetEntry _entry(String targetId) {
    for (final e in _entries) {
      if (e.targetId == targetId) return e;
    }
    return ScheduleAppTargetEntry(targetId: targetId);
  }

  void _setEntry(ScheduleAppTargetEntry e) {
    setState(() {
      final i = _entries.indexWhere((x) => x.targetId == e.targetId);
      if (i >= 0) {
        _entries = [..._entries]..[i] = e;
      } else {
        _entries = [..._entries, e];
      }
    });
    if (widget.canEdit) unawaited(persist());
  }

  void _setBundleLimit(String bundleId, {bool? enabled, int? minutes, int? window}) {
    setState(() {
      _entries = _entries.map((e) {
        final d = ScheduleAppTargetCatalog.defFor(e.targetId);
        if (d?.bundleId != bundleId) return e;
        return e.copyWith(
          limitEnabled: enabled ?? e.limitEnabled,
          limitMinutes: minutes ?? e.limitMinutes,
          windowMinutes: window ?? e.windowMinutes,
        );
      }).toList();
    });
    if (widget.canEdit) unawaited(persist());
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

  Future<void> _pickIos() async {
    if (!IsleApplePlatform.isNativeBlockHost) return;
    setState(() => _iosPickBusy = true);
    final additive = ScheduleScreenTimeService.shouldUseAdditiveOnly(widget.schedule.id);
    final ok = await ScheduleScreenTimeService.pickForSchedule(
      widget.schedule.id,
      additiveOnly: additive,
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
    }
    if (widget.canEdit) unawaited(persist());
  }

  @override
  Widget build(BuildContext context) {
    final active = ScheduleActiveService.isScheduleActiveNow(widget.schedule);
    final isle = ScheduleAppTargetCatalog.isleTargets();
    final ios = ScheduleAppTargetCatalog.iosTargets();
    final hasIosSel = _iosApps > 0 || _iosCats > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '지금 적용 중',
              style: IsleText.caption(color: Colors.red.shade700),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Isle 안', style: IsleText.subtitle()),
                ...isle.map((d) => _targetTile(d)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (IsleApplePlatform.isScreenTimeHost || Platform.isAndroid)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Platform.isAndroid ? 'Android 앱' : 'iPhone 앱',
                    style: IsleText.subtitle(),
                  ),
                  if (!hasIosSel) ...[
                    const SizedBox(height: 4),
                    Text(
                      '체크 후 아래 버튼으로 앱 선택',
                      style: IsleText.caption(color: IsleColors.muted),
                    ),
                  ],
                  if (hasIosSel) ...[
                    const SizedBox(height: 8),
                    ScreenTimeSelectionPreview(
                      encoded: ScreenTimeSelectionSummary.encodedForSchedule(widget.schedule.id),
                      textFallbackLabels:
                          ScreenTimeSelectionSummary.textLabelsForSchedule(widget.schedule.id),
                      height: 36,
                    ),
                  ],
                  ...ios.map((d) => _targetTile(d)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: IsleSize.minTouchTarget,
                    child: FilledButton.icon(
                      onPressed: !widget.canEdit || _iosPickBusy ? null : _pickIos,
                      icon: _iosPickBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.apps_outage),
                      label: Text(hasIosSel ? '앱 다시 선택' : '앱 선택'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text('시간 한도', style: IsleText.subtitle()),
        const SizedBox(height: 8),
        ...ScheduleAppTargetCatalog.bundles.map(_bundleLimitCard),
      ],
    );
  }

  Widget _targetTile(ScheduleAppTargetDef d) {
    final e = _entry(d.id);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(d.icon, color: IsleColors.ocean500, size: 22),
      title: Text(d.label, style: IsleText.body()),
      subtitle: Text(d.subtitle, style: IsleText.caption(color: IsleColors.muted)),
      value: e.blockInSlot,
      onChanged: widget.canEdit
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
              onChanged: widget.canEdit
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
                onChanged: widget.canEdit
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
                        onSelected: widget.canEdit
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
