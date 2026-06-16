import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ai/ai_activity_service.dart';
import '../../../core/ai/ai_client.dart';
import '../../../core/ai/ai_config_store.dart';
import '../../../core/ai/api_budget_store.dart';
import '../../../core/block_schedule/schedule_active_service.dart';
import '../../../core/block_schedule/schedule_edit_guard.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/library/interest_pipeline_service.dart';
import '../../../core/library/interest_pipeline_store.dart' show interestPipelineProvider;
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/youtube/youtube_watch_timer_store.dart';
import '../../feed/providers/feed_provider.dart';
import '../../../core/library/personal_library_store.dart';
import '../../ai/presentation/widgets/ai_waiting_card.dart';
import '../../social/presentation/widgets/instagram_limit_controls.dart';
import '../../youtube/presentation/widgets/screen_time_guide_sheet.dart';
import '../../youtube/presentation/widgets/youtube_limit_controls.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/social/instagram_usage_lock.dart';
import '../../../core/youtube/youtube_usage_lock.dart';

class YoutubeLimitsSettingsScreen extends StatefulWidget {
  const YoutubeLimitsSettingsScreen({super.key});

  @override
  State<YoutubeLimitsSettingsScreen> createState() => _YoutubeLimitsSettingsScreenState();
}

class _YoutubeLimitsSettingsScreenState extends State<YoutubeLimitsSettingsScreen> {
  late bool _intervalMode;
  late bool _enabled;
  late double _allowMinutes;
  late double _windowHours;
  late bool _savedIntervalMode;
  late bool _savedEnabled;
  late double _savedAllowMinutes;
  late double _savedWindowHours;

  @override
  void initState() {
    super.initState();
    _syncFromDefaults();
  }

  void _syncFromDefaults() {
    _intervalMode = IsleUserDefaults.youtubeLimitUsesInterval;
    _enabled = YoutubeWatchTimerStore.isEnabled;
    if (_intervalMode) {
      _allowMinutes = IsleUserDefaults.youtubeIntervalAllowMinutes.toDouble();
      _windowHours = IsleUserDefaults.youtubeIntervalWindowMinutes / 60.0;
    } else {
      _allowMinutes = IsleUserDefaults.youtubeDailyLimitMinutes.toDouble();
      _windowHours = 3;
    }
    _savedIntervalMode = _intervalMode;
    _savedEnabled = _enabled;
    _savedAllowMinutes = _allowMinutes;
    _savedWindowHours = _windowHours;
  }

  bool get _scheduleBlocks => ScheduleActiveService.isYoutubeWebViewBlockedNow();

  bool get _limitReached => YoutubeWatchTimerStore.isLimitReached;

  bool get _canEditLimit => ScheduleEditGuard.canChangeDailyWatchLimit();

  int get _savedMinutes => _savedIntervalMode
      ? IsleUserDefaults.youtubeIntervalAllowMinutes
      : IsleUserDefaults.youtubeDailyLimitMinutes;

  bool get _hasPendingChanges =>
      _intervalMode != _savedIntervalMode ||
      _enabled != _savedEnabled ||
      _allowMinutes.round() != _savedAllowMinutes.round() ||
      (_intervalMode && (_windowHours * 60).round() != (_savedWindowHours * 60).round());

  bool _isLoweringMinutes(double v) => v.round() < _savedMinutes;

  bool _canApplyMinutes(double v) {
    if (!_canEditLimit) return false;
    if (_isLoweringMinutes(v)) return true;
    if (_limitReached) return false;
    return YoutubeUsageLock.canApplyChange(
      currentMinutes: _savedMinutes,
      newMinutes: v.round(),
      currentlyEnabled: _savedEnabled,
      newEnabled: _enabled,
    );
  }

  bool _canToggleEnabled(bool v) {
    if (!_canEditLimit) return false;
    if (!v && _savedEnabled) {
      return YoutubeUsageLock.canApplyChange(
        currentMinutes: _savedMinutes,
        newMinutes: _savedMinutes,
        currentlyEnabled: _savedEnabled,
        newEnabled: false,
      );
    }
    if (v && !_savedEnabled) return true;
    return true;
  }

  Future<void> _setIntervalMode(bool interval) async {
    setState(() {
      _intervalMode = interval;
      if (interval) {
        _allowMinutes = IsleUserDefaults.youtubeIntervalAllowMinutes.toDouble();
        _windowHours = IsleUserDefaults.youtubeIntervalWindowMinutes / 60.0;
      } else {
        _allowMinutes = IsleUserDefaults.youtubeDailyLimitMinutes.toDouble();
        _windowHours = 3;
      }
    });
  }

