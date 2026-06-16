import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/block_schedule/block_schedule_enforcement_service.dart';
import '../../../core/block_schedule/block_schedule_store.dart';
import '../../../core/block_schedule/schedule_limit_setup_helper.dart';
import '../../../core/block_schedule/schedule_notification_service.dart';
import '../../../core/block_schedule/models/block_schedule.dart';
import '../../../core/block_schedule/schedule_active_service.dart';
import '../../../core/block_schedule/schedule_constants.dart';
import '../../../core/block_schedule/schedule_lock_phase.dart';
import '../../../core/block_schedule/schedule_edit_guard.dart';
import '../../../core/block_schedule/schedule_lock_service.dart';
import '../../../core/block_schedule/schedule_app_target_catalog.dart';
import '../../../core/block_schedule/url_rules/schedule_rule_store.dart';
import '../../../core/block_schedule/schedule_app_targets_store.dart';
import '../../../core/block_schedule/schedule_slot_edit_policy.dart';
import '../../../core/intervention/screen_time_selection_summary.dart';
import '../../../core/intervention/schedule_screen_time_store.dart';
import '../../../core/localization/schedule_strings.dart';
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
  final _targetsKey = GlobalKey<ScheduleAppTargetsSectionState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nameCtrl = TextEditingController();
    _cooldownCtrl = TextEditingController(text: '30');
    unawaited(ScheduleLockService.finalizeExpiredLocks().then((_) => _load()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ScheduleLockService.finalizeExpiredLocks().then((_) {
        if (mounted) _load();
      }));
    }
  }

  void _load() {
    unawaited(ScheduleScreenTimeStore.ensureOpen());
    final s = BlockScheduleStore.loadAll().where((e) => e.id == widget.scheduleId).firstOrNull;
    _schedule = s;
    if (s != null) {
      _nameCtrl.text = s.name;
      _cooldownCtrl.text = s.lockCooldownMinutes.toString();
    }
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
      unawaited(ScheduleLockService.finalizeExpiredLocks().then((_) {
        if (mounted) _load();
      }));
      return;
    }
    final wake = remaining > const Duration(seconds: 60)
        ? const Duration(seconds: 60)
        : remaining + const Duration(milliseconds: 200);
    _lockWake = Timer(wake, () {
      if (!mounted) return;
      unawaited(ScheduleLockService.finalizeExpiredLocks().then((_) {
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

  Future<void> _save(
    BlockSchedule s, {
    _SaveFeedbackKind feedback = _SaveFeedbackKind.silent,
    String? message,
  }) async {
    if (_saving) return;
    final trimmed = _nameCtrl.text.trim();
    final toSave = trimmed.isEmpty ? s : s.copyWith(name: trimmed);

    setState(() => _saving = true);
    try {
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
      missing.add(needsIosPick && !hasIosPick ? '③ iPhone 앱 Screen Time 선택' : '③ 차단·한도 대상');
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
                '편집 가능: ${ScheduleLockService.editWindowRemaining(s)?.inMinutes ?? 0}분 남음',
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
                child: const Text('잠금 해제 취소'),
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
        ScheduleLockPhase.editWindow => '편집 가능 (5분)',
      };

  @override
  Widget build(BuildContext context) {
    final s = _schedule;
    if (s == null) {
      return const Scaffold(body: Center(child: Text('스케줄을 찾을 수 없습니다')));
    }
    final canEdit = ScheduleEditGuard.canEditScheduleFields(s);
    final canEditName = canEdit;
    final commitmentLocked = ScheduleEditGuard.isCommitmentLocked(s);
    final active = ScheduleActiveService.isScheduleActiveNow(s);
    final sch = ScheduleStrings.of(context);

    return Scaffold(
      appBar: IsleAppBar(
        title: s.name,
        actions: [
          if (canEdit)
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
          Card(
            margin: EdgeInsets.zero,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Text(sch.t('edit_help_title'), style: IsleText.caption()),
              children: [
                Text(
                  sch.t('edit_help_body'),
                  style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _RequiredSetupCard(schedule: s),
          const SizedBox(height: 16),
          ScheduleEditSectionHeader(
            step: 1,
            icon: Icons.schedule,
            title: sch.t('step1_title'),
            subtitle: sch.t('step1_sub'),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(sch.t('schedule_enabled')),
            value: s.enabled,
            onChanged: ScheduleEditGuard.canToggleScheduleEnabled(s)
                ? (v) => _save(s.copyWith(enabled: v))
                : null,
          ),
          TextField(
            controller: _nameCtrl,
            enabled: canEditName,
            decoration: InputDecoration(labelText: sch.t('schedule_name'), border: const OutlineInputBorder()),
            onSubmitted: canEditName
                ? (_) => _save(
                      s.copyWith(name: _nameCtrl.text.trim()),
                      feedback: _SaveFeedbackKind.brief,
                    )
                : null,
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
          if (canEdit)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _editWindows(s),
                icon: Icon(s.slots.isEmpty ? Icons.add : Icons.edit_calendar),
                label: Text(s.slots.isEmpty ? sch.t('window_add') : sch.t('window_edit')),
              ),
            ),
          const Divider(height: 28),
          ScheduleEditSectionHeader(
            step: 2,
            icon: Icons.tune,
            title: sch.t('step2_title'),
            subtitle: sch.t('step2_sub'),
          ),
          const SizedBox(height: 10),
          ScheduleEnforcementModePicker(
            value: s.enforcementMode,
            onChanged: canEdit ? (m) => _setEnforcementMode(s, m) : null,
          ),
          const Divider(height: 28),
          ScheduleEditSectionHeader(
            step: 3,
            icon: Icons.apps_outage,
            title: sch.t('step3_title'),
            subtitle: sch.t('step3_sub'),
          ),
          const SizedBox(height: 10),
          ScheduleAppTargetsSection(
            key: _targetsKey,
            schedule: s,
            canEdit: canEdit,
          ),
          const Divider(height: 28),
          ScheduleEditSectionHeader(
            step: 4,
            icon: Icons.link_off,
            title: '웹사이트 · URL',
            subtitle: '붙여넣기 · 숫자 우회 · 유사 주소 차단',
          ),
          const SizedBox(height: 10),
          ScheduleRulesSection(
            scheduleId: s.id,
            canEdit: canEdit,
          ),
          const Divider(height: 28),
          ScheduleEditSectionHeader(
            step: 5,
            icon: Icons.lock_outline,
            title: sch.t('step4_title'),
            subtitle: sch.t('step4_sub'),
          ),
          const SizedBox(height: 10),
          _lockPanel(s),
          const SizedBox(height: 24),
          if (canEdit)
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

class _RequiredSetupCard extends StatelessWidget {
  const _RequiredSetupCard({required this.schedule});

  final BlockSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final sch = ScheduleStrings.of(context);
    final hasSlots = schedule.slots.isNotEmpty;
    final apps = ScreenTimeSelectionSummary.appCountForSchedule(schedule.id);
    final cats = ScreenTimeSelectionSummary.categoryCountForSchedule(schedule.id);
    final needsShieldApps = schedule.enforcementMode.appliesShieldInSlot;
    final hasShieldSelection = apps > 0 || cats > 0;
    final ready = hasSlots && (!needsShieldApps || hasShieldSelection);

    Widget row({
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

    if (ready) return const SizedBox.shrink();

    final footer = sch.t('check_footer');
    return Card(
      color: const Color(0xFFFFF3E0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sch.t('not_ready'),
              style: IsleText.caption(color: IsleColors.gold500).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            row(
              ok: hasSlots,
              title: sch.t('check_step1'),
              subtitle: hasSlots
                  ? sch.t('check_step1_ok', args: {'n': '${schedule.slots.length}'})
                  : sch.t('check_step1_need'),
            ),
            const SizedBox(height: 6),
            row(
              ok: !needsShieldApps || hasShieldSelection,
              title: sch.t('check_step2'),
              subtitle: needsShieldApps
                  ? (hasShieldSelection
                      ? sch.t('check_step2_ok', args: {'apps': '$apps', 'cats': '$cats'})
                      : sch.t('check_step2_need'))
                  : sch.t('check_step2_optional'),
            ),
            if (footer.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(footer, style: IsleText.badge(color: IsleColors.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

