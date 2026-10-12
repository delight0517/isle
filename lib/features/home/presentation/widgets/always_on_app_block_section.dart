import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/block/rule_removal_lock.dart';
import '../../../../core/block_schedule/block_schedule_enforcement_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/intervention/app_intervention_service.dart';
import '../../../../core/intervention/external_app_shield_store.dart';
import '../../../../core/platform/isle_apple_platform.dart';
import '../../../../shared/widgets/rule_removal_lock_controls.dart';
import '../../../../shared/widgets/screen_time_selection_preview.dart';
import 'safari_pause_widget.dart';

/// 스케줄 없이 선택한 앱을 지금 바로 잠금 (전역 Screen Time / Android 접근성 쉴드)
class AlwaysOnAppBlockSection extends StatefulWidget {
  const AlwaysOnAppBlockSection({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<AlwaysOnAppBlockSection> createState() =>
      _AlwaysOnAppBlockSectionState();
}

class _AlwaysOnAppBlockSectionState extends State<AlwaysOnAppBlockSection> {
  bool _busy = false;
  bool _alwaysOn = false;
  bool _hasApps = false;
  int _appCount = 0;

  bool get _isAndroid => Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await ExternalAppShieldStore.ensureOpen();
    if (!mounted) return;
    setState(() {
      _alwaysOn = !ExternalAppShieldStore.syncWithBlockSchedule;
      _hasApps = ExternalAppShieldStore.hasSelection;
      _appCount = ExternalAppShieldStore.applicationCount;
    });
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
      await _load();
      widget.onChanged?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleAlwaysOn(bool on) async {
    if (!on && RuleRemovalLock.removalBlocked) {
      if (!mounted) return;
      showRuleRemovalBlockedSnackBar(context);
      return;
    }
    await ExternalAppShieldStore.setSyncWithBlockSchedule(!on);
    if (on) {
      if (!ExternalAppShieldStore.hasSelection) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('먼저 아래에서 막을 앱을 선택하세요')),
        );
        await ExternalAppShieldStore.setSyncWithBlockSchedule(true);
        await _load();
        return;
      }
      if (!await AppInterventionService.ensureAuthorized()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isAndroid
                  ? '설정 → 접근성 → Isle 차단 서비스를 켜 주세요'
                  : 'Screen Time 권한이 필요해요',
            ),
          ),
        );
        await ExternalAppShieldStore.setSyncWithBlockSchedule(true);
        await _load();
        return;
      }
      if (!RuleRemovalLock.lockEnabled) {
        await RuleRemovalLock.setLockEnabled(true);
        if (mounted) {
          final min = RuleRemovalLock.freezeMinutes;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Safari·앱 끄기 전 $min분 대기가 켜졌어요 — 아래에서 시간을 바꿀 수 있어요',
              ),
            ),
          );
        }
      }
      await AppInterventionService.applySavedAppShield();
    }
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
  }

  Future<void> _pickApps() async {
    if (!await AppInterventionService.ensureAuthorized()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAndroid ? '접근성 차단 서비스 권한을 허용해 주세요' : 'Screen Time 권한을 허용해 주세요',
          ),
        ),
      );
      return;
    }
    final pick = await AppInterventionService.pickApps();
    if (pick == null) return;
    await ExternalAppShieldStore.savePickResult(
      encoded: pick.encoded,
      applicationCount: pick.applicationCount,
      categoryCount: pick.categoryCount,
    );
    if (_alwaysOn) {
      await AppInterventionService.applySavedAppShield();
    }
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('앱 ${pick.applicationCount}개 · 즉시 차단 목록에 저장')),
    );
  }

  Widget _stepLine(String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n,
              style: IsleText.caption(color: IsleColors.ocean700)
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: IsleText.caption(color: IsleColors.muted)
                    .copyWith(height: 1.35)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!IsleApplePlatform.isNativeBlockHost) {
      return const SizedBox.shrink();
    }

    final freezeMin = RuleRemovalLock.freezeMinutes;
    final pickLabel = _isAndroid
        ? (_hasApps ? '막을 앱 변경' : 'Chrome·Instagram 등 앱 선택')
        : (_hasApps ? '막을 앱 변경' : 'Safari·Instagram 등 앱 선택');

    return Card(
      color: _alwaysOn && _hasApps ? const Color(0xFFFFEBEE) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: IsleColors.ocean100.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이 카드가 하는 일',
                    style: IsleText.caption().copyWith(
                        fontWeight: FontWeight.w700,
                        color: IsleColors.ocean900),
                  ),
                  const SizedBox(height: 6),
                  _stepLine(
                    '①',
                    _isAndroid
                        ? '막을 앱을 고릅니다 (Chrome·YouTube 앱 등)'
                        : '막을 앱을 고릅니다 — Safari를 넣으면 브라우저로 유튜브·SNS 보는 것도 막혀요',
                  ),
                  _stepLine(
                    '②',
                    _isAndroid
                        ? '계속 차단 ON → 선택한 Android 앱을 스케줄과 무관하게 차단하고, MOA 안의 대체 기능을 이용할 수 있어요.'
                        : '계속 차단 ON → 선택한 iPhone 앱을 스케줄과 무관하게 차단하고, MOA 안의 대체 기능을 이용할 수 있어요.',
                  ),
                  _stepLine('③',
                      '직접 해제하거나 목록을 바꿀 때는 아래 삭제 대기($freezeMin분, 변경 가능)가 적용돼요.'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _alwaysOn && _hasApps,
              onChanged: _busy ? null : (v) => _run(() => _toggleAlwaysOn(v)),
              title: Text('선택한 앱 계속 차단', style: IsleText.subtitle()),
              subtitle: Text(
                _hasApps
                    ? (_alwaysOn
                        ? '켜짐 — $_appCount개 앱 계속 차단 중 (시스템 권한 유지 시)'
                        : '꺼짐 — 차단 스케줄 시간에만 잠금')
                    : '먼저 막을 앱을 선택하세요',
                style: IsleText.caption(color: IsleColors.muted)
                    .copyWith(height: 1.35),
              ),
            ),
            const SizedBox(height: 6),
            SafariPauseWidget(alwaysOn: _alwaysOn, hasApps: _hasApps),
            if (_alwaysOn && _hasApps && !_isAndroid) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Text(
                  'Safari를 막으면 유튜브·웹을 브라우저로 보는 우회도 함께 줄일 수 있어요. '
                  '끄기 전 $freezeMin분 대기(삭제 대기)가 적용됩니다.',
                  style: IsleText.caption(color: Colors.orange.shade900)
                      .copyWith(height: 1.4),
                ),
              ),
            ],
            if (_hasApps) ...[
              const SizedBox(height: 4),
              ScreenTimeSelectionPreview(
                encoded: ExternalAppShieldStore.encodedSelection,
                height: 36,
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: IsleSize.minTouchTarget,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _run(_pickApps),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.apps_outage),
                label: Text(pickLabel),
              ),
            ),
            if (!_isAndroid) ...[
              const SizedBox(height: 4),
              Text(
                '예: iPhone YouTube 앱을 차단하고 MOA 안의 YouTube를 이용할 수 있어요. Safari와 App Store는 필요할 때만 선택하세요.',
                style: IsleText.caption(color: IsleColors.muted)
                    .copyWith(height: 1.35),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push('/settings/app-deletion-guard'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('앱 삭제까지 막기 (마지막 구멍)'),
                ),
              ),
            ],
            if (_hasApps) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                'Safari·앱 끄기 전 대기',
                style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '충동적으로 스위치를 끄지 않도록, 해제·목록 변경 전 $freezeMin분(기본) 대기합니다.',
                style: IsleText.caption(color: IsleColors.muted)
                    .copyWith(height: 1.35),
              ),
              const SizedBox(height: 8),
              const RuleRemovalLockControls(compact: true),
            ],
          ],
        ),
      ),
    );
  }
}
