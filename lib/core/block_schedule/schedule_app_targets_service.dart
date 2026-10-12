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
import 'schedule_app_targets_guard.dart';
import 'schedule_app_targets_store.dart';

class ScheduleAppTargetsService {
  ScheduleAppTargetsService._();

  /// Preserve legacy whole-schedule selections while introducing independent
  /// Screen Time selections for each iPhone app bundle.
  static Future<void> migrateLegacyScreenTimeSelectionsIfNeeded() async {
    await ScheduleScreenTimeStore.ensureOpen();
    await BlockScheduleStore.ensureOpen();
    if (ScheduleScreenTimeStore.migratedToPerBundle) return;
    var migrated = false;
    try {
      final bundleIds = ScheduleAppTargetCatalog.iosTargets()
          .map((target) => target.bundleId)
          .toSet();
      for (final schedule in BlockScheduleStore.loadAll()) {
        final legacy = ScheduleScreenTimeStore.encodedFor(schedule.id);
        if (legacy == null || legacy.isEmpty) continue;
        for (final bundleId in bundleIds) {
          if (ScheduleScreenTimeStore.encodedFor(schedule.id,
                  bundleId: bundleId) !=
              null) {
            continue;
          }
          await ScheduleScreenTimeStore.savePick(
            scheduleId: schedule.id,
            bundleId: bundleId,
            encoded: legacy,
            applicationCount: ScheduleScreenTimeStore.appCountFor(schedule.id),
            categoryCount:
                ScheduleScreenTimeStore.categoryCountFor(schedule.id),
          );
        }
      }
      migrated = true;
    } catch (e) {
      IsleAppLogService.log('ScreenTime per-bundle migration failed: $e',
          level: IsleLogLevel.warn);
    }
    if (migrated) {
      await ScheduleScreenTimeStore.markMigratedToPerBundle();
    }
  }

  static Future<void> saveAndSync({
    required String scheduleId,
    required List<ScheduleAppTargetEntry> entries,
    BlockSchedule? schedule,
  }) async {
    await ScheduleAppTargetsStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();

    final sch = schedule ??
        BlockScheduleStore.loadAll()
            .where((s) => s.id == scheduleId)
            .firstOrNull;
    // 잠긴 스케줄은 스케줄 레벨(enforcementMode 등)과 똑같이 앱별 타깃 항목
    // (완전 차단↔리필 전환, 한도값)도 우회 방지 대상이다 — 안 그러면 스케줄
    // 레벨만 락으로 되돌아가고 타깃 항목만 바뀐 모순 상태가 남는다
    // (Cage에서 먼저 발견·수정, 2026-07-11 이식).
    final sanitizedEntries =
        (sch == null || !ScheduleAppTargetsStore.hasSavedEntries(scheduleId))
            ? entries
            : ScheduleAppTargetsGuard.sanitizeEntries(
                schedule: sch,
                existing: ScheduleAppTargetsStore.loadForSchedule(scheduleId),
                incoming: entries,
              );
    await ScheduleAppTargetsStore.saveForSchedule(scheduleId, sanitizedEntries);
    if (sch == null) return;

    final anyIsleBlock = sanitizedEntries.any((e) {
      final d = ScheduleAppTargetCatalog.defFor(e.targetId);
      return d != null && d.isIsle && e.blockInSlot;
    });
    if (sch.blockIsleInApp != anyIsleBlock) {
      await BlockScheduleStore.upsert(
          sch.copyWith(blockIsleInApp: anyIsleBlock));
    }

    await _syncLimitRules(scheduleId, sanitizedEntries, sch);
    await BlockScheduleEnforcementService.syncPlatformEnforcement();
    await ScheduleAppLimitSyncService.syncAll();
    IsleAppLogService.log(
        'ScheduleAppTargets saved $scheduleId (${sanitizedEntries.where((e) => e.blockInSlot).length} block)');
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

    for (final bundle in ScheduleAppTargetCatalog.bundles) {
      final inBundle = entries.where((e) {
        final d = ScheduleAppTargetCatalog.defFor(e.targetId);
        return d?.bundleId == bundle.id;
      }).toList();
      if (inBundle.isEmpty) continue;

      final limitOn = inBundle.any((e) => e.limitEnabled);
      if (!limitOn) continue;

      final ref = inBundle.firstWhere((e) => e.limitEnabled);
      final hasIos = inBundle.any(
          (e) => ScheduleAppTargetCatalog.defFor(e.targetId)?.isIos == true);
      final iosEncoded = ScheduleScreenTimeStore.encodedFor(
        scheduleId,
        bundleId: bundle.id,
      );
      final androidPkg = _androidPackageForBundle(bundle.id);
      final isKakao = bundle.id == 'kakao_talk';
      final isYtMusic = bundle.id == 'youtube_music';

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
          interventionTitle: isYtMusic
              ? 'YouTube Music 화면 한도'
              : isKakao
                  ? '카카오톡 한도에 도달했어요'
                  : '오늘 한도에 도달했어요',
          interventionBody: isYtMusic
              ? '앱 화면 ${ref.limitMinutes}분/${ref.windowMinutes >= 60 ? "${ref.windowMinutes ~/ 60}시간" : "${ref.windowMinutes}분"} 도달. '
                  '잠금 화면·백그라운드 음악은 iOS가 한도 밖으로 셉니다.'
              : isKakao
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
