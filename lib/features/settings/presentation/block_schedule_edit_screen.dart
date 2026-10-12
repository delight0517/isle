import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/platform_block_intent.dart';
import '../../../core/block_schedule/block_schedule_enforcement_service.dart';
import '../../../core/block_schedule/block_schedule_store.dart';
import '../../../core/block_schedule/schedule_limit_setup_helper.dart';
import '../../../core/block_schedule/schedule_notification_service.dart';
import '../../../core/block_schedule/models/block_schedule.dart';
import '../../../core/block_schedule/schedule_active_service.dart';
import '../../../core/block_schedule/schedule_display_helper.dart';
import '../../../core/block_schedule/schedule_constants.dart';
import '../../../core/block_schedule/schedule_lock_phase.dart';
import '../../../core/block_schedule/schedule_edit_guard.dart';
import '../../../core/block_schedule/schedule_lock_service.dart';
import '../../../core/block_schedule/schedule_pending_target_service.dart';
import '../../../core/block_schedule/schedule_pending_field_service.dart';
import '../../../core/block_schedule/schedule_app_target_catalog.dart';
import '../../../core/block_schedule/url_rules/schedule_rule_store.dart';
import '../../../core/block/schedule_premade_block_pack_service.dart';
import '../../../core/block_schedule/schedule_app_targets_store.dart';
import '../../../core/block_schedule/schedule_slot_edit_policy.dart';
import '../../../core/intervention/screen_time_selection_summary.dart';
import '../../../core/intervention/schedule_screen_time_store.dart';
import '../../../core/localization/schedule_strings.dart';
import '../../../core/services/isle_app_log_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import 'widgets/schedule_edit_section_header.dart';
import 'widgets/schedule_enforcement_mode_picker.dart';
import 'widgets/schedule_app_targets_section.dart';
import 'widgets/schedule_rules_section.dart';
import 'widgets/schedule_window_sheet.dart';
import '../../../core/block_schedule/models/schedule_enforcement_mode.dart';

enum _SaveFeedbackKind { silent, brief, prominent }

class BlockScheduleEditScreen extends ConsumerStatefulWidget {
  final String scheduleId;

  const BlockScheduleEditScreen({super.key, required this.scheduleId});

  @override
  ConsumerState<BlockScheduleEditScreen> createState() => _BlockScheduleEditScreenState();
}

