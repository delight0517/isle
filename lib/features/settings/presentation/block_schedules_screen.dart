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
import '../../../core/block_schedule/schedule_lock_service.dart';
import '../../../core/block_schedule/schedule_notification_service.dart';
import '../../../core/block_schedule/volt_schedule_boundary_service.dart';
import '../../../core/block_schedule/models/block_schedule.dart';
import '../../../core/block_schedule/models/schedule_slot.dart';
import '../../../core/localization/schedule_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/isle_routes.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/block_schedule/schedule_edit_guard.dart';
import '../../../core/intervention/schedule_screen_time_store.dart';
import '../../../core/intervention/schedule_screen_time_service.dart';
import '../../home/presentation/widgets/schedule_list_card.dart';
import '../../../core/platform/isle_apple_platform.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../youtube/presentation/widgets/screen_time_guide_sheet.dart';
import '../../../shared/widgets/isle_app_bar.dart';

class BlockSchedulesScreen extends ConsumerStatefulWidget {
  const BlockSchedulesScreen({super.key});

  @override
  ConsumerState<BlockSchedulesScreen> createState() => _BlockSchedulesScreenState();
}

class _BlockSchedulesScreenState extends ConsumerState<BlockSchedulesScreen> {
  bool _masterOn = IsleUserDefaults.youtubeScheduleLockEnabled;
  bool _notifOn = IsleUserDefaults.scheduleBlockNotificationsEnabled;

  @override
  void initState() {
    super.initState();
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
        SnackBar(content: Text(ScheduleStrings.of(context).t('lock_master_blocked'))),
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
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ScheduleStrings.of(context).t('notif_permission'))),
        );
        return;
      }
    }
    await IsleUserDefaults.setScheduleBlockNotificationsEnabled(v);
    setState(() => _notifOn = v);
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

    return Scaffold(
      appBar: IsleAppBar(title: sch.t('hub_title')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            sch.t('hub_intro'),
            style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            sch.t('hub_lock_note'),
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 10),
          Card(
            color: IsleColors.ocean100.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                sch.t('hub_important'),
                style: IsleText.caption(color: IsleColors.ocean700).copyWith(height: 1.4),
              ),
            ),
          ),
          if (_masterOn) ...[
            const SizedBox(height: 4),
            Builder(
              builder: (_) {
                final label = VoltScheduleBoundaryService.nextTransitionLabel();
                if (label == null) return const SizedBox.shrink();
                return Text(label, style: IsleText.caption(color: IsleColors.ocean700));
              },
            ),
            Text(
              sch.t('volt_resume'),
              style: IsleText.caption(color: IsleColors.muted),
            ),
          ],
          const SizedBox(height: 12),
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
          if (IsleApplePlatform.isScreenTimeHost) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => showScreenTimeGuideSheet(context),
              icon: Icon(Platform.isMacOS ? Icons.laptop_mac : Icons.phonelink_lock),
              label: Text(
                Platform.isMacOS
                    ? 'Safari·Chrome YouTube (Screen Time)'
                    : 'Safari·다른 앱 YouTube (Screen Time 안내)',
              ),
            ),
          ],
          if (Platform.isAndroid) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => showScreenTimeGuideSheet(context),
              icon: const Icon(Icons.android),
              label: const Text('Chrome·앱 차단 (Android 접근성/VPN)'),
            ),
          ],
          const Divider(height: 28),
          Text(sch.t('schedule_list'), style: IsleText.subtitle()),
          const SizedBox(height: 8),
          _easyPresetBar(
            label: '빠르게 추가',
            presets: const [
              _Preset('집중 1시간', 9, 0, 60),
              _Preset('집중 1시간 15분', 14, 0, 75),
              _Preset('집중 1시간 30분', 20, 0, 90),
            ],
          ),
          if (schedules.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(sch.t('schedule_empty_list'), style: IsleText.caption(color: IsleColors.muted)),
            ),
          ...schedules.map((s) {
            final active = activeIds.contains(s.id);
            return ScheduleListCard(
              schedule: s,
              active: active,
              onTap: () => context.push(IsleRoutes.blockScheduleEdit(s.id)),
              onEditApps: () async {
                await ScheduleScreenTimeService.pickForSchedule(
                  s.id,
                  additiveOnly: ScheduleScreenTimeService.shouldUseAdditiveOnly(s.id),
                );
                if (context.mounted) setState(() {});
              },
              trailing: Switch(
                value: s.enabled,
                onChanged: (v) => _toggleScheduleEnabled(s, v),
              ),
            );
          }),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final s = await ref.read(blockSchedulesProvider.notifier).createDefault('새 스케줄');
              if (context.mounted) context.push(IsleRoutes.blockScheduleEdit(s.id));
            },
            icon: const Icon(Icons.add),
            label: Text(sch.t('add_schedule')),
          ),
          const Divider(height: 32),
          Text('Mac · iPhone 동기화', style: IsleText.subtitle()),
          const SizedBox(height: 8),
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
    );
  }

  Future<void> _importSyncDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('동기화 JSON'),
        content: TextField(controller: ctrl, maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('가져오기')),
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
          n > 0
              ? '가져옴 · $n개 스케줄 (잠금 중인 스케줄은 설정·시간표 보호)'
              : '가져올 스케줄이 없어요',
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
      for (var d = 0; d < 7; d++) ScheduleSlot(day: d, startMinute: start, endMinute: end),
    ];
    final schedule = await BlockScheduleStore.create(name: p.label, slots: slots);
    await ref.read(blockSchedulesProvider.notifier).reload();
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    unawaited(ScheduleNotificationService.rescheduleAll());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${p.label} 스케줄이 생성됐어요. ②에서 막을 앱을 고르세요.')),
    );
    context.push(IsleRoutes.blockScheduleEdit(schedule.id));
  }

  Future<void> _toggleScheduleEnabled(BlockSchedule schedule, bool enabled) async {
    if (!enabled && schedule.locked && ScheduleLockService.isEffectivelyLocked(schedule)) {
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
  const _Preset(this.label, this.startHour, this.startMinute, this.durationMinutes);
  final String label;
  final int startHour;
  final int startMinute;
  final int durationMinutes;
}
