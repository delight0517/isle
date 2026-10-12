import 'dart:async';
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
import '../../../core/platform/platform_block_intent.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/localization/settings_strings.dart';
import '../../../core/library/interest_pipeline_service.dart';
import '../../../core/library/interest_pipeline_store.dart'
    show interestPipelineProvider;
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/usage_budget/usage_budget_engine.dart';
import '../../../core/usage_budget/usage_budget_models.dart';
import '../../../core/usage_budget/usage_budget_store.dart';
import '../../../core/youtube/youtube_watch_timer_store.dart';
import '../../feed/providers/feed_provider.dart';
import '../../../core/library/personal_library_store.dart';
import '../../ai/presentation/widgets/ai_waiting_card.dart';
import '../../social/presentation/widgets/instagram_limit_controls.dart';
import '../../youtube/presentation/widgets/screen_time_guide_sheet.dart';
import '../../youtube/presentation/widgets/youtube_limit_controls.dart';
import '../../../core/qa/device_qa_item_panel.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_version_badge_layout.dart';
import '../../../core/social/instagram_usage_lock.dart';
import '../../../core/youtube/youtube_usage_lock.dart';

class YoutubeLimitsSettingsScreen extends StatefulWidget {
  const YoutubeLimitsSettingsScreen({super.key, this.qaMode = false});

  final bool qaMode;

  @override
  State<YoutubeLimitsSettingsScreen> createState() =>
      _YoutubeLimitsSettingsScreenState();
}

enum _YoutubeLimitMode { budget, interval, daily }

