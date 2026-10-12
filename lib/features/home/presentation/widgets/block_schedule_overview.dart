import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/block_schedule/block_focus_service.dart';
import '../../../../core/block_schedule/block_schedule_store.dart';
import '../../../../core/block_schedule/models/block_schedule.dart';
import '../../../../core/block_schedule/quick_block_service.dart';
import '../../../../core/block_schedule/schedule_active_service.dart';
import '../../../../core/block_schedule/schedule_app_targets_store.dart';
import '../../../../core/block_schedule/schedule_display_helper.dart';
import '../../../../core/block_schedule/schedule_target_access_guard.dart';
import '../../../../core/block_schedule/volt_schedule_boundary_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/intervention/app_usage_limit_store.dart';
import '../../../../core/intervention/external_app_shield_store.dart';
import '../../../../core/intervention/models/app_usage_limit_rule.dart';
import '../../../../core/intervention/schedule_screen_time_service.dart';
import '../../../../core/intervention/schedule_screen_time_store.dart';
import '../../../../core/intervention/screen_time_selection_summary.dart';
import '../../../../core/navigation/schedule_overlay_navigation.dart';
import '../../../../core/intervention/screen_time_persistence_service.dart';
import '../../../../shared/widgets/screen_time_selection_preview.dart';
import 'schedule_list_card.dart';
import '../../../../core/blocking/blocking_controller_provider.dart';
import '../../../../core/platform/ios_screen_time_service.dart';
import '../../../../core/platform/isle_apple_platform.dart';
import '../../../../core/services/isle_user_defaults.dart';

/// 차단 탭 상단 — 지금 상태 + 스케줄·한도 목록 (튜토리얼보다 우선)
class BlockScheduleOverview extends StatefulWidget {
  const BlockScheduleOverview({
    super.key,
    this.refreshToken = 0,
    this.onRefresh,
    this.afterHero = const [],
  });

  final int refreshToken;
  final VoidCallback? onRefresh;
  /// 히어로(지금 차단) 바로 아래 — 항상 막기·Safari·웹 차단 등
  final List<Widget> afterHero;

  @override
  State<BlockScheduleOverview> createState() => _BlockScheduleOverviewState();
}

class _BlockScheduleOverviewState extends State<BlockScheduleOverview> {
  BlockFocusStatus? _status;
  List<BlockSchedule> _schedules = const [];
  List<BlockSchedule> _activeNow = const [];
  List<AppUsageLimitRule> _limits = const [];
  Set<String> _activeIds = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BlockScheduleOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    await BlockScheduleStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await QuickBlockService.ensureOpen();
    await QuickBlockService.pruneExpired();
    await ScheduleAppTargetsStore.ensureOpen();

    final status = await BlockFocusService.loadStatus();
    final all = BlockScheduleStore.loadAll()
        .where((s) => s.id != QuickBlockService.presetScheduleId)
        .toList();
    final activeNow = ScheduleActiveService.activeSchedulesNow();
    final activeIds = activeNow.map((s) => s.id).toSet();
    final limits = AppUsageLimitStore.loadRules().where((r) => r.enabled).toList();

