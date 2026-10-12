import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../block/premade_block_pack_service.dart';
import '../../block/rule_pending_removal_service.dart';
import '../../block/rule_removal_lock.dart';
import 'block_audit_log_store.dart';
import '../suggestion/block_suggestion_engine.dart';
import '../../block_schedule/block_schedule_enforcement_service.dart';
import '../../block_schedule/app_open_block_trigger_service.dart';
import '../../block_schedule/block_schedule_store.dart';
import '../../block_schedule/isle_youtube_schedule_service.dart';
import '../../block_schedule/models/block_schedule.dart';
import '../../block_schedule/models/schedule_app_target_entry.dart';
import '../../block_schedule/models/schedule_enforcement_mode.dart';
import '../../block_schedule/models/schedule_slot.dart';
import '../../block_schedule/schedule_app_limit_sync_service.dart';
import '../../block_schedule/schedule_app_target_catalog.dart';
import '../../block_schedule/schedule_app_targets_service.dart';
import '../../block_schedule/quick_block_service.dart';
import '../../block_schedule/schedule_active_service.dart';
import '../../block_schedule/schedule_app_targets_store.dart';
import '../../block_schedule/schedule_block_reconcile_service.dart';
import '../../block_schedule/schedule_display_helper.dart';
import '../../block_schedule/schedule_lock_phase.dart';
import '../../block_schedule/schedule_lock_service.dart';
import '../../block_schedule/schedule_notification_service.dart';
import '../../block_schedule/safety_baseline_service.dart';
import '../../block_schedule/schedule_pending_target_service.dart';
import '../../block_schedule/schedule_app_targets_guard.dart';
import '../../block_schedule/schedule_edit_guard.dart';
import '../../intervention/always_on_url_pattern_store.dart';
import '../../intervention/app_intervention_service.dart';
import '../../intervention/app_usage_limit_store.dart';
import '../../intervention/external_app_shield_store.dart';
import '../../intervention/schedule_screen_time_service.dart';
import '../../intervention/schedule_screen_time_store.dart';
import '../../platform/isle_apple_platform.dart';
import '../../intervention/models/app_usage_limit_rule.dart';
import '../../focus/kakao_shorts_preset_service.dart';
import '../../intervention/safari_pause_service.dart';
import '../../intervention/website_block_store.dart';
import '../../library/platform_watch_limit_store.dart';
import '../../navigation/isle_routes.dart';
import '../../platform/ios_rules_export_service.dart';
import '../../services/isle_keychain_survival_store.dart';
import '../../services/isle_user_defaults.dart';
import '../../usage_budget/usage_budget_engine.dart';
import '../../usage_budget/usage_budget_models.dart';
import '../../usage_budget/usage_budget_pending_policy_service.dart';
import '../../usage_budget/usage_budget_store.dart';
import '../../youtube/blocked_channel_store.dart';
import '../../youtube/blocked_url_store.dart';
import '../../youtube/channel_genre_ai_service.dart';
import '../../youtube/content_filter_store.dart';
import '../../youtube/models/blocked_channel.dart';
import '../../youtube/youtube_block_rules_sync.dart';
import '../../youtube/youtube_usage_lock.dart';
import '../../youtube/youtube_watch_timer_store.dart';
import '../../youtube/youtube_weekly_usage_store.dart';
import '../../library/usage_day.dart';
import 'block_chat_coach_service.dart';
import 'block_chat_models.dart';
import 'block_chat_permission_auditor.dart';
import 'block_chat_persona_scenarios.dart';
import 'block_chat_ration_tag.dart';
import 'block_chat_schedule_dedup.dart';
import 'block_chat_schedule_resolver.dart';

/// 차단 계획 → 실제 저장·동기화
class BlockChatExecutor {
  BlockChatExecutor._();

  /// 앱 재방문(resume) 시 호출 — "모든 차단 초기화"가 삭제 대기 잠금에 걸려
  /// 대기 중이었다면, 잠금 해제 창이 열린 지금 자동으로 적용한다.
  /// 삭제 대기 잠금 때문에 미뤄뒀던 "모든 차단 초기화"를 앱 재방문 시 자동
  /// 적용한다 — 챗 화면을 안 거치는 유일한 리셋 경로라, 예전엔 감사 로그에
  /// 전혀 안 남고 조용히 스케줄이 사라진 것처럼 보였다(2026-07-16 사용자
  /// 제보 — "언제 어디서 어떤 커맨드가 항상 리셋을 했는지 모르겠다"). 여기서
  /// 직접 기록해 UI를 거치는 [_resetAllBlocks]와 별개로 이 경로도 추적된다.
  static Future<void> applyPendingFullResetIfDue() async {
    if (!IsleUserDefaults.pendingFullResetRequested) return;
    if (RuleRemovalLock.removalBlocked) return;
    await BlockScheduleStore.ensureOpen();
    final beforeCount = BlockScheduleStore.loadAll().length;
    final stillLockedCount = await performFullReset();
    try {
      await BlockAuditLogStore.ensureOpen();
      await BlockAuditLogStore.record(
        command: '(자동) 앱 재방문 시 대기 중이던 전체 초기화 적용',
        action: 'reset_all_blocks_deferred',
        summary: '삭제 대기 잠금이 풀려 스케줄 $beforeCount개 → $stillLockedCount개로 초기화됨'
            '${stillLockedCount > 0 ? ' (커밋먼트 락 걸린 $stillLockedCount개는 남김)' : ''}',
        steps: const [],
        success: true,
      );
    } catch (_) {}
  }

  static Future<BlockChatResult> apply(BlockChatPlan plan, {WidgetRef? ref}) async {
    final result = await _dispatch(plan, ref: ref);
    if (result.isFailure) return result;
    final coach =
        await BlockChatCoachService.build(plan: plan, applied: result);
    // 능동 제안(proactive) — 이미 있는 반응형 제안(FAQ 등)에 덧붙인다.
    final proactive = await BlockSuggestionEngine.evaluate();
    if (coach.isEmpty && proactive.isEmpty) return result;
    return result.copyWith(
      coach: coach.isEmpty ? null : coach,
      suggestions: [...result.suggestions, ...proactive],
    );
  }

  static Future<BlockChatResult> _dispatch(BlockChatPlan plan, {WidgetRef? ref}) async {
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await ContentFilterStore.ensureOpen();

    switch (plan.action) {
      case 'add_keyword':
        return _attachPermissionGaps(plan, await _addKeyword(plan));
      case 'remove_keyword':
        return _attachPermissionGaps(plan, await _removeKeyword(plan));
      case 'remove_url':
        return _attachPermissionGaps(plan, await _removeUrl(plan));
      case 'morning_schedule':
        return _attachPermissionGaps(plan, await _morningSchedule(plan));
      case 'app_session_limit':
        return _attachPermissionGaps(plan, await _appSessionLimit(plan));
      case 'remove_schedule':
        return _attachPermissionGaps(plan, await _removeSchedule(plan));
      case 'relax_block':
        return _attachPermissionGaps(plan, await _relaxBlock(plan));
      case 'allow_window':
        return _attachPermissionGaps(plan, await _allowWindow(plan));
      case 'rename_schedule':
        return _attachPermissionGaps(plan, await _renameSchedule(plan));
      case 'update_schedule_time':
        return _attachPermissionGaps(plan, await _updateScheduleTime(plan));
      case 'add_schedule_days':
        return _attachPermissionGaps(plan, await _addScheduleDays(plan));
      case 'remove_schedule_days':
        return _attachPermissionGaps(plan, await _removeScheduleDays(plan));
      case 'toggle_shorts':
        return _attachPermissionGaps(plan, await _toggleShorts(plan));
      case 'toggle_reels':
        return _attachPermissionGaps(plan, await _toggleReels(plan));
      case 'youtube_limit':
        return _attachPermissionGaps(plan, await _youtubeLimit(plan));
      case 'youtube_weekday_limit':
        return await _youtubeWeekdayLimit(plan);
      case 'youtube_weekly_limit':
        return await _youtubeWeeklyLimit(plan);
      case 'youtube_budget':
      case 'usage_budget':
        return _attachPermissionGaps(plan, await _usageBudget(plan));
      case 'scheduled_reservation':
        return _attachPermissionGaps(plan, await _scheduledReservation(plan));
      case 'app_open_block_trigger':
        return _attachPermissionGaps(plan, await _appOpenBlockTrigger(plan));
      case 'morning_habit_pack':
        return _attachPermissionGaps(plan, await _morningHabitPack(plan));
      case 'music_foreground_limit':
        return _attachPermissionGaps(plan, await _musicForegroundLimit(plan));
      case 'night_schedule':
        return _attachPermissionGaps(plan, await _nightSchedule(plan));
      case 'split_night_schedule':
        return _attachPermissionGaps(plan, await _splitNightSchedule(plan));
      case 'toggle_reels_guard':
        return _attachPermissionGaps(plan, await _toggleReelsGuard(plan));
      case 'safari_pause':
        return _attachPermissionGaps(plan, await _safariPause(plan));
      case 'block_website':
        return _attachPermissionGaps(plan, await _blockWebsite(plan));
      case 'block_url':
        return _attachPermissionGaps(plan, await _blockUrl(plan));
      case 'block_channel':
        return _attachPermissionGaps(plan, await _blockChannel(plan));
      case 'platform_limit':
        return _attachPermissionGaps(plan, await _platformLimit(plan));
      case 'apply_premade_pack':
        return _attachPermissionGaps(plan, await _applyPremadePack(plan));
      case 'block_genre':
        return _attachPermissionGaps(plan, await _applyGenreBlock(plan, ref));
      case 'finance_guidance':
        return _financeGuidance(plan);
      case 'convert_schedule_mode':
        return await _convertScheduleMode(plan);
      case 'modify_schedule_apps':
        return _attachPermissionGaps(plan, await _modifyScheduleApps(plan));
      case 'reset_reapply':
        return _attachPermissionGaps(plan, await _resetReapply(plan));
      case 'set_default_lock_cooldown':
        return await _setDefaultLockCooldown(plan);
      case 'set_morning_notification_time':
        return await _setMorningNotificationTime(plan);
      case 'quick_block_now':
        return await _quickBlockNow(plan);
      case 'study_mode':
        return await _studyMode(plan);
      case 'persona_bundle':
        return await _personaBundle(plan);
      case 'explain_status':
        return await _explainStatus(plan);
      case 'reset_all_blocks':
        return await _resetAllBlocks(plan);
      case 'explain':
        return BlockChatResult(
          summary: plan.reply.isNotEmpty ? plan.reply : '도움이 필요한 설정을 말씀해 주세요.',
          steps: const [],
        );
      default:
        return BlockChatResult.fail('아직 지원하지 않는 설정이에요: ${plan.action}');
    }
  }

  static bool _planNeedsOsAppBlock(BlockChatPlan plan) {
    if (plan.action == 'persona_bundle') {
      final persona = BlockChatPersonaScenarios.byId(plan.personaId ?? '');
      if (persona == null) return false;
      return persona.subPlans.any(_planNeedsOsAppBlock);
    }
    switch (plan.action) {
      case 'morning_schedule':
        return plan.blockSafariNote;
      case 'app_session_limit':
      case 'morning_habit_pack':
      case 'music_foreground_limit':
        return true;
      case 'modify_schedule_apps':
        // isle_* 타깃만 추가/제거하면(인앱 유튜브·브런치 등) Screen Time
        // 권한이 필요 없다 — night_schedule과 동일한 판단 로직.
        final ids = _catalogTargetIdsForModify(plan.limitPlatform ?? '', plan.appId);
        if (ids == null) return true; // 카탈로그 밖 → Screen Time 선택 필요.
        return !ids.every((id) => ScheduleAppTargetCatalog.defFor(id)?.isIsle == true);
      case 'night_schedule':
        // isle_* 타깃만 있으면(인앱 브라우저·유튜브·인스타 등) Screen Time
        // 없이 100% 자동으로 막히므로 OS 권한 경고를 붙이면 안 된다 — 예전엔
        // night_schedule이면 무조건 true라 "인앱 브라우저 차단"까지도
        // "Screen Time으로 선택하세요"라는 잘못된 안내가 붙었다(2026-07-12
        // 발견, "인터넷은 오후 1시까지 막아줘" 등 사용자 표현 테스트 중).
        if ((plan.extraTargetIds?.isNotEmpty ?? false)) {
          return !plan.extraTargetIds!
              .every((id) => ScheduleAppTargetCatalog.defFor(id)?.isIsle == true);
        }
        final t = _nightScheduleLimitTarget(plan);
        if (t != null && t.targetIds.isNotEmpty) {
          return !t.targetIds
              .every((id) => ScheduleAppTargetCatalog.defFor(id)?.isIsle == true);
        }
        return true;
      default:
        return false;
    }
  }

  // 도메인/URL/채널 차단(Safari Content Blocker 전용)은 OS 앱 쉴드(Screen
  // Time)와 별개 권한이다 — 사용자가 "성인 사이트 차단"·특정 도메인을
  // 추가해도 Safari 확장이 켜져 있지 않으면 목록엔 저장되지만 실제로는
  // 아무것도 안 막힌다. 이 확장 상태를 아무 데서도 점검·경고하지 않던
  // 실사용 버그(2026-07-10, Cage에서 먼저 발견·이식 — "mingky05.live가
  // 성인 사이트 목록에 있는데 왜 차단이 안 되지?" 제보).
  static bool _planNeedsSafariContentBlocker(BlockChatPlan plan) {
    if (plan.action == 'persona_bundle') {
      final persona = BlockChatPersonaScenarios.byId(plan.personaId ?? '');
      if (persona == null) return false;
      return persona.subPlans.any(_planNeedsSafariContentBlocker);
    }
    if (plan.subPlans != null) {
      return plan.subPlans!.any(_planNeedsSafariContentBlocker);
    }
    switch (plan.action) {
      case 'block_website':
      case 'block_url':
      case 'block_channel':
      case 'apply_premade_pack':
      case 'block_genre':
        return true;
      default:
        return false;
    }
  }

  static Future<BlockChatResult> _attachPermissionGaps(
    BlockChatPlan plan,
    BlockChatResult result,
  ) async {
    if (result.isFailure) return result;
    final needsOsAppBlock = _planNeedsOsAppBlock(plan);
    final needsSafariContentBlocker = _planNeedsSafariContentBlocker(plan);
    if (!needsOsAppBlock && !needsSafariContentBlocker) return result;

    final scheduleId = result.impact?.scheduleId;
    final gaps = await BlockChatPermissionAuditor.audit(
      scheduleId: scheduleId,
      needsOsAppBlock: needsOsAppBlock,
      needsSafariContentBlocker: needsSafariContentBlocker,
    );
    if (gaps.isEmpty) return result;

    final gapSteps = gaps
        .map(
          (g) => BlockChatAppliedStep(
            title: g.title,
            detail: '${g.issue}\n\n허용하면: ${g.effectWhenGranted}',
            route: g.route,
            routeLabel: g.actionLabel ?? g.routeLabel,
            needsManualSetup: true,
          ),
        )
        .toList();

    var summary = result.summary;
    summary += '\n\n⚠️ 스케줄·규칙은 저장됐지만 OS 차단 권한이 아직 없어요. '
        '아래에서 허용·앱 선택을 마치면 실제로 막혀요.';

    final pending = [
      ...?result.impact?.pendingSteps,
      ...gapSteps,
    ];

    BlockChatApplySummary? impact = result.impact;
    if (impact != null) {
      impact = BlockChatApplySummary(
        headline: impact.headline,
        scheduleId: impact.scheduleId,
        timeRange: impact.timeRange,
        daysLabel: impact.daysLabel,
        endMinute: impact.endMinute,
        locations: impact.locations,
        targets: impact.targets,
        pendingSteps: pending,
      );
    }

    return BlockChatResult(
      summary: summary,
      steps: [...result.steps, ...gapSteps],
      impact: impact,
      usedAi: result.usedAi,
      needsUnlockWait: result.needsUnlockWait,
      unlockMinutes: result.unlockMinutes,
      removalScheduledAuto: result.removalScheduledAuto,
      permissionGaps: gaps,
    );
  }

  /// "OO 관련 스케줄 전부 초토화 후 콜론 뒤 내용으로 덮어쓰기" — RESET_REAPPLY.
  /// persona_bundle 과 동일한 순차 dispatch 를 재사용하되, 첫 subPlan(remove_schedule)이
  /// "지울 게 없음"으로 실패해도 계속 진행한다 — 목표는 "깨끗한 상태 보장 후 적용"이지,
  /// 기존 스케줄이 반드시 있어야 하는 게 아니다. 마지막 subPlan(새 스케줄) 실패만 진짜 실패로 본다.
  /// "지금부터 N시간동안 X 차단해줘" — 매일 반복 스케줄이 아니라 기존
  /// QuickBlockService(6VPN 시절 "빠른 차단" 타이머 세션, UI만 없어졌고
  /// 서비스는 살아있음)를 재사용한 일회성 차단.
  static Future<BlockChatResult> _quickBlockNow(BlockChatPlan plan) async {
    await QuickBlockService.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();

    // 24시간 상한이면 "3일간 차단해줘"처럼 파서가 맞게 계산한 기간도 여기서
    // 하루로 잘려버린다(cage에서 발견한 것과 같은 클래스의 실사용 버그,
    // 2026-07-13). QuickBlockService 세션은 절대시각(endsAt)으로 스스로
    // 만료되므로 상한을 30일(720시간)로 넉넉히 둔다.
    final hours = ((plan.windowMinutes ?? 180) / 60).ceil().clamp(1, 24 * 30);
    await QuickBlockService.start(hours: hours);

    final target = _nightScheduleLimitTarget(plan);
    var pickerDone = false;
    if (target != null && target.targetIds.isNotEmpty) {
      final schedule = BlockScheduleStore.loadAll()
          .firstWhere((s) => s.id == QuickBlockService.presetScheduleId);
      var entries = ScheduleAppTargetsStore.mergeWithCatalog(
        ScheduleAppTargetsStore.loadForSchedule(schedule.id),
      );
      entries = entries.map((e) {
        if (target.targetIds.contains(e.targetId)) {
          return e.copyWith(blockInSlot: true, limitEnabled: false);
        }
        return e;
      }).toList();
      await ScheduleAppTargetsService.saveAndSync(
        scheduleId: schedule.id,
        entries: entries,
        schedule: schedule,
      );
      await ScheduleScreenTimeStore.ensureOpen();
      pickerDone = ScheduleScreenTimeStore.appCountFor(schedule.id) > 0;
      if (!pickerDone &&
          (IsleApplePlatform.isScreenTimeHost || Platform.isAndroid)) {
        pickerDone = await ScheduleScreenTimeService.pickForSchedule(schedule.id);
        if (pickerDone) await ScheduleAppLimitSyncService.syncAll();
      }
    }

    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    final endsAt = DateTime.now().add(Duration(hours: hours));
    final label = target?.label ?? '선택한 앱';
    final endLabel = _fmt(endsAt.hour * 60 + endsAt.minute);

    return BlockChatResult(
      summary: (plan.reply.isNotEmpty
              ? plan.reply
              : '지금부터 $hours시간 동안 $label을 차단합니다.') +
          '\n\n$endLabel쯤 자동으로 풀려요.',
      steps: [
        BlockChatAppliedStep(
          title: '지금부터 $hours시간 차단',
          detail: pickerDone
              ? '$label — Screen Time 연결됨. 자동 해제: $endLabel'
              : '$label — 앱 선택이 아직 안 됐어요. 자동 해제: $endLabel',
          route: '/home/block',
          routeLabel: '차단 탭',
          needsManualSetup: !pickerDone && target != null,
        ),
      ],
    );
  }

  static Future<BlockChatResult> _studyMode(BlockChatPlan plan) async {
    await KakaoShortsPresetService.enablePomodoro30x10();
    final subPlans = plan.subPlans;
    if (subPlans == null || subPlans.isEmpty) {
      return BlockChatResult.fail('공부 모드에 적용할 설정이 비어 있어요.');
    }
    BlockChatResult? last;
    for (final sub in subPlans) {
      final r = sub.action == 'quick_block_now'
          ? await _quickBlockNow(sub)
          : await _dispatch(sub);
      if (r.isFailure) return r;
      last = r;
    }
    return BlockChatResult(
      summary: plan.reply.isNotEmpty ? plan.reply : (last?.summary ?? '공부 모드를 적용했어요.'),
      steps: last?.steps ?? const [],
      impact: last?.impact,
      suggestions: const [],
    );
  }

  static Future<BlockChatResult> _setMorningNotificationTime(
    BlockChatPlan plan,
  ) async {
    final hour = (plan.startHour ?? 8).clamp(0, 23);
    final minute = (plan.startMinute ?? 0).clamp(0, 59);
    await IsleUserDefaults.setMorningNotificationTime(hour, minute);
    await IsleUserDefaults.setMorningNotificationEnabled(true);
    await ScheduleNotificationService.rescheduleAll();
    return BlockChatResult(
      summary: plan.reply.isNotEmpty
          ? plan.reply
          : '아침 알림을 매일 ${_fmt(hour * 60 + minute)}에 보낼게요.',
      steps: const [
        BlockChatAppliedStep(
          title: '아침 알림 시각',
          detail: '매일 이 시간에 오늘의 차단 요약을 알려줘요',
        ),
      ],
    );
  }

  static Future<BlockChatResult> _setDefaultLockCooldown(
    BlockChatPlan plan,
  ) async {
    final mins = (plan.dailyMinutes ?? 30).clamp(15, 180).toInt();
    await IsleUserDefaults.setDefaultScheduleLockCooldownMinutes(mins);
    return BlockChatResult(
      summary: plan.reply.isNotEmpty
          ? plan.reply
          : '앞으로 새로 만드는 스케줄은 기본으로 $mins분 설정 잠금이 걸려요.',
      steps: const [
        BlockChatAppliedStep(
          title: '타임락 기본값',
          detail: '이미 있는 스케줄은 그대로, 새로 만드는 것부터 적용',
        ),
      ],
    );
  }

