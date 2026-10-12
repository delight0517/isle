import '../services/isle_app_log_service.dart';
import '../youtube/youtube_timelock_service.dart';
import 'block_schedule_enforcement_service.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'quick_block_service.dart';
import 'schedule_app_target_catalog.dart';
import 'schedule_app_targets_store.dart';
import 'schedule_block_relax_service.dart';
import 'schedule_target_access_guard.dart';

/// 스케줄·타깃 중복 — 「하나만 꺼도 여전히 막힘」 방지
enum BlockRelaxScope { youtube, safari, instagram, all }

class ScheduleBlockReconcileResult {
  const ScheduleBlockReconcileResult({
    required this.relaxedNow,
    required this.waitingTimelock,
    required this.stillBlocking,
    required this.scope,
  });

  final List<String> relaxedNow;
  final List<String> waitingTimelock;
  final List<String> stillBlocking;
  final BlockRelaxScope scope;

  bool get fullyRelaxed => stillBlocking.isEmpty;
  int get totalTouched => relaxedNow.length + waitingTimelock.length;
}

class ScheduleBlockReconcileService {
  ScheduleBlockReconcileService._();

  static BlockRelaxScope scopeFromQuery(String raw) {
    final q = raw.toLowerCase().trim();
    if (q.contains('safari') || q.contains('사파리')) return BlockRelaxScope.safari;
    if (q.contains('insta') || q.contains('인스타')) return BlockRelaxScope.instagram;
    if (q.contains('유튜브') ||
        q.contains('youtube') ||
        q.contains('뮤직') ||
        q.contains('music') ||
        q.contains('ytm')) {
      return BlockRelaxScope.youtube;
    }
    if (q.isEmpty) return BlockRelaxScope.all;
    return BlockRelaxScope.all;
  }

  static BlockRelaxScope scopeFromTarget(String? target) {
    switch (target?.toLowerCase()) {
      case 'safari':
        return BlockRelaxScope.safari;
      case 'instagram':
      case 'insta':
        return BlockRelaxScope.instagram;
      case 'youtube':
      case 'yt':
        return BlockRelaxScope.youtube;
      case 'all':
        return BlockRelaxScope.all;
      default:
        return BlockRelaxScope.youtube;
    }
  }

  /// enabled 스케줄 중 scope에 실제로 기여하는 것만
  static List<BlockSchedule> schedulesAffectingScope(BlockRelaxScope scope) {
    return BlockScheduleStore.loadAll().where((s) {
      if (s.id == QuickBlockService.presetScheduleId) return false;
      if (!s.enabled) return false;
      return _scheduleAffectsScope(s, scope);
    }).toList();
  }

  static bool _scheduleAffectsScope(BlockSchedule s, BlockRelaxScope scope) {
    final entries = ScheduleAppTargetsStore.loadForSchedule(s.id);
    switch (scope) {
      case BlockRelaxScope.youtube:
        if (s.domains.any(_isYoutubeHost)) return true;
        if (entries.any(
          (e) =>
              (e.targetId == 'isle_youtube' ||
                  e.targetId == 'ios_youtube' ||
                  e.targetId == 'ios_youtube_music') &&
              (e.blockInSlot || e.limitEnabled),
        )) {
          return true;
        }
        if (s.blockIsleInApp &&
            (s.name.toLowerCase().contains('유튜브') ||
                s.name.toLowerCase().contains('아침') ||
                s.name.toLowerCase().contains('youtube') ||
                entries.any((e) => e.targetId == 'isle_youtube' && e.blockInSlot))) {
          return true;
        }
        return false;
      case BlockRelaxScope.safari:
        if (s.blockIsleInApp) return true;
        if (s.domains.isNotEmpty && !s.domains.every(_isYoutubeHost)) return true;
        final isleIds = ScheduleAppTargetCatalog.isleTargets().map((t) => t.id);
        if (s.blockIsleInApp &&
            isleIds.every(
              (id) => entries.any((e) => e.targetId == id && e.blockInSlot),
            )) {
          return true;
        }
        return s.name.toLowerCase().contains('safari');
      case BlockRelaxScope.instagram:
        return entries.any(
          (e) =>
              (e.targetId == 'isle_instagram' ||
                  e.targetId == 'isle_instagram_dm' ||
                  e.targetId == 'ios_instagram') &&
              (e.blockInSlot || e.limitEnabled),
        );
      case BlockRelaxScope.all:
        return _scheduleAffectsScope(s, BlockRelaxScope.youtube) ||
            _scheduleAffectsScope(s, BlockRelaxScope.safari) ||
            _scheduleAffectsScope(s, BlockRelaxScope.instagram) ||
            s.domains.isNotEmpty ||
            entries.any((e) => e.blockInSlot || e.limitEnabled);
    }
  }

  static ScheduleBlockRelaxAction actionForScope(BlockRelaxScope scope) {
    return switch (scope) {
      BlockRelaxScope.youtube => ScheduleBlockRelaxAction.youtubeOff,
      BlockRelaxScope.safari => ScheduleBlockRelaxAction.isleInAppOff,
      BlockRelaxScope.instagram => ScheduleBlockRelaxAction.instagramOff,
      BlockRelaxScope.all => ScheduleBlockRelaxAction.scheduleOff,
    };
  }

