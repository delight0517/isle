import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/isle_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/usage_budget/usage_budget_models.dart';
import '../../../../core/usage_budget/usage_budget_store.dart';
import '../../../../core/youtube/youtube_usage_lock.dart';
import '../../../../core/youtube/youtube_watch_timer_store.dart';

/// 유튜브 탭 상단 — 주기·일일 한도를 프리셋으로 바로 설정
class YoutubeWatchLimitHubCard extends StatefulWidget {
  const YoutubeWatchLimitHubCard({super.key});

  @override
  State<YoutubeWatchLimitHubCard> createState() => _YoutubeWatchLimitHubCardState();
}

class _YoutubeWatchLimitHubCardState extends State<YoutubeWatchLimitHubCard> {
  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<bool> _confirmPresetChange({
    required String label,
    required bool lowering,
    required int minutes,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lowering ? '한도를 줄일까요?' : '한도를 늘릴까요?'),
        content: Text(
          lowering
              ? '「$label」로 줄입니다.\n실수 방지를 위해 확인이 필요해요.'
              : '「$label」로 늘립니다.\n타임락 대기를 완료한 뒤에만 가능해요.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lowering ? '줄이기' : '늘리기'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _applyPreset({
    required bool interval,
    required int windowMinutes,
    required int allowMinutes,
    required String label,
  }) async {
    final current = interval
        ? IsleUserDefaults.youtubeIntervalAllowMinutes
        : IsleUserDefaults.youtubeDailyLimitMinutes;
    final budget = UsageBudgetStore.policyFor(UsageBudgetTarget.youtube);
    final budgetOn = budget?.enabled ?? false;
    final isLowering = allowMinutes < current;
    final canApply = YoutubeUsageLock.canApplyPolicyChange(
      currentlyEnabled: budgetOn || YoutubeWatchTimerStore.isEnabled,
      newEnabled: true,
      currentDailyTotalMinutes: budgetOn ? budget!.dailyCapMinutes : current,
      newDailyTotalMinutes: allowMinutes,
      modeChanged: budgetOn || interval != YoutubeWatchTimerStore.usesInterval,
    );
    if (!canApply) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('타임락: 한도 방식 변경은 대기 완료 후 가능해요')),
        );
      }
      return;
    }
    if (!await _confirmPresetChange(
      label: label,
      lowering: isLowering,
      minutes: allowMinutes,
    )) {
      return;
    }
    await IsleUserDefaults.setYoutubeLimitUsesInterval(interval);
    if (interval) {
      await IsleUserDefaults.setYoutubeIntervalLimitEnabled(true);
      await IsleUserDefaults.setYoutubeIntervalWindowMinutes(windowMinutes);
      await IsleUserDefaults.setYoutubeIntervalAllowMinutes(allowMinutes);
    } else {
      await IsleUserDefaults.setYoutubeDailyLimitEnabled(true);
      await IsleUserDefaults.setYoutubeDailyLimitMinutes(allowMinutes);
    }
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLowering
                ? '한도를 ${allowMinutes}분으로 줄였어요'
                : '한도를 ${allowMinutes}분으로 저장했어요',
          ),
        ),
      );
    }
  }

  Future<void> _setLimitEnabled(bool v) async {
    if (!v &&
        !YoutubeUsageLock.canApplyChange(
          currentMinutes: YoutubeWatchTimerStore.usesInterval
              ? IsleUserDefaults.youtubeIntervalAllowMinutes
              : IsleUserDefaults.youtubeDailyLimitMinutes,
          newMinutes: YoutubeWatchTimerStore.usesInterval
              ? IsleUserDefaults.youtubeIntervalAllowMinutes
              : IsleUserDefaults.youtubeDailyLimitMinutes,
          currentlyEnabled: YoutubeWatchTimerStore.isEnabled,
          newEnabled: false,
        )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('타임락: 한도를 끄려면 대기를 완료하세요')),
        );
      }
      return;
    }
    if (YoutubeWatchTimerStore.usesInterval) {
      await IsleUserDefaults.setYoutubeIntervalLimitEnabled(v);
    } else {
      await IsleUserDefaults.setYoutubeDailyLimitEnabled(v);
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final on = YoutubeWatchTimerStore.isEnabled;
    final interval = YoutubeWatchTimerStore.usesInterval;

    return Card(
      elevation: 0,
      color: on ? IsleColors.ocean100 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: on ? IsleColors.ocean500 : IsleColors.muted.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_clock, color: on ? IsleColors.ocean700 : IsleColors.muted),
                const SizedBox(width: 10),
                Expanded(child: Text('유튜브 시청 한도', style: IsleText.subtitle())),
                Switch(
                  value: on,
                  onChanged: (v) => unawaited(_setLimitEnabled(v)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              YoutubeWatchTimerStore.formatStatusLine(),
              style: IsleText.caption(color: IsleColors.muted),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('주기 한도')),
                ButtonSegment(value: false, label: Text('일일 한도')),
              ],
              selected: {interval},
              onSelectionChanged: (s) async {
                await IsleUserDefaults.setYoutubeLimitUsesInterval(s.first);
                _refresh();
              },
            ),
            const SizedBox(height: 10),
            Text(
              interval ? '이 간격마다 시청 가능 분만 허용' : '하루 총 시청 시간',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: interval
                  ? [
                      _PresetChip(
                        label: '3시간 · 20분',
                        selected: on &&
                            IsleUserDefaults.youtubeIntervalWindowMinutes == 180 &&
                            IsleUserDefaults.youtubeIntervalAllowMinutes == 20,
                        onTap: () => _applyPreset(
                          interval: true,
                          windowMinutes: 180,
                          allowMinutes: 20,
                          label: '3시간 · 20분',
                        ),
                      ),
                      _PresetChip(
                        label: '1시간 · 10분',
                        selected: on &&
                            IsleUserDefaults.youtubeIntervalWindowMinutes == 60 &&
                            IsleUserDefaults.youtubeIntervalAllowMinutes == 10,
                        onTap: () => _applyPreset(
                          interval: true,
                          windowMinutes: 60,
                          allowMinutes: 10,
                          label: '1시간 · 10분',
                        ),
                      ),
                      _PresetChip(
                        label: '6시간 · 30분',
                        selected: on &&
                            IsleUserDefaults.youtubeIntervalWindowMinutes == 360 &&
                            IsleUserDefaults.youtubeIntervalAllowMinutes == 30,
                        onTap: () => _applyPreset(
                          interval: true,
                          windowMinutes: 360,
                          allowMinutes: 30,
                          label: '6시간 · 30분',
                        ),
                      ),
                    ]
                  : [
                      _PresetChip(
                        label: '하루 20분',
                        selected: on && IsleUserDefaults.youtubeDailyLimitMinutes == 20,
                        onTap: () => _applyPreset(
                          interval: false,
                          windowMinutes: 1440,
                          allowMinutes: 20,
                          label: '하루 20분',
                        ),
                      ),
                      _PresetChip(
                        label: '하루 45분',
                        selected: on && IsleUserDefaults.youtubeDailyLimitMinutes == 45,
                        onTap: () => _applyPreset(
                          interval: false,
                          windowMinutes: 1440,
                          allowMinutes: 45,
                          label: '하루 45분',
                        ),
                      ),
                      _PresetChip(
                        label: '하루 90분',
                        selected: on && IsleUserDefaults.youtubeDailyLimitMinutes == 90,
                        onTap: () => _applyPreset(
                          interval: false,
                          windowMinutes: 1440,
                          allowMinutes: 90,
                          label: '하루 90분',
                        ),
                      ),
                    ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push(IsleRoutes.youtubeLimits),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('세부 조절'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: IsleColors.ocean500.withValues(alpha: 0.2),
      checkmarkColor: IsleColors.ocean700,
    );
  }
}