class _BlockScheduleEditScreenState extends ConsumerState<BlockScheduleEditScreen>
    with WidgetsBindingObserver {
  BlockSchedule? _schedule;
  late TextEditingController _nameCtrl;
  late TextEditingController _cooldownCtrl;
  Timer? _lockWake;
  bool _saving = false;
  bool _loading = false;
  DateTime? _lastLoadAt;
  final _targetsKey = GlobalKey<ScheduleAppTargetsSectionState>();

  int _buildCount = 0;

  @override
  void initState() {
    super.initState();
    IsleAppLogService.log('EditScreen.initState id=${widget.scheduleId}');
    WidgetsBinding.instance.addObserver(this);
    _nameCtrl = TextEditingController();
    _cooldownCtrl = TextEditingController(text: '30');
    unawaited(ScheduleLockService.finalizeExpiredLocks().then((_) => _load()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ScheduleLockService.finalizeExpiredLocks().then((_) async {
        await SchedulePendingTargetService.tryApplyForSchedule(widget.scheduleId);
        await SchedulePendingFieldService.tryApplyForSchedule(widget.scheduleId);
        if (mounted) _load();
      }));
    }
  }

  void _load() {
    if (_loading) return;
    final now = DateTime.now();
    if (_lastLoadAt != null &&
        now.difference(_lastLoadAt!) < const Duration(milliseconds: 800)) {
      return;
    }
    _loading = true;
    _lastLoadAt = now;
    IsleAppLogService.log('EditScreen._load id=${widget.scheduleId}');
    unawaited(ScheduleScreenTimeStore.ensureOpen());
    final s = BlockScheduleStore.loadAll().where((e) => e.id == widget.scheduleId).firstOrNull;
    _schedule = s;
    if (s != null) {
      _nameCtrl.text = s.name;
      _cooldownCtrl.text = s.lockCooldownMinutes.toString();
    }
    _loading = false;
    if (mounted) setState(() {});
    _scheduleLockWake();
  }

  /// [Volt] 1초 폴링 대신 다음 경계까지 one-shot (최대 60초 간격)
  void _scheduleLockWake() {
    _lockWake?.cancel();
    final s = _schedule;
    if (s == null || !mounted) return;
    final p = ScheduleLockService.phase(s);
    if (p != ScheduleLockPhase.countdown && p != ScheduleLockPhase.editWindow) return;

    final remaining = p == ScheduleLockPhase.countdown
        ? ScheduleLockService.countdownRemaining(s)
        : ScheduleLockService.editWindowRemaining(s);
    if (remaining == null || remaining <= Duration.zero) {
      // 만료됐으면 1회만 정리·갱신 (500ms 무한 루프 방지)
      unawaited(ScheduleLockService.finalizeExpiredLocks().then((_) async {
        if (!mounted) return;
        await SchedulePendingTargetService.tryApplyForSchedule(widget.scheduleId);
        await SchedulePendingFieldService.tryApplyForSchedule(widget.scheduleId);
        if (!mounted) return;
        final nextPhase = _schedule == null
            ? ScheduleLockPhase.unlocked
            : ScheduleLockService.phase(_schedule!);
        if (nextPhase != p) _load();
      }));
      return;
    }
    final wake = remaining > const Duration(seconds: 60)
        ? const Duration(seconds: 60)
        : remaining + const Duration(milliseconds: 200);
    _lockWake = Timer(wake, () {
      if (!mounted) return;
      unawaited(ScheduleLockService.finalizeExpiredLocks().then((_) async {
        await SchedulePendingTargetService.tryApplyForSchedule(widget.scheduleId);
        await SchedulePendingFieldService.tryApplyForSchedule(widget.scheduleId);
        if (mounted) _load();
      }));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockWake?.cancel();
    _nameCtrl.dispose();
    _cooldownCtrl.dispose();
    super.dispose();
  }

  /// 잠금 중(편집 창 아님)이면 즉시 저장 대신 [SchedulePendingFieldService]에
  /// 예약 — 15분 타임락 후 자동 적용된다. 이전엔 이 상태에서 편집 UI 자체를
  /// 숨겼는데, 이제 앱 타깃(③단계)과 동일하게 시간표·이름·모드·on/off(①②단계)도
  /// 잠금 중에 미리 바꿔두면 대기가 끝나는 대로 자동 반영된다(2026-07-20
  /// 사용자 요청 — "수동으로 적용을 눌러도 자동으로 timelock 이후에 적용").
  Future<void> _save(
    BlockSchedule s, {
    _SaveFeedbackKind feedback = _SaveFeedbackKind.silent,
    String? message,
  }) async {
    if (_saving) return;
    final original = _schedule;
    if (original == null) return;
    final trimmed = _nameCtrl.text.trim();
    final toSave = trimmed.isEmpty ? s : s.copyWith(name: trimmed);

    setState(() => _saving = true);
    try {
      if (ScheduleEditGuard.isCommitmentLocked(original)) {
        final outcome = await SchedulePendingFieldService.requestFieldChange(
          current: original,
          desired: toSave,
        );
        _load();
        if (!mounted || feedback == _SaveFeedbackKind.silent) return;
        _showSaveFeedback(
          message != null && outcome.kind == ScheduleFieldChangeOutcomeKind.immediate
              ? message
              : _buildQueuedMessage(outcome),
          prominent: feedback == _SaveFeedbackKind.prominent,
        );
        return;
      }

      await BlockScheduleStore.upsert(toSave);
      await ref.read(blockSchedulesProvider.notifier).reload();
      await BlockScheduleEnforcementService.syncPlatformEnforcement();
      unawaited(ScheduleNotificationService.rescheduleAll());
      _load();
      if (!mounted || feedback == _SaveFeedbackKind.silent) return;
      _showSaveFeedback(
        message ?? _buildSaveMessage(toSave),
        prominent: feedback == _SaveFeedbackKind.prominent,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장하지 못했어요. 다시 시도해 주세요.'),
          backgroundColor: IsleColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _buildQueuedMessage(ScheduleFieldChangeOutcome outcome) {
    switch (outcome.kind) {
      case ScheduleFieldChangeOutcomeKind.noop:
        return '바뀐 내용이 없어요.';
      case ScheduleFieldChangeOutcomeKind.immediate:
        return '저장됐어요.';
      case ScheduleFieldChangeOutcomeKind.scheduled:
      case ScheduleFieldChangeOutcomeKind.alreadyPending:
        final mins = outcome.remaining?.inMinutes ?? 0;
        return '잠금 중이라 지금은 안 바뀌어요 — 약 $mins분 후 자동 적용돼요.';
    }
  }

  String _buildSaveMessage(BlockSchedule s) {
    final parts = <String>['「${s.name}」 저장됨'];
    if (s.slots.isEmpty) {
      parts.add('시간 슬롯 없음 — ①에서 추가하세요');
    } else {
      parts.add('슬롯 ${s.slots.length}개');
    }
    if (!s.enabled) {
      parts.add('스케줄 꺼짐');
    } else if (ScheduleActiveService.isScheduleActiveNow(s)) {
      parts.add('지금 차단 적용 중');
    } else {
      parts.add('대기 중');
    }
    final st = ScreenTimeSelectionSummary.countLineForSchedule(s.id);
    if (!st.contains('미선택')) {
      parts.add(st);
    }
    return parts.join(' · ');
  }

  void _showSaveFeedback(String text, {required bool prominent}) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: prominent ? 4 : 2),
        showCloseIcon: prominent,
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              prominent ? Icons.check_circle : Icons.check,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: IsleText.body(color: Colors.white).copyWith(height: 1.35),
              ),
            ),
          ],
        ),
        action: prominent
            ? SnackBarAction(
                label: '목록으로',
                textColor: Colors.white,
                onPressed: () {
                  if (context.canPop()) context.pop();
                },
              )
            : null,
      ),
    );
  }

  Future<void> _savePrimary() async {
    final s = _schedule;
    if (s == null) return;
    if (!_validateFinalize(s)) return;
    await _targetsKey.currentState?.persist();
    await _save(s, feedback: _SaveFeedbackKind.prominent);
  }

  bool _validateFinalize(BlockSchedule s) {
    final hasSlots = s.slots.isNotEmpty;
    final entries = ScheduleAppTargetsStore.loadForSchedule(s.id);
    final anyTarget = entries.any((e) => e.blockInSlot || e.limitEnabled);
    final needsIosPick = entries.any((e) {
      if (!e.blockInSlot) return false;
      return ScheduleAppTargetCatalog.defFor(e.targetId)?.isIos == true;
    });
    final hasIosPick = ScreenTimeSelectionSummary.appCountForSchedule(s.id) > 0 ||
        ScreenTimeSelectionSummary.categoryCountForSchedule(s.id) > 0;
    final hasShieldSelection =
        !s.enforcementMode.appliesShieldInSlot || (anyTarget && (!needsIosPick || hasIosPick));
    if (hasSlots && hasShieldSelection) return true;

    final missing = <String>[];
    if (!hasSlots) missing.add('① 시간표');
    if (!hasShieldSelection) {
      missing.add(needsIosPick && !hasIosPick
          ? '③ ${PlatformBlockCopy.nativeInstalledAppLabel} 선택'
          : '③ 차단·한도 대상');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '마무리 전 필수 설정이 남았어요: ${missing.join(' · ')}',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
    return false;
  }

  Future<void> _setEnforcementMode(BlockSchedule s, ScheduleEnforcementMode mode) async {
    await _save(s.copyWith(enforcementMode: mode));
    if (!mounted) return;
    if (!ScheduleLimitSetupHelper.needsLimitRules(s.id, mode)) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          mode == ScheduleEnforcementMode.limitInSlot
              ? '③ 차단·한도 대상에서 묶음 시간 한도를 켜 주세요.'
              : '③에서 슬롯 밖 시간 한도(묶음)를 설정해 주세요.',
        ),
      ),
    );
  }

  /// 통합 시간대 편집 — "시작 → 종료" + 요일 멀티선택 (Cold Turkey 방식).
  /// 잠금 편집창에서도 지금 활성 중인 슬롯은 강제로 유지(커밋먼트 보호).
  Future<void> _editWindows(BlockSchedule s) async {
    final result = await ScheduleWindowSheet.show(
      context,
      initialSlots: s.slots,
      schedule: s,
    );
    if (result == null || !mounted) return;

    final protected = s.slots
        .where((sl) => !ScheduleSlotEditPolicy.canModifySlot(schedule: s, slot: sl))
        .toList();
    final merged = [...result];
    for (final p in protected) {
      final present = merged.any((m) =>
          m.day == p.day && m.startMinute == p.startMinute && m.endMinute == p.endMinute);
      if (!present) merged.add(p);
    }
    await _save(
      s.copyWith(slots: merged),
      feedback: _SaveFeedbackKind.brief,
      message: '시간대 저장됨 · 슬롯 ${merged.length}개',
    );
  }

  Widget _lockPanel(BlockSchedule s) {
    final phase = ScheduleLockService.phase(s);
    final canEditCooldown = ScheduleEditGuard.canEditCooldownMinutes(s);
    final canToggleLock = ScheduleEditGuard.canToggleCommitmentLock(s, !s.locked);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('설정 잠금'),
              subtitle: Text(
                s.locked
                    ? '앱 차단 아님 · 해제 후 5분만 편집'
                    : '시간표를 함부로 바꾸지 않게 (최소 ${ScheduleConstants.minCooldownMinutes}분 대기)',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              value: s.locked,
              onChanged: !canToggleLock
                  ? null
                  : (v) {
                if (v) {
                  final mins = int.tryParse(_cooldownCtrl.text) ?? 30;
                  if (mins < ScheduleConstants.minCooldownMinutes) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '대기 시간은 최소 ${ScheduleConstants.minCooldownMinutes}분이어야 해요.',
                        ),
                      ),
                    );
                    return;
                  }
                  _save(
                    s.copyWith(
                      locked: true,
                      lockCooldownMinutes: mins.clamp(ScheduleConstants.minCooldownMinutes, 24 * 60),
                      clearUnlock: true,
                    ),
                  );
                } else {
                  _save(s.copyWith(locked: false, clearUnlock: true));
                }
              },
            ),
            if (canEditCooldown)
              TextField(
                controller: _cooldownCtrl,
                enabled: canEditCooldown,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '잠금 해제 대기 (분) — 잠금 켜면 확정',
                  border: OutlineInputBorder(),
                ),
              )
            else if (s.locked)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('잠금 해제 대기', style: IsleText.caption(color: IsleColors.muted)),
                subtitle: Text(
                  '${s.lockCooldownMinutes}분 (변경 불가)',
                  style: IsleText.body(),
                ),
              ),
            Text('상태: ${_phaseLabel(phase)}', style: IsleText.body()),
            if (phase == ScheduleLockPhase.countdown) ...[
              Text(
                '남은 대기: ${ScheduleLockService.countdownRemaining(s)?.inMinutes ?? 0}분',
                style: IsleText.caption(color: Colors.red),
              ),
            ],
            if (phase == ScheduleLockPhase.editWindow) ...[
              Text(
                ScheduleLockService.editWindowRemaining(s) != null
                    ? '편집 가능: ${ScheduleLockService.editWindowRemaining(s)?.inMinutes ?? 0}분 남음'
                    : '편집 가능 — 「편집 완료 · 잠금」을 누를 때까지',
                style: IsleText.caption(color: IsleColors.ocean700),
              ),
            ],
            const SizedBox(height: 8),
            if (s.locked && phase == ScheduleLockPhase.locked)
              FilledButton(
                onPressed: () async {
                  await ScheduleLockService.startUnlockCountdown(s.id);
                  _load();
                },
                child: const Text('잠금 해제 시작 (카운트다운)'),
              ),
            if (phase == ScheduleLockPhase.countdown || phase == ScheduleLockPhase.editWindow)
              TextButton(
                onPressed: () async {
                  await ScheduleLockService.cancelUnlock(s.id);
                  _load();
                },
                child: Text(
                  phase == ScheduleLockPhase.editWindow
                      ? '편집 완료 · 잠금 다시 걸기'
                      : '잠금 해제 취소',
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _phaseLabel(ScheduleLockPhase p) => switch (p) {
        ScheduleLockPhase.unlocked => '잠금 꺼짐',
        ScheduleLockPhase.locked => '잠김',
        ScheduleLockPhase.countdown => '대기 중',
        ScheduleLockPhase.editWindow => '편집 가능',
      };

  /// ①③ 완료 여부 — `_ScheduleReadinessStrip`·스텝 기본 펼침 판정 공용
  ({bool hasSlots, bool needsShieldApps, bool hasShieldSelection, int apps, int cats})
      get _readiness {
    final s = _schedule!;
    final apps = ScreenTimeSelectionSummary.appCountForSchedule(s.id);
    final cats = ScreenTimeSelectionSummary.categoryCountForSchedule(s.id);
    final hasIsleOrDomain = ScheduleDisplayHelper.targetVisualsForSchedule(s).isNotEmpty;
    return (
      hasSlots: s.slots.isNotEmpty,
      needsShieldApps: s.enforcementMode.appliesShieldInSlot,
      hasShieldSelection: apps > 0 || cats > 0 || hasIsleOrDomain,
      apps: apps,
      cats: cats,
    );
  }

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    if (_buildCount <= 5 || _buildCount % 20 == 0) {
      IsleAppLogService.log('EditScreen.build #$_buildCount id=${widget.scheduleId} schedule=${_schedule != null}');
    }
    final s = _schedule;
    if (s == null) {
      return const Scaffold(body: Center(child: Text('스케줄을 찾을 수 없습니다')));
    }
    // canEdit는 삭제·URL 규칙(④)·앱 타깃(③, 자체 예약 로직 있음) 등 이
    // 화면의 다른 섹션에 그대로 넘겨준다 — ①②(시간표·이름·모드·on/off)만
    // 아래에서 canEdit 게이팅 없이 항상 인터랙티브하게 바꾸고, `_save()`가
    // 내부적으로 잠금 상태를 보고 즉시 저장/15분 후 예약 적용을 분기한다
    // (2026-07-20 사용자 요청 — 이전엔 잠금 중엔 편집 UI 자체가 안 보였음).
    final canEdit = ScheduleEditGuard.canEditScheduleFields(s);
    final commitmentLocked = ScheduleEditGuard.isCommitmentLocked(s);
    final active = ScheduleActiveService.isScheduleActiveNow(s);
    final sch = ScheduleStrings.of(context);

    return Scaffold(
      appBar: IsleAppBar(
        title: s.name,
        subtitle: ScheduleDisplayHelper.targetsSummaryDetailed(s),
        actions: [
          TextButton(
            onPressed: _saving ? null : _savePrimary,
            child: Text(_saving ? '저장 중…' : '완료'),
          ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await BlockScheduleStore.delete(s.id);
                if (!ok) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('타임락 중에는 스케줄을 삭제할 수 없어요')),
                  );
                  return;
                }
                await SchedulePremadePackService.deleteScheduleLinks(s.id);
                await ScheduleRuleStore.deleteForSchedule(s.id);
                await ref.read(blockSchedulesProvider.notifier).reload();
                if (context.mounted) context.pop();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (active)
            Text(
              commitmentLocked
                  ? sch.t('active_blocking_locked')
                  : sch.t('active_blocking'),
              style: IsleText.caption(color: Colors.red.shade700),
            ),
          if (commitmentLocked) ...[
            const SizedBox(height: 8),
            _CommitmentLockBanner(
              schedule: s,
              onUnlockStarted: _load,
            ),
          ],
          _ScheduleReadinessStrip(schedule: s),
          const SizedBox(height: 16),
          _CollapsibleStep(
            step: 1,
            icon: Icons.schedule,
            title: sch.t('step1_title'),
            summary: s.slots.isEmpty
                ? sch.t('no_windows_yet')
                : ScheduleDisplayHelper.formatScheduleTimes(s.slots),
            initiallyExpanded: s.slots.isEmpty,
            helpBody: sch.t('step1_sub'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(sch.t('schedule_enabled')),
                  value: s.enabled,
                  onChanged: (v) => _save(s.copyWith(enabled: v)),
                ),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: sch.t('schedule_name'),
                    helperText: sch.t('schedule_name_hint'),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _save(
                    s.copyWith(name: _nameCtrl.text.trim()),
                    feedback: _SaveFeedbackKind.brief,
                  ),
                ),
                const SizedBox(height: 8),
                if (s.slots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      sch.t('no_windows_yet'),
                      style: IsleText.caption(color: IsleColors.muted),
                    ),
                  )
                else
                  ...ScheduleWindowSheet.summarize(s.slots).map(
                    (line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, size: 16, color: IsleColors.ocean500),
                          const SizedBox(width: 8),
                          Expanded(child: Text(line, style: IsleText.body())),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _editWindows(s),
                    icon: Icon(s.slots.isEmpty ? Icons.add : Icons.edit_calendar),
                    label: Text(s.slots.isEmpty ? sch.t('window_add') : sch.t('window_edit')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _CollapsibleStep(
            step: 2,
            icon: Icons.tune,
            title: sch.t('step2_title'),
            summary: s.enforcementMode
                .localizedLabel(Localizations.localeOf(context).languageCode),
            initiallyExpanded: false,
            child: ScheduleEnforcementModePicker(
              value: s.enforcementMode,
              onChanged: (m) => _setEnforcementMode(s, m),
            ),
          ),
          const SizedBox(height: 10),
          _CollapsibleStep(
            step: 3,
            icon: Icons.apps_outage,
            title: sch.t('step3_title'),
            summary: ScheduleDisplayHelper.configuredSummaryLine(s),
            initiallyExpanded: _readiness.needsShieldApps && !_readiness.hasShieldSelection,
            child: ScheduleAppTargetsSection(
              key: _targetsKey,
              schedule: s,
              canEdit: canEdit,
              commitmentLocked: commitmentLocked,
            ),
          ),
          const SizedBox(height: 10),
          _CollapsibleStep(
            step: 4,
            icon: Icons.link_off,
            title: '웹사이트 · URL',
            summary: () {
              final n = ScheduleRuleStore.loadForSchedule(s.id).length;
              return n > 0 ? '규칙 $n개' : '규칙 없음';
            }(),
            initiallyExpanded: false,
            child: ScheduleRulesSection(
              scheduleId: s.id,
              canEdit: canEdit,
            ),
          ),
          const SizedBox(height: 10),
          _CollapsibleStep(
            step: 5,
            icon: Icons.lock_outline,
            title: sch.t('step4_title'),
            summary: _phaseLabel(ScheduleLockService.phase(s)),
            initiallyExpanded: false,
            child: _lockPanel(s),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: IsleSize.minTouchTarget + 8,
            child: FilledButton.icon(
              onPressed: _saving ? null : _savePrimary,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? sch.t('saving') : sch.t('save')),
            ),
          ),
        ],
      ),
    );
  }
}

