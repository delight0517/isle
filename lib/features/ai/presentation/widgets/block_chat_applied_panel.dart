import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ai/block_chat/block_chat_models.dart';
import '../../../../core/blocking/blocking_controller_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/navigation/isle_routes.dart';
import '../../../../core/navigation/schedule_overlay_navigation.dart';
import '../../../../core/platform/ios_screen_time_service.dart';

/// AI 차단 챗 — 적용 결과를 「어디에 반영됐는지」 적극적으로 보여주는 패널
class BlockChatAppliedPanel extends StatelessWidget {
  const BlockChatAppliedPanel({
    super.key,
    required this.impact,
    this.steps = const [],
    this.permissionGaps = const [],
  });

  final BlockChatApplySummary impact;
  final List<BlockChatAppliedStep> steps;
  final List<BlockChatPermissionGap> permissionGaps;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * 0.94;

    return Container(
      width: width,
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF81C784), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(headline: impact.headline),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (permissionGaps.isNotEmpty) ...[
                  _PermissionGapSection(gaps: permissionGaps),
                  const SizedBox(height: 14),
                ],
                if (impact.hasScheduleVisual) ...[
                  _ScheduleTimeline(
                    timeRange: impact.timeRange!,
                    daysLabel: impact.daysLabel,
                    endMinute: impact.endMinute!,
                  ),
                  const SizedBox(height: 14),
                ],
                if (impact.locations.isNotEmpty) ...[
                  _SectionLabel(
                    icon: Icons.place_outlined,
                    label: '어디에 적용됐나요',
                  ),
                  const SizedBox(height: 8),
                  _LocationGrid(locations: impact.locations),
                  const SizedBox(height: 14),
                ],
                if (impact.targets.isNotEmpty) ...[
                  _SectionLabel(
                    icon: Icons.gpp_maybe_outlined,
                    label: '막히는 대상',
                  ),
                  const SizedBox(height: 8),
                  _TargetChips(targets: impact.targets),
                  const SizedBox(height: 14),
                ],
                if (impact.pendingSteps.isNotEmpty) ...[
                  _PendingSection(steps: impact.pendingSteps),
                  const SizedBox(height: 12),
                ],
                _PrimaryActions(impact: impact, steps: steps),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.headline});

  final String headline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '적용 완료',
                  style: IsleText.caption(color: const Color(0xFF1B5E20))
                      .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
                ),
                const SizedBox(height: 2),
                Text(
                  headline,
                  style: IsleText.subtitle(color: IsleColors.ocean900)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: IsleColors.ocean700),
        const SizedBox(width: 6),
        Text(
          label,
          style: IsleText.caption(color: IsleColors.ocean700)
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ScheduleTimeline extends StatelessWidget {
  const _ScheduleTimeline({
    required this.timeRange,
    this.daysLabel,
    required this.endMinute,
  });

  final String timeRange;
  final String? daysLabel;
  final int endMinute;

  @override
  Widget build(BuildContext context) {
    final fraction = (endMinute / 1440).clamp(0.02, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IsleColors.ocean100.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: IsleColors.ocean700),
              const SizedBox(width: 6),
              Text(
                timeRange,
                style: IsleText.body(color: IsleColors.ocean900)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              if (daysLabel != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: IsleColors.ocean500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    daysLabel!,
                    style: IsleText.caption(color: IsleColors.ocean700)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final barW = constraints.maxWidth;
              final fillW = barW * fraction;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: IsleColors.ocean100),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: fillW,
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF5350), Color(0xFFE53935)],
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  Positioned(
                    left: fillW.clamp(0, barW - 2),
                    top: -3,
                    child: Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC62828),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('00:00', style: IsleText.caption(color: IsleColors.muted)),
              Text(
                '차단 구간 (빨간색)',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              Text(
                '${(endMinute ~/ 60).toString().padLeft(2, '0')}:${(endMinute % 60).toString().padLeft(2, '0')}',
                style: IsleText.caption(color: IsleColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationGrid extends StatelessWidget {
  const _LocationGrid({required this.locations});

  final List<BlockChatApplyLocation> locations;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final loc in locations)
          _LocationTile(location: loc),
      ],
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.location});

  final BlockChatApplyLocation location;

  @override
  Widget build(BuildContext context) {
    final manual = location.needsManualSetup;
    final bg = manual ? const Color(0xFFFFF3E0) : const Color(0xFFF1F8E9);
    final border = manual ? const Color(0xFFFFCC80) : const Color(0xFFA5D6A7);
    final iconColor = manual ? const Color(0xFFE65100) : const Color(0xFF2E7D32);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: location.route != null ? () => pushRoutePreferRoot(context, location.route!) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 148,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(location.icon, size: 18, color: iconColor),
                  if (manual) ...[
                    const Spacer(),
                    Icon(Icons.touch_app, size: 14, color: iconColor),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                location.tabLabel,
                style: IsleText.body().copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                location.detail,
                style: IsleText.caption(color: IsleColors.muted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetChips extends StatelessWidget {
  const _TargetChips({required this.targets});

  final List<BlockChatApplyTarget> targets;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in targets)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (t.tint ?? IsleColors.ocean700).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: t.needsManualSetup
                    ? const Color(0xFFFFB74D)
                    : (t.tint ?? IsleColors.ocean700).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  t.icon,
                  size: 16,
                  color: t.tint ?? IsleColors.ocean700,
                ),
                const SizedBox(width: 6),
                Text(
                  t.label,
                  style: IsleText.caption(color: IsleColors.ocean900)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                if (t.needsManualSetup) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFE65100)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PermissionGapSection extends StatefulWidget {
  const _PermissionGapSection({required this.gaps});

  final List<BlockChatPermissionGap> gaps;

  @override
  State<_PermissionGapSection> createState() => _PermissionGapSectionState();
}

class _PermissionGapSectionState extends State<_PermissionGapSection> {
  bool _busy = false;

  Future<void> _requestOsAuth() async {
    setState(() => _busy = true);
    try {
      if (Platform.isAndroid) {
        final c = resolveBlockingController();
        final res = await c.requestAuthorization();
        if (!mounted) return;
        if (res.ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('접근성 차단이 켜졌어요 — 스케줄 시간에 앱이 막혀요.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message ?? '접근성 설정에서 Isle 차단을 켜 주세요'),
              action: SnackBarAction(
                label: '설정',
                onPressed: () => c.openSystemSettings(),
              ),
            ),
          );
        }
      } else {
        final res = await IosScreenTimeService.requestAuthorizationDetailed();
        if (!mounted) return;
        if (res.ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Screen Time 허용됨 — 이제 앱을 고르면 OS에서 막혀요.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message ?? 'Screen Time 권한이 필요해요'),
              action: SnackBarAction(
                label: '설정',
                onPressed: IosScreenTimeService.openScreenTimeSettings,
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.privacy_tip_outlined, size: 18, color: Color(0xFFC62828)),
              const SizedBox(width: 6),
              Text(
                '권한이 없어 OS 차단이 아직 안 돼요',
                style: IsleText.caption(color: const Color(0xFFB71C1C))
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final g in widget.gaps) ...[
            Text(
              g.title,
              style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              g.issue,
              style: IsleText.caption(color: IsleColors.ocean900).copyWith(height: 1.45),
            ),
            if (g.effectWhenGranted.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bolt, size: 16, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '허용하면: ${g.effectWhenGranted}',
                      style: IsleText.caption(color: const Color(0xFF1B5E20))
                          .copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (g.kind == BlockChatPermissionGapKind.osAuth)
                  FilledButton.icon(
                    onPressed: _busy ? null : _requestOsAuth,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.verified_user_outlined, size: 18),
                    label: Text(g.actionLabel ?? '지금 허용'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC62828),
                      minimumSize: Size(0, IsleSize.minTouchTarget - 8),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => pushRoutePreferRoot(context, g.route),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(g.actionLabel ?? g.routeLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      minimumSize: Size(0, IsleSize.minTouchTarget - 8),
                    ),
                  ),
              ],
            ),
            if (g != widget.gaps.last) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _PendingSection extends StatelessWidget {
  const _PendingSection({required this.steps});

  final List<BlockChatAppliedStep> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFFE65100)),
              const SizedBox(width: 6),
              Text(
                '한 번 더 설정해 주세요 (허용 후 효과)',
                style: IsleText.caption(color: const Color(0xFFE65100))
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final s in steps) ...[
            Text(
              '• ${s.title}: ${s.detail}',
              style: IsleText.caption(color: IsleColors.ocean900).copyWith(height: 1.4),
            ),
            if (s.route != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => pushRoutePreferRoot(context, s.route!),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(s.routeLabel ?? '설정 열기'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE65100),
                    minimumSize: Size(IsleSize.minTouchTarget, IsleSize.minTouchTarget - 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({required this.impact, required this.steps});

  final BlockChatApplySummary impact;
  final List<BlockChatAppliedStep> steps;

  @override
  Widget build(BuildContext context) {
    final scheduleRoute = impact.scheduleId != null
        ? IsleRoutes.blockScheduleEditOutsideShell(impact.scheduleId!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (scheduleRoute != null)
          FilledButton.icon(
            onPressed: () => pushBlockScheduleEdit(context, impact.scheduleId!),
            icon: const Icon(Icons.edit_calendar, size: 18),
            label: const Text('스케줄 편집에서 확인'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              minimumSize: Size.fromHeight(IsleSize.minTouchTarget),
            ),
          ),
        if (scheduleRoute != null) const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/home/block'),
          icon: const Icon(Icons.shield_outlined, size: 18),
          label: const Text('차단 탭에서 보기'),
          style: OutlinedButton.styleFrom(
            foregroundColor: IsleColors.ocean700,
            minimumSize: Size.fromHeight(IsleSize.minTouchTarget - 4),
          ),
        ),
        if (steps.any((s) => s.route != null && !s.needsManualSetup)) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in steps.where((s) => s.route != null && !s.needsManualSetup))
                TextButton(
                  onPressed: () => pushRoutePreferRoot(context, s.route!),
                  child: Text(s.routeLabel ?? s.title),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// "오늘 블락은 뭐가 켜져있어?" 전체 조회 — 앱별 오늘 24시간 타임라인
class BlockChatDailyTimelinePanel extends StatelessWidget {
  const BlockChatDailyTimelinePanel({super.key, required this.items});

  final List<BlockChatDailyTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * 0.94;
    return Container(
      width: width,
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today_outlined, size: 18, color: IsleColors.ocean700),
              const SizedBox(width: 6),
              Text(
                '오늘 차단·한도 타임라인',
                style: IsleText.subtitle().copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _LegendDot(color: const Color(0xFFE53935), label: '완전 차단'),
              const SizedBox(width: 12),
              _LegendDot(color: const Color(0xFFFB8C00), label: '부분 허용(한도)'),
              const SizedBox(width: 12),
              _LegendDot(color: IsleColors.ocean100, label: '자유'),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items) ...[
            _DailyTimelineRow(item: item),
            if (item != items.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: IsleText.caption(color: IsleColors.muted)),
      ],
    );
  }
}

class _DailyTimelineRow extends StatelessWidget {
  const _DailyTimelineRow({required this.item});
  final BlockChatDailyTimelineItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          style: IsleText.body().copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          item.statusText,
          style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final barW = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: IsleColors.ocean100.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: IsleColors.ocean100),
                  ),
                ),
                for (final seg in item.segments)
                  Positioned(
                    left: barW * (seg.startMinute.clamp(0, 1440) / 1440),
                    width: barW *
                        ((seg.endMinute.clamp(seg.startMinute, 1440) -
                                seg.startMinute.clamp(0, 1440)) /
                            1440),
                    top: 0,
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: seg.kind == BlockTimelineSegmentKind.fullBlock
                            ? const Color(0xFFE53935)
                            : const Color(0xFFFB8C00),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('00:00', style: IsleText.caption(color: IsleColors.muted)),
            Text('24:00', style: IsleText.caption(color: IsleColors.muted)),
          ],
        ),
      ],
    );
  }
}