    if (!mounted) return;
    setState(() {
      _status = status;
      _schedules = all;
      _activeNow = activeNow;
      _limits = limits;
      _activeIds = activeIds;
      _loading = false;
    });
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await _load();
    widget.onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _status == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final status = _status;
    final blocking = status?.scheduleActiveNow == true && status?.masterOn == true;
    final alwaysOn = ExternalAppShieldStore.hasSelection &&
        !ExternalAppShieldStore.syncWithBlockSchedule;
    final hasAnySchedule = _schedules.isNotEmpty;
    final masterOn = status?.masterOn ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LiveStatusHero(
          status: status,
          blocking: blocking,
          alwaysOn: alwaysOn,
          alwaysOnAppCount: ExternalAppShieldStore.applicationCount,
          masterOn: masterOn,
          activeSchedules: _activeNow,
        ),
        if (widget.afterHero.isNotEmpty) ...[
          for (final w in widget.afterHero) ...[
            const SizedBox(height: 16),
            w,
          ],
        ],
        if (IsleUserDefaults.pendingScreenTimeReapply &&
            (ExternalAppShieldStore.hasSelection ||
                ScheduleScreenTimeStore.box.isNotEmpty)) ...[
          const SizedBox(height: 10),
          _ScreenTimeRestoreBanner(onRestored: _reload),
        ],
        if (!masterOn && hasAnySchedule) ...[
          const SizedBox(height: 10),
          _WarningStrip(
            icon: Icons.toggle_off,
            color: IsleColors.gold500,
            text: '스케줄 차단이 꺼져 있어요 — 아래 목록이 적용되지 않습니다.',
            actionLabel: '켜기',
            onAction: () => pushBlockScheduleList(context),
          ),
        ],
        if (status != null && !_setupComplete(status)) ...[
          const SizedBox(height: 10),
          _SetupGapBanner(status: status, onRefresh: _reload),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Text('차단 스케줄', style: IsleText.subtitle(color: IsleColors.ocean900)),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                await pushBlockScheduleList(context);
                if (mounted) await _reload();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('추가'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (!hasAnySchedule)
          _EmptySchedulesCard(onAdd: () async {
            await pushBlockScheduleList(context);
            if (mounted) await _reload();
          })
        else
          ..._schedules.map((s) => ScheduleListCard(
                schedule: s,
                active: _activeIds.contains(s.id),
                onTap: () async {
                  await pushBlockScheduleEdit(context, s.id);
                  if (mounted) await _reload();
                },
                onEditApps: () async {
                  await ScheduleScreenTimeService.pickForSchedule(
                    s.id,
                    additiveOnly: ScheduleScreenTimeService.shouldUseAdditiveOnly(s.id),
                  );
                  if (mounted) await _reload();
                },
              )),
        const SizedBox(height: 18),
        Row(
          children: [
            Text('앱 시간 한도', style: IsleText.subtitle(color: IsleColors.ocean900)),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/settings/app-usage-limits'),
              child: const Text('편집'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_limits.isEmpty)
          _MutedCard(
            child: Text(
              '설정된 한도 없음 — Instagram·TikTok 등 일일/시간당 제한을 추가할 수 있어요.',
              style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
            ),
          )
        else
          ..._limits.map((r) => _LimitRow(rule: r)),
        const SizedBox(height: 14),
        _ShieldSummary(
          encoded: ExternalAppShieldStore.encodedSelection,
          appCount: status?.appCount ?? ExternalAppShieldStore.applicationCount,
          categoryCount: ExternalAppShieldStore.categoryCount,
          textLabels: ScreenTimeSelectionSummary.textLabelsGlobal(),
          onTap: () => context.push('/settings/external-apps'),
          onEditApps: () => context.push('/settings/external-apps'),
        ),
        if (blocking) ...[
          const SizedBox(height: 10),
          Builder(
            builder: (_) {
              final label = VoltScheduleBoundaryService.nextTransitionLabel();
              if (label == null) return const SizedBox.shrink();
              return Text(label, style: IsleText.caption(color: IsleColors.ocean700));
            },
          ),
        ],
      ],
    );
  }

  bool _setupComplete(BlockFocusStatus s) {
    if (!IsleApplePlatform.isNativeBlockHost) return true;
    return s.osAuthorized && s.hasApps && s.hasSchedule && s.masterOn;
  }
}

class _LiveStatusHero extends StatelessWidget {
  const _LiveStatusHero({
    required this.status,
    required this.blocking,
    required this.alwaysOn,
    required this.alwaysOnAppCount,
    required this.masterOn,
    required this.activeSchedules,
  });

  final BlockFocusStatus? status;
  final bool blocking;
  final bool alwaysOn;
  final int alwaysOnAppCount;
  final bool masterOn;
  final List<BlockSchedule> activeSchedules;