/// 상단 카드 3개(사용법·타깃 설명·필수 항목) 병합 — 평소엔 한 줄, 탭하면 펼쳐짐
class _ScheduleReadinessStrip extends StatefulWidget {
  const _ScheduleReadinessStrip({required this.schedule});

  final BlockSchedule schedule;

  @override
  State<_ScheduleReadinessStrip> createState() => _ScheduleReadinessStripState();
}

class _ScheduleReadinessStripState extends State<_ScheduleReadinessStrip> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sch = ScheduleStrings.of(context);
    final schedule = widget.schedule;
    final hasSlots = schedule.slots.isNotEmpty;
    final apps = ScreenTimeSelectionSummary.appCountForSchedule(schedule.id);
    final cats = ScreenTimeSelectionSummary.categoryCountForSchedule(schedule.id);
    final needsShieldApps = schedule.enforcementMode.appliesShieldInSlot;
    final visuals = ScheduleDisplayHelper.targetVisualsForSchedule(schedule);
    final hasShieldSelection = apps > 0 || cats > 0 || visuals.isNotEmpty;
    final ready = hasSlots && (!needsShieldApps || hasShieldSelection);
    final domainOnly = ScheduleDisplayHelper.hasYoutubeDomainsOnly(schedule);

    final headline = ready
        ? '✅ ${ScheduleDisplayHelper.configuredSummaryLine(schedule)}'
        : '⚠️ ${!hasSlots ? sch.t('check_step1_need') : sch.t('check_step2_need')}';

    return Card(
      margin: EdgeInsets.zero,
      color: ready ? IsleColors.ocean100.withValues(alpha: 0.3) : const Color(0xFFFFF3E0),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      headline,
                      maxLines: _expanded ? null : 1,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                      style: IsleText.body().copyWith(
                        fontWeight: FontWeight.w600,
                        color: ready ? IsleColors.ocean700 : IsleColors.gold500,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: IsleColors.muted,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                if (visuals.isEmpty)
                  Text(
                    sch.t('target_explainer_body'),
                    style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.45),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final v in visuals)
                        Chip(
                          avatar: Icon(v.icon, color: v.color, size: 16),
                          label: Text(v.label, style: IsleText.caption()),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                if (domainOnly) ...[
                  const SizedBox(height: 8),
                  Text(
                    sch.t('target_domain_youtube_only'),
                    style: IsleText.caption(color: Colors.orange.shade900).copyWith(height: 1.4),
                  ),
                ],
                const SizedBox(height: 10),
                _readinessRow(
                  ok: hasSlots,
                  title: sch.t('check_step1'),
                  subtitle: hasSlots
                      ? sch.t('check_step1_ok', args: {'n': '${schedule.slots.length}'})
                      : sch.t('check_step1_need'),
                ),
                const SizedBox(height: 6),
                _readinessRow(
                  ok: !needsShieldApps || hasShieldSelection,
                  title: sch.t('check_step2'),
                  subtitle: needsShieldApps
                      ? (hasShieldSelection
                          ? sch.t('check_step2_ok', args: {'apps': '$apps', 'cats': '$cats'})
                          : sch.t('check_step2_need'))
                      : sch.t('check_step2_optional'),
                ),
                const SizedBox(height: 10),
                Text(
                  sch.t('edit_help_body'),
                  style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _readinessRow({
    required bool ok,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: ok ? IsleColors.grassDeep : IsleColors.muted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$title\n$subtitle',
            style: IsleText.caption(
              color: ok ? IsleColors.ocean700 : IsleColors.muted,
            ).copyWith(height: 1.35),
          ),
        ),
      ],
    );
  }
}