  /// scope에 걸린 **모든** 스케줄을 순회해 완화 — 하나만 끄고 끝나지 않음
  static Future<ScheduleBlockReconcileResult> relaxAllForScope(
    BlockRelaxScope scope,
  ) async {
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();

    final relaxedNow = <String>[];
    final waitingTimelock = <String>[];

    if (scope == BlockRelaxScope.youtube || scope == BlockRelaxScope.all) {
      if (YoutubeTimelockService.isActive) {
        final result = await YoutubeTimelockService.requestDisable();
        if (result.kind == YoutubeTimelockDisableRequestKind.disabledNow ||
            result.kind == YoutubeTimelockDisableRequestKind.alreadyOff) {
          relaxedNow.add(YoutubeTimelockService.timelockScheduleName);
        } else {
          waitingTimelock.add(YoutubeTimelockService.timelockScheduleName);
        }
      }
    }

    final targets = schedulesAffectingScope(scope);
    final action = actionForScope(scope);

    for (final schedule in targets) {
      // 안전 라인 스케줄도 여기서 걸러내지 않고 그대로 순회한다 — locked:true라서
      // relaxScheduleWithLocks 안에서 자동으로 15분 타임락 대기열로 들어간다
      // (2026-07-20 사용자 확정 — 채팅 요청은 가능하되 즉시 적용은 없음).
      // 한 스케줄 완화 실패가 나머지 완화를 중단시키고, 아래 syncPlatformEnforcement
      // 까지 건너뛰어 "스토어는 풀렸는데 플랫폼은 아직 막힌" 부분해제 불일치를
      // 남기던 문제 방지. 항목별로 격리하고, 아래 sync 는 항상 실행한다.
      try {
        var outcome = await ScheduleBlockRelaxService.relaxScheduleWithLocks(
          schedule,
          action,
        );
        if (outcome.applied) {
          relaxedNow.add(schedule.name);
        } else if (outcome.startedCountdown || outcome.needsCountdown) {
          waitingTimelock.add(schedule.name);
        }
        if (scope == BlockRelaxScope.safari && schedule.domains.isNotEmpty) {
          final refreshed = BlockScheduleStore.loadAll().firstWhere((s) => s.id == schedule.id);
          outcome = await ScheduleBlockRelaxService.relaxScheduleWithLocks(
            refreshed,
            ScheduleBlockRelaxAction.domainsOff,
          );
          if (outcome.applied && !relaxedNow.contains(schedule.name)) {
            relaxedNow.add('${schedule.name} (도메인)');
          }
        }
      } catch (e, st) {
        IsleAppLogService.log(
          'relaxAllForScope: "${schedule.name}" 완화 실패, 나머지 계속: $e',
          level: IsleLogLevel.warn,
          stack: st,
        );
      }
    }

    // 루프 중 예외가 나도 반드시 실행 — 완화된 스토어 상태를 플랫폼에 반영해
    // 스토어=플랫폼 일관성을 항상 보장한다.
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);

    final stillBlocking = auditRemaining(scope);

    return ScheduleBlockReconcileResult(
      relaxedNow: relaxedNow,
      waitingTimelock: waitingTimelock,
      stillBlocking: stillBlocking,
      scope: scope,
    );
  }

  /// 완화 후에도 막히는 레이어 (스케줄 외 한도·OS 등)
  static List<String> auditRemaining(BlockRelaxScope scope) {
    final out = <String>[];
    if (scope == BlockRelaxScope.youtube || scope == BlockRelaxScope.all) {
      if (ScheduleTargetAccessGuard.isIsleYoutubeBlocked) {
        final names = schedulesAffectingScope(BlockRelaxScope.youtube)
            .map((s) => s.name)
            .toList();
        if (names.isEmpty) {
          out.add('Isle 유튜브 — 활성 스케줄 타깃 (이름 확인 필요)');
        } else {
          out.add('Isle 유튜브 — ${names.join(' · ')}');
        }
      }
      if (YoutubeTimelockService.isActive) {
        out.add('YouTube 타임락 (24h)');
      }
    }
    if (scope == BlockRelaxScope.safari || scope == BlockRelaxScope.all) {
      if (ScheduleTargetAccessGuard.isIsleCustomWebBlocked) {
        out.add('Isle Safari — 아침·웹 일괄 차단 스케줄');
      }
    }
    if (scope == BlockRelaxScope.instagram || scope == BlockRelaxScope.all) {
      if (ScheduleTargetAccessGuard.isIsleInstagramBlocked) {
        out.add('Instagram — 활성 스케줄 타깃');
      }
    }
    return out;
  }

  static bool _isYoutubeHost(String d) {
    final h = d.toLowerCase();
    return h.contains('youtube') || h.contains('youtu.be') || h.contains('googlevideo');
  }

  /// remove_schedule — 이름뿐 아니라 **실제 차단 기여**로 매칭
  static List<BlockSchedule> schedulesForRemoveQuery(String query) {
    final scope = scopeFromQuery(query);
    final byScope = schedulesAffectingScope(scope);
    if (byScope.isNotEmpty) return byScope;

    final q = query.toLowerCase().trim();
    if (q.isEmpty) {
      return BlockScheduleStore.loadAll()
          .where((s) => s.enabled && s.id != QuickBlockService.presetScheduleId)
          .toList();
    }
    return BlockScheduleStore.loadAll()
        .where((s) => s.enabled && s.name.toLowerCase().contains(q))
        .toList();
  }
}
