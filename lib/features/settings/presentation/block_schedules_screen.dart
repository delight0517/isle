import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/block_schedule/block_schedule_enforcement_service.dart';
import '../../../core/block_schedule/block_schedule_store.dart';
import '../../../core/block_schedule/quick_block_service.dart';
import '../../../core/block_schedule/block_sync_export_service.dart';
import '../../../core/block_schedule/schedule_active_service.dart';
import '../../../core/block_schedule/schedule_display_helper.dart';
import '../../../core/block_schedule/schedule_app_targets_service.dart';
import '../../../core/block_schedule/schedule_app_targets_store.dart';
import '../../../core/block_schedule/schedule_lock_service.dart';
import '../../../core/block_schedule/schedule_notification_service.dart';
import '../../../core/block_schedule/volt_schedule_boundary_service.dart';
import '../../../core/block_schedule/models/block_schedule.dart';
import '../../../core/block_schedule/models/schedule_slot.dart';
import '../../../core/localization/schedule_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/schedule_overlay_navigation.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/block_schedule/schedule_edit_guard.dart';
import '../../../core/navigation/isle_routes.dart';
import '../../../core/intervention/schedule_screen_time_store.dart';
import '../../../core/intervention/schedule_screen_time_service.dart';
import '../../home/presentation/widgets/schedule_list_card.dart';
import 'widgets/pomodoro_wake_lock_targets_section.dart';
import '../../../core/platform/isle_apple_platform.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../youtube/presentation/widgets/screen_time_guide_sheet.dart';
import '../../../shared/widgets/isle_app_bar.dart';

class BlockSchedulesScreen extends ConsumerStatefulWidget {
  const BlockSchedulesScreen({super.key});

  @override
  ConsumerState<BlockSchedulesScreen> createState() =>
      _BlockSchedulesScreenState();
}

class _BlockSchedulesScreenState extends ConsumerState<BlockSchedulesScreen> {
  bool _masterOn = IsleUserDefaults.youtubeScheduleLockEnabled;
  bool _notifOn = IsleUserDefaults.scheduleBlockNotificationsEnabled;
  bool _morningNotifOn = IsleUserDefaults.morningNotificationEnabled;
  late bool _helpExpanded;