class _YoutubeLimitsSettingsScreenState
    extends State<YoutubeLimitsSettingsScreen> {
  late bool _intervalMode;
  late bool _budgetMode;
  late bool _enabled;
  late double _allowMinutes;
  late double _windowHours;
  late double _dailyCapMinutes;
  late double _burstMinutes;
  late double _refillMinutes;
  late double _cooldownMinutes;
  late bool _savedIntervalMode;
  late bool _savedBudgetMode;
  late bool _savedEnabled;
  late double _savedAllowMinutes;
  late double _savedWindowHours;
  late double _savedDailyCapMinutes;
  late double _savedBurstMinutes;
  late double _savedRefillMinutes;
  late double _savedCooldownMinutes;
  bool _qaSliderTouched = false;
  bool _qaSavedAfterChange = false;
  bool _qaBadgeLiftSeen = false;

  @override
  void initState() {
    super.initState();
    _syncFromDefaults();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyReadyDraftIfPending();
      _updateBadgeLift();
    });
  }

  /// 대기(타임락)가 끝난 예약 변경을 자동 적용한다 — 화면을 열 때마다 확인.
  /// (2026-07-20: "안 된다"고만 하지 않고 대기 후 자동 적용해달라는 요청)
  void _applyReadyDraftIfPending() {
    final draft = YoutubeUsageLock.takeReadyPolicyDraft();
    if (draft == null) return;
    setState(() {
      _budgetMode = draft['budgetMode'] as bool? ?? _budgetMode;
      _intervalMode = draft['intervalMode'] as bool? ?? _intervalMode;
      _enabled = draft['enabled'] as bool? ?? _enabled;
      _allowMinutes =
          (draft['allowMinutes'] as num?)?.toDouble() ?? _allowMinutes;
      _windowHours = (draft['windowHours'] as num?)?.toDouble() ?? _windowHours;
      _dailyCapMinutes =
          (draft['dailyCapMinutes'] as num?)?.toDouble() ?? _dailyCapMinutes;
      _burstMinutes =
          (draft['burstMinutes'] as num?)?.toDouble() ?? _burstMinutes;
      _refillMinutes =
          (draft['refillMinutes'] as num?)?.toDouble() ?? _refillMinutes;
      _cooldownMinutes =
          (draft['cooldownMinutes'] as num?)?.toDouble() ?? _cooldownMinutes;
    });
    unawaited(_persistCurrentDraftFields(
      snackMessage: '예약했던 한도 설정이 타임락 해제 후 자동으로 적용됐어요',
    ));
  }

  Map<String, dynamic> _draftAsMap() => {
        'budgetMode': _budgetMode,
        'intervalMode': _intervalMode,
        'enabled': _enabled,
        'allowMinutes': _allowMinutes,
        'windowHours': _windowHours,
        'dailyCapMinutes': _dailyCapMinutes,
        'burstMinutes': _burstMinutes,
        'refillMinutes': _refillMinutes,
        'cooldownMinutes': _cooldownMinutes,
      };

  /// 타임락에 막힌 변경을 "안 됨"으로 끝내지 않고, 대기 완료 후 자동
  /// 적용되도록 예약할지 물어본다. 예약 후에도 아래 배너의 "예약 취소"로
  /// 언제든 되돌릴 수 있다.
  Future<void> _offerToReserve(String lockMessage) async {
    final freezeMinutes = YoutubeUsageLock.unlockFreezeMinutes;
    final strings = SettingsStrings.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('timer_change_title')),
        content: Text(
          '$lockMessage\n\n${strings.t('timer_change_body', args: {
                'minutes': '$freezeMinutes'
              })}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('그만둘게요')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.t('timer_change_action')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await YoutubeUsageLock.reserveDraftUntilUnlocked(_draftAsMap());
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.t('timer_change_done')),
      ),
    );
  }

  Future<void> _cancelReservedDraft() async {
    await YoutubeUsageLock.clearPendingPolicyDraft();
    if (!mounted) return;
    setState(_syncFromDefaults);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('예약을 취소했어요 — 설정은 그대로예요')),
    );
  }

  @override
  void dispose() {
    AppVersionBadgeLayout.instance.clearLift();
    super.dispose();
  }

  void _updateBadgeLift() {
    if (!mounted) return;
    final lift = _hasPendingChanges ? IsleSize.stickySaveBarHeight : 0.0;
    AppVersionBadgeLayout.instance.setLift(lift);
    if (widget.qaMode && lift > 0) {
      _qaBadgeLiftSeen = true;
    }
  }

  void _markQaSliderTouched() {
    if (widget.qaMode && !_qaSliderTouched) {
      _qaSliderTouched = true;
    }
  }

  void _syncFromDefaults() {
    final budget = UsageBudgetStore.policyFor(UsageBudgetTarget.youtube);
    _budgetMode = budget?.enabled ?? false;
    _intervalMode =
        _budgetMode ? false : IsleUserDefaults.youtubeLimitUsesInterval;
    _enabled = _budgetMode ? true : YoutubeWatchTimerStore.isEnabled;
    _dailyCapMinutes = (budget?.dailyCapMinutes ?? 60).toDouble();
    _burstMinutes = (budget?.burstCapMinutes ?? 20).toDouble();
    _refillMinutes = (budget?.refillIntervalMinutes ?? 60).toDouble();
    _cooldownMinutes = (budget?.cooldownMinutes ?? 60).toDouble();
    if (_intervalMode) {
      _allowMinutes = IsleUserDefaults.youtubeIntervalAllowMinutes.toDouble();
      _windowHours = IsleUserDefaults.youtubeIntervalWindowMinutes / 60.0;
    } else {
      _allowMinutes = IsleUserDefaults.youtubeDailyLimitMinutes.toDouble();
      _windowHours = 3;
    }
    _savedIntervalMode = _intervalMode;
    _savedBudgetMode = _budgetMode;
    _savedEnabled = _enabled;
    _savedAllowMinutes = _allowMinutes;
    _savedWindowHours = _windowHours;
    _savedDailyCapMinutes = _dailyCapMinutes;
    _savedBurstMinutes = _burstMinutes;
    _savedRefillMinutes = _refillMinutes;
    _savedCooldownMinutes = _cooldownMinutes;
  }

  bool get _scheduleBlocks =>
      ScheduleActiveService.isYoutubeWebViewBlockedNow();

  bool get _limitReached => YoutubeWatchTimerStore.isLimitReached;

  bool get _canEditLimit => ScheduleEditGuard.canChangeDailyWatchLimit();

  int get _savedMinutes => _savedIntervalMode
      ? IsleUserDefaults.youtubeIntervalAllowMinutes
      : IsleUserDefaults.youtubeDailyLimitMinutes;

  int get _savedDailyTotalForLock => _savedBudgetMode
      ? _savedDailyCapMinutes.round()
      : _savedAllowMinutes.round();

  int get _newDailyTotalForLock =>
      _budgetMode ? _dailyCapMinutes.round() : _allowMinutes.round();

  bool get _modeChangedForLock =>
      _budgetMode != _savedBudgetMode || _intervalMode != _savedIntervalMode;

  bool get _cadenceWeakenedForLock {
    if (_budgetMode && _savedBudgetMode) {
      return _burstMinutes.round() > _savedBurstMinutes.round() ||
          _refillMinutes.round() < _savedRefillMinutes.round() ||
          _cooldownMinutes.round() < _savedCooldownMinutes.round();
    }
    if (_intervalMode && _savedIntervalMode) {
      return (_windowHours * 60).round() < (_savedWindowHours * 60).round();
    }
    return false;
  }

  bool get _canApplyPolicyDraft => YoutubeUsageLock.canApplyPolicyChange(
        currentlyEnabled: _savedEnabled,
        newEnabled: _enabled,
        currentDailyTotalMinutes: _savedDailyTotalForLock,
        newDailyTotalMinutes: _newDailyTotalForLock,
        modeChanged: _modeChangedForLock,
        cadenceWeakened: _cadenceWeakenedForLock,
      );

  String? get _policyLockMessage {
    if (!_canEditLimit) return '스케줄 잠금 중 — 한도를 바꿀 수 없어요';
    if (_canApplyPolicyDraft) return null;
    return '타임락: 한도 방식·총량·충전 규칙을 바꾸려면 아래에서 대기를 완료하세요';
  }

  bool get _hasPendingChanges =>
      _budgetMode != _savedBudgetMode ||
      _intervalMode != _savedIntervalMode ||
      _enabled != _savedEnabled ||
      _allowMinutes.round() != _savedAllowMinutes.round() ||
      (_budgetMode &&
          (_dailyCapMinutes.round() != _savedDailyCapMinutes.round() ||
              _burstMinutes.round() != _savedBurstMinutes.round() ||
              _refillMinutes.round() != _savedRefillMinutes.round() ||
              _cooldownMinutes.round() != _savedCooldownMinutes.round())) ||
      (_intervalMode &&
          (_windowHours * 60).round() != (_savedWindowHours * 60).round());

  bool _isLoweringMinutes(double v) => v.round() < _savedMinutes;

  bool _canApplyMinutes(double v) {
    if (_budgetMode) return _canEditLimit && _canApplyPolicyDraft;
    if (!_canEditLimit) return false;
    if (!_canApplyPolicyDraft) return false;
    if (_isLoweringMinutes(v)) return true;
    if (_limitReached) return false;
    return YoutubeUsageLock.canApplyChange(
      currentMinutes: _savedMinutes,
      newMinutes: v.round(),
      currentlyEnabled: _savedEnabled,
      newEnabled: _enabled,
    );
  }

  _YoutubeLimitMode get _mode {
    if (_budgetMode) return _YoutubeLimitMode.budget;
    return _intervalMode ? _YoutubeLimitMode.interval : _YoutubeLimitMode.daily;
  }

  Future<void> _setMode(_YoutubeLimitMode mode) async {
    _markQaSliderTouched();
    setState(() {
      _budgetMode = mode == _YoutubeLimitMode.budget;
      _intervalMode = mode == _YoutubeLimitMode.interval;
      if (_budgetMode) {
        _enabled = true;
      } else if (_intervalMode) {
        _enabled = IsleUserDefaults.youtubeIntervalLimitEnabled;
        _allowMinutes = IsleUserDefaults.youtubeIntervalAllowMinutes.toDouble();
        _windowHours = IsleUserDefaults.youtubeIntervalWindowMinutes / 60.0;
      } else {
        _enabled = IsleUserDefaults.youtubeDailyLimitEnabled;
        _allowMinutes = IsleUserDefaults.youtubeDailyLimitMinutes.toDouble();
        _windowHours = 3;
      }
    });
    _updateBadgeLift();
  }

  bool _canToggleEnabled(bool v) {
    if (!_canEditLimit) return false;
    if (!v && _savedEnabled) {
      return YoutubeUsageLock.canApplyPolicyChange(
        currentlyEnabled: _savedEnabled,
        newEnabled: v,
        currentDailyTotalMinutes: _savedDailyTotalForLock,
        newDailyTotalMinutes: _newDailyTotalForLock,
      );
    }
    if (v && !_savedEnabled) return true;
    return true;
  }

  Future<void> _setEnabled(bool v) async {
    if (!_canToggleEnabled(v)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('타임락: 한도를 끄려면 아래에서 대기를 완료하세요')),
      );
      return;
    }
    setState(() => _enabled = v);
    _markQaSliderTouched();
    _updateBadgeLift();
  }

  Future<void> _seedYoutubeBudgetLedger(
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

  Future<void> _savePendingChanges() async {
    if (!_hasPendingChanges) return;
    // ScheduleEditGuard 잠금은 YoutubeUsageLock 타임락과 다른 별개 잠금이라
    // 아직 예약 대상이 아님(2026-07-20 — 필요하면 후속 작업으로 별도 확장).
    if (!_canEditLimit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('스케줄 잠금 중 — 한도를 바꿀 수 없어요')),
      );
      return;
    }
    final lockMessage = _policyLockMessage;
    if (lockMessage != null) {
      await _offerToReserve(lockMessage);
      return;
    }
    if (!_canApplyMinutes(_allowMinutes)) {
      await _offerToReserve('타임락: 한도를 늘리려면 대기가 필요해요');
      return;
    }
    if (!_canToggleEnabled(_enabled)) {
      await _offerToReserve('타임락: 한도를 끄려면 대기가 필요해요');
      return;
    }
    await _persistCurrentDraftFields();
  }

  Future<void> _persistCurrentDraftFields({String? snackMessage}) async {
    final oldBudget = UsageBudgetStore.policyFor(UsageBudgetTarget.youtube);
    final oldBudgetUsedSeconds = oldBudget == null
        ? 0
        : UsageBudgetStore.ledgerFor(oldBudget).usedSecondsToday;
    final carriedSeconds = (_savedBudgetMode
            ? oldBudgetUsedSeconds
            : YoutubeWatchTimerStore.secondsUsedToday)
        .clamp(0, 24 * 60 * 60)
        .toInt();

    if (_budgetMode) {
      final policy = UsageBudgetPolicy(
        target: UsageBudgetTarget.youtube,
        enabled: _enabled,
        dailyCapMinutes: _dailyCapMinutes.round(),
        burstCapMinutes:
            _burstMinutes.round().clamp(1, _dailyCapMinutes.round()).toInt(),
        refillAmountMinutes:
            _burstMinutes.round().clamp(1, _dailyCapMinutes.round()).toInt(),
        refillIntervalMinutes: _refillMinutes.round(),
        cooldownMinutes: _cooldownMinutes.round(),
        updatedAt: DateTime.now(),
      );
      await UsageBudgetStore.savePolicy(policy);
      if (!_savedBudgetMode) {
        await _seedYoutubeBudgetLedger(policy, carriedSeconds);
      }
      await IsleUserDefaults.setYoutubeDailyLimitEnabled(false);
      await IsleUserDefaults.setYoutubeIntervalLimitEnabled(false);
    } else {
      await UsageBudgetStore.clearPolicy(UsageBudgetTarget.youtube);
      await IsleUserDefaults.setYoutubeLimitUsesInterval(_intervalMode);
      if (_savedBudgetMode) {
        await YoutubeWatchTimerStore.preserveTodayUsageAtLeast(carriedSeconds);
        if (_intervalMode) {
          await YoutubeWatchTimerStore.preserveCurrentWindowUsageAtLeast(
            carriedSeconds,
          );
        }
      }
      if (_intervalMode) {
        await IsleUserDefaults.setYoutubeIntervalLimitEnabled(_enabled);
        await IsleUserDefaults.setYoutubeIntervalWindowMinutes(
          (_windowHours * 60).round().clamp(30, 720),
        );
        await IsleUserDefaults.setYoutubeIntervalAllowMinutes(
            _allowMinutes.round());
      } else {
        await IsleUserDefaults.setYoutubeDailyLimitEnabled(_enabled);
        await IsleUserDefaults.setYoutubeDailyLimitMinutes(
            _allowMinutes.round());
      }
    }

    final message = snackMessage ??
        (_isLoweringMinutes(_allowMinutes)
            ? '한도를 ${_allowMinutes.round()}분으로 줄였어요'
            : _budgetMode
                ? '나눠 쓰기 한도를 저장했어요'
                : '한도 설정을 저장했어요');
    if (!mounted) return;
    setState(() {
      _syncFromDefaults();
      if (widget.qaMode && _qaSliderTouched) {
        _qaSavedAfterChange = true;
      }
    });
    _updateBadgeLift();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _discardPendingChanges() {
    setState(_syncFromDefaults);
    _updateBadgeLift();
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
                      label: Text(_budgetMode
                          ? '나눠 쓰기 저장'
                          : '${_allowMinutes.round()}분으로 저장'),
                    ),
                  ),
                  TextButton(
                    onPressed: _discardPendingChanges,
                    child: const Text('변경 취소'),
                  ),
                  Text(
                    '더 엄격한 변경은 즉시 · 방식/총량/충전 규칙 변경은 타임락 후 저장',
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
            extra: _hasPendingChanges ? IsleSize.stickySaveBarHeight : 16,
          ),
        ),
        children: [
          if (widget.qaMode) ...[
            DeviceQaItemPanel(
              itemId: 'youtube_limits_ui',
              title: '실기기 확인 — 유튜브 한도 UI',
              steps: [
                DeviceQaStep(
                  label: '① 슬라이더·토글 변경',
                  done: _qaSliderTouched,
                ),
                DeviceQaStep(
                  label: '② sticky 저장 바 표시',
                  done: _qaSliderTouched &&
                      (_hasPendingChanges || _qaSavedAfterChange),
                ),
                DeviceQaStep(
                  label: '③ 저장 완료',
                  done: _qaSavedAfterChange,
                ),
                DeviceQaStep(
                  label: '④ 버전 배지 lift',
                  done: _qaBadgeLiftSeen,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (YoutubeUsageLock.hasPendingPolicyDraft) ...[
            Card(
              color: const Color(0xFFFFF3E0),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_send, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '변경 예약됨 — 타임락이 풀리면 자동으로 저장돼요',
                        style: IsleText.caption(color: Colors.orange.shade900),
                      ),
                    ),
                    TextButton(
                      onPressed: _cancelReservedDraft,
                      child: const Text('예약 취소'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _YoutubeLimitHeroCard(
            statusLine: YoutubeWatchTimerStore.formatStatusLine(),
            scheduleBlocks: _scheduleBlocks,
            limitReached: _limitReached && !_scheduleBlocks,
            intervalMode: _intervalMode,
            budgetMode: _budgetMode,
          ),
          const SizedBox(height: 20),
          Text('한도 방식', style: IsleText.subtitle(color: IsleColors.ocean900)),
          const SizedBox(height: 8),
          SegmentedButton<_YoutubeLimitMode>(
            segments: const [
              ButtonSegment(
                value: _YoutubeLimitMode.budget,
                label: Text('나눠 쓰기'),
              ),
              ButtonSegment(
                  value: _YoutubeLimitMode.interval, label: Text('주기')),
              ButtonSegment(value: _YoutubeLimitMode.daily, label: Text('일일')),
            ],
            selected: {_mode},
            onSelectionChanged: _canEditLimit
                ? (s) async {
                    await _setMode(s.first);
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
                      _budgetMode
                          ? '하루 총량을 작은 사용권으로 충전'
                          : _intervalMode
                              ? 'N시간마다 정해진 분만 시청'
                              : '하루 최대 시청 시간',
                      style: IsleText.caption(color: IsleColors.muted),
                    ),
                    value: _enabled,
                    onChanged: _canToggleEnabled(!_enabled)
                        ? (v) => _setEnabled(v)
                        : null,
                  ),
                  if (_enabled) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    if (_budgetMode) ...[
                      Center(
                        child: Text(
                          '하루 ${_dailyCapMinutes.round()}분 · ${_burstMinutes.round()}분씩',
                          style: IsleText.subtitle(color: IsleColors.ocean900),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Text(
                        '${_refillMinutes.round()}분 뒤 다시 충전 · 다 쓰면 ${_cooldownMinutes.round()}분 잠금',
                        style: IsleText.caption(color: IsleColors.muted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      _BudgetSlider(
                        label: '하루 총량',
                        value: _dailyCapMinutes,
                        min: 10,
                        max: 240,
                        divisions: 46,
                        suffix: '분',
                        onChanged: _canEditLimit
                            ? (v) {
                                _markQaSliderTouched();
                                setState(() {
                                  _dailyCapMinutes = v;
                                  if (_burstMinutes > v) _burstMinutes = v;
                                });
                                _updateBadgeLift();
                              }
                            : null,
                      ),
                      _BudgetSlider(
                        label: '한 번에 보기',
                        value:
                            _burstMinutes.clamp(1, _dailyCapMinutes).toDouble(),
                        min: 1,
                        max: _dailyCapMinutes.clamp(10, 240).toDouble(),
                        divisions:
                            _dailyCapMinutes.round().clamp(9, 80).toInt(),
                        suffix: '분',
                        onChanged: _canEditLimit
                            ? (v) {
                                _markQaSliderTouched();
                                setState(() => _burstMinutes = v);
                                _updateBadgeLift();
                              }
                            : null,
                      ),
                      _BudgetSlider(
                        label: '충전 대기',
                        value: _refillMinutes,
                        min: 10,
                        max: 240,
                        divisions: 23,
                        suffix: '분',
                        onChanged: _canEditLimit
                            ? (v) {
                                _markQaSliderTouched();
                                setState(() => _refillMinutes = v);
                                _updateBadgeLift();
                              }
                            : null,
                      ),
                      Text(
                        '충전 대기: 한 번에 보기 시간을 다 쓴 뒤 다시 사용권이 들어오는 간격',
                        style: IsleText.caption(color: IsleColors.muted),
                        textAlign: TextAlign.center,
                      ),
                      _BudgetSlider(
                        label: '잠금 시간',
                        value: _cooldownMinutes,
                        min: 5,
                        max: 240,
                        divisions: 47,
                        suffix: '분',
                        onChanged: _canEditLimit
                            ? (v) {
                                _markQaSliderTouched();
                                setState(() => _cooldownMinutes = v);
                                _updateBadgeLift();
                              }
                            : null,
                      ),
                      Text(
                        '잠금 시간: 사용권을 모두 쓴 직후 유튜브를 쉬게 하는 시간',
                        style: IsleText.caption(color: IsleColors.muted),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '하루 남은 시간이 ${_burstMinutes.round()}분보다 적으면 남은 시간만 충전돼요.',
                        style: IsleText.caption(color: IsleColors.muted),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
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
                        Text('주기 길이',
                            style: IsleText.caption(color: IsleColors.muted)),
                        Slider(
                          min: 0.5,
                          max: 12,
                          divisions: 23,
                          label: '${_windowHours.toStringAsFixed(1)}시간',
                          value: _windowHours.clamp(0.5, 12),
                          onChanged: _canEditLimit
                              ? (v) {
                                  _markQaSliderTouched();
                                  setState(() => _windowHours = v);
                                  _updateBadgeLift();
                                }
                              : null,
                        ),
                      ],
                      Text('허용 시청',
                          style: IsleText.caption(color: IsleColors.muted)),
                      Slider(
                        min: 5,
                        max: _intervalMode ? 120 : 180,
                        divisions: _intervalMode ? 23 : 35,
                        label: '${_allowMinutes.round()}분',
                        value: _allowMinutes.clamp(
                            5, _intervalMode ? 120.0 : 180.0),
                        onChanged: _canEditLimit
                            ? (v) {
                                if (!_canApplyMinutes(v)) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          '타임락: 한도 방식·총량·충전 규칙 변경은 대기 완료 후 가능해요'),
                                    ),
                                  );
                                  return;
                                }
                                _markQaSliderTouched();
                                setState(() => _allowMinutes = v);
                                _updateBadgeLift();
                              }
                            : null,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('타임락', style: IsleText.subtitle(color: IsleColors.ocean900)),
          const SizedBox(height: 4),
          Text(
            '한도 방식·총량·충전 규칙을 느슨하게 바꾸기 전에 기다리는 시간',
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
              label: Text(PlatformBlockCopy.systemYoutubeBlockGuideLabel),
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
    required this.budgetMode,
  });

  final String statusLine;
  final bool scheduleBlocks;
  final bool limitReached;
  final bool intervalMode;
  final bool budgetMode;

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
                  : budgetMode
                      ? '충전식 한도 도달 · 다음 충전까지 잠시 쉬어요'
                      : '오늘 한도 도달 · 줄이기만 바로 저장 가능',
              style: IsleText.caption(color: Colors.red.shade700),
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetSlider extends StatelessWidget {
  const _BudgetSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String suffix;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final display = value.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child:
                  Text(label, style: IsleText.caption(color: IsleColors.muted)),
            ),
            Text(
              '$display$suffix',
              style: IsleText.caption(color: IsleColors.ocean700).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          min: min,
          max: max,
          divisions: divisions,
          label: '$display$suffix',
          value: value.clamp(min, max).toDouble(),
          onChanged: onChanged,
        ),
      ],
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

class _InstagramLimitsSettingsScreenState
    extends State<InstagramLimitsSettingsScreen> {
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
            '피드·릴스·탐색만 일일 한도 · DM은 무제한',
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
  State<ApiBudgetSettingsScreen> createState() =>
      _ApiBudgetSettingsScreenState();
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

class _InterestPipelineSettingsScreenState
    extends ConsumerState<InterestPipelineSettingsScreen> {
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
                title:
                    Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle:
                    Text('${e.sourceType} · ${e.publishArticleAt.toLocal()}'),
              ),
            ),
        ],
      ),
    );
  }
}