  Future<void> _setEnabled(bool v) async {
    if (!_canToggleEnabled(v)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('타임락: 한도를 끄려면 아래에서 대기를 시작하세요')),
      );
      return;
    }
    setState(() => _enabled = v);
  }

  Future<void> _savePendingChanges() async {
    if (!_hasPendingChanges) return;
    if (!_canEditLimit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('스케줄 잠금 중 — 한도를 바꿀 수 없어요')),
      );
      return;
    }
    if (!_canApplyMinutes(_allowMinutes)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('타임락: 한도를 늘리려면 아래에서 대기를 시작하세요')),
      );
      return;
    }
    if (!_canToggleEnabled(_enabled)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('타임락: 한도를 끄려면 아래에서 대기를 시작하세요')),
      );
      return;
    }

    await IsleUserDefaults.setYoutubeLimitUsesInterval(_intervalMode);
    if (_intervalMode) {
      await IsleUserDefaults.setYoutubeIntervalLimitEnabled(_enabled);
      await IsleUserDefaults.setYoutubeIntervalWindowMinutes(
        (_windowHours * 60).round().clamp(30, 720),
      );
      await IsleUserDefaults.setYoutubeIntervalAllowMinutes(_allowMinutes.round());
    } else {
      await IsleUserDefaults.setYoutubeDailyLimitEnabled(_enabled);
      await IsleUserDefaults.setYoutubeDailyLimitMinutes(_allowMinutes.round());
    }

    if (!mounted) return;
    setState(_syncFromDefaults);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isLoweringMinutes(_allowMinutes)
              ? '한도를 ${_allowMinutes.round()}분으로 줄였어요'
              : '한도 설정을 저장했어요',
        ),
      ),
    );
  }

  void _discardPendingChanges() {
    setState(_syncFromDefaults);
  }

  @override
  Widget build(BuildContext context) {
    final usedMin = YoutubeWatchTimerStore.secondsUsed ~/ 60;
    final capMin = _enabled
        ? (_intervalMode
            ? IsleUserDefaults.youtubeIntervalAllowMinutes
            : IsleUserDefaults.youtubeDailyLimitMinutes)
        : _allowMinutes.round();

    return Scaffold(
      appBar: AppBar(title: Text('유튜브 시청 한도', style: IsleText.subtitle())),
      bottomNavigationBar: _hasPendingChanges
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: IsleSize.minTouchTarget,
                    child: FilledButton.icon(
                      onPressed: _savePendingChanges,
                      icon: const Icon(Icons.save_outlined),
                      label: Text('${_allowMinutes.round()}분으로 저장'),
                    ),
                  ),
                  TextButton(
                    onPressed: _discardPendingChanges,
                    child: const Text('변경 취소'),
                  ),
                  Text(
                    '줄이기는 바로 적용 · 늘리기·끄기는 타임락 필요',
                    style: IsleText.caption(color: IsleColors.muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          IsleSize.scrollBottomPadding(
            context,
            extra: _hasPendingChanges ? 128 : 16,
          ),
        ),
        children: [
          _YoutubeLimitHeroCard(
            statusLine: YoutubeWatchTimerStore.formatStatusLine(),
            scheduleBlocks: _scheduleBlocks,
            limitReached: _limitReached && !_scheduleBlocks,
            intervalMode: _intervalMode,
          ),
          const SizedBox(height: 20),
          Text('한도 방식', style: IsleText.subtitle(color: IsleColors.ocean900)),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('주기')),
              ButtonSegment(value: false, label: Text('일일')),
            ],
            selected: {_intervalMode},
            onSelectionChanged: _canEditLimit
                ? (s) async {
                    await _setIntervalMode(s.first);
                  }
                : null,
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: IsleColors.ocean100),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _intervalMode ? '주기 한도 켜기' : '일일 한도 켜기',
                      style: IsleText.body(),
                    ),
                    subtitle: Text(
                      _intervalMode
                          ? 'N시간마다 정해진 분만 시청'
                          : '하루 최대 시청 시간',
                      style: IsleText.caption(color: IsleColors.muted),
                    ),
                    value: _enabled,
                    onChanged: _canToggleEnabled(!_enabled) ? (v) => _setEnabled(v) : null,
                  ),
                  if (_enabled) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        '${_allowMinutes.round()}분',
                        style: IsleText.title(color: IsleColors.ocean900),
                      ),
                    ),
                    Text(
                      _intervalMode
                          ? '매 ${_windowHours.toStringAsFixed(1)}시간마다 허용'
                          : '오늘 $usedMin분 사용 · 저장됨 $capMin분',
                      style: IsleText.caption(color: IsleColors.muted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (_intervalMode) ...[
                      Text('주기 길이', style: IsleText.caption(color: IsleColors.muted)),
                      Slider(
                        min: 0.5,
                        max: 12,
                        divisions: 23,
                        label: '${_windowHours.toStringAsFixed(1)}시간',
                        value: _windowHours.clamp(0.5, 12),
                        onChanged: _canEditLimit
                            ? (v) => setState(() => _windowHours = v)
                            : null,
                      ),
                    ],
                    Text('허용 시청', style: IsleText.caption(color: IsleColors.muted)),
                    Slider(
                      min: 5,
                      max: _intervalMode ? 120 : 180,
                      divisions: _intervalMode ? 23 : 35,
                      label: '${_allowMinutes.round()}분',
                      value: _allowMinutes.clamp(5, _intervalMode ? 120.0 : 180.0),
                      onChanged: _canEditLimit
                          ? (v) {
                              if (!_canApplyMinutes(v)) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('타임락: 한도를 늘리려면 아래에서 대기를 시작하세요'),
                                  ),
                                );
                                return;
                              }
                              setState(() => _allowMinutes = v);
                            }
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('타임락', style: IsleText.subtitle(color: IsleColors.ocean900)),
          const SizedBox(height: 4),
          Text(
            '한도를 늘리거나 끄기 전에 기다리는 시간',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 8),
          const YoutubeLimitControls(compact: true, hideUsageInCard: true),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.push('/settings/block-schedules'),
            icon: const Icon(Icons.schedule),
            label: const Text('차단 스케줄'),
          ),
          if (Platform.isIOS || Platform.isAndroid) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => showScreenTimeGuideSheet(context),
              icon: const Icon(Icons.phonelink_lock_outlined),
              label: const Text('유튜브 앱·Safari (Screen Time)'),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Isle 앱 안 WebView에서만 시간을 셉니다.',
            style: IsleText.caption(color: IsleColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _YoutubeLimitHeroCard extends StatelessWidget {
  const _YoutubeLimitHeroCard({
    required this.statusLine,
    required this.scheduleBlocks,
    required this.limitReached,
    required this.intervalMode,
  });

  final String statusLine;
  final bool scheduleBlocks;
  final bool limitReached;
  final bool intervalMode;

  @override
  Widget build(BuildContext context) {
    final bg = limitReached
        ? const Color(0xFFFFEBEE)
        : IsleColors.ocean100.withValues(alpha: 0.55);
    final iconColor = limitReached ? Colors.red.shade700 : IsleColors.ocean700;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: iconColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  statusLine,
                  style: IsleText.subtitle(color: IsleColors.ocean900),
                ),
              ),
            ],
          ),
          if (scheduleBlocks) ...[
            const SizedBox(height: 8),
            Text(
              '스케줄 잠금 중 — 한도를 바꿀 수 없어요.',
              style: IsleText.caption(color: Colors.red.shade700),
            ),
          ] else if (limitReached) ...[
            const SizedBox(height: 8),
            Text(
              intervalMode
                  ? '이번 주기 한도 도달 · 줄이기만 바로 저장 가능'
                  : '오늘 한도 도달 · 줄이기만 바로 저장 가능',
              style: IsleText.caption(color: Colors.red.shade700),
            ),
          ],
        ],
      ),
    );
  }
}