  @override
  Widget build(BuildContext context) {
    final activeCount = status?.activeScheduleCount ?? 0;
    Color bg1;
    Color bg2;
    IconData icon;
    String title;
    String subtitle;

    final todayLine =
        '${ScheduleDisplayHelper.todayHeadline()} · ${ScheduleDisplayHelper.clockLabel()}';

    if (blocking) {
      bg1 = const Color(0xFF1B4332);
      bg2 = const Color(0xFF2D6A5A);
      icon = Icons.shield;
      title = '지금 차단 중';
      final summary = ScheduleDisplayHelper.heroBlockingSummary(
        scheduleCount: activeCount,
        activeSchedules: activeSchedules,
      );
      subtitle = '$todayLine\n$summary';
    } else if (alwaysOn && alwaysOnAppCount > 0) {
      bg1 = const Color(0xFF6A1B1B);
      bg2 = const Color(0xFFB71C1C);
      icon = Icons.lock;
      title = '항상 막기 켜짐';
      subtitle = '$todayLine\n앱 $alwaysOnAppCount개 잠금 · 스케줄 없어도 유지';
    } else if (masterOn && (status?.hasSchedule ?? false)) {
      bg1 = IsleColors.ocean700;
      bg2 = IsleColors.ocean500;
      icon = Icons.schedule;
      title = '대기 중';
      subtitle = '$todayLine\n${status?.headline ?? '스케줄 시간에 자동으로 차단됩니다'}';
    } else {
      bg1 = const Color(0xFF5C4B3A);
      bg2 = const Color(0xFF8B7355);
      icon = Icons.shield_outlined;
      title = '차단 미설정';
      subtitle = '$todayLine\n${status?.headline ?? '스케줄을 추가하면 여기서 상태가 보여요'}';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [bg1, bg2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bg2.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: IsleText.title(color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: IsleText.caption(color: Colors.white.withValues(alpha: 0.88)).copyWith(height: 1.35),
                ),
                if (blocking && activeSchedules.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ActiveTargetChips(schedules: activeSchedules),
                ],
                if (alwaysOn && !blocking && alwaysOnAppCount > 0) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _IsleTargetChip(
                        icon: Icons.apps,
                        label: '앱 $alwaysOnAppCount개',
                        color: Colors.white,
                      ),
                    ],
                  ),
                ],
                if (ScheduleTargetAccessGuard.isIsleYoutubeBlocked) ...[
                  const SizedBox(height: 8),
                  _IsleTargetChip(
                    icon: Icons.headphones,
                    label: 'Isle 유튜브 막힘',
                    color: const Color(0xFFFF0000),
                  ),
                ],
              ],
            ),
          ),
          if (blocking)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'ON',
                style: IsleText.caption(color: Colors.white).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveTargetChips extends StatelessWidget {
  const _ActiveTargetChips({required this.schedules});

  final List<BlockSchedule> schedules;

  @override
  Widget build(BuildContext context) {
    final labels = ScheduleDisplayHelper.uniqueTargetLabelsForSchedules(schedules);
    if (labels.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: labels.take(6).map((l) => _IsleTargetChip(
            icon: Icons.block,
            label: l,
            color: Colors.white,
          )).toList(),
    );
  }
}

class _IsleTargetChip extends StatelessWidget {
  const _IsleTargetChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: IsleText.caption(color: Colors.white).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({required this.rule});
  final AppUsageLimitRule rule;

  @override
  Widget build(BuildContext context) {
    final window = rule.windowMinutes >= 1440 ? '일일' : '${rule.windowMinutes}분';
    return _MutedCard(
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 18, color: IsleColors.ocean500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${rule.label} · $window ${rule.minutesPerWindow}분',
              style: IsleText.body(),
            ),
          ),
          Icon(Icons.check_circle, size: 16, color: IsleColors.grassDeep.withValues(alpha: 0.8)),
        ],
      ),
    );
  }
}

class _ShieldSummary extends StatelessWidget {
  const _ShieldSummary({
    required this.encoded,
    required this.appCount,
    required this.categoryCount,
    required this.textLabels,
    required this.onTap,
    required this.onEditApps,
  });

  final String? encoded;
  final int appCount;
  final int categoryCount;
  final List<String> textLabels;
  final VoidCallback onTap;
  final VoidCallback onEditApps;