  static Future<BlockChatResult> _resetReapply(BlockChatPlan plan) async {
    final subPlans = plan.subPlans;
    if (subPlans == null || subPlans.isEmpty) {
      return BlockChatResult.fail('적용할 설정이 비어 있어요.');
    }

    BlockChatResult? last;
    for (var i = 0; i < subPlans.length; i++) {
      final r = await _dispatch(subPlans[i]);
      final isLast = i == subPlans.length - 1;
      if (r.isFailure && isLast) {
        return BlockChatResult.fail(
          '${plan.reply.isNotEmpty ? plan.reply : ''}\n\n⚠️ ${r.summary}'.trim(),
        );
      }
      last = r;
    }

    return BlockChatResult(
      summary: plan.reply.isNotEmpty ? plan.reply : (last?.summary ?? '적용했어요.'),
      steps: last?.steps ?? const [],
      impact: last?.impact,
      permissionGaps: last?.permissionGaps ?? const [],
    );
  }

  static Future<BlockChatResult> _personaBundle(BlockChatPlan plan) async {
    final persona = BlockChatPersonaScenarios.byId(plan.personaId ?? '');
    if (persona == null) {
      return BlockChatResult.fail('고민 시나리오를 찾지 못했어요.');
    }
    if (persona.subPlans.isEmpty) {
      return BlockChatResult.fail('적용할 설정이 비어 있어요.');
    }

    final empathy = plan.reply.isNotEmpty ? plan.reply : persona.empathy;
    final mergedSteps = <BlockChatAppliedStep>[];
    final mergedGaps = <BlockChatPermissionGap>[];
    final mergedLocations = <BlockChatApplyLocation>[];
    final mergedTargets = <BlockChatApplyTarget>[];
    final detailLines = <String>[];

    for (final sub in persona.subPlans) {
      final r = await _dispatch(sub);
      if (r.isFailure) {
        return BlockChatResult.fail('$empathy\n\n⚠️ ${r.summary}');
      }
      if (r.summary.isNotEmpty) detailLines.add(r.summary);
      mergedSteps.addAll(r.steps);
      mergedGaps.addAll(r.permissionGaps);
      final impact = r.impact;
      if (impact != null) {
        mergedLocations.addAll(impact.locations);
        mergedTargets.addAll(impact.targets);
      }
    }

    var summary = empathy;
    if (detailLines.isNotEmpty) {
      summary = '$empathy\n\n${detailLines.join('\n')}';
    }
    if (mergedGaps.isNotEmpty) {
      summary += '\n\n⚠️ 스케줄·규칙은 저장됐지만 OS 차단 권한이 아직 없어요. '
          '아래에서 허용·앱 선택을 마치면 실제로 막혀요.';
    }

    return BlockChatResult(
      summary: summary,
      steps: mergedSteps,
      permissionGaps: mergedGaps,
      impact: BlockChatApplySummary(
        headline: '${persona.persona} · 맞춤 설정',
        locations: mergedLocations,
        targets: mergedTargets,
        pendingSteps: mergedGaps
            .map(
              (g) => BlockChatAppliedStep(
                title: g.title,
                detail: g.issue,
                route: g.route,
                routeLabel: g.actionLabel ?? g.routeLabel,
                needsManualSetup: true,
              ),
            )
            .toList(),
      ),
    );
  }

  static Future<BlockChatResult> _addKeyword(BlockChatPlan plan) async {
    final kw = plan.keyword?.trim().toLowerCase();
    if (kw == null || kw.isEmpty) {
      return BlockChatResult.fail('숨길 키워드를 찾지 못했어요.');
    }
    final list = List<String>.from(ContentFilterStore.loadKeywords());
    if (!list.contains(kw)) list.add(kw);
    await ContentFilterStore.saveKeywords(list);
    return BlockChatResult(
      summary: plan.reply.isNotEmpty ? plan.reply : '키워드 「$kw」를 숨김 목록에 추가했어요.',
      steps: [
        BlockChatAppliedStep(
          title: '키워드 숨김',
          detail: '피드·Isle 유튜브 제목·채널명에 「$kw」가 있으면 안 보여요.',
          route: '/home/my-isle/manage',
          routeLabel: '유튜브·SNS 관리',
        ),
      ],
      impact: BlockChatApplySummary(
        headline: '키워드 「$kw」 숨김',
        locations: [
          BlockChatApplyLocation(
            tabLabel: '피드',
            detail: '제목·채널명 필터',
            icon: Icons.dynamic_feed,
            route: '/feed',
            routeLabel: '피드',
          ),
          BlockChatApplyLocation(
            tabLabel: '유튜브·SNS 관리',
            detail: '숨김 키워드 목록',
            icon: Icons.tune,
            route: '/home/my-isle/manage',
            routeLabel: '관리 센터',
          ),
        ],
        targets: [
          BlockChatApplyTarget(label: kw, icon: Icons.block),
        ],
      ),
    );
  }

  static Future<BlockChatResult> _removeKeyword(BlockChatPlan plan) async {
    final kw = plan.removeKeyword?.trim().toLowerCase();
    if (kw == null || kw.isEmpty) {
      return BlockChatResult.fail('제거할 키워드를 알려주세요.');
    }
    if (!ContentFilterStore.loadKeywords().contains(kw)) {
      return BlockChatResult.fail('키워드 「$kw」가 숨김 목록에 없어요.');
    }
    final outcome = await RulePendingRemovalService.requestKeywordRemove(kw);
    return _resultFromRuleRemoval(
      outcome: outcome,
      itemLabel: '키워드 「$kw」',
      immediateSummary: '키워드 「$kw」를 제거했어요.',
      step: BlockChatAppliedStep(
        title: '키워드 해제',
        detail: '다시 피드·유튜브에 노출될 수 있어요.',
        route: '/home/my-isle/manage',
        routeLabel: '숨김 목록',
      ),
    );
  }