/// Instagram 피드 / DM — 각각 일일 한도 + 설정 타임락
class InstagramLimitsSettingsScreen extends StatefulWidget {
  const InstagramLimitsSettingsScreen({super.key, this.initialScope});

  final InstagramUsageScope? initialScope;

  @override
  State<InstagramLimitsSettingsScreen> createState() =>
      _InstagramLimitsSettingsScreenState();
}

class _InstagramLimitsSettingsScreenState extends State<InstagramLimitsSettingsScreen> {
  late InstagramUsageScope _scope;

  @override
  void initState() {
    super.initState();
    _scope = widget.initialScope ?? InstagramUsageScope.feed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Instagram 한도', style: IsleText.subtitle())),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '피드와 DM은 시간·타임락이 따로예요.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 12),
          SegmentedButton<InstagramUsageScope>(
            segments: const [
              ButtonSegment(
                value: InstagramUsageScope.feed,
                label: Text('피드'),
                icon: Icon(Icons.camera_alt_outlined),
              ),
              ButtonSegment(
                value: InstagramUsageScope.dm,
                label: Text('DM'),
                icon: Icon(Icons.forum_outlined),
              ),
            ],
            selected: {_scope},
            onSelectionChanged: (s) => setState(() => _scope = s.first),
          ),
          const SizedBox(height: 20),
          Text(_scope.label, style: IsleText.subtitle()),
          const SizedBox(height: 8),
          InstagramLimitControls(key: ValueKey(_scope), scope: _scope),
          const Divider(height: 32),
          FilledButton.icon(
            onPressed: () => context.push('/settings/block-schedules'),
            icon: const Icon(Icons.schedule),
            label: const Text('스케줄로 앱 잠금'),
          ),
        ],
      ),
    );
  }
}

