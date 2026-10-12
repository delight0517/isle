import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../../../core/block_schedule/models/block_schedule.dart';
import '../../../../core/block_schedule/models/schedule_enforcement_mode.dart';
import '../../../../core/block_schedule/schedule_active_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/intervention/schedule_screen_time_service.dart';
import '../../../../core/intervention/schedule_screen_time_store.dart';
import '../../../../core/intervention/screen_time_selection_summary.dart';
import '../../../../core/localization/schedule_strings.dart';
import '../../../../core/platform/isle_apple_platform.dart';
import '../../../../core/platform/ios_screen_time_service.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/block_schedule/block_schedule_enforcement_service.dart';
import '../../../../shared/widgets/screen_time_selection_preview.dart';

/// 스케줄 편집 화면 — 이 스케줄에만 적용할 Screen Time 앱·카테고리 선택.
class ScheduleScreenTimeSection extends StatefulWidget {
  const ScheduleScreenTimeSection({
    super.key,
    required this.schedule,
    this.onBlockIsleInAppChanged,
  });

  final BlockSchedule schedule;
  final ValueChanged<bool>? onBlockIsleInAppChanged;

  @override
  State<ScheduleScreenTimeSection> createState() =>
      _ScheduleScreenTimeSectionState();
}

class _ScheduleScreenTimeSectionState extends State<ScheduleScreenTimeSection> {
  bool _busy = false;
  int _apps = 0;
  int _cats = 0;
  String? _lockdownAllowedEncoded;
  int _lockdownAllowedCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(ScheduleScreenTimeStore.ensureOpen().then((_) {
      if (mounted) {
        _refreshCounts();
        setState(() {
          _lockdownAllowedEncoded = IsleUserDefaults.lockdownAllowedAppsEncoded;
          _lockdownAllowedCount = IsleUserDefaults.lockdownAllowedAppsCount;
        });
      }
    }));
  }

  Future<void> _pickLockdownAllowedApps() async {
    setState(() => _busy = true);
    final pick = await IosScreenTimeService.pickFamilyActivitySelection(
      existingEncoded: _lockdownAllowedEncoded,
      purpose: 'lockdownAllow',
    );
    if (!mounted) return;
    if (pick == null) {
      setState(() => _busy = false);
      return;
    }
    await IsleUserDefaults.setLockdownAllowedAppsEncoded(pick.encoded);
    await IsleUserDefaults.setLockdownAllowedAppsCount(pick.applicationCount);
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lockdownAllowedEncoded = pick.encoded;
      _lockdownAllowedCount = pick.applicationCount;
    });
  }

  void _refreshCounts() {
    final id = widget.schedule.id;
    setState(() {
      _apps = ScheduleScreenTimeStore.appCountFor(id);
      _cats = ScheduleScreenTimeStore.categoryCountFor(id);
    });
  }

  Future<void> _pick() async {
    if (!IsleApplePlatform.isNativeBlockHost) return;
    setState(() => _busy = true);
    final additive =
        ScheduleScreenTimeService.shouldUseAdditiveOnly(widget.schedule.id);
    final ok = await ScheduleScreenTimeService.pickForSchedule(
      widget.schedule.id,
      additiveOnly: additive,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _refreshCounts();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('앱 선택이 취소되었거나 권한이 없어요.')),
      );
      return;
    }
    if (additive && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('활성·잠금 중 — 기존 선택에 추가만 가능해요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!IsleApplePlatform.isNativeBlockHost) return const SizedBox.shrink();

    final active = ScheduleActiveService.isScheduleActiveNow(widget.schedule);
    final hasSel = _apps > 0 || _cats > 0;
    final sch = ScheduleStrings.of(context);
    final whenIn =
        widget.schedule.enforcementMode == ScheduleEnforcementMode.limitInSlot
            ? (sch.lang == 'ko'
                ? '안'
                : sch.lang == 'ja'
                    ? '内'
                    : sch.lang == 'zh'
                        ? '内'
                        : sch.lang == 'he'
                            ? 'בתוך'
                            : 'inside')
            : (sch.lang == 'ko'
                ? '밖'
                : sch.lang == 'ja'
                    ? '外'
                    : sch.lang == 'zh'
                        ? '外'
                        : sch.lang == 'he'
                            ? 'מחוץ'
                            : 'outside');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.schedule.enforcementMode.appliesShieldInSlot
                  ? sch.t('pick_apps_shield')
                  : sch.t('pick_apps_limit'),
              style: IsleText.subtitle(),
            ),
            const SizedBox(height: 6),
            Text(
              hasSel
                  ? ScreenTimeSelectionSummary.countLineForSchedule(
                      widget.schedule.id)
                  : sch.t('pick_apps_fallback'),
              style: IsleText.caption(color: IsleColors.muted),
            ),
            if (hasSel) ...[
              const SizedBox(height: 8),
              ScreenTimeSelectionPreview(
                encoded: ScreenTimeSelectionSummary.encodedForSchedule(
                    widget.schedule.id),
                textFallbackLabels:
                    ScreenTimeSelectionSummary.textLabelsForSchedule(
                        widget.schedule.id),
                height: 36,
              ),
            ],
            Text(
              widget.schedule.enforcementMode.appliesShieldInSlot
                  ? sch.t('shield_when_slot')
                  : sch.t('limit_when_slot', args: {'when': whenIn}),
              style: IsleText.caption(color: IsleColors.muted),
            ),
            if (active)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  sch.t('active_now'),
                  style: IsleText.caption(color: Colors.red.shade700),
                ),
              ),
            if (!Platform.isAndroid)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Safari에서 유튜브(youtube.com) 같은 특정 사이트를 막고 싶다면, '
                  '위 선택 화면에서 "웹 사이트" 탭으로 이동해 주소를 추가하세요 — '
                  '앱 전체 차단과 별도로 안전하게 그 사이트만 막혀요.',
                  style: IsleText.caption(color: IsleColors.muted)
                      .copyWith(height: 1.35),
                ),
              ),
            if (widget.onBlockIsleInAppChanged != null) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(sch.t('block_isle_in_app'), style: IsleText.body()),
                subtitle: Text(
                  sch.t('block_isle_sub'),
                  style: IsleText.caption(color: IsleColors.muted)
                      .copyWith(height: 1.35),
                ),
                value: widget.schedule.blockIsleInApp,
                onChanged: widget.onBlockIsleInAppChanged,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: IsleSize.minTouchTarget,
              child: FilledButton.icon(
                onPressed: _busy ? null : _pick,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.apps_outage),
                label: Text(
                  hasSel
                      ? (Platform.isAndroid ? 'Android 앱 수정' : '앱·카테고리 수정')
                      : (Platform.isAndroid ? 'Android 앱 선택' : '앱·카테고리 선택'),
                ),
              ),
            ),
            if (widget.schedule.lockdownAllApps) ...[
              const SizedBox(height: 14),
              Text('야간 전체 잠금 예외 앱', style: IsleText.subtitle()),
              const SizedBox(height: 4),
              Text(
                '선택한 앱만 올나이트 잠금에서 제외합니다. 앱 이름만 선택하세요. 카테고리나 웹사이트 선택은 예외에 반영되지 않습니다.',
                style: IsleText.caption(color: IsleColors.muted)
                    .copyWith(height: 1.35),
              ),
              if (_lockdownAllowedCount > 0 &&
                  _lockdownAllowedEncoded != null) ...[
                const SizedBox(height: 8),
                Text('허용 앱 $_lockdownAllowedCount개', style: IsleText.caption()),
                const SizedBox(height: 6),
                ScreenTimeSelectionPreview(
                  encoded: _lockdownAllowedEncoded!,
                  textFallbackLabels: const [],
                  height: 36,
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickLockdownAllowedApps,
                  icon: const Icon(Icons.checklist),
                  label:
                      Text(_lockdownAllowedCount == 0 ? '예외 앱 선택' : '예외 앱 수정'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