/// 스텝 아코디언 — 완료된 스텝은 한 줄 요약으로 접힘, 미완료 스텝만 기본 펼침
class _CollapsibleStep extends StatefulWidget {
  const _CollapsibleStep({
    required this.step,
    required this.icon,
    required this.title,
    required this.summary,
    required this.initiallyExpanded,
    required this.child,
    this.helpBody,
  });

  final int step;
  final IconData icon;
  final String title;
  final String summary;
  final bool initiallyExpanded;
  final Widget child;
  /// 펼쳤을 때 본문 위에 한 번 더 보여줄 사용법 한 줄 (선택)
  final String? helpBody;

  @override
  State<_CollapsibleStep> createState() => _CollapsibleStepState();
}

class _CollapsibleStepState extends State<_CollapsibleStep> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ScheduleEditSectionHeader(
                      step: widget.step,
                      icon: widget.icon,
                      title: widget.title,
                      subtitle: widget.summary,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: IsleColors.muted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.helpBody != null && widget.helpBody!.trim().isNotEmpty) ...[
                    Text(
                      widget.helpBody!,
                      style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
                    ),
                    const SizedBox(height: 10),
                  ],
                  widget.child,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CommitmentLockBanner extends StatelessWidget {
  const _CommitmentLockBanner({required this.schedule, required this.onUnlockStarted});

  final BlockSchedule schedule;
  final VoidCallback onUnlockStarted;

  @override
  Widget build(BuildContext context) {
    final phase = ScheduleLockService.phase(schedule);
    final cooldown = schedule.lockCooldownMinutes;

    return Card(
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.orange.shade800, size: 18),
                const SizedBox(width: 8),
                Text(
                  '설정 잠금 활성',
                  style: IsleText.body().copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (phase == ScheduleLockPhase.locked) ...[
              Text(
                '지금 바꿔도 즉시 반영되지 않고 잠금 해제 대기($cooldown분) 후 자동 적용돼요.\n'
                '시간표·이름·모드·전체 on/off, 앱 추가·제거 전부 지금 예약할 수 있어요.',
                style: IsleText.caption(color: Colors.orange.shade900).copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
                  onPressed: () async {
                    await ScheduleLockService.startUnlockCountdown(schedule.id);
                    onUnlockStarted();
                  },
                  icon: const Icon(Icons.lock_open),
                  label: Text('잠금 해제 시작 — $cooldown분 대기'),
                ),
              ),
            ] else if (phase == ScheduleLockPhase.countdown) ...[
              Text(
                '잠금 해제 카운트다운 중 · ${ScheduleLockService.countdownRemaining(schedule)?.inMinutes ?? 0}분 남음\n'
                '지금까지 예약한 변경(시간표·이름·모드·on/off·앱)은 대기가 끝나면 자동 적용돼요.',
                style: IsleText.caption(color: Colors.orange.shade900).copyWith(height: 1.4),
              ),
            ] else if (phase == ScheduleLockPhase.editWindow) ...[
              Text(
                '편집 가능 상태입니다. 아래에서 수정하세요.',
                style: IsleText.caption(color: IsleColors.ocean700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