class ApiBudgetSettingsScreen extends StatefulWidget {
  const ApiBudgetSettingsScreen({super.key});

  @override
  State<ApiBudgetSettingsScreen> createState() => _ApiBudgetSettingsScreenState();
}

class _ApiBudgetSettingsScreenState extends State<ApiBudgetSettingsScreen> {
  late double _budget;
  late bool _enforced;

  @override
  void initState() {
    super.initState();
    _budget = IsleUserDefaults.apiMonthlyBudgetUsd;
    _enforced = IsleUserDefaults.apiBudgetEnforced;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI API 예산', style: IsleText.subtitle())),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'AI 사용량을 월 예산으로 제한합니다. ${AiClient.isConfigured ? 'API 키 설정됨' : '로컬 폴백만'}',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('예산 강제'),
            value: _enforced,
            onChanged: (v) async {
              await IsleUserDefaults.setApiBudgetEnforced(v);
              setState(() => _enforced = v);
            },
          ),
          Text('월 \$${_budget.toStringAsFixed(1)}', style: IsleText.body()),
          Slider(
            min: 0,
            max: 50,
            divisions: 50,
            value: _budget,
            label: '\$${_budget.toStringAsFixed(1)}',
            onChanged: (v) async {
              setState(() => _budget = v);
              await IsleUserDefaults.setApiMonthlyBudgetUsd(v);
            },
          ),
          const Divider(height: 24),
          Text('이번 달 사용', style: IsleText.subtitle()),
          Text(
            '\$${ApiBudgetStore.spentThisMonthUsd.toStringAsFixed(3)}',
            style: IsleText.body(),
          ),
        ],
      ),
    );
  }
}

class InterestPipelineSettingsScreen extends ConsumerStatefulWidget {
  const InterestPipelineSettingsScreen({super.key});

  @override
  ConsumerState<InterestPipelineSettingsScreen> createState() =>
      _InterestPipelineSettingsScreenState();
}

class _InterestPipelineSettingsScreenState extends ConsumerState<InterestPipelineSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(interestPipelineProvider);

    final activities = AiActivityService.currentActivities()
        .where((a) => a.feature == 'interest_article')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('관심 → 기사', style: IsleText.subtitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => context.push('/settings/ai-hub'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '피드에서 「관심 있어요」 → ${IsleUserDefaults.interestArticleDays}일 후 '
            '${AiConfigStore.isConfigured ? 'AI' : '로컬'} 기사화. '
            '대기 중에는 네트워크 전송 없음.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          if (activities.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...activities.map((a) => AiWaitingCard(item: a)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('기사까지'),
              Expanded(
                child: Slider(
                  value: IsleUserDefaults.interestArticleDays.toDouble(),
                  min: 1,
                  max: 14,
                  divisions: 13,
                  label: '${IsleUserDefaults.interestArticleDays}일',
                  onChanged: (v) async {
                    await IsleUserDefaults.setInterestArticleDays(v.round());
                    setState(() {});
                  },
                ),
              ),
              Text('${IsleUserDefaults.interestArticleDays}일'),
            ],
          ),
          FilledButton(
            onPressed: () async {
              final n = await InterestPipelineService.processDueItems();
              await ref.read(personalLibraryProvider.notifier).reload();
              ref.invalidate(feedProvider);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(n > 0 ? '$n개 처리' : '대기 항목 없음')),
              );
            },
            child: const Text('지금 처리'),
          ),
          const Divider(height: 24),
          Text('대기열 (${queue.length})', style: IsleText.subtitle()),
          if (queue.isEmpty)
            Text('비어 있음', style: IsleText.body(color: IsleColors.muted))
          else
            ...queue.map(
              (e) => ListTile(
                title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${e.sourceType} · ${e.publishArticleAt.toLocal()}'),
              ),
            ),
        ],
      ),
    );
  }
}