  @override
  Widget build(BuildContext context) {
    final hasSel = appCount > 0 || categoryCount > 0;
    return _MutedCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasSel ? Icons.apps : Icons.apps_outlined,
                color: hasSel ? IsleColors.ocean500 : IsleColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasSel
                      ? '전역 Screen Time · 앱 $appCount개 · 카테고리 $categoryCount개'
                      : '차단할 앱 미선택 — 탭해서 고르세요',
                  style: IsleText.body(color: hasSel ? IsleColors.ocean900 : IsleColors.muted),
                ),
              ),
              const Icon(Icons.chevron_right, color: IsleColors.muted, size: 20),
            ],
          ),
          if (encoded != null || textLabels.isNotEmpty) ...[
            const SizedBox(height: 10),
            ScreenTimeSelectionPreview(
              encoded: encoded,
              textFallbackLabels: textLabels,
              height: 36,
            ),
          ],
          if (hasSel) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onEditApps,
                child: const Text('앱 목록 수정'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySchedulesCard extends StatelessWidget {
  const _EmptySchedulesCard({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IsleColors.gold500.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: IsleColors.gold500),
              const SizedBox(width: 8),
              Text('차단 스케줄 없음', style: IsleText.subtitle(color: IsleColors.ocean900)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '아직 막을 시간표가 없어요. 평일 밤·주말 등 원하는 시간에 Instagram·YouTube 앱을 자동으로 잠글 수 있습니다.',
            style: IsleText.body(color: IsleColors.ocean700).copyWith(height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('첫 스케줄 만들기'),
            style: FilledButton.styleFrom(
              backgroundColor: IsleColors.ocean500,
              minimumSize: const Size.fromHeight(IsleSize.minTouchTarget),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenTimeRestoreBanner extends StatelessWidget {
  const _ScreenTimeRestoreBanner({required this.onRestored});

  final Future<void> Function() onRestored;

  Future<void> _approve(BuildContext context) async {
    final res = await IosScreenTimeService.requestAuthorizationDetailed();
    if (!context.mounted) return;
    if (res.ok) {
      await ScreenTimePersistenceService.onAuthorizationGranted();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장된 앱 차단을 다시 적용했어요')),
      );
      await onRestored();
    } else if (res.message != null && res.message!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _WarningStrip(
      icon: Icons.restore,
      color: IsleColors.ocean700,
      text: '앱을 다시 설치했어요. 차단·한도 데이터는 복구됐어요 — 아래 「승인」을 눌렀을 때만 Screen Time을 물어봅니다.',
      actionLabel: '승인',
      onAction: () => unawaited(_approve(context)),
    );
  }
}

class _SetupGapBanner extends StatefulWidget {
  const _SetupGapBanner({required this.status, required this.onRefresh});
  final BlockFocusStatus status;
  final Future<void> Function() onRefresh;

  @override
  State<_SetupGapBanner> createState() => _SetupGapBannerState();
}

class _SetupGapBannerState extends State<_SetupGapBanner> {
  bool _busy = false;

  Future<void> _requestAuth() async {
    setState(() => _busy = true);
    try {
      if (Platform.isAndroid) {
        final c = resolveBlockingController();
        final res = await c.requestAuthorization();
        if (!mounted) return;
        if (res.ok) {
          await widget.onRefresh();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message ?? '접근성 차단 서비스를 켜 주세요'),
              action: SnackBarAction(
                label: '설정',
                onPressed: () => c.openSystemSettings(),
              ),
            ),
          );
        }
        return;
      }
      final res = await IosScreenTimeService.requestAuthorizationDetailed();
      if (!mounted) return;
      if (res.ok) {
        await widget.onRefresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Screen Time 권한이 필요해요'),
            action: SnackBarAction(
              label: 'iOS 설정',
              onPressed: IosScreenTimeService.openScreenTimeSettings,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    // 첫 번째 미완료 항목만 배너로 표시
    if (IsleApplePlatform.isNativeBlockHost && !status.osAuthorized) {
      final isAndroid = Platform.isAndroid;
      return _WarningStrip(
        icon: _busy ? Icons.hourglass_top : Icons.security,
        color: IsleColors.ocean500,
        text: isAndroid
            ? '접근성 차단 서비스를 켜야 앱 차단이 작동해요 (아래 버튼을 탭하세요)'
            : 'Screen Time 권한을 허용해야 앱 차단이 작동해요 (아래 버튼을 탭하세요)',
        actionLabel: _busy ? '요청 중…' : (isAndroid ? '설정 열기' : '지금 허용'),
        onAction: _busy ? () {} : _requestAuth,
      );
    }
    if (IsleApplePlatform.isNativeBlockHost && !status.hasApps) {
      return _WarningStrip(
        icon: Icons.apps_outage,
        color: IsleColors.gold500,
        text: '막을 앱(Instagram 등)을 아직 고르지 않았어요',
        actionLabel: '앱 선택',
        onAction: () => context.push('/settings/external-apps'),
      );
    }
    if (!status.hasSchedule) {
      return _WarningStrip(
        icon: Icons.schedule,
        color: IsleColors.gold500,
        text: '차단 시간표가 없어요 — 언제 막을지 추가하세요',
        actionLabel: '스케줄 추가',
        onAction: () => pushBlockScheduleList(context),
      );
    }
    if (!status.masterOn) {
      return _WarningStrip(
        icon: Icons.toggle_off,
        color: IsleColors.muted,
        text: '스케줄 차단 스위치가 꺼져 있어요',
        actionLabel: '켜기',
        onAction: () => pushBlockScheduleList(context),
      );
    }
    return const SizedBox.shrink();
  }
}

class _WarningStrip extends StatelessWidget {
  const _WarningStrip({
    required this.icon,
    required this.color,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: IsleText.caption(color: IsleColors.ocean900))),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _MutedCard extends StatelessWidget {
  const _MutedCard({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: IsleColors.ocean100),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