/// impact 없을 때 폴백 — 간단 적용 카드
class BlockChatSimpleAppliedList extends StatelessWidget {
  const BlockChatSimpleAppliedList({
    super.key,
    required this.steps,
    this.scheduledAuto = false,
  });

  final List<BlockChatAppliedStep> steps;
  final bool scheduledAuto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        for (final s in steps)
          _SimpleAppliedCard(step: s, scheduled: scheduledAuto),
      ],
    );
  }
}

class _SimpleAppliedCard extends StatelessWidget {
  const _SimpleAppliedCard({required this.step, this.scheduled = false});

  final BlockChatAppliedStep step;
  final bool scheduled;

  @override
  Widget build(BuildContext context) {
    final bg = scheduled ? const Color(0xFFFFF8E1) : const Color(0xFFE8F5E9);
    final border = scheduled ? const Color(0xFFFFCC80) : const Color(0xFFA5D6A7);
    final icon = scheduled ? Icons.schedule : Icons.check_circle;
    final iconColor =
        scheduled ? const Color(0xFFE65100) : const Color(0xFF2E7D32);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    step.title,
                    style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(step.detail, style: IsleText.caption(color: IsleColors.muted)),
            if (step.route != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: IsleSize.minTouchTarget - 8,
                child: OutlinedButton.icon(
                  onPressed: () => pushRoutePreferRoot(context, step.route!),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(step.routeLabel ?? '설정 열기'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