  static Future<BlockChatResult> _removeUrl(BlockChatPlan plan) async {
    final raw = plan.removeUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return BlockChatResult.fail('제거할 URL을 알려주세요.');
    }
    final outcome = await RulePendingRemovalService.requestUrlRemove(raw);
    final label = raw.length > 48 ? '${raw.substring(0, 45)}…' : raw;
    return _resultFromRuleRemoval(
      outcome: outcome,
      itemLabel: 'URL 「$label」',
      immediateSummary: 'URL 차단을 해제했어요.',
      step: const BlockChatAppliedStep(
        title: 'URL 차단 해제',
        detail: '해당 주소가 다시 열릴 수 있어요.',
        route: '/home/my-isle/manage',
        routeLabel: 'URL 차단 목록',
      ),
    );
  }

  static BlockChatResult _resultFromRuleRemoval({
    required RuleRemovalOutcome outcome,
    required String itemLabel,
    required String immediateSummary,
    required BlockChatAppliedStep step,
  }) {
    switch (outcome.kind) {
      case RuleRemovalOutcomeKind.immediate:
        return BlockChatResult(
          summary: immediateSummary,
          steps: [step],
        );
      case RuleRemovalOutcomeKind.scheduled:
        final wait = outcome.remaining ??
            Duration(minutes: RuleRemovalLock.freezeMinutes);
        final when = RulePendingRemovalService.formatRemaining(wait);
        return BlockChatResult(
          summary: '제거 타임락이 켜져 있어요.\n'
              '$when $itemLabel 차단이 자동으로 해제됩니다.\n'
              '그동안에는 지금처럼 차단이 유지돼요.',
          removalScheduledAuto: true,
          steps: [
            BlockChatAppliedStep(
              title: '자동 제거 예약',
              detail: '$when 적용 · 추가 조작 없이 해제됩니다',
              route: step.route,
              routeLabel: step.routeLabel,
            ),
          ],
        );
      case RuleRemovalOutcomeKind.alreadyPending:
        final when = RulePendingRemovalService.formatRemaining(
            outcome.remaining ?? Duration(minutes: RuleRemovalLock.freezeMinutes));
        return BlockChatResult(
          summary: '이미 삭제가 예약돼 있어요.\n'
              '$when $itemLabel 차단이 자동으로 해제됩니다.',
          removalScheduledAuto: true,
          steps: [
            BlockChatAppliedStep(
              title: '삭제 대기 중',
              detail: '$when 자동 적용 · 그동안 차단 유지',
              route: step.route,
              routeLabel: step.routeLabel,
            ),
          ],
        );
    }
  }

  static Future<BlockChatResult> _morningSchedule(BlockChatPlan plan) async {
    if (plan.blockIsleYoutube && !plan.blockSafariNote) {
      final schedule = await IsleYoutubeScheduleService.applyMorningBlock(
        endHour: plan.endHour,
        endMinute: plan.endMinute,
        scheduleName: plan.scheduleName,
        days: plan.days,
      );
      final endMin = plan.endHour * 60 + plan.endMinute;
      final editRoute = IsleRoutes.blockScheduleEditOutsideShell(schedule.id);
      return BlockChatResult(
        summary: plan.reply.isNotEmpty ? plan.reply : '아침 Isle 유튜브 스케줄을 만들었어요.',
        steps: [
          BlockChatAppliedStep(
            title: 'Isle 유튜브 스케줄',
            detail:
                '매일 00:00–${IsleYoutubeScheduleService.formatEndLabel(endMin)} 「${schedule.name}」',
            route: editRoute,
            routeLabel: '스케줄 편집',
          ),
        ],
        impact: _scheduleImpact(
          headline: schedule.name,
          scheduleId: schedule.id,
          endMin: endMin,
          days: plan.days,
          targets: const [
            BlockChatApplyTarget(
              label: 'Isle 유튜브',
              icon: Icons.play_circle_filled,
              tint: Color(0xFFFF0000),
            ),
          ],
        ),
      );
    }

    await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);
    final endMin = (plan.endHour * 60 + plan.endMinute).clamp(1, 1439);
    final slots = <ScheduleSlot>[
      for (final d in plan.days)
        ScheduleSlot(day: d.clamp(0, 6), startMinute: 0, endMinute: endMin),
    ];
    final name = plan.scheduleName?.isNotEmpty == true
        ? plan.scheduleName!
        : '아침 차단 (AI)';
    final existing =
        BlockChatScheduleDedup.findSafariMorning(preferredName: name);
    final schedule = existing ??
        await BlockScheduleStore.create(
          name: name,
          slots: slots,
          locked: true,
          lockCooldownMinutes: IsleUserDefaults.defaultScheduleLockCooldownMinutes,
        );
    var enabled = schedule.copyWith(
      enabled: true,
      blockIsleInApp: plan.blockSafariNote,
      slots: slots,
      locked: true,
    );
    await BlockScheduleStore.upsert(enabled);

    if (plan.blockSafariNote) {
      final isleEntries =
          ScheduleAppTargetsStore.loadForSchedule(schedule.id).map((e) {
        final def = ScheduleAppTargetCatalog.defFor(e.targetId);
        if (def?.isIsle == true) return e.copyWith(blockInSlot: true);
        return e;
      }).toList();
      await ScheduleAppTargetsService.saveAndSync(
        scheduleId: schedule.id,
        entries: isleEntries,
        schedule: enabled,
      );
      enabled =
          BlockScheduleStore.loadAll().firstWhere((s) => s.id == schedule.id);
    }

    final editRoute = IsleRoutes.blockScheduleEditOutsideShell(schedule.id);
    final steps = <BlockChatAppliedStep>[
      BlockChatAppliedStep(
        title: '스케줄 생성',
        detail: '매일 00:00–${_fmt(endMin)} 「$name」 (타임락 켜짐)',
        route: editRoute,
        routeLabel: '스케줄 편집',
      ),
    ];

    final targets = <BlockChatApplyTarget>[];
    final pending = <BlockChatAppliedStep>[];

    if (plan.blockSafariNote) {
      steps.add(
        BlockChatAppliedStep(
          title: 'Isle · 웹·앱 차단',
          detail: '슬롯 안에서 Isle Safari·YouTube·Instagram·Brunch 탐색이 막혀요.',
          route: editRoute,
          routeLabel: '스케줄 편집',
        ),
      );
      targets.addAll(const [
        BlockChatApplyTarget(label: 'Isle Safari', icon: Icons.language),
        BlockChatApplyTarget(
          label: 'Isle 유튜브',
          icon: Icons.play_circle_filled,
          tint: Color(0xFFFF0000),
        ),
        BlockChatApplyTarget(
            label: 'Instagram', icon: Icons.camera_alt_outlined),
        BlockChatApplyTarget(label: 'Brunch', icon: Icons.menu_book_outlined),
        BlockChatApplyTarget(
          label: 'Safari 앱',
          icon: Icons.phone_iphone,
          needsManualSetup: true,
        ),
      ]);
      pending.add(
        BlockChatAppliedStep(
          title: 'Safari · iPhone 앱',
          detail: '스케줄 편집 → ③ 차단 대상에서 Safari 앱을 Screen Time으로 선택해 주세요.',
          route: editRoute,
          routeLabel: '스케줄 편집',
          needsManualSetup: true,
        ),
      );
    }

    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    unawaited(IosRulesExportService.exportNow());

    return BlockChatResult(
      summary: plan.reply.isNotEmpty ? plan.reply : '아침 $name 스케줄을 만들었어요.',
      steps: steps,
      impact: _scheduleImpact(
        headline: name,
        scheduleId: schedule.id,
        endMin: endMin,
        days: plan.days,
        targets: targets,
        pendingSteps: pending,
      ),
    );
  }

  static Future<BlockChatResult> _appSessionLimit(BlockChatPlan plan) async {
    final appId = plan.appId ?? 'instagram';
    final daily = (plan.dailyMinutes ?? 10).clamp(1, 180);
    final session = (plan.sessionMinutes ?? 5).clamp(1, 60);
    final cooldown = (plan.cooldownMinutes ?? 10).clamp(1, 120);
    final window = session + cooldown;

    final preset = switch (appId) {
      'tiktok' => AppUsageLimitRule.tiktokPreset,
      'youtube_app' => AppUsageLimitRule.youtubeAppPreset,
      _ => AppUsageLimitRule.instagramPreset,
    };

    final rules = AppUsageLimitStore.loadRules();
    final idx = rules.indexWhere((r) => r.id == preset.id);
    final updated = AppUsageLimitRule(
      id: preset.id,
      label: preset.label,
      minutesPerWindow: daily,
      enabled: true,
      presetId: preset.id,
      androidPackageName: preset.androidPackage,
      windowMinutes: 1440,
      interventionTitle: '오늘 ${preset.label} 한도',
      interventionBody:
          '세션 ${session}분 후 ${cooldown}분 쉬어요. Isle에서 의도한 콘텐츠만 보세요.',
    );
    if (idx >= 0) {
      rules[idx] = updated;
    } else {
      rules.add(updated);
    }
    await AppUsageLimitStore.saveRules(rules);

    await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);
    final schName = plan.scheduleName?.isNotEmpty == true
        ? plan.scheduleName!
        : '${preset.label} 세션 (AI)';
    final existingSession = BlockChatScheduleDedup.findAiNamedPack(
      preset.label.toLowerCase(),
    );
    final schedule = existingSession ??
        await BlockScheduleStore.create(
          name: schName,
          slots: _allDaySlots(),
          locked: true,
        );
    if (existingSession == null) {
      await BlockScheduleStore.upsert(schedule.copyWith(enabled: true));
    } else {
      await BlockScheduleStore.upsert(existingSession.copyWith(enabled: true));
    }
    final activeSchedule = existingSession ?? schedule;

    final entries = ScheduleAppTargetsStore.loadForSchedule(activeSchedule.id);
    final bundleId = switch (preset.id) {
      'instagram' => 'instagram_feed',
      'tiktok' => 'tiktok',
      'youtube_app' => 'youtube',
      _ => 'instagram_feed',
    };
    final patched = entries.map((e) {
      final def = ScheduleAppTargetCatalog.defFor(e.targetId);
      if (def?.bundleId != bundleId) return e;
      return e.copyWith(
        limitEnabled: true,
        limitMinutes: session,
        windowMinutes: window,
        blockInSlot: false,
      );
    }).toList();
    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: activeSchedule.id,
      entries: patched,
      schedule: activeSchedule.copyWith(enabled: true),
    );

    final editRoute =
        IsleRoutes.blockScheduleEditOutsideShell(activeSchedule.id);
    final iosPending = preset.id == 'instagram'
        ? BlockChatAppliedStep(
            title: 'iPhone Instagram 앱',
            detail: '스케줄 편집에서 iPhone Instagram을 Screen Time으로 선택하면 OS 차단이 붙어요.',
            route: editRoute,
            routeLabel: '스케줄 편집',
            needsManualSetup: true,
          )
        : null;

    return BlockChatResult(
      summary: plan.reply.isNotEmpty
          ? plan.reply
          : '${preset.label} — 하루 $daily분, ${session}분 쓰고 ${cooldown}분 쉬기',
      steps: [
        BlockChatAppliedStep(
          title: '앱 일일 한도',
          detail: '하루 $daily분 (외부 ${preset.label} 앱)',
          route: '/settings/app-usage-limits',
          routeLabel: '앱별 한도',
        ),
        BlockChatAppliedStep(
          title: '세션·쿨다운',
          detail: '${session}분 사용 → ${cooldown}분 대기 (${window}분 창)',
          route: editRoute,
          routeLabel: '스케줄 편집',
        ),
        if (iosPending != null) iosPending,
      ],
      impact: BlockChatApplySummary(
        headline: '$schName · ${preset.label}',
        scheduleId: activeSchedule.id,
        timeRange: '하루 종일 (24시간)',
        daysLabel: '매일',
        endMinute: 1440,
        locations: [
          BlockChatApplyLocation(
            tabLabel: '앱별 한도',
            detail: '일일 $daily분',
            icon: Icons.timer_outlined,
            route: '/settings/app-usage-limits',
            routeLabel: '한도 설정',
          ),
          BlockChatApplyLocation(
            tabLabel: '스케줄 편집',
            detail: '세션 ${session}분 · 쿨다운 ${cooldown}분',
            icon: Icons.edit_calendar_outlined,
            route: editRoute,
            routeLabel: '편집 화면',
          ),
          const BlockChatApplyLocation(
            tabLabel: '차단 탭',
            detail: '스케줄·한도 목록',
            icon: Icons.shield_outlined,
            route: '/home/block',
            routeLabel: '차단 탭',
          ),
        ],
        targets: [
          BlockChatApplyTarget(
            label: preset.label,
            icon: preset.id == 'instagram'
                ? Icons.camera_alt_outlined
                : Icons.play_circle_outline,
          ),
          if (iosPending != null)
            const BlockChatApplyTarget(
              label: 'iPhone 앱',
              icon: Icons.phone_iphone,
              needsManualSetup: true,
            ),
        ],
        pendingSteps: iosPending != null ? [iosPending] : const [],
      ),
    );
  }

  static String? _scheduleQueryFor(BlockChatPlan plan) {
    final q = plan.scheduleQuery?.trim();
    if (q != null && q.isNotEmpty) return q;
    final r = plan.removeScheduleQuery?.trim();
    if (r != null && r.isNotEmpty) return r;
    return null;
  }

  static BlockChatScheduleMatch? _resolvePlanSchedule(BlockChatPlan plan) {
    return BlockChatScheduleResolver.resolve(_scheduleQueryFor(plan));
  }

  static String _matchNote(BlockChatScheduleMatch match) =>
      ' (${match.matchedBecause})';

  /// 안전 라인 스케줄도 이제 채팅으로 변경을 "요청"할 수 있다 — 다만
  /// 항상 locked:true라서 아래 일반 잠금 로직(카운트다운 → 15분 대기 →
  /// 편집 창)을 그대로 타고, 즉시·silent 적용은 절대 없다(2026-07-20
  /// 사용자 확정: "안전 스케줄은 timelock 15분과 함께 채팅으로 변경될 수
  /// 있게 해줘" — 스위치를 내리는 것과 동일한 흐름을 채팅 요청이 대신
  /// 시작해줄 뿐, 결과는 항상 15분 뒤에야 반영된다).
  static Future<BlockChatResult?> _ensureScheduleEditable(
    BlockSchedule s,
    String opLabel,
  ) async {
    if (ScheduleEditGuard.canEditScheduleFields(s)) return null;

    // 안전 라인도 일반 잠긴 스케줄과 동일한 흐름을 탄다 — 챗이 카운트다운을
    // 대신 시작해줄 순 있지만(스위치를 내린 것과 동일 효과), 결과는 항상
    // 15분 타임락을 다 기다린 뒤에만 반영된다. 즉시·silent 적용은 없다
    // (2026-07-20, 최초엔 아예 거부했으나 사용자가 "요청 자체는 가능,
    // 다만 즉시 반영은 안 됨"으로 최종 확정).
    final phase = ScheduleLockService.phase(s);
    if (phase == ScheduleLockPhase.countdown) {
      final left = ScheduleLockService.countdownRemaining(s);
      final mins = left?.inMinutes ?? s.lockCooldownMinutes;
      return BlockChatResult(
        summary: '「${s.name}」은 타임락 해제 대기 중이에요.\n'
            '약 ${mins}분 후 편집 창이 열리면 $opLabel 할 수 있어요.',
        needsUnlockWait: true,
        unlockMinutes: mins,
        steps: [
          BlockChatAppliedStep(
            title: '편집 대기',
            detail: '타임락 편집 창에서 다시 말해 주세요',
            route: IsleRoutes.blockScheduleEditOutsideShell(s.id),
            routeLabel: '대기 상태 보기',
          ),
        ],
      );
    }

    await ScheduleLockService.startUnlockCountdown(s.id);
    final mins = s.lockCooldownMinutes;
    unawaited(ScheduleNotificationService.scheduleUnlockCountdownReminder(
      schedule: s,
      readyAt: DateTime.now().add(Duration(minutes: mins)),
    ));
    return BlockChatResult(
      summary: '「${s.name}」은 타임락이 걸려 있어요.\n'
          '${mins}분 대기 후 편집 창에서 $opLabel 해 주세요.',
      needsUnlockWait: true,
      unlockMinutes: mins,
      steps: [
        BlockChatAppliedStep(
          title: '타임락 해제 시작',
          detail: '${mins}분 후 편집 창 — 그때 같은 요청을 다시 해 주세요',
          route: IsleRoutes.blockScheduleEditOutsideShell(s.id),
          routeLabel: '대기 상태 보기',
        ),
      ],
    );
  }

  static String _relaxTargetForScope(BlockRelaxScope scope) => switch (scope) {
        BlockRelaxScope.youtube => 'youtube',
        BlockRelaxScope.safari => 'safari',
        BlockRelaxScope.instagram => 'instagram',
        BlockRelaxScope.all => 'all',
      };

  static String _scopeLabelKo(BlockRelaxScope scope) => switch (scope) {
        BlockRelaxScope.youtube => '유튜브',
        BlockRelaxScope.safari => 'Safari·웹',
        BlockRelaxScope.instagram => 'Instagram',
        BlockRelaxScope.all => '차단',
      };

  static Future<BlockChatResult> _removeSchedule(BlockChatPlan plan) async {
    final query = _scheduleQueryFor(plan) ?? '';
    final scope = ScheduleBlockReconcileService.scopeFromQuery(query);
    final affecting =
        ScheduleBlockReconcileService.schedulesAffectingScope(scope);
    final contentScoped = query.isNotEmpty && scope != BlockRelaxScope.all;

    if (affecting.isNotEmpty && (contentScoped || affecting.length >= 2)) {
      return _relaxBlock(
        BlockChatPlan(
          action: 'relax_block',
          relaxTarget: _relaxTargetForScope(scope),
          scheduleQuery: query,
          removeScheduleQuery: query,
          reply: plan.reply.isNotEmpty
              ? plan.reply
              : '겹친 ${affecting.length}개 스케줄에서 ${_scopeLabelKo(scope)} 차단을 모두 완화할게요.',
        ),
      );
    }

    final match = _resolvePlanSchedule(plan);
    if (match == null) {
      return BlockChatResult.fail('해제할 스케줄이 없어요.');
    }
    final s = match.schedule;
    final note = _matchNote(match);

    // 안전 라인도 일반 잠긴 스케줄과 같은 흐름 — 챗 요청이 카운트다운을
    // 대신 시작시킬 순 있지만(스위치를 내린 것과 동일 효과), 실제 해제는
    // 항상 15분 타임락을 다 기다린 뒤 편집 창에서만 반영된다. 즉시·silent
    // 해제는 절대 없다(2026-07-20 최종 확정 — 최초엔 요청 자체를 거부했으나
    // "요청은 가능, 다만 즉시 반영은 안 됨"으로 사용자가 정정).
    final phase = ScheduleLockService.phase(s);

    if (s.locked) {
      if (phase == ScheduleLockPhase.editWindow) {
        await IsleUserDefaults.clearPendingBlockRelax();
        await BlockScheduleStore.upsert(s.copyWith(enabled: false));
        await BlockScheduleEnforcementService.syncPlatformEnforcement(
            force: true);
        return BlockChatResult(
          summary: '「${s.name}」 스케줄을 껐어요 (편집 창 안).$note',
          steps: [
            BlockChatAppliedStep(
              title: '스케줄 비활성',
              detail: '타임락 편집 창에서 해제됨',
              route: IsleRoutes.blockScheduleEditOutsideShell(s.id),
              routeLabel: '스케줄 보기',
            ),
          ],
          impact: _scheduleOffImpact(s),
        );
      }
      if (phase == ScheduleLockPhase.countdown) {
        final left = ScheduleLockService.countdownRemaining(s);
        final mins = left?.inMinutes ?? s.lockCooldownMinutes;
        return BlockChatResult(
          summary: '「${s.name}」 타임락 해제 대기 중이에요.\n'
              '약 ${mins}분 후 편집 창이 열리면 스케줄을 자동으로 꺼요.',
          needsUnlockWait: true,
          unlockMinutes: mins,
          removalScheduledAuto: true,
          steps: [
            BlockChatAppliedStep(
              title: '자동 해제 예약됨',
              detail: '대기 종료 후 추가 조작 없이 스케줄이 꺼집니다',
              route: IsleRoutes.blockScheduleEditOutsideShell(s.id),
              routeLabel: '대기 상태 보기',
            ),
          ],
        );
      }
      await IsleUserDefaults.setPendingBlockRelax('${s.id}|scheduleOff');
      final updated = await ScheduleLockService.startUnlockCountdown(s.id);
      final mins = updated?.lockCooldownMinutes ?? s.lockCooldownMinutes;
      unawaited(ScheduleNotificationService.scheduleUnlockCountdownReminder(
        schedule: updated ?? s,
        readyAt: DateTime.now().add(Duration(minutes: mins)),
      ));
      return BlockChatResult(
        summary: '「${s.name}」은 타임락이 걸려 있어요.\n'
            '${mins}분 대기 후 편집 창이 열리면 자동으로 스케줄을 꺼요.',
        needsUnlockWait: true,
        unlockMinutes: mins,
        removalScheduledAuto: true,
        steps: [
          BlockChatAppliedStep(
            title: '타임락 → 자동 해제',
            detail: '${mins}분 대기 후 스케줄 OFF · 그동안 차단 유지',
            route: IsleRoutes.blockScheduleEditOutsideShell(s.id),
            routeLabel: '대기 상태 보기',
          ),
        ],
      );
    }

    await BlockScheduleStore.upsert(s.copyWith(enabled: false));
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    return BlockChatResult(
      summary: '「${s.name}」 스케줄을 껐어요.$note',
      steps: [
        BlockChatAppliedStep(
          title: '스케줄 비활성',
          detail: '다시 켜려면 스케줄 목록에서 활성화하세요.',
          route: IsleRoutes.blockScheduleEditOutsideShell(s.id),
          routeLabel: '스케줄 보기',
        ),
      ],
      impact: _scheduleOffImpact(s),
    );
  }

  /// 허용 창 — 지정 시간대만 Isle 유튜브를 보게 하고 나머지는 차단.
  static Future<BlockChatResult> _allowWindow(BlockChatPlan plan) async {
    final startMin = (plan.startHour ?? 15) * 60 + (plan.startMinute ?? 0);
    final endMin = plan.endHour * 60 + plan.endMinute;
    if (endMin <= startMin) {
      return BlockChatResult.fail(
        '허용 시간대가 올바르지 않아요. 예: 「유튜브 평일 15시부터 19시까지 풀어줘」',
      );
    }

    final schedule = await IsleYoutubeScheduleService.applyAllowWindow(
      startMinute: startMin,
      endMinute: endMin,
      scheduleName: plan.scheduleName,
      days: plan.days,
    );
    final editRoute = IsleRoutes.blockScheduleEditOutsideShell(schedule.id);
    final windowLabel = '${_fmt(startMin)}–${_fmt(endMin)}';
    return BlockChatResult(
      summary: plan.reply.isNotEmpty
          ? plan.reply
          : '$windowLabel만 Isle 유튜브를 허용하는 스케줄을 만들었어요.',
      steps: [
        BlockChatAppliedStep(
          title: '유튜브 허용 창',
          detail: '$windowLabel 동안만 허용 · 그 외 시간 차단 「${schedule.name}」 (타임락 켜짐)',
          route: editRoute,
          routeLabel: '스케줄 편집',
        ),
      ],
      impact: _scheduleImpact(
        headline: schedule.name,
        scheduleId: schedule.id,
        endMin: endMin,
        days: plan.days,
        targets: const [
          BlockChatApplyTarget(
            label: 'Isle 유튜브',
            icon: Icons.play_circle_filled,
            tint: Color(0xFFFF0000),
          ),
        ],
      ),
    );
  }

  static Future<BlockChatResult> _relaxBlock(BlockChatPlan plan) async {
    final scope = plan.relaxTarget != null
        ? ScheduleBlockReconcileService.scopeFromTarget(plan.relaxTarget)
        : ScheduleBlockReconcileService.scopeFromQuery(
            plan.scheduleQuery ??
                plan.removeScheduleQuery ??
                plan.scheduleName ??
                '',
          );
    final outcome = await ScheduleBlockReconcileService.relaxAllForScope(scope);
    final label = _scopeLabelKo(scope);

    if (outcome.totalTouched == 0 && outcome.stillBlocking.isEmpty) {
      return BlockChatResult.fail('$label 관련 활성 차단 스케줄이 없어요.');
    }

    final buf = StringBuffer();
    if (plan.reply.isNotEmpty) buf.writeln(plan.reply);
    if (outcome.relaxedNow.isNotEmpty) {
      buf.writeln(
          '즉시 품 (${outcome.relaxedNow.length}개): ${outcome.relaxedNow.join(' · ')}');
    }
    if (outcome.waitingTimelock.isNotEmpty) {
      buf.writeln(
        '타임락 대기 (${outcome.waitingTimelock.length}개): ${outcome.waitingTimelock.join(' · ')}',
      );
    }
    if (outcome.fullyRelaxed) {
      buf.write('✓ $label 차단이 모두 풀렸어요.');
    } else if (outcome.stillBlocking.isNotEmpty) {
      buf.write('⚠️ 아직 막힘: ${outcome.stillBlocking.join(' · ')}');
    }

    final steps = <BlockChatAppliedStep>[
      if (outcome.relaxedNow.isNotEmpty)
        BlockChatAppliedStep(
          title: '즉시 완화',
          detail: outcome.relaxedNow.join(' · '),
          route: IsleRoutes.blockSchedulesOutsideShell,
          routeLabel: '스케줄 목록',
        ),
      if (outcome.waitingTimelock.isNotEmpty)
        BlockChatAppliedStep(
          title: '타임락 대기',
          detail: outcome.waitingTimelock.join(' · '),
          route: IsleRoutes.blockSchedulesOutsideShell,
          routeLabel: '대기 보기',
        ),
      if (outcome.stillBlocking.isNotEmpty)
        BlockChatAppliedStep(
          title: '아직 막힘',
          detail: outcome.stillBlocking.join(' · '),
          route: '/home/block',
          routeLabel: '차단 탭',
        ),
    ];

    return BlockChatResult(
      summary: buf.toString().trim(),
      steps: steps,
      needsUnlockWait: outcome.waitingTimelock.isNotEmpty,
      removalScheduledAuto: outcome.waitingTimelock.isNotEmpty,
      impact: BlockChatApplySummary(
        headline: '$label 차단 일괄 해제',
        locations: [
          const BlockChatApplyLocation(
            tabLabel: '차단 탭',
            detail: '남은 레이어 확인',
            icon: Icons.shield_outlined,
            route: '/home/block',
            routeLabel: '차단 탭',
          ),
          BlockChatApplyLocation(
            tabLabel: '완화됨',
            detail: outcome.relaxedNow.isEmpty
                ? '대기 중'
                : '${outcome.relaxedNow.length}개',
            icon: Icons.check_circle_outline,
            route: IsleRoutes.blockSchedulesOutsideShell,
            routeLabel: '스케줄 목록',
          ),
        ],
        targets: [
          if (outcome.stillBlocking.isNotEmpty)
            const BlockChatApplyTarget(
              label: '아직 막힘',
              icon: Icons.warning_amber_rounded,
              tint: Color(0xFFE65100),
              needsManualSetup: true,
            )
          else
            BlockChatApplyTarget(
              label: '$label OK',
              icon: Icons.play_circle_outline,
              tint: const Color(0xFF2E7D32),
            ),
        ],
        pendingSteps: outcome.stillBlocking
            .map(
              (s) => BlockChatAppliedStep(
                title: '남은 차단',
                detail: s,
                route: '/home/block',
                routeLabel: '차단 탭',
                needsManualSetup: true,
              ),
            )
            .toList(),
      ),
    );
  }

  /// "카카오톡 밤에 통째로 블락 말고, 10분마다 3분만 보기로 변형해줘" — 기존 스케줄을 찾아
  /// enforcementMode 를 전체차단→구간제한으로 바꾼다(SCHEDULE_CONVERT). _nightSchedule 의
  /// limit 분기와 동일한 ScheduleAppTargetsStore 변경 경로를 재사용한다.
  static Future<BlockChatResult> _convertScheduleMode(BlockChatPlan plan) async {
    final match = _resolvePlanSchedule(plan);
    if (match == null) {
      return BlockChatResult.fail('변형할 스케줄을 찾지 못했어요.');
    }
    final s = match.schedule;
    final blocked = await _ensureScheduleEditable(s, '모드 변형');
    if (blocked != null) return blocked;

    final target = _nightScheduleLimitTarget(plan);
    if (target == null) {
      return BlockChatResult.fail('어떤 앱을 바꿀지 확인하지 못했어요.');
    }
    final sessionMinutes = (plan.sessionMinutes ?? 3).clamp(1, 60).toInt();
    final windowMinutes = (plan.windowMinutes ?? 60).clamp(5, 1440).toInt();

    final updated = s.copyWith(enforcementMode: ScheduleEnforcementMode.limitInSlot);
    await BlockScheduleStore.upsert(updated);

    var entries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(s.id),
    );
    entries = entries.map((e) {
      if (target.targetIds.contains(e.targetId)) {
        return e.copyWith(
          blockInSlot: false,
          limitEnabled: true,
          limitMinutes: sessionMinutes,
          windowMinutes: windowMinutes,
        );
      }
      return e;
    }).toList();

    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: s.id,
      entries: entries,
      schedule: updated,
    );
    await _upsertAndroidAppUsageLimitForNightSchedule(
      scheduleId: s.id,
      targetIds: target.targetIds,
      limitMinutes: sessionMinutes,
      windowMinutes: windowMinutes,
    );

    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    unawaited(IosRulesExportService.exportNow());

    return BlockChatResult(
      summary: plan.reply.isNotEmpty
          ? plan.reply
          : '「${s.name}」을(를) $windowMinutes분마다 $sessionMinutes분만 보는 방식으로 바꿨어요.${_matchNote(match)}',
      steps: [
        BlockChatAppliedStep(
          title: '스케줄 모드 변경',
          detail: '전체차단 → $windowMinutes분마다 $sessionMinutes분만 (「${s.name}」)',
          route: '/settings/block-schedules/${s.id}',
          routeLabel: '스케줄 편집',
        ),
      ],
    );
  }

  /// [_parseModifyScheduleApps]가 인식한 카탈로그 앱(카카오·틱톡·유튜브·
  /// 인스타·크롬·브런치·사파리)을 실제 [ScheduleAppTargetCatalog] 타깃
  /// id로 바꾼다. `_nightScheduleLimitTarget`을 그대로 재사용하지 않는 이유:
  /// 그건 "챗으로 새 완전차단 스케줄을 만들 때" 카카오·틱톡을 스코프 밖으로
  /// 막는 별개 정책(모아는 인앱 전용 제품이라 신규 완전차단 생성을 막음)이
  /// 섞여 있는데, 여기(기존 스케줄에 앱 추가/제거)는 그 정책과 무관하다 —
  /// 사용자가 이미 화면 안에서 직접 만든 스케줄(PC방 인증 앱 등)에 카카오를
  /// 추가하는 건 완전히 정상적인 요청이다.
  static List<String>? _catalogTargetIdsForModify(String platform, String? appId) {
    final id = appId ?? platform;
    switch (id) {
      case 'kakao':
      case 'kakaotalk':
        return const ['ios_kakao'];
      case 'tiktok':
        return const ['ios_tiktok'];
      case 'chrome':
        return const ['ios_chrome'];
      case 'youtube':
      case 'youtube_app':
        return const ['isle_youtube', 'ios_youtube'];
      case 'instagram':
        return const ['isle_instagram', 'ios_instagram'];
      case 'brunch':
        return const ['isle_brunch'];
      case 'safari':
        return const ['isle_customweb'];
      default:
        return null;
    }
  }

  static Future<BlockChatResult> _modifyScheduleApps(BlockChatPlan plan) async {
    final match = _resolvePlanSchedule(plan);
    if (match == null) {
      return BlockChatResult.fail('어떤 스케줄에 적용할지 찾지 못했어요. 스케줄 이름을 같이 말씀해 주세요.');
    }
    final s = match.schedule;
    final isAdd = plan.toggleOn ?? true;
    final label = _platformLabelForModify(plan);

    final blocked = await _ensureScheduleEditable(s, isAdd ? '앱 추가' : '앱 제거');
    if (blocked != null) return blocked;

    final targetIds = _catalogTargetIdsForModify(plan.limitPlatform ?? '', plan.appId);
    if (targetIds == null) {
      // 카탈로그 밖 앱 — 정확히 어떤 iOS 앱인지 앱이 스스로 알 방법이 없다
      // (bundle id를 지어낼 수 없음). Screen Time 추가 선택으로 안내한다.
      return BlockChatResult(
        summary: '$label은(는) 카탈로그에 없어서 자동으로는 못 골라요. '
            '스케줄 편집 화면 → "앱·카테고리 ${isAdd ? '수정' : '수정'}"에서 '
            '기존 선택에 ${isAdd ? '추가로' : '해제하며'} 골라주세요.',
        steps: [
          BlockChatAppliedStep(
            title: isAdd ? '앱 추가' : '앱 제거',
            detail: 'Screen Time 선택에서 직접 골라야 해요.',
            route: IsleRoutes.blockScheduleEditOutsideShell(s.id),
            routeLabel: '스케줄 보기',
            needsManualSetup: true,
          ),
        ],
      );
    }

    final existingEntries =
        ScheduleAppTargetsStore.mergeWithCatalog(ScheduleAppTargetsStore.loadForSchedule(s.id));
    final wantsRefill = s.enforcementMode == ScheduleEnforcementMode.limitInSlot;
    final entries = existingEntries.map((e) {
      if (!targetIds.contains(e.targetId)) return e;
      if (!isAdd) {
        return e.copyWith(blockInSlot: false, limitEnabled: false);
      }
      return wantsRefill
          ? e.copyWith(blockInSlot: false, limitEnabled: true)
          : e.copyWith(blockInSlot: true, limitEnabled: false);
    }).toList();

    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: s.id,
      entries: entries,
      schedule: s,
    );

    return BlockChatResult(
      summary: isAdd
          ? '「${s.name}」에 $label을(를) 추가했어요.${_matchNote(match)}'
          : '「${s.name}」에서 $label을(를) 뺐어요.${_matchNote(match)}',
      steps: [
        BlockChatAppliedStep(
          title: isAdd ? '앱 추가' : '앱 제거',
          detail: '$label · ${s.name}',
          route: IsleRoutes.blockScheduleEditOutsideShell(s.id),
          routeLabel: '스케줄 보기',
        ),
      ],
      impact: BlockChatApplySummary(
        headline: '「${s.name}」 $label ${isAdd ? '추가' : '제거'}',
        scheduleId: s.id,
      ),
    );
  }

  static String _platformLabelForModify(BlockChatPlan plan) {
    final id = plan.appId ?? plan.limitPlatform ?? '';
    switch (id) {
      case 'kakao':
      case 'kakaotalk':
        return '카카오톡';
      case 'tiktok':
        return 'TikTok';
      case 'chrome':
        return 'Chrome';
      case 'youtube':
      case 'youtube_app':
        return '유튜브';
      case 'instagram':
        return 'Instagram';
      case 'brunch':
        return 'Brunch';
      case 'safari':
        return 'Safari';
      default:
        return id.isEmpty ? '앱' : id;
    }
  }

  static Future<BlockChatResult> _renameSchedule(BlockChatPlan plan) async {
    final match = _resolvePlanSchedule(plan);
    if (match == null) {
      return BlockChatResult.fail('이름을 바꿀 스케줄을 찾지 못했어요.');
    }
    final newName = plan.scheduleNewName?.trim();
    if (newName == null || newName.isEmpty) {
      return BlockChatResult.fail(
        '새 이름을 알려주세요. 예: 「저녁 집중」으로 이름 바꿔줘',
      );
    }
    final s = match.schedule;
    final blocked = await _ensureScheduleEditable(s, '이름 변경');
    if (blocked != null) return blocked;

    final updated = s.copyWith(name: newName);
    await BlockScheduleStore.upsert(updated);
    final endMin = BlockChatScheduleResolver.morningEndMinute(updated) ?? 540;
    final days = updated.slots.map((sl) => sl.day).toSet().toList()..sort();
    return BlockChatResult(
      summary: '「${s.name}」→「$newName」${_matchNote(match)}',
      steps: [
        BlockChatAppliedStep(
          title: '이름 변경',
          detail: newName,
          route: IsleRoutes.blockScheduleEditOutsideShell(s.id),
          routeLabel: '스케줄 보기',
        ),
      ],
      impact: _scheduleImpact(
        headline: '「$newName」',
        scheduleId: s.id,
        endMin: endMin,
        days: days.isEmpty ? const [0, 1, 2, 3, 4, 5, 6] : days,
      ),
    );
  }

  static Future<BlockChatResult> _updateScheduleTime(BlockChatPlan plan) async {
    final match = _resolvePlanSchedule(plan);
    if (match == null) {
      return BlockChatResult.fail('시간을 바꿀 스케줄을 찾지 못했어요.');
    }
    final s = match.schedule;
    final blocked = await _ensureScheduleEditable(s, '시간 변경');
    if (blocked != null) return blocked;

    final endMin = plan.endHour * 60 + plan.endMinute;
    if (endMin <= 0 || endMin >= 1440) {
      return BlockChatResult.fail('0시~23시 59분 사이로 말해 주세요.');
    }

    final allDays = plan.days.length >= 7;
    final slots = BlockChatScheduleResolver.replaceMorningEnd(
      schedule: s,
      endMinute: endMin,
      days: allDays ? null : plan.days,
    );
    if (slots.isEmpty) {
      return BlockChatResult.fail('슬롯이 비어 있어요. 스케줄 편집 화면에서 확인해 주세요.');
    }

    final updated = s.copyWith(slots: slots);
    await BlockScheduleStore.upsert(updated);
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    final days = slots.map((sl) => sl.day).toSet().toList()..sort();
    return BlockChatResult(
      summary: '「${s.name}」 종료를 ${_fmt(endMin)}까지로 바꿨어요.${_matchNote(match)}',
      steps: [
        BlockChatAppliedStep(
          title: '종료 시각 변경',
          detail: '00:00 – ${_fmt(endMin)}',
          route: IsleRoutes.blockScheduleEditOutsideShell(s.id),
          routeLabel: '스케줄 보기',
        ),
      ],
      impact: _scheduleImpact(
        headline: '「${updated.name}」 시간 변경',
        scheduleId: s.id,
        endMin: endMin,
        days: days,
      ),
    );
  }

  static Future<BlockChatResult> _addScheduleDays(BlockChatPlan plan) async {
    final match = _resolvePlanSchedule(plan);
    if (match == null) {
      return BlockChatResult.fail('요일을 추가할 스케줄을 찾지 못했어요.');
    }
    final s = match.schedule;
    final blocked = await _ensureScheduleEditable(s, '요일 추가');
    if (blocked != null) return blocked;

    final endMin = BlockChatScheduleResolver.morningEndMinute(s) ??
        (plan.endHour * 60 + plan.endMinute).clamp(1, 1439);
    final slots = BlockChatScheduleResolver.addMorningDays(
      schedule: s,
      days: plan.days,
      endMinute: endMin,
    );
    final updated = s.copyWith(slots: slots);
    await BlockScheduleStore.upsert(updated);
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    final days = slots.map((sl) => sl.day).toSet().toList()..sort();
    return BlockChatResult(
      summary:
          '「${s.name}」에 ${ScheduleDisplayHelper.formatDaysPattern(plan.days.toSet())} 요일을 추가했어요.${_matchNote(match)}',
      steps: [
        BlockChatAppliedStep(
          title: '요일 추가',
          detail: ScheduleDisplayHelper.formatDaysPattern(plan.days.toSet()),
          route: IsleRoutes.blockScheduleEditOutsideShell(s.id),
          routeLabel: '스케줄 보기',
        ),
      ],
      impact: _scheduleImpact(
        headline: '「${updated.name}」 요일 추가',
        scheduleId: s.id,
        endMin: endMin,
        days: days,
      ),
    );
  }

  static Future<BlockChatResult> _removeScheduleDays(BlockChatPlan plan) async {
    final match = _resolvePlanSchedule(plan);
    if (match == null) {
      return BlockChatResult.fail('요일을 뺄 스케줄을 찾지 못했어요.');
    }
    final s = match.schedule;
    final blocked = await _ensureScheduleEditable(s, '요일 제거');
    if (blocked != null) return blocked;

    final slots = BlockChatScheduleResolver.removeDays(
      schedule: s,
      days: plan.days,
    );
    if (slots.isEmpty) {
      return BlockChatResult.fail('모든 요일을 빼면 스케줄이 비어요. 스케줄을 끄거나 편집해 주세요.');
    }

    final updated = s.copyWith(slots: slots);
    await BlockScheduleStore.upsert(updated);
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    final endMin = BlockChatScheduleResolver.morningEndMinute(updated) ?? 540;
    final days = slots.map((sl) => sl.day).toSet().toList()..sort();
    return BlockChatResult(
      summary:
          '「${s.name}」에서 ${ScheduleDisplayHelper.formatDaysPattern(plan.days.toSet())} 요일을 뺐어요.${_matchNote(match)}',
      steps: [
        BlockChatAppliedStep(
          title: '요일 제거',
          detail: ScheduleDisplayHelper.formatDaysPattern(plan.days.toSet()),
          route: IsleRoutes.blockScheduleEditOutsideShell(s.id),
          routeLabel: '스케줄 보기',
        ),
      ],
      impact: _scheduleImpact(
        headline: '「${updated.name}」 요일 제거',
        scheduleId: s.id,
        endMin: endMin,
        days: days,
      ),
    );
  }

  static Future<BlockChatResult> _toggleShorts(BlockChatPlan plan) async {
    final on = plan.toggleOn ?? true;
    await IsleUserDefaults.setHideYoutubeShorts(on);
    return BlockChatResult(
      summary: on ? 'YouTube Shorts 숨김을 켰어요.' : 'YouTube Shorts를 다시 보이게 했어요.',
      steps: [
        BlockChatAppliedStep(
          title: on ? 'Shorts 숨김 ON' : 'Shorts 숨김 OFF',
          detail: on ? '홈·피드·검색에서 숏츠 선반이 제거돼요.' : '숏츠 선반이 다시 보여요.',
          route: '/home/my-isle/manage',
          routeLabel: '유튜브·SNS 관리',
        ),
      ],
      impact: BlockChatApplySummary(
        headline: on ? 'YouTube Shorts 숨김' : 'Shorts 다시 표시',
        locations: [
          BlockChatApplyLocation(
            tabLabel: '유튜브·SNS 관리',
            detail: '숏츠 토글',
            icon: Icons.tune,
            route: '/home/my-isle/manage',
            routeLabel: '관리 센터',
          ),
          BlockChatApplyLocation(
            tabLabel: 'Isle 유튜브',
            detail: 'WebView·피드',
            icon: Icons.play_circle_filled,
            route: '/youtube',
            routeLabel: '유튜브',
          ),
        ],
        targets: [
          BlockChatApplyTarget(
            label: on ? 'Shorts 숨김' : 'Shorts 표시',
            icon: Icons.video_library_outlined,
            tint: const Color(0xFFFF0000),
          ),
        ],
      ),
    );
  }

  static Future<BlockChatResult> _toggleReels(BlockChatPlan plan) async {
    final on = plan.toggleOn ?? true;
    await IsleUserDefaults.setHideInstagramReels(on);
    return BlockChatResult(
      summary: on ? 'Instagram Reels 숨김을 켰어요.' : 'Reels를 다시 보이게 했어요.',
      steps: [
        BlockChatAppliedStep(
          title: on ? 'Reels 숨김 ON' : 'Reels 숨김 OFF',
          detail: on ? '인스타 WebView에서 릴·숏폼이 숨겨져요.' : '릴이 다시 보여요.',
          route: '/home/my-isle/manage',
          routeLabel: '유튜브·SNS 관리',
        ),
      ],
      impact: BlockChatApplySummary(
        headline: on ? 'Instagram Reels 숨김' : 'Reels 다시 표시',
        locations: const [
          BlockChatApplyLocation(
            tabLabel: '유튜브·SNS 관리',
            detail: '릴스 토글',
            icon: Icons.tune,
            route: '/home/my-isle/manage',
            routeLabel: '관리 센터',
          ),
          BlockChatApplyLocation(
            tabLabel: 'Instagram',
            detail: 'Isle WebView',
            icon: Icons.camera_alt_outlined,
            route: '/explore/browser?site=instagram',
            routeLabel: '인스타',
          ),
        ],
        targets: [
          BlockChatApplyTarget(
            label: on ? 'Reels 숨김' : 'Reels 표시',
            icon: Icons.movie_outlined,
          ),
        ],
      ),
    );
  }

  static Future<BlockChatResult> _nightSchedule(BlockChatPlan plan) async {
    await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);

    final startH = plan.startHour ?? 21;
    final startM = plan.startMinute ?? 0;
    final endH = plan.endHour;
    final endM = plan.endMinute;
    final startMin = (startH * 60 + startM).clamp(0, 1439);
    final endMin = (endH * 60 + endM).clamp(1, 1439);

    final slots = <ScheduleSlot>[
      for (final d in plan.days)
        ScheduleSlot(
            day: d.clamp(0, 6), startMinute: startMin, endMinute: endMin),
    ];
    // 완전 차단 구간이 나눠쓰기 구간 중간에 끼어 있어 앞뒤로 쪼개진 경우
    // (예: 22:30-23:00 나눠쓰기 / 23:00-13:00 완전차단 / 13:00-14:00 나눠쓰기)
    // 나머지 조각도 같은 세션·창으로 추가 슬롯을 건다(2026-07-11 cage 제보).
    final extra = plan.extraSlotMinutes;
    if (extra != null && extra.length >= 2) {
      for (var i = 0; i + 1 < extra.length; i += 2) {
        final s = extra[i].clamp(0, 1439);
        final e = extra[i + 1].clamp(1, 1439);
        for (final d in plan.days) {
          slots.add(ScheduleSlot(day: d.clamp(0, 6), startMinute: s, endMinute: e));
        }
      }
    }
    final name = plan.scheduleName?.isNotEmpty == true
        ? plan.scheduleName!
        : 'SNS 야간 차단 (AI)';
    // 어떤 앱을 대상으로 하는지는 "차단 모드"와 별개로 결정한다.
    // appId/limitPlatform이 명시되면 그 앱을, 없으면 기존 기본값인 Instagram을 따른다.
    // blockSafariNote(브라우저/사파리)만 명시되고 다른 카탈로그 타깃이 없으면
    // Instagram으로 새지 않는다 — 'safari'는 카탈로그 밖 앱이라
    // _nightScheduleLimitTarget이 못 알아듣고 null을 반환하는데, 예전엔 그
    // null을 무조건 Instagram으로 취급해서 "브라우저 차단해줘"가 Instagram
    // 야간 차단으로 둔갑하던 실사용 버그(cage 2026-07-11 발견, 이식).
    final namedTarget = _nightScheduleLimitTarget(plan);
    final baseTarget = namedTarget ??
        (plan.blockSafariNote
            ? (label: '브라우저(Safari)', targetIds: const <String>[])
            : (label: 'Instagram', targetIds: const ['isle_instagram']));
    // 다중 카테고리 요청(_parseMultiCategoryNightBlock, cage 2026-07-11 이식)은
    // extraTargetIds에 카탈로그 타깃을 여러 개 담아 보낸다 — 그 경우
    // baseTarget(단일 앱 전용 로직)이 아니라 이 목록 전부를 한 스케줄에 건다.
    final resolvedTarget = (plan.extraTargetIds?.isNotEmpty ?? false)
        ? (
            label: plan.scheduleName?.replaceAll(' 차단 (AI)', '') ?? baseTarget.label,
            targetIds: plan.extraTargetIds!,
          )
        : baseTarget;
    // "나눠 쓰기(리필)"는 세션·창·쿨다운을 명시했을 때만 — 그 외엔 완전 차단.
    final wantsRefill = plan.sessionMinutes != null ||
        plan.windowMinutes != null ||
        plan.cooldownMinutes != null;
    final limitMinutes =
        (plan.sessionMinutes ?? plan.dailyMinutes ?? 3).clamp(1, 60).toInt();
    final windowMinutes = (plan.windowMinutes ?? 60).clamp(5, 1440).toInt();

    final targetMode = wantsRefill
        ? ScheduleEnforcementMode.limitInSlot
        : ScheduleEnforcementMode.fullBlock;
    final existing = plan.disableFuzzyDedup
        ? BlockChatScheduleDedup.findExactName(name)
        : BlockChatScheduleDedup.findNightSns(
              preferredName: name,
              targetIds: resolvedTarget.targetIds,
            ) ??
            BlockChatScheduleDedup.findExactName(name);
    final schedule = existing ??
        await BlockScheduleStore.create(
          name: name,
          slots: slots,
          locked: true,
          lockCooldownMinutes: IsleUserDefaults.defaultScheduleLockCooldownMinutes,
          enforcementMode: targetMode,
          blockIsleInApp: plan.blockSafariNote,
        );
    // 기존 스케줄을 재사용할 때 slots를 통째로 덮어쓰면 이미 있던 다른
    // 시간대(예: 14:00-16:00)가 조용히 지워진다(cage에서 먼저 발견·수정한
    // 실사용 버그, 2026-07-13 이식 — "23:00~07:00 브라우저 차단해줘"를 보내면
    // 기존 14:00-16:00 차단이 사라짐). 같은 (시작,종료) 시간대만 갱신하고,
    // 다른 시간대는 그대로 남겨 하나의 스케줄에 여러 시간대가 공존하게 한다.
    final mergedSlots =
        existing != null ? _mergeNightSlots(schedule.slots, slots) : slots;
    final enabled = schedule.copyWith(
      enabled: true,
      enforcementMode: targetMode,
      blockIsleInApp: plan.blockSafariNote,
      locked: true,
      slots: mergedSlots,
    );
    await BlockScheduleStore.upsert(enabled);

    final nightRationTag = plan.appId ?? plan.limitPlatform ?? '';
    final disableResult = nightRationTag.isEmpty
        ? (disabled: const <String>[], lockedSkipped: const <String>[])
        : await _disableConflictingRationSchedules(
            nightRationTag,
            plan,
            excludeName: name,
          );

    final oldEntries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(schedule.id),
    );
    var entries = oldEntries;
    if (!wantsRefill) {
      entries = entries.map((e) {
        if (resolvedTarget.targetIds.contains(e.targetId)) {
          return e.copyWith(blockInSlot: true, limitEnabled: false);
        }
        return e;
      }).toList();
    } else {
      entries = entries.map((e) {
        if (resolvedTarget.targetIds.contains(e.targetId)) {
          return e.copyWith(
            blockInSlot: false,
            limitEnabled: true,
            limitMinutes: limitMinutes,
            windowMinutes: windowMinutes,
          );
        }
        return e;
      }).toList();
      await _upsertAndroidAppUsageLimitForNightSchedule(
        scheduleId: schedule.id,
        targetIds: resolvedTarget.targetIds,
        limitMinutes: limitMinutes,
        windowMinutes: windowMinutes,
      );
    }

    // 잠긴 스케줄에 "완화"(더 풀어주는 쪽) 요청이면 saveAndSync가 조용히
    // 되돌린다(스플릿-브레인 방지) — 그 대신 여기서 감지해
    // SchedulePendingTargetService에 예약해서, 잠금 편집창이 열리면 자동으로
    // 적용되게 한다(Cage에서 먼저 발견·구현, 2026-07-11 이식).
    Duration? relaxationQueuedRemaining;
    if (ScheduleAppTargetsStore.hasSavedEntries(schedule.id) &&
        ScheduleEditGuard.isCommitmentLocked(enabled)) {
      final oldById = {for (final e in oldEntries) e.targetId: e};
      for (final targetId in resolvedTarget.targetIds) {
        final old = oldById[targetId];
        final desired = entries.firstWhere((e) => e.targetId == targetId,
            orElse: () => old ?? const ScheduleAppTargetEntry(targetId: ''));
        if (old == null || desired.targetId.isEmpty) continue;
        if (!ScheduleAppTargetsGuard.isRelaxation(old, desired)) continue;
        final outcome = await SchedulePendingTargetService.requestEntryChange(
          schedule: enabled,
          desired: desired,
          currentPersisted: old,
        );
        if (outcome.kind == ScheduleTargetChangeOutcomeKind.scheduled ||
            outcome.kind == ScheduleTargetChangeOutcomeKind.alreadyPending) {
          relaxationQueuedRemaining = outcome.remaining;
        }
      }
    }

    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: schedule.id,
      entries: entries,
      schedule: enabled,
    );

    await ScheduleScreenTimeStore.ensureOpen();
    var pickerDone = ScheduleScreenTimeStore.appCountFor(schedule.id) > 0;
    if (!pickerDone &&
        (IsleApplePlatform.isScreenTimeHost || Platform.isAndroid)) {
      pickerDone = await ScheduleScreenTimeService.pickForSchedule(schedule.id);
      if (pickerDone) {
        await ScheduleAppLimitSyncService.syncAll();
      }
    }

    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    unawaited(IosRulesExportService.exportNow());

    final editRoute = IsleRoutes.blockScheduleEditOutsideShell(schedule.id);
    final rangeLabel =
        '${_fmt(startMin)}–${_fmt(endMin)}${startMin > endMin ? ' (다음날)' : ''}';

    final targetLabel = resolvedTarget.label;
    final limitDetail = '$targetLabel $limitMinutes분/$windowMinutes분 리필';
    final overwriteNote = _overwriteNote(disableResult);
    // 완화 요청이 예약 큐로 들어갔으면 "지금은 안 바뀌었지만 언제 자동
    // 적용되는지"까지 명확히 알려준다 — 예전엔 조용히 씹혀서 채팅이 "리필
    // 스케줄을 만들었어요"라고 거짓 보고했다(Cage에서 먼저 발견, 이식).
    final relaxationNote = relaxationQueuedRemaining != null
        ? '🔒 $targetLabel 완화 요청은 잠금 중이라 지금은 못 바꿨어요 — '
            // formatRemaining()이 이미 "N분 후 적용" 형태로 완결된 문장을
            // 돌려주므로 뒤에 "자동으로 적용할게요"를 또 붙이면 "적용 적용"처럼
            // 중복돼 어색해진다.
            '${SchedulePendingTargetService.formatRemaining(relaxationQueuedRemaining)}돼요.\n\n'
        : '';

    return BlockChatResult(
      summary: relaxationNote +
          (plan.reply.isNotEmpty
              ? plan.reply
              : !wantsRefill
                  ? '야간 $targetLabel 차단 스케줄을 만들었어요.'
                  : '야간 $targetLabel 리필 스케줄을 만들었어요.') +
          overwriteNote,
      steps: [
        BlockChatAppliedStep(
          title: '야간 스케줄',
          detail: !wantsRefill
              ? '매일 $rangeLabel · $targetLabel 차단 (타임락 켜짐)'
              : '매일 $rangeLabel · $limitDetail (타임락 켜짐)',
          route: editRoute,
          routeLabel: '스케줄 편집',
        ),
        // isle_* 타깃만 있으면(인앱 브라우저·유튜브·인스타 등) Screen Time
        // 앱 선택 자체가 필요 없다 — 예전엔 이 스텝이 무조건 붙어서 이미
        // 100% 자동으로 막힌 인앱 대상에도 "Screen Time으로 선택하세요"라는
        // 잘못된 안내가 나갔다(2026-07-12 발견).
        if (!_isIsleOnlyTargetIds(resolvedTarget.targetIds))
          BlockChatAppliedStep(
            title: !wantsRefill ? 'iPhone $targetLabel' : targetLabel,
            detail: pickerDone
                ? 'Screen Time 앱 차단이 연결됐어요.'
                : '스케줄 편집 → ③에서 $targetLabel 앱을 Screen Time으로 선택하세요.',
            route: editRoute,
            routeLabel: pickerDone ? '스케줄 확인' : '앱 선택',
            needsManualSetup: !pickerDone,
          ),
      ],
      impact: _scheduleImpact(
        headline: name,
        scheduleId: schedule.id,
        endMin: endMin,
        days: plan.days,
        targets: [
          BlockChatApplyTarget(
            label: !wantsRefill ? targetLabel : limitDetail,
            icon: !wantsRefill
                ? Icons.camera_alt_outlined
                : Icons.timer_outlined,
          ),
        ],
        pendingSteps: pickerDone || _isIsleOnlyTargetIds(resolvedTarget.targetIds)
            ? const []
            : [
                BlockChatAppliedStep(
                  title: '$targetLabel 앱 선택',
                  detail: '스케줄 편집 → ③ iPhone 앱 → $targetLabel을 선택하세요.',
                  route: editRoute,
                  routeLabel: '앱 선택',
                  needsManualSetup: true,
                ),
              ],
      ),
    );
  }

  /// isle_* 타깃만 있으면(비어있지 않고 전부 isle) Screen Time 앱 선택 없이
  /// 100% 자동으로 막힌다는 뜻 — 관련 안내 스텝을 붙일지 판단하는 데 쓴다.
  static bool _isIsleOnlyTargetIds(List<String> targetIds) {
    if (targetIds.isEmpty) return false;
    return targetIds.every((id) => ScheduleAppTargetCatalog.defFor(id)?.isIsle == true);
  }

  /// 같은 (시작,종료) 시간대의 기존 슬롯만 새 슬롯으로 교체하고, 다른 시간대는
  /// 그대로 남긴다 — 한 스케줄에 여러 시간대가 공존할 수 있게(cage 2026-07-13
  /// 이식).
  static List<ScheduleSlot> _mergeNightSlots(
    List<ScheduleSlot> existingSlots,
    List<ScheduleSlot> newSlots,
  ) {
    if (newSlots.isEmpty) return existingSlots;
    final newStart = newSlots.first.startMinute;
    final newEnd = newSlots.first.endMinute;
    final kept = existingSlots
        .where((s) => !(s.startMinute == newStart && s.endMinute == newEnd))
        .toList();
    return [...kept, ...newSlots];
  }

  static ({String label, List<String> targetIds})? _nightScheduleLimitTarget(
    BlockChatPlan plan,
  ) {
    final appId = (plan.appId ?? '').toLowerCase();
    final platform = (plan.limitPlatform ?? '').toLowerCase();
    // 모아는 인앱(isle_*) 전용 제품 스코프(2026-07-11 확정) — 카카오톡·틱톡은
    // 모아 안에 대응하는 인앱 화면이 없어(외부 iOS 앱뿐) "완전 차단"은 스코프
    // 밖으로 뺐다(2026-07-12). 단, "N분마다 M분만"류 나눠쓰기(limit-in-slot,
    // sessionMinutes/windowMinutes 존재)는 실제 카카오·틱톡 앱 사용량을
    // Screen Time으로 관찰해야만 가능한 별개의 기존 기능이라(모아 안에 대체
    // 수단이 없음) 그대로 ios_kakao/ios_tiktok를 쓴다 — 완전 차단만 막는다.
    final isKakaoOrTiktok = appId == 'kakao' ||
        platform == 'kakao' ||
        platform == 'kakaotalk' ||
        platform == '카카오톡' ||
        appId == 'tiktok' ||
        platform == 'tiktok';
    final isRationing = plan.sessionMinutes != null || plan.windowMinutes != null;
    if (isKakaoOrTiktok && !isRationing) return null;
    if (isKakaoOrTiktok && isRationing) {
      final isKakao = appId == 'kakao' ||
          platform == 'kakao' ||
          platform == 'kakaotalk' ||
          platform == '카카오톡';
      return isKakao
          ? (label: '카카오톡', targetIds: const ['ios_kakao'])
          : (label: 'TikTok', targetIds: const ['ios_tiktok']);
    }
    if (appId == 'youtube_app' || platform == 'youtube') {
      return (label: 'YouTube', targetIds: const ['isle_youtube']);
    }
    if (platform == 'instagram') {
      return (label: 'Instagram', targetIds: const ['isle_instagram']);
    }
    // "브라우저/인터넷/사파리"는 Isle 자체 인앱 브라우저(isle_customweb)를
    // 직접 막는다 — 100% 자동, Screen Time 권한·앱 선택 불필요. 예전엔 여기서
    // targetIds를 비워 사용자가 Screen Time에서 외부 Safari를 직접 고르게
    // 했는데, Isle에 이미 자체 웹 탐색 화면이 있어서 그럴 필요가 없었다
    // (2026-07-12 발견 — "모아는 자체 브라우저가 있다" 사용자 지적).
    if (appId == 'safari' || platform == 'safari') {
      return (label: '인앱 브라우저', targetIds: const ['isle_customweb']);
    }
    // "크롬 차단해줘"류 — Isle 자체 브라우저는 아니고 별도 설치된 앱이라
    // ios_chrome(Screen Time 앱 쉴드)으로 완전 차단한다(2026-[REDACTED], 유튜브
    // 우회 경로로 Chrome을 쓰는 사례 대응 — TODO.md 참고).
    if (appId == 'chrome' || platform == 'chrome' || platform == '크롬') {
      return (label: 'Chrome', targetIds: const ['ios_chrome']);
    }
    if (appId.isNotEmpty || platform.isNotEmpty) {
      // 이름은 짚었는데(예: 넷플릭스·디스코드) 카탈로그에 없는 경우도 같은
      // 이유로 Instagram으로 새지 않게 한다 — 라벨만 있는 그대로 돌려주고
      // targetIds는 비워서 Screen Time 선택에 맡긴다.
      final label = platform.isNotEmpty ? platform : appId;
      return (label: label, targetIds: const []);
    }
    if (plan.sessionMinutes != null || plan.windowMinutes != null) {
      return (
        label: 'Instagram',
        targetIds: const ['isle_instagram'],
      );
    }
    return null;
  }

  static Future<void> _upsertAndroidAppUsageLimitForNightSchedule({
    required String scheduleId,
    required List<String> targetIds,
    required int limitMinutes,
    required int windowMinutes,
  }) async {
    final rules = AppUsageLimitStore.loadRules();
    var changed = false;
    for (final targetId in targetIds) {
      final def = ScheduleAppTargetCatalog.defFor(targetId);
      final pkg = def?.androidPackage;
      if (def == null || pkg == null || pkg.isEmpty) continue;
      final rule = AppUsageLimitRule(
        id: 'schedule_${scheduleId}_${def.bundleId}',
        label: def.label,
        minutesPerWindow: limitMinutes,
        enabled: true,
        presetId: def.id,
        scheduleId: scheduleId,
        androidPackageName: pkg,
        windowMinutes: windowMinutes,
        interventionTitle: '${def.label} 리필 한도',
        interventionBody: '스케줄 시간에는 $limitMinutes분만 허용돼요.',
      );
      final idx = rules.indexWhere((r) => r.id == rule.id);
      if (idx >= 0) {
        rules[idx] = rule;
      } else {
        rules.add(rule);
      }
      changed = true;
    }
    if (changed) await AppUsageLimitStore.saveRules(rules);
  }

  /// "분리해줘" — 병합돼 여러 시간대를 가진 야간 스케줄 하나를, 시간대(시작,
  /// 종료)별로 별개 스케줄 여러 개로 나눈다(cage 2026-07-13 이식).
  static Future<BlockChatResult> _splitNightSchedule(BlockChatPlan plan) async {
    final namedTarget = _nightScheduleLimitTarget(plan);
    final baseTarget = namedTarget ??
        (plan.blockSafariNote
            ? (label: '브라우저(Safari)', targetIds: const <String>[])
            : (label: 'Instagram', targetIds: const ['isle_instagram']));
    final resolvedTarget = (plan.extraTargetIds?.isNotEmpty ?? false)
        ? (
            label: plan.scheduleName?.replaceAll(' 차단 (AI)', '') ?? baseTarget.label,
            targetIds: plan.extraTargetIds!,
          )
        : baseTarget;

    final name = plan.scheduleName?.isNotEmpty == true
        ? plan.scheduleName!
        : 'SNS 야간 차단 (AI)';
    final schedule = BlockChatScheduleDedup.findNightSns(
          preferredName: name,
          targetIds: resolvedTarget.targetIds,
        ) ??
        BlockChatScheduleDedup.findExactName(name);

    if (schedule == null) {
      return const BlockChatResult(
        summary: '분리할 스케줄을 찾지 못했어요. 방금 만든 스케줄이 맞는지 확인해 주세요.',
        steps: [],
        isFailure: true,
      );
    }

    // 분리는 원본 스케줄의 slots를 비우는 수정 작업이라, 시간 변경과 똑같이
    // 커밋먼트 락(타임락)의 보호를 받아야 한다 — 안 그러면 "분리"를 자기
    // 차단을 몰래 느슨하게 만드는 우회로로 쓸 수 있다. 병합 직후엔 그
    // 병합 자체가 스케줄을 즉시 잠그므로(모든 night_schedule 적용이 그렇듯)
    // 이 케이스가 실사용에서 흔하다 — 정직하게 안내한다.
    if (ScheduleEditGuard.isCommitmentLocked(schedule)) {
      return BlockChatResult(
        summary: '⚠️ 이 스케줄은 타임락 중이라 지금은 분리할 수 없어요. '
            '스케줄 편집 화면에서 잠금을 해제한 뒤 다시 "분리해줘"라고 말해주세요.',
        steps: [
          BlockChatAppliedStep(
            title: '스케줄 편집',
            detail: '잠금을 해제한 뒤 다시 분리를 요청해 주세요.',
            route: IsleRoutes.blockScheduleEditOutsideShell(schedule.id),
            routeLabel: '스케줄 편집',
            needsManualSetup: true,
          ),
        ],
        isFailure: true,
      );
    }

    final buckets = <(int, int), List<ScheduleSlot>>{};
    for (final s in schedule.slots) {
      final key = (s.startMinute, s.endMinute);
      buckets.putIfAbsent(key, () => []).add(s);
    }

    if (buckets.length < 2) {
      return const BlockChatResult(
        summary: '이 스케줄엔 시간대가 하나뿐이라 나눌 게 없어요.',
        steps: [],
        isFailure: true,
      );
    }

    final entries = ScheduleAppTargetsStore.loadForSchedule(schedule.id);
    final targetLabel = resolvedTarget.label;
    final createdRanges = <String>[];
    var i = 1;
    for (final bucket in buckets.entries) {
      final (startMin, endMin) = bucket.key;
      final rangeLabel =
          '${_fmt(startMin)}–${_fmt(endMin)}${startMin > endMin ? ' (다음날)' : ''}';
      final newName = '$targetLabel 스케줄 $i ($rangeLabel) (AI)';
      final created = await BlockScheduleStore.create(
        name: newName,
        slots: bucket.value,
        locked: schedule.locked,
        lockCooldownMinutes: schedule.lockCooldownMinutes,
        enforcementMode: schedule.enforcementMode,
        blockIsleInApp: schedule.blockIsleInApp,
      );
      if (entries.isNotEmpty) {
        await ScheduleAppTargetsStore.saveForSchedule(created.id, entries);
      }
      createdRanges.add('$newName · $rangeLabel');
      i++;
    }

    // 원본은 재사용 불가(락 중엔 delete가 조용히 실패할 수 있음)하니
    // 삭제 대신 끄고 비워서 중복 차단이 안 남게 한다.
    await BlockScheduleStore.upsert(
      schedule.copyWith(enabled: false, slots: const []),
    );
    await ScheduleAppTargetsStore.saveForSchedule(schedule.id, const []);

    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    unawaited(IosRulesExportService.exportNow());

    return BlockChatResult(
      summary: '$targetLabel 스케줄을 ${buckets.length}개로 분리했어요:\n'
          '${createdRanges.map((r) => '· $r').join('\n')}',
      steps: [
        for (final r in createdRanges)
          BlockChatAppliedStep(title: '새 스케줄', detail: r),
      ],
    );
  }

  static Future<BlockChatResult> _toggleReelsGuard(BlockChatPlan plan) async {
    final on = plan.toggleOn ?? true;
    await IsleUserDefaults.setInstagramReelsGuardEnabled(on);
    return BlockChatResult(
      summary: on ? '인스타 릴스 둠스크롤 멈춤을 켰어요.' : '릴스 둠스크롤 멈춤을 껐어요.',
      steps: [
        BlockChatAppliedStep(
          title: on ? '둠스크롤 멈춤 ON' : '둠스크롤 멈춤 OFF',
          detail: on ? '피드에서 넘긴 영상이 임계치를 넘으면 멈춤 화면이 떠요.' : '무한 스크롤 가드가 꺼져요.',
          route: '/home/my-isle/manage',
          routeLabel: '유튜브·SNS 관리',
        ),
      ],
      impact: BlockChatApplySummary(
        headline: on ? '릴스 둠스크롤 멈춤' : '둠스크롤 멈춤 해제',
        locations: const [
          BlockChatApplyLocation(
            tabLabel: '유튜브·SNS 관리',
            detail: '릴스 둠스크롤 멈춤 토글',
            icon: Icons.tune,
            route: '/home/my-isle/manage',
            routeLabel: '관리 센터',
          ),
        ],
        targets: [
          BlockChatApplyTarget(
            label: on ? '둠스크롤 멈춤' : '가드 해제',
            icon: Icons.pause_circle_outline,
          ),
        ],
      ),
    );
  }

  static Future<BlockChatResult> _safariPause(BlockChatPlan plan) async {
    var mins = (plan.pauseMinutes ?? 10).clamp(5, 15);
    if (mins != 5 && mins != 10 && mins != 15) {
      mins = mins <= 7 ? 5 : (mins <= 12 ? 10 : 15);
    }

    if (SafariPauseService.isPaused) {
      return BlockChatResult.fail(
        '이미 Safari·앱 쉴드가 임시 해제 중이에요. '
        '차단 탭에서 「즉시 재잠금」을 누르거나 만료 후 다시 시도해 주세요.',
      );
    }
    if (!ExternalAppShieldStore.isOpen ||
        ExternalAppShieldStore.syncWithBlockSchedule ||
        !ExternalAppShieldStore.hasSelection) {
      return BlockChatResult.fail(
        '항상-막기 쉴드가 켜져 있지 않아요.\n'
        '차단 탭 → Safari·앱 선택 → 「항상 막기」를 먼저 켜 주세요.',
      );
    }

    await SafariPauseService.pauseFor(mins);
    return BlockChatResult(
      summary: plan.reply.isNotEmpty
          ? plan.reply
          : 'Safari·앱 쉴드를 ${mins}분만 임시 해제했어요. 만료 후 자동 재잠금.',
      steps: [
        BlockChatAppliedStep(
          title: '임시 해제 ${mins}분',
          detail: '만료 전에는 차단 탭에서 「즉시 재잠금」으로 되돌릴 수 있어요.',
          route: '/home/block',
          routeLabel: '차단 탭',
        ),
      ],
      impact: BlockChatApplySummary(
        headline: 'Safari 잠깐 풀기 · ${mins}분',
        locations: const [
          BlockChatApplyLocation(
            tabLabel: '차단 탭',
            detail: 'Safari 잠깐 풀기 위젯',
            icon: Icons.shield_outlined,
            route: '/home/block',
            routeLabel: '차단 탭',
          ),
        ],
        targets: [
          BlockChatApplyTarget(
            label: '${mins}분 임시 해제',
            icon: Icons.timer_outlined,
          ),
        ],
      ),
    );
  }

  static Future<BlockChatResult> _blockWebsite(BlockChatPlan plan) async {
    final raw = plan.websiteDomain?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) {
      return BlockChatResult.fail('차단할 도메인을 알려주세요.');
    }
    await WebsiteBlockStore.ensureOpen();
    final domain = WebsiteBlockStore.normalizeDomain(raw) ?? raw;
    final ok = await WebsiteBlockStore.addCustomDomain(domain);
    if (!ok) {
      return BlockChatResult.fail('도메인 「$raw」 형식을 확인해 주세요.');
    }
    // 번호-우회 미러 사이트로 감지된 경우, 정확한 도메인 하나뿐 아니라
    // 어간도 항상-켜짐 정규식 패턴으로 같이 저장해 아직 안 나온 번호
    // 변형(mingky06.live 등)까지 계속 막히게 한다.
    final stem = plan.websiteDomainStem;
    if (stem != null && stem.isNotEmpty) {
      await AlwaysOnUrlPatternStore.ensureOpen();
      await AlwaysOnUrlPatternStore.addStem(stem);
    }
    unawaited(IosRulesExportService.exportNow());

    final catalogLabel = WebsiteBlockStore.catalog
        .where((c) => c.domain == domain)
        .map((c) => c.label)
        .firstOrNull;

    return BlockChatResult(
      summary: plan.reply.isNotEmpty
          ? plan.reply
          : 'Safari Content Blocker에 「$domain」을 추가했어요.',
      steps: [
        BlockChatAppliedStep(
          title: '웹사이트 차단',
          detail: catalogLabel != null
              ? '$catalogLabel ($domain) — Safari만 해당 · Isle WebView 무관'
              : '「$domain」 — iOS 설정 → Safari → 확장 프로그램에서 Isle 활성화 필요',
          route: '/home/block',
          routeLabel: '차단 탭',
        ),
      ],
      impact: BlockChatApplySummary(
        headline: 'Safari · $domain',
        locations: const [
          BlockChatApplyLocation(
            tabLabel: '차단 탭',
            detail: '웹사이트 차단',
            icon: Icons.language,
            route: '/home/block',
            routeLabel: '차단 탭',
          ),
        ],
        targets: [
          BlockChatApplyTarget(label: domain, icon: Icons.block),
        ],
      ),
    );
  }

  static Future<BlockChatResult> _blockUrl(BlockChatPlan plan) async {
    final raw = plan.removeUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return BlockChatResult.fail('차단할 URL을 알려주세요.');
    }
    await BlockedUrlStore.ensureOpen();
    final ok = await BlockedUrlStore.add(raw);
    if (!ok) {
      return BlockChatResult.fail('URL 형식을 확인해 주세요.');
    }
    final label = raw.length > 48 ? '${raw.substring(0, 45)}…' : raw;
    return BlockChatResult(
      summary: plan.reply.isNotEmpty ? plan.reply : 'URL 차단을 추가했어요.',
      steps: [
        BlockChatAppliedStep(
          title: 'URL 차단',
          detail: '「$label」 — Isle·피드·유튜브에서 열리지 않아요.',
          route: '/home/my-isle/manage',
          routeLabel: '숨김·차단 목록',
        ),
      ],
      impact: BlockChatApplySummary(
        headline: 'URL 차단',
        targets: [BlockChatApplyTarget(label: label, icon: Icons.link_off)],
      ),
    );
  }

  static Future<BlockChatResult> _blockChannel(BlockChatPlan plan) async {
    final name = plan.channelName?.trim();
    if (name == null || name.isEmpty) {
      return BlockChatResult.fail('숨길 채널 이름을 알려주세요.');
    }
    await BlockedChannelStore.ensureOpen();
    final channels = List<BlockedChannel>.from(BlockedChannelStore.loadAll());
    final lower = name.toLowerCase();
    if (channels.any((c) => c.channelName.toLowerCase() == lower)) {
      return BlockChatResult(
        summary: '채널 「$name」은 이미 숨김 목록에 있어요.',
        steps: const [
          BlockChatAppliedStep(
            title: '채널 숨김',
            detail: '피드·유튜브에서 해당 채널이 필터됩니다.',
            route: '/home/my-isle/manage',
            routeLabel: '숨김 목록',
          ),
        ],
      );
    }
    channels.add(
      BlockedChannel(
        channelId: '',
        channelName: name,
        blockedAt: DateTime.now(),
      ),
    );
    await BlockedChannelStore.saveAll(channels);
    YoutubeBlockRulesSync.scheduleExport();

    return BlockChatResult(
      summary: plan.reply.isNotEmpty ? plan.reply : '채널 「$name」을 숨겼어요.',
      steps: [
        BlockChatAppliedStep(
          title: '채널 숨김',
          detail: '피드·유튜브에서 「$name」 채널이 필터됩니다.',
          route: '/home/my-isle/manage',
          routeLabel: '숨김 목록',
        ),
      ],
      impact: BlockChatApplySummary(
        headline: '채널 숨김',
        targets: [
          BlockChatApplyTarget(label: name, icon: Icons.person_off_outlined)
        ],
      ),
    );
  }

  /// "모든 게임 채널 차단해줘" — ChannelGenreAiService 가 주제 라벨로 관련 채널을 찾아
  /// 키워드+채널 규칙을 일괄 추가한다. AI 미설정이면 서비스 내부에서 로컬 폴백으로 처리.
  /// "주식 관련 앱들을 차단해주라" — 실제 증권앱 패키지ID는 지어낼 수 없어 바로 차단하지 않고
  /// 어떤 앱/URL인지 되묻는다. 사용자가 이름/URL을 대면 기존 block_website·add_keyword가 처리한다.
  static BlockChatResult _financeGuidance(BlockChatPlan plan) {
    return BlockChatResult(
      summary: plan.reply,
      steps: const [],
      suggestions: const [
        BlockChatSuggestion(
          id: 'finance_examples',
          label: '어떤 증권 앱이 있나요?',
          kind: 'faq',
          answer: '토스증권, 카카오페이증권, 삼성증권, 키움증권(영웅문), 미래에셋증권 등이 많이 쓰여요. '
              '"OO 막아줘"라고 말씀해 주시면 바로 차단해드려요.',
        ),
        BlockChatSuggestion(
          id: 'finance_how',
          label: 'URL로도 되나요?',
          kind: 'faq',
          answer: '네, "toss.im 막아줘"처럼 사이트 주소를 말씀해 주셔도 바로 차단돼요.',
        ),
      ],
    );
  }

  static Future<BlockChatResult> _applyGenreBlock(
    BlockChatPlan plan,
    WidgetRef? ref,
  ) async {
    final topicLabel = plan.topicLabel;
    if (topicLabel == null || topicLabel.isEmpty) {
      return BlockChatResult.fail('차단할 장르·주제를 찾지 못했어요.');
    }
    if (ref == null) {
      return BlockChatResult.fail('지금 화면에서는 이 기능을 쓸 수 없어요. 채팅 화면에서 다시 시도해 주세요.');
    }

    final result = await ChannelGenreAiService.applyTopicLabel(
      ref,
      topicLabel: topicLabel,
      languageCode: plan.languageCode,
    );
    if (result == null) {
      return BlockChatResult.fail('「$topicLabel」 관련 채널을 찾지 못했어요.');
    }

    return BlockChatResult(
      summary: plan.reply.isNotEmpty
          ? plan.reply
          : '「${result.genreLabel}」 관련 채널을 차단했어요.',
      steps: [
        BlockChatAppliedStep(
          title: '「${result.genreLabel}」 장르 차단',
          detail: '채널 +${result.channelsAdded} · 키워드 +${result.keywordsAdded}'
              '${result.usedAi ? '' : ' (로컬 매칭, AI 미설정)'}',
          route: '/home/my-isle/manage',
          routeLabel: '유튜브·SNS 관리',
        ),
      ],
    );
  }

  static Future<BlockChatResult> _applyPremadePack(BlockChatPlan plan) async {
    final packId = plan.presetId;
    if (packId == null || packId.isEmpty) {
      return BlockChatResult.fail('적용할 프리셋을 확인하지 못했어요.');
    }

    final result = await PremadeBlockPackService.applyPack(packId);
    final pack = await PremadeBlockPackService.packById(packId);
    final label = pack?.displayName ?? '프리셋';
    final total = result.channelsAdded +
        result.keywordsAdded +
        result.urlsAdded +
        result.domainsAdded;

    final steps = <BlockChatAppliedStep>[
      BlockChatAppliedStep(
        title: label,
        detail: '도메인 +${result.domainsAdded} · 채널 +${result.channelsAdded} · '
            'URL +${result.urlsAdded} · 키워드 +${result.keywordsAdded}'
            '${result.skipped > 0 ? ' (중복 ${result.skipped}건 제외)' : ''}',
        route: '/home/my-isle/manage',
        routeLabel: '차단 관리',
      ),
    ];
    if (plan.suggestTimelock) {
      steps.add(
        const BlockChatAppliedStep(
          title: '타임락 (권장)',
          detail: 'YouTube 탭 → 「타임락」을 켜면 24시간 잠금 + 해제 대기로 '
              '설정 변경을 더 어렵게 할 수 있어요.',
          route: '/youtube',
          routeLabel: '유튜브 · 타임락',
        ),
      );
    }

    return BlockChatResult(
      summary: plan.reply.isNotEmpty
          ? plan.reply
          : '$label 을(를) 적용했어요. 규칙 $total개가 추가됐어요.',
      steps: steps,
      suggestions: plan.suggestTimelock ? _timelockFaqSuggestions : const [],
    );
  }

  /// 타임락 권유 후 궁금해서 누를 수 있는 FAQ 칩 — 캔드 답변, API 호출 없음(CHAT_SPEC SUGGEST).
  static const _timelockFaqSuggestions = [
    BlockChatSuggestion(
      id: 'timelock_why',
      label: '왜 타임락이 좋아요?',
      kind: 'faq',
      answer: '타임락을 켜면 24시간 동안 해당 차단을 못 풀어요. '
          '충동적으로 "잠깐만 풀어야지" 하는 순간을 막아주는 장치예요.',
    ),
    BlockChatSuggestion(
      id: 'timelock_undo',
      label: '타임락 나중에 풀 수 있나요?',
      kind: 'faq',
      answer: '네, 언제든 끌 수 있어요. 다만 끄기를 누른 뒤에도 24시간 대기 후에 실제로 풀려요 — '
          '그게 타임락의 핵심이에요.',
    ),
  ];

  static Future<BlockChatResult> _platformLimit(BlockChatPlan plan) async {
    await PlatformWatchLimitStore.ensureOpen();
    final platform = plan.limitPlatform?.toLowerCase() ?? 'instagram';
    final id = switch (platform) {
      'brunch' => PlatformWatchId.brunch,
      _ => PlatformWatchId.instagram,
    };
    final minutes = (plan.dailyMinutes ?? 30).clamp(5, 480).toInt();
    final label = PlatformWatchLimitStore.label(id);

    if (!PlatformWatchLimitStore.canChangeLimit(
      id: id,
      newMinutes: minutes,
      newEnabled: true,
    )) {
      final lockMsg = ScheduleEditGuard.canChangeDailyWatchLimit()
          ? '한도에 도달했거나 타임락 때문에 지금은 줄일 수 없어요.'
          : '스케줄 타임락 편집 창 안에서만 한도를 바꿀 수 있어요.';
      return BlockChatResult.fail(
        '$label 한도 $minutes분 적용 불가 — $lockMsg',
      );
    }

    if (!PlatformWatchLimitStore.isEnabled(id)) {
      await PlatformWatchLimitStore.setEnabled(id, true);
    }
    await PlatformWatchLimitStore.setLimitMinutes(id, minutes);
    final applied = PlatformWatchLimitStore.limitMinutes(id);
    if (applied != minutes) {
      return BlockChatResult.fail('한도 변경이 적용되지 않았어요. 설정 화면에서 직접 확인해 주세요.');
    }

    final route = platform == 'brunch'
        ? '/explore/browser?site=brunch'
        : '/explore/browser?site=instagram';

    return BlockChatResult(
      summary: plan.reply.isNotEmpty
          ? plan.reply
          : 'Isle $label 일일 한도를 $minutes분으로 설정했어요.',
      steps: [
        BlockChatAppliedStep(
          title: '$label 일일 한도',
          detail: '하루 $minutes분 (Isle WebView 체류)',
          route: '/home/my-isle/manage',
          routeLabel: '한도 관리',
        ),
      ],
      impact: BlockChatApplySummary(
        headline: '$label 일일 $minutes분',
        locations: [
          BlockChatApplyLocation(
            tabLabel: label,
            detail: 'WebView 한도',
            icon: platform == 'brunch'
                ? Icons.menu_book_outlined
                : Icons.camera_alt_outlined,
            route: route,
            routeLabel: label,
          ),
        ],
        targets: [
          BlockChatApplyTarget(
              label: '$minutes분/일', icon: Icons.timer_outlined),
        ],
      ),
    );
  }

  static Future<BlockChatResult> _musicForegroundLimit(
      BlockChatPlan plan) async {
    await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);

    final endMin = (plan.endHour * 60 + plan.endMinute).clamp(1, 1439);
    final slots = <ScheduleSlot>[
      for (final d in plan.days)
        ScheduleSlot(day: d.clamp(0, 6), startMinute: 0, endMinute: endMin),
    ];
    final name = plan.scheduleName?.isNotEmpty == true
        ? plan.scheduleName!
        : 'YouTube Music · 화면 한도 (AI)';

    final existing = BlockChatScheduleDedup.findAiNamedPack('music') ??
        BlockChatScheduleDedup.findExactName(name);
    final schedule = existing ??
        await BlockScheduleStore.create(
          name: name,
          slots: slots,
          locked: true,
          lockCooldownMinutes: IsleUserDefaults.defaultScheduleLockCooldownMinutes,
          enforcementMode: ScheduleEnforcementMode.limitInSlot,
        );
    final enabled = schedule.copyWith(
      enabled: true,
      enforcementMode: ScheduleEnforcementMode.limitInSlot,
      blockIsleInApp: false,
      locked: true,
      slots: slots,
    );
    await BlockScheduleStore.upsert(enabled);

    final disableResult = await _disableConflictingRationSchedules(
      'youtube_music',
      plan,
      excludeName: name,
    );

    // "10분에 5분" 류 짧은 구간 나눠쓰기도 있으므로 시간 단위 전제인 30분 최소값을
    // 그대로 강제하면 안 된다(2026-07-11) — 파서가 이미 적절히 계산한 값을 신뢰한다.
    final windowMin = (plan.windowMinutes ?? 60).clamp(1, 720);
    final allowMin = (plan.sessionMinutes ?? 10).clamp(1, 120);

    var entries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(schedule.id),
    );
    entries = entries.map((e) {
      if (e.targetId == 'ios_youtube_music') {
        return e.copyWith(
          limitEnabled: true,
          limitMinutes: allowMin,
          windowMinutes: windowMin,
          blockInSlot: false,
        );
      }
      if (e.targetId == 'isle_youtube' || e.targetId == 'ios_youtube') {
        return e.copyWith(limitEnabled: false, blockInSlot: false);
      }
      return e;
    }).toList();

    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: schedule.id,
      entries: entries,
      schedule: enabled,
    );

    await ScheduleScreenTimeStore.ensureOpen();
    var pickerDone = ScheduleScreenTimeStore.appCountFor(schedule.id) > 0;
    if (!pickerDone &&
        (IsleApplePlatform.isScreenTimeHost || Platform.isAndroid)) {
      pickerDone = await ScheduleScreenTimeService.pickForSchedule(schedule.id);
      if (pickerDone) {
        await ScheduleAppLimitSyncService.syncAll();
      }
    }

    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    unawaited(IosRulesExportService.exportNow());

    final editRoute = IsleRoutes.blockScheduleEditOutsideShell(schedule.id);
    final windowLabel = windowMin >= 60 && windowMin % 60 == 0
        ? '${windowMin ~/ 60}시간'
        : '${windowMin}분';
    final iosScreenTimeNote = Platform.isIOS
        ? 'iOS Screen Time은 앱 화면(on-screen) 시간만 셉니다. '
            '잠금 화면·백그라운드 음악은 한도 밖이에요.'
        : 'Android는 앱이 화면에 있을 때만 시간을 셉니다.';

    final steps = <BlockChatAppliedStep>[
      BlockChatAppliedStep(
        title: '아침 스케줄',
        detail:
            '매일 00:00–${_fmt(endMin)} · iPhone YouTube Music 화면 $allowMin분/$windowLabel',
        route: editRoute,
        routeLabel: '스케줄 편집',
      ),
      BlockChatAppliedStep(
        title: 'YouTube Music (iPhone 앱)',
        detail: pickerDone
            ? 'Screen Time 한도 등록됨 — $windowLabel당 화면 ${allowMin}분. $iosScreenTimeNote'
            : '아래 「앱 선택」에서 YouTube Music만 고르세요. $iosScreenTimeNote',
        route: editRoute,
        routeLabel: pickerDone ? '스케줄 확인' : '앱 선택',
        needsManualSetup: !pickerDone,
      ),
      const BlockChatAppliedStep(
        title: '백그라운드 음악',
        detail: '한도는 화면만 해당. 잠금 후 잠금 화면 컨트롤로 듣기는 iOS가 별도로 셉니다.',
        route: '/settings/app-usage-limits',
        routeLabel: '앱별 한도',
      ),
    ];

    final overwriteNote = _overwriteNote(disableResult);
    return BlockChatResult(
      summary: (plan.reply.isNotEmpty
              ? plan.reply
              : 'iPhone YouTube Music — $windowLabel당 화면 ${allowMin}분, 백그라운드는 한도 밖.') +
          overwriteNote,
      steps: steps,
      impact: _scheduleImpact(
        headline: name,
        scheduleId: schedule.id,
        endMin: endMin,
        days: plan.days,
        targets: [
          BlockChatApplyTarget(
            label: 'YT Music 화면 $allowMin분/$windowLabel',
            icon: Icons.music_note,
            tint: const Color(0xFFFF0000),
          ),
          const BlockChatApplyTarget(
            label: '백그라운드 음악',
            icon: Icons.headphones_outlined,
          ),
          BlockChatApplyTarget(
            label: pickerDone ? 'Screen Time 연결됨' : '앱 선택 필요',
            icon: Icons.phone_iphone,
            needsManualSetup: !pickerDone,
          ),
        ],
        pendingSteps: pickerDone
            ? const []
            : [
                BlockChatAppliedStep(
                  title: 'YouTube Music 선택',
                  detail: '스케줄 편집 → ③ iPhone 앱 → YouTube Music만 선택하세요.',
                  route: editRoute,
                  routeLabel: '앱 선택',
                  needsManualSetup: true,
                ),
              ],
      ),
    );
  }

  /// 예약 스케줄("내일부터 3일간 유튜브 차단해줘" 등, 2026-07-20 신설) —
  /// 지금 당장 켜지 않고 미래에 자동 활성화, 종료 시각까지 타임락 대기로도
  /// 못 푸는 스케줄을 만든다. 실제 활성화/비활성화는
  /// [ScheduleReservationService.processDue]가 앱 부팅·리쥼 시 처리한다.
  static Future<BlockChatResult> _scheduledReservation(
    BlockChatPlan plan,
  ) async {
    final activationAt = plan.scheduledActivationAtMs;
    final deactivationAt = plan.scheduledDeactivationAtMs;
    if (activationAt == null || deactivationAt == null) {
      return BlockChatResult.fail('예약 기간을 이해하지 못했어요. 날짜를 다시 말해줄래요?');
    }
    final targetIds = plan.extraTargetIds ?? const <String>[];
    if (targetIds.isEmpty && !plan.blockSafariNote) {
      return BlockChatResult.fail('어떤 앱을 차단할지 알려줄래요?');
    }
    final name = plan.scheduleName?.isNotEmpty == true
        ? plan.scheduleName!
        : '예약 차단 (AI)';

    // 예약 스케줄은 특정 요일·시간대가 아니라 "그 기간 내내" 켜져 있어야 하므로
    // 매일 00:00-23:59 슬롯을 전부 건다 — slots가 비면
    // ScheduleActiveService가 항상 비활성으로 취급한다.
    final slots = <ScheduleSlot>[
      for (var d = 0; d < 7; d++) ScheduleSlot(day: d, startMinute: 0, endMinute: 1439),
    ];

    final existing = BlockChatScheduleDedup.findExactName(name);
    final schedule = existing ??
        await BlockScheduleStore.create(
          name: name,
          slots: slots,
          locked: true,
          lockCooldownMinutes: IsleUserDefaults.defaultScheduleLockCooldownMinutes,
          enforcementMode: ScheduleEnforcementMode.fullBlock,
          blockIsleInApp: plan.blockSafariNote,
          enabled: false,
          scheduledActivationAtMs: activationAt,
          scheduledDeactivationAtMs: deactivationAt,
          reservationLocked: true,
        );
    final reserved = schedule.copyWith(
      enabled: false,
      enforcementMode: ScheduleEnforcementMode.fullBlock,
      blockIsleInApp: plan.blockSafariNote,
      locked: true,
      slots: slots,
      scheduledActivationAtMs: activationAt,
      scheduledDeactivationAtMs: deactivationAt,
      reservationLocked: true,
    );
    await BlockScheduleStore.upsert(reserved);

    if (targetIds.isNotEmpty) {
      var entries = ScheduleAppTargetsStore.mergeWithCatalog(
        ScheduleAppTargetsStore.loadForSchedule(schedule.id),
      );
      entries = entries.map((e) {
        if (targetIds.contains(e.targetId)) {
          return e.copyWith(blockInSlot: true, limitEnabled: false);
        }
        return e;
      }).toList();
      await ScheduleAppTargetsService.saveAndSync(
        scheduleId: schedule.id,
        entries: entries,
        schedule: reserved,
      );
    }

    unawaited(IosRulesExportService.exportNow());

    final start = DateTime.fromMillisecondsSinceEpoch(activationAt);
    final end = DateTime.fromMillisecondsSinceEpoch(deactivationAt);
    final editRoute = IsleRoutes.blockScheduleEditOutsideShell(schedule.id);
    final steps = <BlockChatAppliedStep>[
      BlockChatAppliedStep(
        title: '예약 차단',
        detail:
            '${_fmtDate(start)}부터 ${_fmtDate(end)}까지 자동 적용 · 기간 중엔 타임락 대기로도 해제 불가',
        route: editRoute,
        routeLabel: '예약 확인',
      ),
    ];

    return BlockChatResult(
      summary: plan.reply,
      steps: steps,
    );
  }

  static String _fmtDate(DateTime d) => '${d.month}/${d.day}';

  /// 앱 켠 지 N분 트리거("아침에 앱 켠 지 30분은 유튜브 차단", 2026-07-20
  /// 신설) — 여긴 설정만 저장하고, 실제 발동은 [AppOpenBlockTriggerService]가
  /// 매 앱 실행(콜드부팅·리쥼)마다 담당한다. 채팅 직후 바로 오늘치도
  /// 적용되게 한 번 즉시 호출한다(morningOnly면 컷오프 이후일 때 자동으로
  /// 스킵되고 내일부터 적용됨 — 정상 동작).
  static Future<BlockChatResult> _appOpenBlockTrigger(BlockChatPlan plan) async {
    final minutes = plan.appOpenTriggerMinutes;
    if (minutes == null) {
      return BlockChatResult.fail('몇 분간 막을지 이해하지 못했어요. 다시 말해줄래요?');
    }
    final targetIds = plan.extraTargetIds ?? const <String>[];
    if (targetIds.isEmpty && !plan.blockSafariNote) {
      return BlockChatResult.fail('어떤 앱을 막을지 알려줄래요?');
    }

    await IsleUserDefaults.setAppOpenTriggerEnabled(true);
    await IsleUserDefaults.setAppOpenTriggerDurationMinutes(minutes);
    await IsleUserDefaults.setAppOpenTriggerTargetIds(targetIds);
    await IsleUserDefaults.setAppOpenTriggerMorningOnly(plan.appOpenTriggerMorningOnly);
    await IsleUserDefaults.setAppOpenTriggerBlockSafari(plan.blockSafariNote);

    final triggeredNow = await AppOpenBlockTriggerService.maybeTriggerOnAppOpen();

    return BlockChatResult(
      summary: plan.reply,
      steps: [
        BlockChatAppliedStep(
          title: '앱 켠 지 $minutes분 트리거',
          detail: triggeredNow
              ? '지금부터 $minutes분간 적용 중 — 앱을 켤 때마다(하루 1번) 자동 반복'
              : (plan.appOpenTriggerMorningOnly
                  ? '내일 아침 첫 실행부터 적용 시작(오늘은 컷오프 이후거나 이미 발동함)'
                  : '내일 첫 실행부터 적용 시작(오늘은 이미 발동함)'),
        ),
      ],
    );
  }

  static Future<BlockChatResult> _morningHabitPack(BlockChatPlan plan) async {
    await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);

    final endMin = (plan.endHour * 60 + plan.endMinute).clamp(1, 1439);
    final slots = <ScheduleSlot>[
      for (final d in plan.days)
        ScheduleSlot(day: d.clamp(0, 6), startMinute: 0, endMinute: endMin),
    ];
    final name = plan.scheduleName?.isNotEmpty == true
        ? plan.scheduleName!
        : '아침 유튜브·뮤직 (AI)';

    final existing = BlockChatScheduleDedup.findAiNamedPack('아침') ??
        BlockChatScheduleDedup.findExactName(name);
    final schedule = existing ??
        await BlockScheduleStore.create(
          name: name,
          slots: slots,
          locked: true,
          lockCooldownMinutes: IsleUserDefaults.defaultScheduleLockCooldownMinutes,
          enforcementMode: ScheduleEnforcementMode.limitInSlot,
        );
    final enabled = schedule.copyWith(
      enabled: true,
      enforcementMode: ScheduleEnforcementMode.limitInSlot,
      blockIsleInApp: false,
      locked: true,
      slots: slots,
    );
    await BlockScheduleStore.upsert(enabled);

    final refill = KakaoShortsPresetService.microRefillLimits();
    final sessionMin =
        (plan.sessionMinutes ?? refill.limitMinutes).clamp(1, 60);
    final windowMin = refill.windowMinutes;

    var entries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(schedule.id),
    );
    entries = entries.map((e) {
      if (e.targetId == 'ios_youtube' || e.targetId == 'isle_youtube') {
        return e.copyWith(
          limitEnabled: true,
          limitMinutes: sessionMin,
          windowMinutes: windowMin,
          blockInSlot: false,
        );
      }
      return e;
    }).toList();

    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: schedule.id,
      entries: entries,
      schedule: enabled,
    );

    final daily = (plan.dailyMinutes ?? 20).clamp(5, 120);
    await PlatformWatchLimitStore.ensureOpen();
    if (PlatformWatchLimitStore.canChangeLimit(
      id: PlatformWatchId.youtube,
      newMinutes: daily,
      newEnabled: true,
    )) {
      await PlatformWatchLimitStore.setEnabled(PlatformWatchId.youtube, true);
      await PlatformWatchLimitStore.setLimitMinutes(
          PlatformWatchId.youtube, daily);
    }

    final preset = AppUsageLimitRule.youtubeAppPreset;
    final rules = AppUsageLimitStore.loadRules();
    final idx = rules.indexWhere((r) => r.id == preset.id);
    final updated = AppUsageLimitRule(
      id: preset.id,
      label: preset.label,
      minutesPerWindow: daily,
      enabled: true,
      presetId: preset.id,
      androidPackageName: preset.androidPackage,
      windowMinutes: 1440,
      interventionTitle: '오늘 ${preset.label} 한도',
      interventionBody: '아침 시간대엔 ${sessionMin}분씩만 — Isle에서 의도한 콘텐츠만 보세요.',
    );
    if (idx >= 0) {
      rules[idx] = updated;
    } else {
      rules.add(updated);
    }
    await AppUsageLimitStore.saveRules(rules);

    if (plan.blockIsleYoutube) {
      await IsleUserDefaults.setHideYoutubeShorts(true);
    }

    await ScheduleAppLimitSyncService.syncAll();
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    unawaited(IosRulesExportService.exportNow());

    final editRoute = IsleRoutes.blockScheduleEditOutsideShell(schedule.id);
    final windowLabel = windowMin >= 60 ? '시간' : '${windowMin}분';
    final steps = <BlockChatAppliedStep>[
      BlockChatAppliedStep(
        title: '아침 스케줄',
        detail:
            '매일 00:00–${_fmt(endMin)} · 슬롯 안 YouTube ${sessionMin}분/$windowLabel 한도 (타임락 켜짐)',
        route: editRoute,
        routeLabel: '스케줄 편집',
      ),
      BlockChatAppliedStep(
        title: 'Isle 유튜브 일일 한도',
        detail: '하루 $daily분 (앱 안 재생)',
        route: '/home/my-isle/manage',
        routeLabel: '유튜브·SNS 관리',
      ),
      BlockChatAppliedStep(
        title: 'iPhone YouTube·뮤직',
        detail: Platform.isIOS
            ? '스케줄 편집 → ③에서 YouTube·YouTube Music 앱을 Screen Time으로 선택하세요.'
            : '스케줄 편집 → ③에서 YouTube 앱을 선택하세요.',
        route: editRoute,
        routeLabel: '스케줄 편집',
      ),
      if (plan.blockIsleYoutube)
        const BlockChatAppliedStep(
          title: 'Shorts 숨김',
          detail: '아침에 영상만 넘기기 쉬워서 숏츠도 함께 숨겼어요.',
          route: '/home/my-isle/manage',
          routeLabel: '유튜브·SNS 관리',
        ),
    ];

    if (plan.suggestTimelock) {
      steps.add(
        const BlockChatAppliedStep(
          title: '타임락 (권장)',
          detail:
              'YouTube 탭 → 「타임락」을 켜면 24시간 잠금 + 해제 대기로 설정 변경을 더 어렵게 할 수 있어요.',
          route: '/youtube',
          routeLabel: '유튜브 · 타임락',
        ),
      );
    }

    return BlockChatResult(
      summary: plan.reply.isNotEmpty ? plan.reply : '아침 유튜브 습관 패키지를 적용했어요.',
      steps: steps,
      impact: _scheduleImpact(
        headline: name,
        scheduleId: schedule.id,
        endMin: endMin,
        days: plan.days,
        targets: [
          const BlockChatApplyTarget(
            label: 'Isle 유튜브',
            icon: Icons.play_circle_filled,
            tint: Color(0xFFFF0000),
          ),
          BlockChatApplyTarget(
            label: 'YouTube·뮤직 ${sessionMin}분/$windowLabel',
            icon: Icons.phone_iphone,
            needsManualSetup: Platform.isIOS,
          ),
          if (plan.blockIsleYoutube)
            const BlockChatApplyTarget(
                label: 'Shorts 숨김', icon: Icons.video_library_outlined),
        ],
        pendingSteps: [
          BlockChatAppliedStep(
            title: 'iPhone YouTube·뮤직',
            detail: Platform.isIOS
                ? '스케줄 편집 → ③에서 YouTube·YouTube Music 앱을 Screen Time으로 선택하세요.'
                : '스케줄 편집 → ③에서 YouTube 앱을 선택하세요.',
            route: editRoute,
            routeLabel: '스케줄 편집',
            needsManualSetup: true,
          ),
        ],
        extraLocations: [
          BlockChatApplyLocation(
            tabLabel: '유튜브·SNS 관리',
            detail: '일일 $daily분 한도',
            icon: Icons.tune,
            route: '/home/my-isle/manage',
            routeLabel: '한도·숏츠',
          ),
        ],
      ),
    );
  }

  static Future<BlockChatResult> _youtubeLimit(BlockChatPlan plan) async {
    await PlatformWatchLimitStore.ensureOpen();
    await UsageBudgetStore.ensureOpen();
    final minutes = (plan.dailyMinutes ?? 20).clamp(5, 480).toInt();
    final current =
        PlatformWatchLimitStore.limitMinutes(PlatformWatchId.youtube);
    final enabled = PlatformWatchLimitStore.isEnabled(PlatformWatchId.youtube);
    final oldBudget = UsageBudgetStore.policyFor(UsageBudgetTarget.youtube);
    final oldBudgetEnabled = oldBudget?.enabled ?? false;
    final currentTotal =
        oldBudgetEnabled ? oldBudget!.dailyCapMinutes : current;

    if (!PlatformWatchLimitStore.canChangeLimit(
          id: PlatformWatchId.youtube,
          newMinutes: minutes,
          newEnabled: true,
        ) ||
        !YoutubeUsageLock.canApplyPolicyChange(
          currentlyEnabled: oldBudgetEnabled || enabled,
          newEnabled: true,
          currentDailyTotalMinutes: currentTotal,
          newDailyTotalMinutes: minutes,
          modeChanged: oldBudgetEnabled,
        )) {
      final lockMsg = ScheduleEditGuard.canChangeDailyWatchLimit()
          ? '한도 방식·총량 변경은 타임락 대기 완료 후 가능해요.'
          : '스케줄 타임락 편집 창 안에서만 한도를 바꿀 수 있어요.';
      return BlockChatResult.fail(
        '유튜브 한도 $minutes분 적용 불가 — $lockMsg\n'
        '현재: ${enabled ? "$current분" : "꺼짐"}',
      );
    }

    if (!enabled) {
      await PlatformWatchLimitStore.setEnabled(PlatformWatchId.youtube, true);
    }
    final carriedSeconds = oldBudgetEnabled
        ? UsageBudgetStore.ledgerFor(oldBudget!).usedSecondsToday
        : YoutubeWatchTimerStore.secondsUsedToday;
    await UsageBudgetStore.clearPolicy(UsageBudgetTarget.youtube);
    await PlatformWatchLimitStore.setLimitMinutes(
        PlatformWatchId.youtube, minutes);
    if (oldBudgetEnabled) {
      await YoutubeWatchTimerStore.preserveTodayUsageAtLeast(carriedSeconds);
    }
    final applied =
        PlatformWatchLimitStore.limitMinutes(PlatformWatchId.youtube);
    if (applied != minutes) {
      return BlockChatResult.fail('한도 변경이 적용되지 않았어요. 설정 화면에서 직접 확인해 주세요.');
    }

    return BlockChatResult(
      summary: plan.reply.isNotEmpty
          ? plan.reply
          : 'Isle 유튜브 일일 한도를 $minutes분으로 설정했어요.',
      steps: [
        BlockChatAppliedStep(
          title: '유튜브 일일 한도',
          detail: '하루 $minutes분 (Isle 안 유튜브·Safari 유튜브)',
          route: '/home/my-isle/manage',
          routeLabel: '한도 관리',
        ),
      ],
      impact: BlockChatApplySummary(
        headline: '유튜브 일일 $minutes분',
        locations: const [
          BlockChatApplyLocation(
            tabLabel: '유튜브·SNS 관리',
            detail: '한도·숏츠 설정',
            icon: Icons.tune,
            route: '/home/my-isle/manage',
            routeLabel: '관리 센터',
          ),
          BlockChatApplyLocation(
            tabLabel: 'Isle 유튜브',
            detail: '재생 시 카운트',
            icon: Icons.play_circle_filled,
            route: '/youtube',
            routeLabel: '유튜브',
          ),
        ],
        targets: [
          BlockChatApplyTarget(
            label: '하루 $minutes분',
            icon: Icons.timer_outlined,
            tint: const Color(0xFFFF0000),
          ),
        ],
      ),
    );
  }

  /// "일요일에는 하루 유튜브 총량 7시간으로 늘려줘" — 특정 요일만 다른 하루
  /// 총량. `plan.startHour`에 `DateTime.weekday`(1=월~7=일)를 실어 보낸다
  /// (전용 필드가 없어 재사용).
  static Future<BlockChatResult> _youtubeWeekdayLimit(BlockChatPlan plan) async {
    final weekday = (plan.startHour ?? 0).clamp(1, 7);
    final minutes = (plan.dailyMinutes ?? 20).clamp(5, 1440);
    if (weekday < 1 || weekday > 7) {
      return BlockChatResult.fail('어느 요일인지 인식하지 못했어요.');
    }
    await IsleUserDefaults.setYoutubeWeekdayLimitOverride(weekday, minutes);
    const weekdayLabels = ['', '월', '화', '수', '목', '금', '토', '일'];
    final label = weekdayLabels[weekday];
    final hours = (minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1);

    return BlockChatResult(
      summary: plan.reply.isNotEmpty
          ? plan.reply
          : '$label요일엔 하루 유튜브 총량을 $hours시간으로 설정했어요.',
      steps: [
        BlockChatAppliedStep(
          title: '$label요일 전용 하루 총량',
          detail: '$label요일엔 하루 $minutes분(${hours}시간), 다른 요일은 그대로예요.',
          route: '/home/my-isle/manage',
          routeLabel: '한도 관리',
        ),
      ],
      impact: BlockChatApplySummary(
        headline: '$label요일 유튜브 ${hours}시간',
        targets: [
          BlockChatApplyTarget(
            label: '$label요일 $minutes분',
            icon: Icons.calendar_today_outlined,
          ),
        ],
      ),
    );
  }

  /// "이번주만 유튜브 4시간으로 줄여줘"(임시) / "이번주 유튜브 총량 10시간으로
  /// 제한해줘"(영구) — `plan.toggleOn`이 true면 임시(이번 주만).
  static Future<BlockChatResult> _youtubeWeeklyLimit(BlockChatPlan plan) async {
    await YoutubeWeeklyUsageStore.ensureOpen();
    final minutes = (plan.dailyMinutes ?? 60).clamp(1, 10080);
    final isTemporary = plan.toggleOn ?? false;
    final hours = (minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1);

    if (isTemporary) {
      await IsleUserDefaults.setYoutubeWeeklyLimitTemp(minutes, UsageDay.weekKey());
    } else {
      await IsleUserDefaults.setYoutubeWeeklyLimitMinutes(minutes);
    }

    return BlockChatResult(
      summary: plan.reply.isNotEmpty
          ? plan.reply
          : (isTemporary
              ? '이번 주만 유튜브 총량을 $hours시간으로 설정했어요.'
              : '매주 유튜브 총량을 $hours시간으로 설정했어요.'),
      steps: [
        BlockChatAppliedStep(
          title: isTemporary ? '이번 주만 주간 총량' : '매주 반복 주간 총량',
          detail: isTemporary
              ? '이번 주 유튜브 $minutes분(${hours}시간), 다음 주부터는 원래 한도로 돌아가요.'
              : '매주 유튜브 $minutes분(${hours}시간) — 일일 한도와 별개로 주간 누적이 이 값을 넘으면 막혀요.',
          route: '/home/my-isle/manage',
          routeLabel: '한도 관리',
        ),
      ],
      impact: BlockChatApplySummary(
        headline: '유튜브 주간 ${hours}시간',
        targets: [
          BlockChatApplyTarget(
            label: '주간 $minutes분',
            icon: Icons.calendar_view_week_outlined,
          ),
        ],
      ),
    );
  }

  static Future<void> _seedYoutubeBudgetLedger(
    UsageBudgetPolicy policy,
    int usedSeconds,
  ) async {
    final now = DateTime.now();
    final used = usedSeconds.clamp(0, policy.dailyCapSeconds).toInt();
    final remaining =
        (policy.dailyCapSeconds - used).clamp(0, policy.dailyCapSeconds);
    final tokens = policy.burstCapSeconds.clamp(0, remaining).toInt();
    await UsageBudgetStore.saveLedger(
      UsageBudgetTarget.youtube,
      UsageBudgetLedger(
        dayKey: UsageBudgetEngine.dayKey(now),
        usedSecondsToday: used,
        tokenSeconds: tokens,
        lastRefillAt: now,
        lockedUntil: remaining <= 0 ? UsageBudgetEngine.nextDay(now) : null,
      ),
    );
  }

  static String _usageBudgetTarget(BlockChatPlan plan) {
    final platform = (plan.limitPlatform ?? '').toLowerCase();
    switch (platform) {
      case 'youtube':
        return UsageBudgetTarget.youtube;
      case 'instagram':
        return UsageBudgetTarget.instagram;
      case 'brunch':
        return UsageBudgetTarget.brunch;
      case 'app':
        return UsageBudgetTarget.app(plan.appId ?? 'unknown');
      default:
        final appId = plan.appId;
        if (appId != null && appId.isNotEmpty)
          return UsageBudgetTarget.app(appId);
        return platform.isNotEmpty ? platform : UsageBudgetTarget.youtube;
    }
  }

  static String _usageBudgetLabel(BlockChatPlan plan) {
    final app = (plan.appId ?? '').toLowerCase();
    switch (app) {
      case 'kakao':
      case 'kakaotalk':
        return '카카오톡';
      case 'tiktok':
        return 'TikTok';
      case 'safari':
        return 'Safari';
      case 'chrome':
        return 'Chrome';
      case 'netflix':
        return '넷플릭스';
      case 'discord':
        return 'Discord';
    }
    final platform = (plan.limitPlatform ?? '').toLowerCase();
    switch (platform) {
      case 'youtube':
        return '유튜브';
      case 'instagram':
        return 'Instagram';
      case 'brunch':
        return 'Brunch';
      case 'kakao':
      case 'kakaotalk':
        return '카카오톡';
      case 'app':
        return plan.appId ?? '앱';
      default:
        return platform.isNotEmpty ? platform : '유튜브';
    }
  }

  static bool _usageBudgetHasIsleCounter(String target) {
    return target == UsageBudgetTarget.youtube ||
        target == UsageBudgetTarget.instagram ||
        target == UsageBudgetTarget.brunch;
  }

  /// "전부 덮어쓸까요/하나만 고를까요?" 확인 후 사용자가 고른 대상 —
  /// scheduleQuery가 '__ALL__'이면 태그와 겹치는 활성 스케줄을 전부, 특정 이름이면
  /// 그 스케줄만 꺼서 새 나눠쓰기 정책과 겹쳐 충돌하지 않게 한다. scheduleQuery가
  /// 없으면(애초에 겹치는 스케줄이 1개 이하라 물어보지 않은 경우) 아무것도 건드리지
  /// 않는다(2026-07-11).
  ///
  /// 타임락(커밋먼트 락) 걸린 스케줄은 `BlockScheduleStore.upsert`가 내부적으로
  /// `SchedulePersistGuard`(§ScheduleImportGuard)를 거치면서 enabled=false를
  /// 조용히 되돌린다 — 근데 이 함수는 그 결과를 확인 안 하고 upsert를 불렀다는
  /// 사실만으로 "껐다"고 disabled 목록에 넣어서, 채팅이 "기존 스케줄 정리:
  /// OO 껐어요"라고 거짓 성공을 보고했다(2026-07-13 실사용 확인 — 잠긴 "야간
  /// Safari 차단" 스케줄에 겹치는 나눠쓰기를 "전부 덮어쓰기"해도 실제로는 안
  /// 꺼지고 두 스케줄이 겹친 채로 남았음). 잠긴 대상은 미리 걸러 정직하게
  /// lockedSkipped로 따로 보고한다.
  static Future<({List<String> disabled, List<String> lockedSkipped})>
      _disableConflictingRationSchedules(
    String tag,
    BlockChatPlan plan, {
    String? excludeName,
  }) async {
    final query = plan.scheduleQuery;
    if (query == null || query.isEmpty) {
      return (disabled: const <String>[], lockedSkipped: const <String>[]);
    }
    final all = BlockScheduleStore.loadAll();
    final targets = query == '__ALL__'
        ? all
            .where((s) => s.enabled)
            .where((s) => excludeName == null || s.name != excludeName)
            .where((s) => BlockChatRationTag.matches(s, tag))
            .toList()
        : all.where((s) => s.name == query).toList();
    final disabled = <String>[];
    final lockedSkipped = <String>[];
    for (final s in targets) {
      if (!s.enabled) continue;
      if (ScheduleEditGuard.isCommitmentLocked(s)) {
        lockedSkipped.add(s.name);
        continue;
      }
      await BlockScheduleStore.upsert(s.copyWith(enabled: false));
      disabled.add(s.name);
    }
    return (disabled: disabled, lockedSkipped: lockedSkipped);
  }

  /// _disableConflictingRationSchedules 결과를 정직한 안내 문구로 — 실제로 꺼진 것만
  /// "껐어요"라고 말하고, 잠금 때문에 못 끈 건 "겹칠 수 있다"고 따로 경고한다.
  static String _overwriteNote(
    ({List<String> disabled, List<String> lockedSkipped}) result,
  ) {
    var note = '';
    if (result.disabled.isNotEmpty) {
      note += '\n\n기존 스케줄 정리: ${result.disabled.join(' · ')} 껐어요.';
    }
    if (result.lockedSkipped.isNotEmpty) {
      note += '\n\n⚠️ ${result.lockedSkipped.join(' · ')}은(는) 타임락 중이라 못 껐어요 — '
          '잠금이 풀릴 때까지 이 스케줄과 겹쳐 있을 수 있어요.';
    }
    return note;
  }

  static Future<BlockChatResult> _usageBudget(BlockChatPlan plan) async {
    await UsageBudgetStore.ensureOpen();
    await PlatformWatchLimitStore.ensureOpen();
    final target = _usageBudgetTarget(plan);
    final label = _usageBudgetLabel(plan);

    final rationTag = plan.action == 'youtube_budget'
        ? 'youtube'
        : (plan.appId ?? plan.limitPlatform ?? '');
    final disableResult =
        await _disableConflictingRationSchedules(rationTag, plan);

    // "이미 켜져 있는 나눠쓰기를 늘려/연장/줄여줘" — 처음부터 새로 만드는 게 아니라
    // 실제 저장된 활성 정책을 베이스로, 이번 메시지에서 명시적으로 말한 필드만 덮어쓴다.
    // 언급 안 된 필드에 하드코딩 기본값(daily 60, session 20 등)을 지어내 기존 설정을
    // 통째로 날려버리던 실사용 버그(cage에서 먼저 발견, 2026-07-07)의 근본 수정.
    final existing =
        plan.extendsExistingBudget ? UsageBudgetStore.policyFor(target) : null;

    // "existing"이 UsageBudgetStore(나눠쓰기 모드)에만 있는지 본다 — 그런데
    // 사용자가 애초에 "하루 20분" 같은 평범한 총량 한도(PlatformWatchLimitStore,
    // youtube_limit 액션)로 설정해 놨었다면 UsageBudgetStore엔 정책이 아예 없어서
    // "existing"이 null이 되고, daily가 밑에서 하드코딩 기본값(60)으로 조용히
    // 새버려 원래 20분이 사라진다(2026-07-14 사용자 제보 — "하루 20분 → 10분씩
    // 쪼개기"를 채팅으로 하면 기존 20분이 60분으로 바뀜, 실측으로 재현 확인).
    // UsageBudgetStore에 기존 정책이 없고 이번 메시지에서 daily를 안 밝혔으면,
    // 평범한 총량 한도가 켜져 있는지도 확인해서 그 값을 이어받는다.
    final flatDailyFallback = (existing == null &&
            plan.dailyMinutes == null &&
            target == UsageBudgetTarget.youtube &&
            PlatformWatchLimitStore.isEnabled(PlatformWatchId.youtube))
        ? PlatformWatchLimitStore.limitMinutes(PlatformWatchId.youtube)
        : null;

    final minDaily = plan.action == 'youtube_budget' ? 10 : 1;
    // 파서(_parseUsageBudget/_parseNightRefillUsageBudget)는 순수 "N분에 M분"
    // 인터벌 요청에서 하루 총량을 일부러 안 채우고 dailyMinutes를 null로
    // 남긴다 — reply에도 "하루 총량 제한은 없음 — 언급 안 하셔서 안 걸었어요"라고
    // 명시. 그런데 여기서 세 소스가 다 없을 때 60을 지어내면 그 약속을
    // 깨고 사용자가 말한 적 없는 하루 60분 제한이 생긴다(2026-07-21 제보 —
    // "유튜브 1시간에 10분 허락해줘"가 하루 60분으로 새로 제한됨). 모델이
    // dailyCapMinutes를 진짜 무제한(null)으로 표현 못 하므로, 대신 바로 아래
    // clamp 상한(480분=8시간)을 써서 "사실상 무제한"으로 처리한다 — 60처럼
    // 사용자가 원치 않는 낮은 제한을 새로 걸지 않는다.
    final daily = (plan.dailyMinutes ??
            existing?.dailyCapMinutes ??
            flatDailyFallback ??
            480)
        .clamp(minDaily, 480)
        .toInt();
    final burst = (plan.sessionMinutes ?? existing?.burstCapMinutes ?? 20)
        .clamp(1, daily)
        .toInt();
    final refill = (plan.windowMinutes ?? existing?.refillIntervalMinutes ?? 60)
        .clamp(5, 480)
        .toInt();
    final cooldown =
        (plan.cooldownMinutes ?? existing?.cooldownMinutes ?? refill)
            .clamp(1, 480)
            .toInt();
    // plan.startHour/endHour는 야간 구간 나눠쓰기(예: 밤 11시~다음날 12시)에서만 채워짐 —
    // 있으면 그 시간대에만 이 정책을 적용하고, 그 외 시간엔 제한하지 않는다.
    // extend 의도(budgetWindowEndMinuteOfDay)면 이번 메시지에서 새로 말한 종료 시각만
    // 반영하고, 시작 시각은 기존 정책의 값을 그대로 이어간다.
    final hasNewWindow = plan.startHour != null;
    final windowStartMinute = hasNewWindow
        ? (plan.startHour! * 60 + (plan.startMinute ?? 0))
        : (plan.extendsExistingBudget ? existing?.windowStartMinute : null);
    final windowEndMinute = hasNewWindow
        ? (plan.endHour * 60 + plan.endMinute)
        : (plan.extendsExistingBudget
            ? (plan.budgetWindowEndMinuteOfDay ?? existing?.windowEndMinute)
            : null);
    final hasWindow = windowStartMinute != null && windowEndMinute != null;
    final policy = UsageBudgetPolicy(
      target: target,
      enabled: true,
      dailyCapMinutes: daily,
      burstCapMinutes: burst,
      refillAmountMinutes: burst,
      refillIntervalMinutes: refill,
      cooldownMinutes: cooldown,
      updatedAt: DateTime.now(),
      windowStartMinute: hasWindow ? windowStartMinute : null,
      windowEndMinute: hasWindow ? windowEndMinute : null,
    );

    UsageBudgetPolicy? oldYoutubeBudget;
    if (target == UsageBudgetTarget.youtube) {
      oldYoutubeBudget = UsageBudgetStore.policyFor(UsageBudgetTarget.youtube);
      final currentBudget = oldYoutubeBudget;
      final budgetWasOn = currentBudget?.enabled ?? false;
      final currentTotal = budgetWasOn
          ? currentBudget!.dailyCapMinutes
          : PlatformWatchLimitStore.limitMinutes(PlatformWatchId.youtube);
      final currentlyEnabled = budgetWasOn ||
          PlatformWatchLimitStore.isEnabled(PlatformWatchId.youtube);
      final cadenceWeakened = budgetWasOn &&
          currentBudget != null &&
          (burst > currentBudget.burstCapMinutes ||
              refill < currentBudget.refillIntervalMinutes ||
              cooldown < currentBudget.cooldownMinutes);
      if (!PlatformWatchLimitStore.canChangeLimit(
            id: PlatformWatchId.youtube,
            newMinutes: daily,
            newEnabled: true,
          ) ||
          !YoutubeUsageLock.canApplyPolicyChange(
            currentlyEnabled: currentlyEnabled,
            newEnabled: true,
            currentDailyTotalMinutes: currentTotal,
            newDailyTotalMinutes: daily,
            modeChanged: !budgetWasOn,
            cadenceWeakened: cadenceWeakened,
          )) {
        final scheduled =
            await UsageBudgetPendingPolicyService.scheduleYoutubePolicy(
          policy,
          carryUsedSecondsToday: PlatformWatchLimitStore.secondsUsedToday(
            PlatformWatchId.youtube,
          ),
        );
        final waitMinutes = ((scheduled.remaining.inSeconds + 59) ~/ 60)
            .clamp(1, 24 * 60)
            .toInt();
        final waitLabel = SchedulePendingTargetService.formatRemaining(
          scheduled.remaining,
        );
        return BlockChatResult(
          summary: '$label 나눠 쓰기 변환을 예약했어요. 타임락 때문에 $waitLabel, '
              '하루 $daily분 · $burst분마다 스탑 · $refill분 뒤 충전 모드로 자동 변환합니다.',
          needsUnlockWait: true,
          unlockMinutes: waitMinutes,
          removalScheduledAuto: true,
          steps: [
            BlockChatAppliedStep(
              title: '타임락 후 자동 변환',
              detail:
                  '$waitLabel · 하루 $daily분 · 한 번 $burst분 · $refill분 뒤 충전 · $cooldown분 잠금',
              route: IsleRoutes.youtubeLimits,
              routeLabel: '유튜브 한도',
            ),
          ],
          impact: BlockChatApplySummary(
            headline: '$label $burst분씩 나눠 쓰기 예약',
            locations: [
              BlockChatApplyLocation(
                tabLabel: '유튜브 한도',
                detail: '타임락 대기 후 자동 적용',
                icon: Icons.hourglass_bottom,
                route: IsleRoutes.youtubeLimits,
                routeLabel: '유튜브 한도',
              ),
            ],
            targets: [
              BlockChatApplyTarget(
                label: '하루 $daily분',
                icon: Icons.today,
              ),
              BlockChatApplyTarget(
                label: '$burst분마다 스탑',
                icon: Icons.timer_outlined,
              ),
            ],
            pendingSteps: [
              BlockChatAppliedStep(
                title: '자동 적용 대기',
                detail: waitLabel,
                route: IsleRoutes.youtubeLimits,
                routeLabel: '유튜브 한도',
              ),
            ],
          ),
        );
      }
    }

    await UsageBudgetStore.savePolicy(policy);
    if (target == UsageBudgetTarget.youtube) {
      if (oldYoutubeBudget == null || oldYoutubeBudget.enabled == false) {
        await _seedYoutubeBudgetLedger(
          policy,
          YoutubeWatchTimerStore.secondsUsedToday,
        );
      }
      await IsleUserDefaults.setYoutubeDailyLimitEnabled(false);
      await IsleUserDefaults.setYoutubeIntervalLimitEnabled(false);
    }

    final overwriteNote = _overwriteNote(disableResult);
    return BlockChatResult(
      summary: (plan.reply.isNotEmpty
              ? plan.reply
              : '$label을 하루 $daily분 안에서 $burst분씩 나눠 쓰도록 설정했어요.') +
          overwriteNote,
      steps: [
        BlockChatAppliedStep(
          title: '$label 나눠 쓰기',
          detail: '하루 $daily분 · 한 번 $burst분 · $refill분 뒤 충전 · $cooldown분 잠금',
          route: target == UsageBudgetTarget.youtube
              ? IsleRoutes.youtubeLimits
              : '/settings/app-limits',
          routeLabel: target == UsageBudgetTarget.youtube ? '유튜브 한도' : '앱 한도',
        ),
      ],
      impact: BlockChatApplySummary(
        headline: '$label $burst분씩 나눠 쓰기',
        locations: [
          BlockChatApplyLocation(
            tabLabel: target == UsageBudgetTarget.youtube ? '유튜브 한도' : '앱 한도',
            detail: '나눠 쓰기 모드',
            icon: Icons.hourglass_bottom,
            route: target == UsageBudgetTarget.youtube
                ? IsleRoutes.youtubeLimits
                : '/settings/app-limits',
            routeLabel: '한도 설정',
          ),
          if (_usageBudgetHasIsleCounter(target))
            BlockChatApplyLocation(
              tabLabel:
                  target == UsageBudgetTarget.youtube ? 'Isle 유튜브' : label,
              detail: '앱 안 사용 시간 카운트',
              icon: Icons.play_circle_filled,
              route: target == UsageBudgetTarget.youtube ? '/youtube' : null,
              routeLabel: target == UsageBudgetTarget.youtube ? '유튜브' : null,
            )
          else
            const BlockChatApplyLocation(
              tabLabel: '외부 앱',
              detail: '4vpn/cage/OS 차단 어댑터에서 같은 정책 사용',
              icon: Icons.phonelink_lock_outlined,
              route: '/settings/app-limits',
              routeLabel: '앱 한도',
              needsManualSetup: true,
            ),
        ],
        targets: [
          BlockChatApplyTarget(
            label: '하루 $daily분',
            icon: Icons.today,
          ),
          BlockChatApplyTarget(
            label: '$burst분씩',
            icon: Icons.battery_charging_full,
          ),
        ],
      ),
    );
  }

  static BlockChatApplySummary _scheduleImpact({
    required String headline,
    required String scheduleId,
    required int endMin,
    required List<int> days,
    List<BlockChatApplyTarget> targets = const [],
    List<BlockChatAppliedStep> pendingSteps = const [],
    List<BlockChatApplyLocation> extraLocations = const [],
  }) {
    final editRoute = IsleRoutes.blockScheduleEditOutsideShell(scheduleId);
    final daySet = days.map(ScheduleDisplayHelper.normalizeDay).toSet();
    return BlockChatApplySummary(
      headline: headline,
      scheduleId: scheduleId,
      timeRange: endMin >= 1440 ? '하루 종일' : '00:00 – ${_fmt(endMin)}',
      daysLabel: ScheduleDisplayHelper.formatDaysPattern(daySet),
      endMinute: endMin.clamp(1, 1440),
      locations: [
        const BlockChatApplyLocation(
          tabLabel: '차단 탭',
          detail: '스케줄 목록·활성 상태',
          icon: Icons.shield_outlined,
          route: '/home/block',
          routeLabel: '차단 탭',
        ),
        BlockChatApplyLocation(
          tabLabel: '스케줄 편집',
          detail: '시간·대상·타임락',
          icon: Icons.edit_calendar_outlined,
          route: editRoute,
          routeLabel: '편집 화면',
        ),
        ...extraLocations,
      ],
      targets: targets,
      pendingSteps: pendingSteps,
    );
  }

  static BlockChatApplySummary _scheduleOffImpact(BlockSchedule s) {
    final editRoute = IsleRoutes.blockScheduleEditOutsideShell(s.id);
    return BlockChatApplySummary(
      headline: '「${s.name}」 꺼짐',
      scheduleId: s.id,
      locations: [
        const BlockChatApplyLocation(
          tabLabel: '차단 탭',
          detail: '비활성 스케줄 표시',
          icon: Icons.shield_outlined,
          route: '/home/block',
          routeLabel: '차단 탭',
        ),
        BlockChatApplyLocation(
          tabLabel: '스케줄 편집',
          detail: '다시 켜기·수정',
          icon: Icons.edit_calendar_outlined,
          route: editRoute,
          routeLabel: '스케줄 보기',
        ),
      ],
    );
  }

  static List<ScheduleSlot> _allDaySlots() => [
        for (var d = 0; d < 7; d++)
          ScheduleSlot(day: d, startMinute: 0, endMinute: 24 * 60),
      ];

  static String _fmt(int minute) {
    final h = minute ~/ 60;
    final m = minute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// "모든 차단 초기화해줘" — 스케줄·차단·한도 전부 삭제(파괴적, 되돌리기 없음).
  /// cage에서 먼저 구현 후 이식 — 삭제 대기 잠금(RuleRemovalLock)이 켜져
  /// 있으면 즉시 적용하지 않고 대기 플래그만 세운 뒤, 잠금 해제 창이 열리면
  /// (앱 재방문 시 `applyPendingFullResetIfDue`) 자동 적용한다.
  static Future<BlockChatResult> _resetAllBlocks(BlockChatPlan plan) async {
    if (RuleRemovalLock.removalBlocked) {
      if (IsleUserDefaults.ruleRemovalUnlockStartedAtMs == null) {
        await RuleRemovalLock.startUnlockCountdown();
      }
      await IsleUserDefaults.setPendingFullResetRequested(true);
      final remain = RuleRemovalLock.unlockRemaining;
      final mins =
          remain == null ? IsleUserDefaults.ruleRemovalFreezeMinutes : remain.inMinutes + 1;
      return BlockChatResult(
        summary: '삭제 대기 잠금이 켜져 있어서 지금 바로는 초기화할 수 없어요. '
            '약 $mins분 뒤 앱을 다시 열면 자동으로 전부 초기화돼요.',
        steps: const [],
      );
    }
    final stillLockedCount = await performFullReset();
    return BlockChatResult(
      summary: stillLockedCount > 0
          ? '나머지 설정은 전부 초기화했어요. 단, 삭제 대기 커밋먼트 잠금이 걸린 '
              '스케줄 $stillLockedCount개는 그 잠금이 풀릴 때까지 그대로 남겨뒀어요.'
          : '모든 스케줄·차단·한도 설정을 전부 초기화했어요.',
      steps: const [],
    );
  }

  /// 실제 초기화 본체 — [_resetAllBlocks](즉시 적용 분기)와 앱 재방문 시
  /// 대기 중이던 리셋 적용(`applyPendingFullResetIfDue`) 양쪽에서 공유해서 쓴다.
  /// `IsleKeychainSurvivalStore.clear()`까지 지워야 삭제 후 재설치해도 예전
  /// 차단이 자동 복원되지 않는다(안 지우면 되살아남).
  ///
  /// **커밋먼트 잠금 중인 스케줄은 건너뛰고 남겨둔다**(cage에서 07-11 발견·
  /// 수정한 회귀 버그 이식 — 원래는 `ScheduleEditGuard.isCommitmentLocked`를
  /// 전혀 확인 안 하고 전부 지워서, 사용자가 스스로 걸어둔 삭제 대기 커밋먼트를
  /// 이 챗 명령 한 줄로 우회해버렸음). 반환값은 잠금 때문에 남은 스케줄 수.
  static Future<int> performFullReset() async {
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await WebsiteBlockStore.ensureOpen();
    await BlockedUrlStore.ensureOpen();
    await BlockedChannelStore.ensureOpen();
    await ContentFilterStore.ensureOpen();
    await UsageBudgetStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();

    final all = BlockScheduleStore.loadAll();
    final stillLocked = <BlockSchedule>[];
    for (final schedule in all) {
      // 안전 라인은 편집 창이 열려 있어도(=커밋먼트 락 상태와 무관하게)
      // "모든 차단 초기화" 챗 커맨드로 절대 지워지면 안 된다(2026-07-16).
      if (schedule.isSafetyBaseline || ScheduleEditGuard.isCommitmentLocked(schedule)) {
        stillLocked.add(schedule);
        continue;
      }
      await ScheduleAppTargetsStore.saveForSchedule(schedule.id, const []);
      await ScheduleScreenTimeStore.clear(schedule.id);
    }
    await BlockScheduleStore.saveAll(stillLocked);
    await AppUsageLimitStore.saveRules(const []);
    await WebsiteBlockStore.saveDomains(const []);
    await BlockedUrlStore.saveAll(const []);
    await BlockedChannelStore.saveAll(const []);
    await ContentFilterStore.saveVideos(const []);
    await ContentFilterStore.saveKeywords(const []);
    for (final target in [
      UsageBudgetTarget.youtube,
      UsageBudgetTarget.instagram,
      UsageBudgetTarget.brunch,
    ]) {
      await UsageBudgetStore.clearPolicy(target);
    }
    await AppInterventionService.clearAppShield();
    await ExternalAppShieldStore.clearSelection();
    await IsleKeychainSurvivalStore.clear();
    await IsleUserDefaults.setPendingFullResetRequested(false);
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    return stillLocked.length;
  }

  /// 「카카오톡 차단 설정 알려줘」「유튜브 뮤직 스케줄 알려줘」「뭐가 차단하고 있는거야?」
  /// — 읽기 전용 조회. 저장된 값을 바꾸지 않고 지금 상태만 보여준다.
  static Future<BlockChatResult> _explainStatus(BlockChatPlan plan) async {
    await UsageBudgetStore.ensureOpen();
    await BlockScheduleStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();

    final now = DateTime.now();
    final isMusic = plan.limitPlatform == 'youtube_music';

    // "오늘 블락은 뭐가 켜져있어?" 류 — 특정 앱/플랫폼을 안 짚었으면 YouTube로
    // 조용히 좁혀버리던 버그(2026-07-10, cage 제보) 대신 전체를 훑어 타임라인으로
    // 보여준다.
    final broad = !isMusic &&
        (plan.limitPlatform == null || plan.limitPlatform!.trim().isEmpty) &&
        (plan.appId == null || plan.appId!.trim().isEmpty);
    if (broad) return _explainStatusBroad(now);

    final label = isMusic ? '유튜브 뮤직' : _usageBudgetLabel(plan);

    UsageBudgetPolicy? policy;
    UsageBudgetSnapshot? snap;
    List<BlockSchedule> schedules = const [];

    if (isMusic) {
      final schedule = BlockChatScheduleDedup.findAiNamedPack('music');
      schedules = schedule != null ? [schedule] : const [];
    } else {
      final target = _usageBudgetTarget(plan);
      policy = UsageBudgetStore.policyFor(target);
      if (policy != null && policy.enabled) {
        snap = UsageBudgetStore.snapshot(target);
      }
      if (plan.limitPlatform == 'instagram') {
        schedules = ScheduleBlockReconcileService.schedulesAffectingScope(
          BlockRelaxScope.instagram,
        );
      } else if (plan.limitPlatform == 'safari' || plan.appId == 'safari') {
        schedules = ScheduleBlockReconcileService.schedulesAffectingScope(
          BlockRelaxScope.safari,
        );
      } else if (plan.appId == null ||
          plan.appId!.isEmpty ||
          plan.limitPlatform == 'youtube') {
        schedules = ScheduleBlockReconcileService.schedulesAffectingScope(
          BlockRelaxScope.youtube,
        );
      } else {
        // 카카오톡·틱톡·넷플릭스 등 BlockRelaxScope에 없는 임의 앱은 항상
        // YouTube 범위로 조용히 검색되던 버그(2026-07-11 cage 제보 —
        // "카카오톡 관련 스케줄이 뭐가 있어?"가 매번 "없어요"로 나옴) —
        // 스케줄 이름 기반 태그 매칭으로 대신 찾는다.
        final tag = plan.appId!;
        schedules = BlockScheduleStore.loadAll()
            .where((s) => s.enabled && BlockChatRationTag.matches(s, tag))
            .toList();
      }
    }

    final buf = StringBuffer();
    var hasAny = false;
    final items = <BlockChatDailyTimelineItem>[];

    if (policy != null && policy.enabled) {
      hasAny = true;
      final windowLabel = policy.hasWindow
          ? '${_fmt(policy.windowStartMinute!)}~${_fmt(policy.windowEndMinute!)}에만'
          : '하루 종일';
      buf.writeln(
        '$label 나눠쓰기 — $windowLabel 하루 ${policy.dailyCapMinutes}분 안에서 '
        '${policy.burstCapMinutes}분씩, ${policy.refillIntervalMinutes}분마다 충전돼요.',
      );
      if (snap != null) {
        buf.writeln(
          snap.isLocked
              ? '지금은 잠겨 있어요.'
              : '지금 ${snap.availableSeconds ~/ 60}분 바로 쓸 수 있어요.',
        );
      }
      final item = _timelineItemForUsageBudget(_usageBudgetTarget(plan));
      if (item != null) items.add(item);
    }

    if (schedules.isNotEmpty) {
      hasAny = true;
      for (final s in schedules) {
        final times = ScheduleDisplayHelper.formatScheduleTimes(s.slots);
        buf.writeln('「${s.name}」 ${_scheduleNowLabel(s, now)} · $times');
        final item = _timelineItemForSchedule(s, now);
        if (item != null) items.add(item);
      }
    }

    // 스케줄과 별개로 iPhone 앱 수동 선택(Screen Time 쉴드)이 켜져 있으면
    // "왜 막혔지" 질문에 흔히 빠지는 원인이라 존재만이라도 알려준다 — 어떤
    // 앱이 선택에 포함됐는지는 native FamilyActivitySelection이 암호화된
    // 블롭이라 Dart에서 개별 앱 단위로 들여다볼 수 없다.
    if (ExternalAppShieldStore.hasSelection) {
      hasAny = true;
      buf.writeln(
        '별도로 iPhone 앱 선택(수동 쉴드)도 켜져 있어요 — 특정 앱이 스케줄과 '
        '무관하게 항상 막혀 있다면 이것 때문일 수 있어요.',
      );
    }

    if (!hasAny) {
      buf.writeln('$label 관련 활성 차단·한도가 없어요.');
    }

    return BlockChatResult(
      summary: buf.toString().trim(),
      steps: const [],
      dailyTimeline: items.isEmpty ? null : items,
    );
  }

  /// 전체 조회 — 앱별 오늘 24시간 타임라인(완전 차단=빨강 · 부분 허용(한도)=주황 ·
  /// 그 외 시간=무색)을 만든다. 스케줄(앱 잠금)과 나눠쓰기(사용량 예산)를 모두 훑는다.
  static Future<BlockChatResult> _explainStatusBroad(DateTime now) async {
    final items = <BlockChatDailyTimelineItem>[];

    for (final s in BlockScheduleStore.loadAll()) {
      final item = _timelineItemForSchedule(s, now);
      if (item != null) items.add(item);
    }
    for (final target in UsageBudgetStore.configuredTargets()) {
      final item = _timelineItemForUsageBudget(target);
      if (item != null) items.add(item);
    }

    final buf = StringBuffer();
    if (items.isEmpty) {
      buf.writeln('오늘 활성화된 차단·한도가 없어요.');
    } else {
      buf.writeln('오늘 켜져 있는 차단·한도 ${items.length}건이에요.');
      for (final item in items) {
        buf.writeln('「${item.label}」 ${item.statusText}');
      }
    }
    if (ExternalAppShieldStore.hasSelection) {
      buf.writeln(
        '별도로 iPhone 앱 선택(수동 쉴드)도 켜져 있어요 — 특정 앱이 스케줄과 '
        '무관하게 항상 막혀 있다면 이것 때문일 수 있어요.',
      );
    }

    return BlockChatResult(
      summary: buf.toString().trim(),
      steps: const [],
      dailyTimeline: items.isEmpty ? null : items,
    );
  }

  /// 오늘(현재 요일) 기준 이 스케줄의 슬롯이 커버하는 0~1440분 구간들.
  /// 자정을 넘는 슬롯은 오늘 저녁(시작~1440)과, 어제 슬롯이 넘어온 오늘 새벽
  /// (0~끝)을 각각 today 좌표로 만들어 하루 타임라인에 올린다.
  static List<(int, int)> _todaySlotWindows(BlockSchedule s, DateTime now) {
    final todayIdx = now.weekday - 1;
    final yesterdayIdx = (todayIdx + 6) % 7;
    final out = <(int, int)>[];
    for (final slot in s.slots) {
      final wraps = slot.startMinute > slot.endMinute;
      if (slot.day == todayIdx) {
        out.add((slot.startMinute, wraps ? 1440 : slot.endMinute));
      }
      if (wraps && slot.day == yesterdayIdx) {
        out.add((0, slot.endMinute));
      }
    }
    return out;
  }

  /// windows가 안 덮는 오늘 나머지 구간(허용 창 밖 = 슬롯 밖) — combo 모드에서
  /// "슬롯 밖은 시간 한도" 부분 허용 구간을 만들 때 씀.
  static List<(int, int)> _complementOf(List<(int, int)> windows) {
    final sorted = [...windows]..sort((a, b) => a.$1.compareTo(b.$1));
    final out = <(int, int)>[];
    var cursor = 0;
    for (final w in sorted) {
      final s = w.$1.clamp(0, 1440);
      final e = w.$2.clamp(0, 1440);
      if (s > cursor) out.add((cursor, s));
      if (e > cursor) cursor = e;
    }
    if (cursor < 1440) out.add((cursor, 1440));
    return out;
  }

  static BlockChatDailyTimelineItem? _timelineItemForSchedule(
    BlockSchedule s,
    DateTime now,
  ) {
    if (!s.enabled) return null;
    final windows = _todaySlotWindows(s, now);
    if (windows.isEmpty) return null;

    final inSlotKind = s.enforcementMode.appliesShieldInSlot
        ? BlockTimelineSegmentKind.fullBlock
        : BlockTimelineSegmentKind.partialAllow;
    final segments = [
      for (final w in windows)
        BlockTimelineSegment(startMinute: w.$1, endMinute: w.$2, kind: inSlotKind),
    ];
    if (s.enforcementMode.appliesLimitOutsideSlot) {
      for (final c in _complementOf(windows)) {
        segments.add(BlockTimelineSegment(
          startMinute: c.$1,
          endMinute: c.$2,
          kind: BlockTimelineSegmentKind.partialAllow,
        ));
      }
    }
    segments.sort((a, b) => a.startMinute.compareTo(b.startMinute));

    final targetLabel = ScheduleDisplayHelper.targetVisualsForSchedule(s)
        .map((v) => v.label)
        .join('·');
    return BlockChatDailyTimelineItem(
      label: targetLabel.isNotEmpty ? targetLabel : s.name,
      statusText:
          '${_scheduleNowLabel(s, now)} · ${ScheduleDisplayHelper.formatScheduleTimes(s.slots)}',
      segments: segments,
    );
  }

  static BlockChatDailyTimelineItem? _timelineItemForUsageBudget(String target) {
    final policy = UsageBudgetStore.policyFor(target);
    if (policy == null || !policy.enabled) return null;

    final seg = policy.hasWindow
        ? BlockTimelineSegment(
            startMinute: policy.windowStartMinute!,
            endMinute: policy.windowStartMinute! <= policy.windowEndMinute!
                ? policy.windowEndMinute!
                : policy.windowEndMinute! + 1440,
            kind: BlockTimelineSegmentKind.partialAllow,
          )
        : const BlockTimelineSegment(
            startMinute: 0,
            endMinute: 1440,
            kind: BlockTimelineSegmentKind.partialAllow,
          );

    final snap = UsageBudgetStore.snapshot(target);
    final windowLabel = policy.hasWindow
        ? '${_fmt(policy.windowStartMinute!)}~${_fmt(policy.windowEndMinute!)}에만'
        : '하루 종일';
    final live = snap == null
        ? ''
        : (snap.isLocked ? ' · 지금은 잠겨 있어요' : ' · 지금 ${snap.availableSeconds ~/ 60}분 바로 사용 가능');

    return BlockChatDailyTimelineItem(
      label: UsageBudgetTarget.label(target),
      statusText: '$windowLabel ${policy.refillIntervalMinutes}분마다 '
          '${policy.burstCapMinutes}분 허용$live',
      segments: [seg],
    );
  }

  /// 스케줄이 "등록돼 있다"와 "지금 이 순간 실제로 걸려 있다"는 다르다 —
  /// 지금 창(window) 안인지 ScheduleActiveService로 확인해 실제 "왜"에 답한다
  /// (cage에서 먼저 발견·수정: 정적 enabled만 보고 "활성"이라 답해 시간대
  /// 밖에서도 막혀 있다고 착각하게 만듦, 2026-07-07).
  static String _scheduleNowLabel(BlockSchedule s, DateTime now) {
    if (!s.enabled) return '꺼져 있음';
    if (ScheduleActiveService.isScheduleActiveNow(s, now)) {
      final until = _activeSlotEndLabel(s, now);
      return until != null ? '지금 활성 — $until에 풀려요' : '지금 활성';
    }
    final next = _nextSlotStartLabel(s, now);
    return next != null
        ? '지금은 시간대 밖 — $next부터 다시 걸려요'
        : '등록됨 (지금은 시간대 밖)';
  }

  /// 오늘 요일에 지금 이 순간을 덮는 슬롯의 종료 시각.
  static String? _activeSlotEndLabel(BlockSchedule s, DateTime now) {
    final todayIdx = now.weekday - 1;
    final nowMinute = now.hour * 60 + now.minute;
    for (final slot in s.slots) {
      if (slot.day != todayIdx) continue;
      if (!slot.coversMinute(nowMinute)) continue;
      final wraps = slot.startMinute > slot.endMinute;
      return wraps ? '${_fmt(slot.endMinute)} (다음날)' : _fmt(slot.endMinute);
    }
    return null;
  }

  /// 앞으로 7일 안에서 가장 가까운 미래 시작 슬롯.
  static String? _nextSlotStartLabel(BlockSchedule s, DateTime now) {
    if (s.slots.isEmpty) return null;
    const dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final todayIdx = now.weekday - 1;
    final nowMinute = now.hour * 60 + now.minute;
    (int daysAhead, int startMinute)? best;
    for (final slot in s.slots) {
      for (var daysAhead = 0; daysAhead < 7; daysAhead++) {
        final day = (todayIdx + daysAhead) % 7;
        if (slot.day != day) continue;
        if (daysAhead == 0 && slot.startMinute <= nowMinute) continue;
        if (best == null ||
            daysAhead < best.$1 ||
            (daysAhead == best.$1 && slot.startMinute < best.$2)) {
          best = (daysAhead, slot.startMinute);
        }
      }
    }
    if (best == null) return null;
    final day = (todayIdx + best.$1) % 7;
    final prefix = best.$1 == 0
        ? '오늘'
        : best.$1 == 1
            ? '내일'
            : '${dayNames[day]}요일';
    return '$prefix ${_fmt(best.$2)}';
  }
}
