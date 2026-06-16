import '../intervention/app_usage_limit_store.dart';
import '../intervention/models/app_usage_limit_rule.dart';
import '../intervention/schedule_screen_time_store.dart';
import '../services/isle_app_log_service.dart';
import 'block_schedule_enforcement_service.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'models/schedule_app_target_entry.dart';
import 'schedule_app_limit_sync_service.dart';
import 'schedule_app_target_catalog.dart';
import 'schedule_app_targets_store.dart';

class ScheduleAppTargetsService {
  ScheduleAppTargetsService._();

  static Future<void> saveAndSync({
    required String scheduleId,
    required List<ScheduleAppTargetEntry> entries,
    BlockSchedule? schedule,
  }) async {
    await ScheduleAppTargetsStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    await ScheduleAppTargetsStore.saveForSchedule(scheduleId, entries);

    final sch = schedule ??
        BlockScheduleStore.loadAll().where((s) => s.id == scheduleId).firstOrNull;
    if (sch == null) return;

    final anyIsleBlock = entries.any((e) {
      final d = ScheduleAppTargetCatalog.defFor(e.targetId);
      return d != null && d.isIsle && e.blockInSlot;
    });
    if (sch.blockIsleInApp != anyIsleBlock) {
      await BlockScheduleStore.upsert(sch.copyWith(blockIsleInApp: anyIsleBlock));
    }

    await _syncLimitRules(scheduleId, entries, sch);
    await BlockScheduleEnforcementService.syncPlatformEnforcement();
    await ScheduleAppLimitSyncService.syncAll();
    IsleAppLogService.log('ScheduleAppTargets saved $scheduleId (${entries.where((e) => e.blockInSlot).length} block)');
  }

  static Future<void> _syncLimitRules(
    String scheduleId,
    List<ScheduleAppTargetEntry> entries,
    BlockSchedule schedule,
  ) async {
    await AppUsageLimitStore.ensureOpen();
    final all = AppUsageLimitStore.loadRules()
        .where((r) => r.scheduleId != scheduleId)
        .toList();

    final iosEncoded = ScheduleScreenTimeStore.encodedFor(scheduleId);

    for (final bundle in ScheduleAppTargetCatalog.bundles) {
      final inBundle = entries.where((e) {
        final d = ScheduleAppTargetCatalog.defFor(e.targetId);
        return d?.bundleId == bundle.id;
      }).toList();
      if (inBundle.isEmpty) continue;

      final limitOn = inBundle.any((e) => e.limitEnabled);
      if (!limitOn) continue;

      final ref = inBundle.firstWhere((e) => e.limitEnabled);
      final hasIos = inBundle.any((e) => ScheduleAppTargetCatalog.defFor(e.targetId)?.isIos == true);
      final androidPkg = _androidPackageForBundle(bundle.id);
      final isKakao = bundle.id == 'kakao_talk';

      all.add(
        AppUsageLimitRule(
          id: 'schedule_${scheduleId}_${bundle.id}',
          label: bundle.label,
          minutesPerWindow: ref.limitMinutes,
          windowMinutes: ref.windowMinutes,
          enabled: true,
          scheduleId: scheduleId,
          iosFamilyActivityEncoded: hasIos ? iosEncoded : null,
          androidPackageName: androidPkg,
          presetId: bundle.id,
          interventionTitle: isKakao ? '카카오톡 한도에 도달했어요' : '오늘 한도에 도달했어요',
          interventionBody: isKakao
              ? '쇼츠·채팅 잠깐 멈추고 Isle로 돌아와요.'
              : '잠시 쉬었다가 Isle에서 의도한 콘텐츠만 보세요.',
        ),
      );
    }

    await AppUsageLimitStore.saveRules(all);
  }

  static String? _androidPackageForBundle(String bundleId) {
    final bundle = ScheduleAppTargetCatalog.bundleFor(bundleId);
    if (bundle == null) return null;
    for (final tid in bundle.targetIds) {
      final d = ScheduleAppTargetCatalog.defFor(tid);
      if (d?.androidPackage != null) return d!.androidPackage;
    }
    return null;
  }
}
