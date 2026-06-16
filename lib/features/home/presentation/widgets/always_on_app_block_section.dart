import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/block_schedule/block_schedule_enforcement_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/intervention/app_intervention_service.dart';
import '../../../../core/intervention/external_app_shield_store.dart';
import '../../../../core/block/rule_removal_lock.dart';
import '../../../../core/platform/isle_apple_platform.dart';
import '../../../../shared/widgets/rule_removal_lock_controls.dart';
import '../../../../shared/widgets/screen_time_selection_preview.dart';

/// 스케줄 없이 선택한 앱을 지금 바로 잠금 (전역 Screen Time / Android 접근성 쉴드)
class AlwaysOnAppBlockSection extends StatefulWidget {
  const AlwaysOnAppBlockSection({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<AlwaysOnAppBlockSection> createState() => _AlwaysOnAppBlockSectionState();
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
            _isAndroid
                ? '접근성 차단 서비스 권한을 허용해 주세요'
                : 'Screen Time 권한을 허용해 주세요',
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

  @override
  Widget build(BuildContext context) {
    if (!IsleApplePlatform.isNativeBlockHost) {
      return const SizedBox.shrink();
    }

    final pickLabel = _isAndroid
        ? (_hasApps ? '막을 앱 변경' : 'Chrome·Instagram 등 앱 선택')
        : (_hasApps ? '막을 앱 변경' : 'Safari·Instagram 등 앱 선택');

    final hint = _isAndroid
        ? 'Chrome·YouTube 앱 등을 함께 고르면 QR·웹 링크 누수를 줄일 수 있어요. '
            '해제는 위 「제거 잠금」 시간이 지나야 가능합니다. '
            'iOS처럼 OS가 강제하지 않으므로 접근성을 끄면 우회될 수 있어요.'
        : '완전 차단하려면 Safari·Chrome 등 모든 브라우저와 App Store까지 함께 고르세요. '
            '브라우저를 막으면 QR·웹 링크가 새지 않고, App Store를 막으면 새 브라우저 설치도 막혀요. '
            '해제는 위 「제거 잠금」 시간이 지나야 가능합니다.';

    return Card(
      color: _alwaysOn && _hasApps ? const Color(0xFFFFEBEE) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _alwaysOn && _hasApps,
              onChanged: _busy
                  ? null
                  : (v) => _run(() => _toggleAlwaysOn(v)),
              title: Text('항상 막기', style: IsleText.subtitle()),
              subtitle: Text(
                _hasApps
                    ? (_alwaysOn
                        ? '지금 $_appCount개 앱 잠금 · 스케줄 없어도 유지'
                        : '꺼짐 — 아래 스케줄 시간에만 잠금')
                    : pickLabel,
                style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
              ),
            ),
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
            const SizedBox(height: 6),
            Text(
              hint,
              style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
            ),
            if (!_isAndroid)
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
        ),
      ),
    );
  }
}