  @override
  void initState() {
    super.initState();
    // 처음 쓰는 사용자(스케줄 0개)에게는 도움말을 기본으로 펼쳐서 보여줌.
    _helpExpanded = ref
        .read(blockSchedulesProvider)
        .where((s) => s.id != QuickBlockService.presetScheduleId)
        .isEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ScheduleScreenTimeStore.ensureOpen();
      await ref.read(blockSchedulesProvider.notifier).reload();
      await BlockScheduleEnforcementService.syncPlatformEnforcement();
      await ScheduleNotificationService.rescheduleAll();
    });
  }

  Future<void> _toggleMaster(bool v) async {
    if (!v && !ScheduleEditGuard.canDisableMasterScheduleLock()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(ScheduleStrings.of(context).t('lock_master_blocked'))),
      );
      return;
    }
    await IsleUserDefaults.setYoutubeScheduleLockEnabled(v);
    setState(() => _masterOn = v);
    if (v && IsleUserDefaults.scheduleBlockNotificationsEnabled) {
      await ScheduleNotificationService.ensureInitialized();
      await ScheduleNotificationService.requestPermission();
    }
    await BlockScheduleEnforcementService.syncPlatformEnforcement();
    unawaited(ScheduleNotificationService.rescheduleAll());
  }

  Future<void> _toggleNotifications(bool v) async {
    if (v) {
      await ScheduleNotificationService.ensureInitialized();
      final ok = await ScheduleNotificationService.requestPermission();
      await IsleUserDefaults.setNotificationPermissionRequested(true);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ScheduleStrings.of(context).t('notif_permission'))),
        );
        return;
      }
    }
    await IsleUserDefaults.setScheduleBlockNotificationsEnabled(v);
    setState(() => _notifOn = v);
    await ScheduleNotificationService.rescheduleAll();
  }

  Future<void> _toggleMorningNotification(bool v) async {
    if (v) {
      await ScheduleNotificationService.ensureInitialized();
      final ok = await ScheduleNotificationService.requestPermission();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ScheduleStrings.of(context).t('notif_permission'))),
        );
        return;
      }
    }
    await IsleUserDefaults.setMorningNotificationEnabled(v);
    setState(() => _morningNotifOn = v);
    await ScheduleNotificationService.rescheduleAll();
  }

  Future<void> _pickMorningNotificationTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: IsleUserDefaults.morningNotificationHour,
        minute: IsleUserDefaults.morningNotificationMinute,
      ),
    );
    if (picked == null) return;
    await IsleUserDefaults.setMorningNotificationTime(
        picked.hour, picked.minute);
    if (!mounted) return;
    setState(() {});
    await ScheduleNotificationService.rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    final schedules = ref
        .watch(blockSchedulesProvider)
        .where((s) => s.id != QuickBlockService.presetScheduleId)
        .toList();
    final activeIds = ScheduleActiveService.activeScheduleIdsNow().toSet();
    final sch = ScheduleStrings.of(context);

    final activeSchedules =
        schedules.where((s) => activeIds.contains(s.id)).toList();
    final statusLine = schedules.isEmpty
        ? sch.t('schedule_empty_list')
        : (activeSchedules.isNotEmpty
            ? ScheduleDisplayHelper.activeNowHeadline(activeSchedules)
            : sch.t('hub_status_idle', args: {'n': '${schedules.length}'}));
    final transitionLabel =
        _masterOn ? VoltScheduleBoundaryService.nextTransitionLabel() : null;

    return Scaffold(
      appBar: IsleAppBar(
        title: sch.t('hub_title'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: '캘린더로 보기',
            onPressed: () => context.push(IsleRoutes.scheduleCalendar),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 상태 요약 한 줄 + "?" — 예전 4단 설명 텍스트를 여기 하나로 병합.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(statusLine, style: IsleText.subtitle()),
              ),
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: '도움말',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _helpExpanded = !_helpExpanded),
              ),
            ],
          ),
          if (transitionLabel != null)
            Text(transitionLabel,
                style: IsleText.caption(color: IsleColors.ocean700)),
          if (_helpExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                sch.t('hub_help_body'),
                style: IsleText.caption(color: IsleColors.muted)
                    .copyWith(height: 1.4),
              ),
            ),
          const SizedBox(height: 16),
          ...schedules.map((s) {
            final active = activeIds.contains(s.id);
            return ScheduleListCard(
              schedule: s,
              active: active,
              onTap: () => _pushScheduleEdit(s.id),
              onEditApps: () async {
                await ScheduleScreenTimeService.pickForSchedule(
                  s.id,
                  additiveOnly:
                      ScheduleScreenTimeService.shouldUseAdditiveOnly(s.id),
                );
                if (context.mounted) setState(() {});
              },
              trailing: Switch(
                value: s.enabled,
                onChanged: (v) => _toggleScheduleEnabled(s, v),
              ),
            );
          }),
          const PomodoroWakeLockTargetsSection(),
          const SizedBox(height: 12),
          if (schedules.isNotEmpty) const SizedBox(height: 12),
          _easyPresetBar(
            label: '빠르게 추가',
            presets: const [
              _Preset('Isle 유튜브 (오전)', 0, 0, 9 * 60, isleYoutube: true),
              _Preset('집중 1시간', 9, 0, 60),
              _Preset('집중 1시간 15분', 14, 0, 75),
              _Preset('집중 1시간 30분', 20, 0, 90),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () async {
              final s = await ref
                  .read(blockSchedulesProvider.notifier)
                  .createDefault('새 스케줄');
              if (context.mounted) _pushScheduleEdit(s.id);
            },
            icon: const Icon(Icons.add),
            label: Text(sch.t('add_schedule')),
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Text(sch.t('schedule_settings'), style: IsleText.body()),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(sch.t('master_on')),
                  subtitle: Text(sch.t('master_off_sub')),
                  value: _masterOn,
                  onChanged: _toggleMaster,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(sch.t('notif_title')),
                  subtitle: Text(
                    _masterOn ? sch.t('notif_on') : sch.t('notif_need_master'),
                  ),
                  value: _notifOn && _masterOn,
                  onChanged: _masterOn ? _toggleNotifications : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('아침 알림'),
                  subtitle: Text(
                    _notifOn && _masterOn
                        ? '매일 ${IsleUserDefaults.morningNotificationHour.toString().padLeft(2, '0')}:'
                            '${IsleUserDefaults.morningNotificationMinute.toString().padLeft(2, '0')}에 '
                            '오늘 뭐가 막히는지 알려줘요'
                        : '전체 알림이 꺼져 있어요',
                  ),
                  value: _morningNotifOn && _notifOn && _masterOn,
                  onChanged: (_notifOn && _masterOn)
                      ? _toggleMorningNotification
                      : null,
                ),
                if (_morningNotifOn && _notifOn && _masterOn)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _pickMorningNotificationTime,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.schedule, size: 16),
                        label: const Text('시각 변경'),
                      ),
                    ),
                  ),
                if (IsleApplePlatform.isScreenTimeHost)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: OutlinedButton.icon(
                      onPressed: () => showScreenTimeGuideSheet(context),
                      icon: Icon(Platform.isMacOS
                          ? Icons.laptop_mac
                          : Icons.phonelink_lock),
                      label: Text(
                        Platform.isMacOS
                            ? 'Safari·Chrome YouTube (Screen Time)'
                            : 'Safari·다른 앱 YouTube (Screen Time 안내)',
                      ),
                    ),
                  ),
                if (Platform.isAndroid)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: OutlinedButton.icon(
                      onPressed: () => showScreenTimeGuideSheet(context),
                      icon: const Icon(Icons.android),
                      label: const Text('Chrome·앱 차단 (Android 접근성/VPN)'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Text('Mac · iPhone 동기화', style: IsleText.body()),
              children: [
                OutlinedButton.icon(
                  onPressed: () => BlockSyncExportService.shareSyncJson(),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('JSON 동기화 파일 보내기'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => BlockSyncExportService.shareMacHostsFile(),
                  icon: const Icon(Icons.computer),
                  label: const Text('Mac hosts 파일 보내기 (/etc/hosts)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _importSyncDialog(context),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('동기화 JSON 붙여넣기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importSyncDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('동기화 JSON'),
        content: TextField(
            controller: ctrl,
            maxLines: 8,
            decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('가져오기')),
        ],
      ),
    );
    if (ok != true) {
      ctrl.dispose();
      return;
    }
    final n = await BlockSyncExportService.importSyncPayload(ctrl.text);
    await ref.read(blockSchedulesProvider.notifier).reload();
    await BlockScheduleEnforcementService.syncPlatformEnforcement();
    unawaited(ScheduleNotificationService.rescheduleAll());
    ctrl.dispose();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          n > 0 ? '가져옴 · $n개 스케줄 (잠금 중인 스케줄은 설정·시간표 보호)' : '가져올 스케줄이 없어요',
        ),
      ),
    );
  }

  Widget _easyPresetBar({
    required String label,
    required List<_Preset> presets,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: IsleText.caption(color: IsleColors.muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in presets)
              ActionChip(
                label: Text(p.label),
                onPressed: () => _createPreset(p),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _createPreset(_Preset p) async {
    final start = p.startHour * 60 + p.startMinute;
    final end = (start + p.durationMinutes) % (24 * 60);
    final slots = <ScheduleSlot>[
      for (var d = 0; d < 7; d++)
        ScheduleSlot(day: d, startMinute: start, endMinute: end),
    ];
    final schedule =
        await BlockScheduleStore.create(name: p.label, slots: slots);
    if (p.isleYoutube) {
      await ScheduleAppTargetsStore.ensureOpen();
      final entries = ScheduleAppTargetsStore.loadForSchedule(schedule.id)
          .map((e) =>
              e.targetId == 'isle_youtube' ? e.copyWith(blockInSlot: true) : e)
          .toList();
      await ScheduleAppTargetsService.saveAndSync(
        scheduleId: schedule.id,
        entries: entries,
        schedule: schedule,
      );
    }
    await ref.read(blockSchedulesProvider.notifier).reload();
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    unawaited(ScheduleNotificationService.rescheduleAll());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${p.label} 스케줄이 생성됐어요. ②에서 막을 앱을 고르세요.')),
    );
    _pushScheduleEdit(schedule.id);
  }

  /// `/block/schedules` vs `/settings/block-schedules` 부모에 맞는 편집 경로
  void _pushScheduleEdit(String scheduleId) {
    pushScheduleEditFromList(context, scheduleId);
  }

  Future<void> _toggleScheduleEnabled(
      BlockSchedule schedule, bool enabled) async {
    if (!enabled &&
        schedule.locked &&
        ScheduleLockService.isEffectivelyLocked(schedule)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('잠금이 켜진 스케줄은 잠금 해제 후 끌 수 있어요')),
      );
      return;
    }
    await BlockScheduleStore.upsert(schedule.copyWith(enabled: enabled));
    await ref.read(blockSchedulesProvider.notifier).reload();
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    unawaited(ScheduleNotificationService.rescheduleAll());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(enabled ? '스케줄 켜짐' : '스케줄 꺼짐')),
    );
  }
}

class _Preset {
  const _Preset(
    this.label,
    this.startHour,
    this.startMinute,
    this.durationMinutes, {
    this.isleYoutube = false,
  });
  final String label;
  final int startHour;
  final int startMinute;
  final int durationMinutes;
  final bool isleYoutube;
}
