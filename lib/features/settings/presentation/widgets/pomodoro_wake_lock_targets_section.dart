import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../../../core/block_schedule/block_schedule_store.dart';
import '../../../../core/block_schedule/pomodoro_wake_lock_sync.dart';
import '../../../../core/block_schedule/schedule_active_service.dart';
import '../../../../core/intervention/schedule_screen_time_service.dart';
import '../../../../core/intervention/schedule_screen_time_store.dart';
import '../../../../core/localization/schedule_strings.dart';
import '../../../../core/platform/isle_apple_platform.dart';
import '../../../../core/services/isle_user_defaults.dart';

class PomodoroWakeLockTargetsSection extends StatefulWidget {
  const PomodoroWakeLockTargetsSection({super.key});

  @override
  State<PomodoroWakeLockTargetsSection> createState() =>
      _PomodoroWakeLockTargetsSectionState();
}

class _PomodoroWakeLockTargetsSectionState
    extends State<PomodoroWakeLockTargetsSection> {
  late Set<String> _selected =
      IsleUserDefaults.pomodoroWakeLockTargetIds.toSet();
  bool _busy = false;
  int _externalApps = 0;
  int _externalCategories = 0;

  @override
  void initState() {
    super.initState();
    _loadExternalCounts();
  }

  Future<void> _loadExternalCounts() async {
    await ScheduleScreenTimeStore.ensureOpen();
    if (!mounted) return;
    setState(() {
      _externalApps =
          ScheduleScreenTimeStore.appCountFor(PomodoroWakeLockSync.scheduleId);
      _externalCategories = ScheduleScreenTimeStore.categoryCountFor(
        PomodoroWakeLockSync.scheduleId,
      );
    });
  }

  Future<void> _setTarget(String id, bool enabled) async {
    final next = {..._selected};
    if (enabled) {
      next.add(id);
    } else {
      next.remove(id);
    }
    setState(() {
      _busy = true;
      _selected = next;
    });
    await PomodoroWakeLockSync.setBlockedTargets(next);
    if (mounted) setState(() => _busy = false);
  }

  bool get _wakeLockActive => BlockScheduleStore.loadAll().any(
        (schedule) =>
            schedule.id == PomodoroWakeLockSync.scheduleId &&
            ScheduleActiveService.isScheduleActiveNow(schedule),
      );

  Future<void> _pickExternalApps(ScheduleStrings strings) async {
    setState(() => _busy = true);
    final ok = await ScheduleScreenTimeService.pickForSchedule(
      PomodoroWakeLockSync.scheduleId,
      additiveOnly: _wakeLockActive,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    await _loadExternalCounts();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.t('wake_apps_pick_cancelled'))),
      );
    } else if (_wakeLockActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.t('wake_apps_additive_only'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ScheduleStrings.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: const Icon(Icons.wb_twilight_outlined),
        title: Text(strings.t('wake_targets_title')),
        subtitle: Text(strings.t('wake_targets_subtitle')),
        children: [
          Text(
            strings.t('wake_targets_hint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _targetSwitch(strings, 'isle_instagram', 'wake_target_instagram'),
          _targetSwitch(strings, 'isle_instagram_dm', 'wake_target_dm'),
          _targetSwitch(strings, 'isle_youtube', 'wake_target_youtube'),
          _targetSwitch(strings, 'isle_brunch', 'wake_target_brunch'),
          _targetSwitch(strings, 'isle_customweb', 'wake_target_browser'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.qr_code_scanner),
            title: Text(strings.t('wake_qr_allowed')),
            trailing: const Icon(Icons.check_circle, color: Colors.green),
            dense: true,
          ),
          if (Platform.isIOS && IsleApplePlatform.isScreenTimeHost) ...[
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _externalApps + _externalCategories == 0
                    ? strings.t('wake_external_apps_empty')
                    : strings.t('wake_external_apps_summary', args: {
                        'apps': '$_externalApps',
                        'categories': '$_externalCategories',
                      }),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.t('wake_external_apps_hint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_wakeLockActive)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  strings.t('wake_apps_additive_only'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _pickExternalApps(strings),
                icon: const Icon(Icons.phone_iphone),
                label: Text(strings.t('wake_external_apps_button')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _targetSwitch(ScheduleStrings strings, String id, String labelKey) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(strings.t(labelKey)),
        value: _selected.contains(id),
        onChanged: _busy ? null : (value) => _setTarget(id, value),
      );
}
