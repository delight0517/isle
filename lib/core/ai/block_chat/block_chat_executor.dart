import 'dart:async';

import '../../block_schedule/block_schedule_enforcement_service.dart';
import '../../block_schedule/block_schedule_store.dart';
import '../../block_schedule/isle_youtube_schedule_service.dart';
import '../../block_schedule/models/block_schedule.dart';
import '../../block_schedule/models/schedule_slot.dart';
import '../../block_schedule/schedule_app_target_catalog.dart';
import '../../block_schedule/schedule_app_targets_service.dart';
import '../../block_schedule/schedule_app_targets_store.dart';
import '../../block_schedule/schedule_lock_phase.dart';
import '../../block_schedule/schedule_lock_service.dart';
import '../../block_schedule/schedule_edit_guard.dart';
import '../../intervention/app_usage_limit_store.dart';
import '../../intervention/models/app_usage_limit_rule.dart';
import '../../library/platform_watch_limit_store.dart';
import '../../platform/ios_rules_export_service.dart';
import '../../services/isle_user_defaults.dart';
import '../../youtube/content_filter_store.dart';
import 'block_chat_models.dart';

/// 차단 계획 → 실제 저장·동기화
class BlockChatExecutor {
  BlockChatExecutor._();

  static Future<BlockChatResult> apply(BlockChatPlan plan) async {
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await ContentFilterStore.ensureOpen();

    switch (plan.action) {
      case 'add_keyword':
        return _addKeyword(plan);
      case 'remove_keyword':
        return _removeKeyword(plan);
      case 'morning_schedule':
        return _morningSchedule(plan);
      case 'app_session_limit':
        return _appSessionLimit(plan);
      case 'remove_schedule':
        return _removeSchedule(plan);
      case 'toggle_shorts':
        return _toggleShorts(plan);
      case 'toggle_reels':
        return _toggleReels(plan);
      case 'youtube_limit':
        return _youtubeLimit(plan);
      case 'explain':
        return BlockChatResult(
          summary: plan.reply.isNotEmpty ? plan.reply : '도움이 필요한 설정을 말씀해 주세요.',
          steps: const [],
        );
      default:
        return BlockChatResult.fail('아직 지원하지 않는 설정이에요: ${plan.action}');
    }
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
    );
  }

  static Future<BlockChatResult> _removeKeyword(BlockChatPlan plan) async {
    final kw = plan.removeKeyword?.trim().toLowerCase();
    if (kw == null || kw.isEmpty) {
      return BlockChatResult.fail('제거할 키워드를 알려주세요.');
    }
    final list = ContentFilterStore.loadKeywords().where((k) => k != kw).toList();
    await ContentFilterStore.saveKeywords(list);
    return BlockChatResult(
      summary: '키워드 「$kw」를 제거했어요.',
      steps: [
        BlockChatAppliedStep(
          title: '키워드 해제',
          detail: '다시 피드·유튜브에 노출될 수 있어요.',
          route: '/home/my-isle/manage',
          routeLabel: '숨김 목록',
        ),
      ],
    );
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
      return BlockChatResult(
        summary: plan.reply.isNotEmpty
            ? plan.reply
            : '아침 Isle 유튜브 스케줄을 만들었어요.',
        steps: [
          BlockChatAppliedStep(
            title: 'Isle 유튜브 스케줄',
            detail: '매일 00:00–${IsleYoutubeScheduleService.formatEndLabel(endMin)} 「${schedule.name}」',
            route: '/settings/block-schedules/${schedule.id}',
            routeLabel: '스케줄 편집',
          ),
        ],
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
    final existing = _findMorningSchedule(name);
    final schedule = existing ??
        await BlockScheduleStore.create(
          name: name,
          slots: slots,
          locked: true,
          lockCooldownMinutes: 30,
        );
    var enabled = schedule
        .copyWith(
          enabled: true,
          blockIsleInApp: plan.blockSafariNote,
          slots: slots,
          locked: true,
        );
    await BlockScheduleStore.upsert(enabled);

    if (plan.blockSafariNote) {
      final isleEntries = ScheduleAppTargetsStore.loadForSchedule(schedule.id)
          .map((e) {
            final def = ScheduleAppTargetCatalog.defFor(e.targetId);
            if (def?.isIsle == true) return e.copyWith(blockInSlot: true);
            return e;
          })
          .toList();
      await ScheduleAppTargetsService.saveAndSync(
        scheduleId: schedule.id,
        entries: isleEntries,
        schedule: enabled,
      );
      enabled = BlockScheduleStore.loadAll().firstWhere((s) => s.id == schedule.id);
    }

    final steps = <BlockChatAppliedStep>[
      BlockChatAppliedStep(
        title: '스케줄 생성',
        detail: '매일 00:00–${_fmt(endMin)} 「$name」 (타임락 켜짐)',
        route: '/settings/block-schedules/${schedule.id}',
        routeLabel: '스케줄 편집',
      ),
    ];

    if (plan.blockSafariNote) {
      steps.add(
        BlockChatAppliedStep(
          title: 'Isle · 웹·앱 차단',
          detail: '슬롯 안에서 Isle Safari·YouTube·Instagram·Brunch 탐색이 막혀요.',
          route: '/settings/block-schedules/${schedule.id}',
          routeLabel: '스케줄 편집',
        ),
      );
      steps.add(
        const BlockChatAppliedStep(
          title: 'Safari · iPhone 앱',
          detail: '스케줄 편집 → ③ 차단 대상에서 Safari 앱을 Screen Time으로 선택해 주세요.',
          route: '/settings/block-schedules',
          routeLabel: '스케줄 목록',
        ),
      );
    }

    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    unawaited(IosRulesExportService.exportNow());

    return BlockChatResult(
      summary: plan.reply.isNotEmpty
          ? plan.reply
          : '아침 $name 스케줄을 만들었어요.',
      steps: steps,
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
      interventionBody: '세션 ${session}분 후 ${cooldown}분 쉬어요. Isle에서 의도한 콘텐츠만 보세요.',
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
    final schedule = await BlockScheduleStore.create(
      name: schName,
      slots: _allDaySlots(),
      locked: true,
    );
    await BlockScheduleStore.upsert(schedule.copyWith(enabled: true));

    final entries = ScheduleAppTargetsStore.loadForSchedule(schedule.id);
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
      scheduleId: schedule.id,
      entries: patched,
      schedule: schedule.copyWith(enabled: true),
    );

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
          route: '/settings/block-schedules/${schedule.id}',
          routeLabel: '스케줄 편집',
        ),
        if (preset.id == 'instagram')
          const BlockChatAppliedStep(
            title: 'iPhone Instagram 앱',
            detail: '스케줄 편집에서 iPhone Instagram을 Screen Time으로 선택하면 OS 차단이 붙어요.',
            route: '/settings/block-schedules',
            routeLabel: '스케줄 목록',
          ),
      ],
    );
  }

  static Future<BlockChatResult> _removeSchedule(BlockChatPlan plan) async {
    final q = plan.removeScheduleQuery?.toLowerCase() ?? '';
    var list = BlockScheduleStore.loadAll();
    if (q.isNotEmpty) {
      list = list
          .where((s) => s.name.toLowerCase().contains(q))
          .toList();
    }
    if (list.isEmpty) {
      return BlockChatResult.fail(
        q.isEmpty
            ? '해제할 스케줄이 없어요. 스케줄 이름을 알려주세요.'
            : '「$q」가 들어간 스케줄을 찾지 못했어요.',
      );
    }
    final s = list.first;
    final phase = ScheduleLockService.phase(s);

    if (s.locked) {
      if (phase == ScheduleLockPhase.editWindow) {
        await BlockScheduleStore.upsert(s.copyWith(enabled: false));
        await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
        return BlockChatResult(
          summary: '「${s.name}」 스케줄을 껐어요 (편집 창 안).',
          steps: [
            BlockChatAppliedStep(
              title: '스케줄 비활성',
              detail: '타임락 편집 창에서 해제됨',
              route: '/settings/block-schedules/${s.id}',
              routeLabel: '스케줄 보기',
            ),
          ],
        );
      }
      final updated = await ScheduleLockService.startUnlockCountdown(s.id);
      final mins = updated?.lockCooldownMinutes ?? s.lockCooldownMinutes;
      return BlockChatResult(
        summary: '「${s.name}」 해제 대기를 시작했어요. '
            '${mins}분 후 편집 창에서 끌 수 있어요.',
        needsUnlockWait: true,
        unlockMinutes: mins,
        steps: [
          BlockChatAppliedStep(
            title: '타임락 대기 시작',
            detail: '${mins}분 대기 → 5분 편집 창 → 스케줄 끄기',
            route: '/settings/block-schedules/${s.id}',
            routeLabel: '대기 상태 보기',
          ),
        ],
      );
    }

    await BlockScheduleStore.upsert(s.copyWith(enabled: false));
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    return BlockChatResult(
      summary: '「${s.name}」 스케줄을 껐어요.',
      steps: [
        BlockChatAppliedStep(
          title: '스케줄 비활성',
          detail: '다시 켜려면 스케줄 목록에서 활성화하세요.',
          route: '/settings/block-schedules/${s.id}',
          routeLabel: '스케줄 보기',
        ),
      ],
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
    );
  }

  static Future<BlockChatResult> _youtubeLimit(BlockChatPlan plan) async {
    await PlatformWatchLimitStore.ensureOpen();
    final minutes = (plan.dailyMinutes ?? 20).clamp(5, 480);
    final current = PlatformWatchLimitStore.limitMinutes(PlatformWatchId.youtube);
    final enabled = PlatformWatchLimitStore.isEnabled(PlatformWatchId.youtube);

    if (!PlatformWatchLimitStore.canChangeLimit(
      id: PlatformWatchId.youtube,
      newMinutes: minutes,
      newEnabled: true,
    )) {
      final lockMsg = ScheduleEditGuard.canChangeDailyWatchLimit()
          ? '한도에 도달했거나 타임락 때문에 지금은 줄일 수 없어요.'
          : '스케줄 타임락 편집 창 안에서만 한도를 바꿀 수 있어요.';
      return BlockChatResult.fail(
        '유튜브 한도 $minutes분 적용 불가 — $lockMsg\n'
        '현재: ${enabled ? "$current분" : "꺼짐"}',
      );
    }

    if (!enabled) {
      await PlatformWatchLimitStore.setEnabled(PlatformWatchId.youtube, true);
    }
    await PlatformWatchLimitStore.setLimitMinutes(PlatformWatchId.youtube, minutes);
    final applied = PlatformWatchLimitStore.limitMinutes(PlatformWatchId.youtube);
    if (applied != minutes) {
      return BlockChatResult.fail('한도 변경이 적용되지 않았어요. 설정 화면에서 직접 확인해 주세요.');
    }

    return BlockChatResult(
      summary: plan.reply.isNotEmpty ? plan.reply : 'Isle 유튜브 일일 한도를 $minutes분으로 설정했어요.',
      steps: [
        BlockChatAppliedStep(
          title: '유튜브 일일 한도',
          detail: '하루 $minutes분 (Isle 안 유튜브·Safari 유튜브)',
          route: '/home/my-isle/manage',
          routeLabel: '한도 관리',
        ),
      ],
    );
  }

  static BlockSchedule? _findMorningSchedule(String name) {
    final q = name.toLowerCase();
    for (final s in BlockScheduleStore.loadAll()) {
      final n = s.name.toLowerCase();
      if (n == q || n.contains('safari') || n.contains('아침')) return s;
    }
    return null;
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
}
