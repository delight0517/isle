import 'dart:io' show Platform;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/intervention/app_intervention_service.dart';
import '../../../core/intervention/app_usage_limit_store.dart';
import '../../../core/intervention/models/app_usage_limit_rule.dart';
import '../../../core/block_schedule/schedule_limit_setup_helper.dart';
import '../../../core/block_schedule/schedule_app_limit_sync_service.dart';
import '../../../core/intervention/schedule_screen_time_store.dart';
import '../../../core/intervention/platform_app_limit_service.dart';
import '../../../core/platform/isle_apple_platform.dart';
import '../../../core/platform/ios_screen_time_service.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/social/instagram_usage_lock.dart';
import '../../../shared/widgets/screen_time_selection_preview.dart';

/// 외부 앱 일일 한도 — iOS DeviceActivity · Android Usage Stats
class AppUsageLimitsScreen extends StatefulWidget {
  const AppUsageLimitsScreen({super.key, this.scheduleId});

  final String? scheduleId;

  @override
  State<AppUsageLimitsScreen> createState() => _AppUsageLimitsScreenState();
}

class _AppUsageLimitsScreenState extends State<AppUsageLimitsScreen> {
  List<AppUsageLimitRule> _rules = [];
  bool _busy = false;
  bool _usageOk = false;
  bool _iosAuth = false;
  String? _scheduleSelectionEncoded;
  int _scheduleSelectionApps = 0;
  int _scheduleSelectionCats = 0;
  Timer? _freezeWake;
  Duration? _freezeRemaining;

  @override
  void initState() {
    super.initState();
    _load();
    _syncFreezeState();
    _scheduleFreezeWake();
  }

  @override
  void dispose() {
    _freezeWake?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    await ScheduleLimitSetupHelper.pruneAutoSeededPlaceholders();
    if (widget.scheduleId != null) {
      await ScheduleScreenTimeStore.ensureOpen();
      _scheduleSelectionEncoded = ScheduleScreenTimeStore.encodedFor(widget.scheduleId!);
      _scheduleSelectionApps = ScheduleScreenTimeStore.appCountFor(widget.scheduleId!);
      _scheduleSelectionCats = ScheduleScreenTimeStore.categoryCountFor(widget.scheduleId!);
    }
    final all = AppUsageLimitStore.loadRules();
    _rules = widget.scheduleId == null
        ? all
        : all.where((r) => r.scheduleId == widget.scheduleId).toList();
    _normalizeScheduleRules();
    if (Platform.isAndroid) {
      _usageOk = await PlatformAppLimitService.hasUsageAccess();
    } else if (IsleApplePlatform.isScreenTimeHost) {
      _iosAuth = await IosScreenTimeService.isAuthorized();
      _usageOk = _iosAuth;
    }
    if (mounted) setState(() => _busy = false);
  }

  void _normalizeScheduleRules() {
    final sid = widget.scheduleId;
    if (sid == null) return;

    final normalizedId = 'schedule_scope_$sid';
    final existing =
        _rules.where((r) => r.id == normalizedId).firstOrNull ?? _rules.firstOrNull;
    final base = existing ??
        AppUsageLimitRule(
          id: normalizedId,
          label: '이 스케줄에서 선택한 앱',
          minutesPerWindow: 10,
          scheduleId: sid,
          windowMinutes: 60,
        );

    _rules = [
      AppUsageLimitRule(
        id: normalizedId,
        label: base.label,
        minutesPerWindow: base.minutesPerWindow,
        enabled: base.enabled,
        iosFamilyActivityEncoded: _scheduleSelectionEncoded,
        androidPackageName: base.androidPackageName,
        presetId: base.presetId,
        scheduleId: sid,
        windowMinutes: base.windowMinutes,
        interventionTitle: base.interventionTitle,
        interventionBody: base.interventionBody,
      ),
    ];
  }

  bool _isInstagramRule(AppUsageLimitRule rule) {
    final p = (rule.presetId ?? '').toLowerCase();
    final label = rule.label.toLowerCase();
    final pkg = (rule.androidPackageName ?? '').toLowerCase();
    return p == 'instagram' || label.contains('instagram') || pkg.contains('com.instagram');
  }

  void _syncFreezeState() {
    _freezeRemaining = IsleUserDefaults.instagramBlockSettingsUnlockRemaining;
    if (_freezeRemaining == null &&
        IsleUserDefaults.instagramBlockSettingsUnlockStartedAtMs != null) {
      unawaited(IsleUserDefaults.clearInstagramBlockSettingsFreezeCountdown());
    }
  }

  void _scheduleFreezeWake() {
    _freezeWake?.cancel();
    final left = _freezeRemaining;
    if (left == null) return;
    final sec = left.inSeconds.clamp(1, 60);
    _freezeWake = Timer(Duration(seconds: sec), () {
      if (!mounted) return;
      setState(_syncFreezeState);
      _scheduleFreezeWake();
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h시간 ${m.toString().padLeft(2, '0')}분';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _saveAndSync() async {
    setState(() => _busy = true);
    final all = AppUsageLimitStore.loadRules();
    final merged = widget.scheduleId == null
        ? _rules
        : [
            ...all.where((r) => r.scheduleId != widget.scheduleId),
            ..._rules,
          ];
    await AppUsageLimitStore.saveRules(merged);
    if (IsleApplePlatform.isScreenTimeHost && !await IosScreenTimeService.isAuthorized()) {
      await AppInterventionService.ensureAuthorized();
    }
    if (Platform.isAndroid && !await PlatformAppLimitService.hasUsageAccess()) {
      await PlatformAppLimitService.openUsageAccessSettings();
    }
    await ScheduleAppLimitSyncService.syncAll();
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('한도를 OS에 반영했어요')),
      );
    }
  }

  Future<void> _pickIosApps(AppUsageLimitRule rule, int index) async {
    final pick = await AppInterventionService.pickApps(
      existingEncoded: rule.iosFamilyActivityEncoded,
    );
    if (pick == null || !mounted) return;
    setState(() {
      _rules[index] = rule.copyWith(iosFamilyActivityEncoded: pick.encoded);
    });
  }

  Future<void> _pickAndroidPackage(AppUsageLimitRule rule, int index) async {
    if (!await AppInterventionService.ensureAuthorized()) return;
    final pick = await AppInterventionService.pickApps();
    if (pick == null || pick.encoded.isEmpty || !mounted) return;
    final pkg = pick.encoded.split(',').map((p) => p.trim()).firstWhere(
          (p) => p.isNotEmpty,
          orElse: () => '',
        );
    if (pkg.isEmpty) return;
    setState(() {
      _rules[index] = rule.copyWith(androidPackageName: pkg);
    });
  }

  Future<void> _addPreset(({String id, String label, String androidPackage}) preset) async {
    final scopeId = widget.scheduleId == null ? preset.id : '${preset.id}_${widget.scheduleId}';
    if (_rules.any((r) => r.id == scopeId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${preset.label} 규칙이 이미 있어요')),
      );
      return;
    }
    setState(() {
      _rules.add(
        AppUsageLimitRule(
          id: scopeId,
          label: preset.label,
          minutesPerWindow: preset.id == 'instagram' ? 8 : 10,
          windowMinutes: 60,
          scheduleId: widget.scheduleId,
          androidPackageName: preset.androidPackage,
          presetId: preset.id,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IsleColors.sand100,
          appBar: AppBar(
        title: Text(
          widget.scheduleId == null ? '앱별 시간 한도' : '이 스케줄의 앱 한도',
          style: IsleText.subtitle(),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : _saveAndSync, child: const Text('적용')),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                _permissionCard(),
                if (widget.scheduleId == null) ...[
                  const SizedBox(height: 12),
                  _instagramLimitsEntry(),
                ],
                const SizedBox(height: 12),
                if (widget.scheduleId != null)
                  Card(
                    color: IsleColors.ocean100.withValues(alpha: 0.4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '이 스케줄의 차단 방식에 맞춰 iOS는 슬롯 안/밖에만 한도가 적용됩니다. '
                        'Android는 아직 전역 한도만 지원해요.',
                        style: IsleText.caption(color: IsleColors.ocean700).copyWith(height: 1.4),
                      ),
                    ),
                  ),
                if (widget.scheduleId != null) const SizedBox(height: 12),
                Text(
                  widget.scheduleId == null
                      ? '예: Instagram 8분(매시간 리셋) · 「시간당 리셋」을 켜 주세요.\n'
                          'iOS: Screen Time · Android: 사용량 접근 + 전면 안내'
                      : '이 스케줄에서 2단계에 선택한 앱만 대상으로 한도를 설정합니다. '
                          '여기서는 분/리셋 방식만 정하면 됩니다.',
                  style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.45),
                ),
                if (widget.scheduleId != null) ...[
                  const SizedBox(height: 10),
                  Card(
                    color: IsleColors.ocean100.withValues(alpha: 0.32),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _scheduleSelectionApps + _scheduleSelectionCats > 0
                                ? '대상 앱 · 앱 $_scheduleSelectionApps개 / 카테고리 $_scheduleSelectionCats개'
                                : '먼저 2단계 「차단할 앱 선택」에서 앱을 골라 주세요',
                            style: IsleText.caption(color: IsleColors.ocean700),
                          ),
                          if (_scheduleSelectionEncoded != null &&
                              _scheduleSelectionEncoded!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ScreenTimeSelectionPreview(
                              encoded: _scheduleSelectionEncoded,
                              height: 36,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                if (widget.scheduleId != null && _rules.isEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: IsleColors.sand100,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        '아직 한도가 없어요. YouTube·Instagram 등 원하는 앱을 「+」 버튼으로 추가하세요.',
                        style: IsleText.body(color: IsleColors.ocean700).copyWith(height: 1.4),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (widget.scheduleId == null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppUsageLimitRule.presets.map((p) {
                      return ActionChip(
                        label: Text('+ ${p.label}'),
                        onPressed: () => _addPreset(p),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                ..._rules.asMap().entries.map((e) => _ruleCard(e.key, e.value)),
                const SizedBox(height: 12),
                if (widget.scheduleId == null)
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _rules.add(
                          AppUsageLimitRule(
                            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                            label: '새 앱',
                            minutesPerWindow: 20,
                            scheduleId: widget.scheduleId,
                            windowMinutes: 60,
                          ),
                        );
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('직접 추가'),
                  ),
                if (IsleApplePlatform.isScreenTimeHost)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      Platform.isMacOS
                          ? 'macOS: Screen Time 권한 후 앱을 선택하세요. '
                              '스케줄 활성 시 Instagram·TikTok 등이 자동 종료될 수 있습니다.'
                          : 'iOS: Xcode에 Device Activity Monitor 확장을 추가해야 '
                              '백그라운드에서 자동 쉴드가 됩니다. '
                              'docs/IOS_APP_LIMITS_SETUP.md 참고.',
                      style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _permissionCard() {
    final ok = _usageOk;
    return Card(
      color: ok ? IsleColors.ocean100 : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(ok ? Icons.verified_user : Icons.warning_amber, color: IsleColors.ocean700),
        title: Text(
          IsleApplePlatform.isScreenTimeHost ? 'Screen Time 권한' : '사용량 접근 권한',
          style: IsleText.subtitle(),
        ),
        subtitle: Text(
          ok
              ? '한도를 이 기기에 적용할 수 있어요'
              : IsleApplePlatform.isScreenTimeHost
                  ? '허용 후 앱을 다시 선택하세요'
                  : '설정 → 특별한 앱 액세스 → 사용량 접근',
          style: IsleText.caption(),
        ),
        trailing: ok
            ? null
            : FilledButton(
                onPressed: () async {
                  if (IsleApplePlatform.isScreenTimeHost) {
                    await AppInterventionService.ensureAuthorized();
                  } else {
                    await PlatformAppLimitService.openUsageAccessSettings();
                  }
                  await _load();
                },
                child: const Text('허용'),
              ),
      ),
    );
  }

  Widget _ruleCard(int index, AppUsageLimitRule rule) {
    final instagramRule = _isInstagramRule(rule);
    final lockedByFreeze =
        instagramRule && InstagramUsageScope.feed.isSettingsFrozen;
    final editable = !lockedByFreeze;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(rule.label, style: IsleText.subtitle())),
                Switch(
                  value: rule.enabled,
                  onChanged: editable ? (v) {
                    setState(() => _rules[index] = rule.copyWith(enabled: v));
                  } : null,
                ),
              ],
            ),
            if (lockedByFreeze)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '피드 타임락 대기 중 · '
                  '${_formatDuration(InstagramUsageScope.feed.unlockRemaining!)} 후 변경 가능',
                  style: IsleText.caption(color: IsleColors.danger),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('한도'),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: editable && rule.minutesPerWindow > 1
                      ? () => setState(() {
                            _rules[index] =
                                rule.copyWith(minutesPerWindow: rule.minutesPerWindow - 1);
                          })
                      : null,
                ),
                Text('${rule.minutesPerWindow}분', style: IsleText.subtitle()),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: editable && rule.minutesPerWindow < 120
                      ? () => setState(() {
                            _rules[index] =
                                rule.copyWith(minutesPerWindow: rule.minutesPerWindow + 1);
                          })
                      : null,
                ),
                Text(rule.windowMinutes == 60 ? ' / 매시간 리셋' : ' / 하루 리셋', style: IsleText.caption()),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('매시간 리셋'),
                  selected: rule.windowMinutes == 60,
                  onSelected: editable ? (_) {
                    setState(() {
                      _rules[index] = rule.copyWith(windowMinutes: 60);
                    });
                  } : null,
                ),
                ChoiceChip(
                  label: const Text('일일 리셋'),
                  selected: rule.windowMinutes == 1440,
                  onSelected: editable ? (_) {
                    setState(() {
                      _rules[index] = rule.copyWith(windowMinutes: 1440);
                    });
                  } : null,
                ),
              ],
            ),
            if (IsleApplePlatform.isScreenTimeHost && widget.scheduleId == null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: editable ? () => _pickIosApps(rule, index) : null,
                icon: const Icon(Icons.apps, size: 18),
                label: Text(
                  rule.iosFamilyActivityEncoded != null
                      ? '앱 선택됨 · 다시 고르기'
                      : Platform.isMacOS
                          ? 'macOS에서 차단할 앱 선택'
                          : 'iOS에서 차단할 앱 선택',
                ),
              ),
            ] else if (IsleApplePlatform.isScreenTimeHost && widget.scheduleId != null) ...[
              const SizedBox(height: 10),
              Text(
                '대상 앱은 스케줄 2단계 「차단할 앱 선택」을 그대로 사용합니다.',
                style: IsleText.caption(color: IsleColors.muted),
              ),
            ] else if (Platform.isAndroid && widget.scheduleId != null) ...[
              const SizedBox(height: 10),
              Text(
                '대상 앱은 스케줄 편집 「Android 앱」 선택을 그대로 사용합니다.',
                style: IsleText.caption(color: IsleColors.muted),
              ),
            ] else if (Platform.isAndroid && widget.scheduleId == null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: editable ? () => _pickAndroidPackage(rule, index) : null,
                icon: const Icon(Icons.android, size: 18),
                label: Text(
                  rule.androidPackageName != null
                      ? '${rule.androidPackageName} · 다시 고르기'
                      : 'Android에서 한도 적용할 앱 선택',
                ),
              ),
            ],
            if (Platform.isAndroid && rule.androidPackageName != null) ...[
              const SizedBox(height: 8),
              FutureBuilder<int>(
                future: PlatformAppLimitService.usageMinutesToday(
                  androidPackage: rule.androidPackageName,
                ),
                builder: (context, snap) {
                  final used = snap.data ?? 0;
                  return Text(
                    '오늘 $used분 사용 · ${rule.androidPackageName}',
                    style: IsleText.caption(color: IsleColors.muted),
                  );
                },
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: IsleColors.danger),
                onPressed: editable ? () {
                  setState(() => _rules.removeAt(index));
                } : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _instagramLimitsEntry() {
    return Card(
      color: const Color(0xFFEAF4FF),
      child: ListTile(
        title: Text('Instagram 피드 / DM 한도', style: IsleText.subtitle()),
        subtitle: Text(
          '피드·DM 각각 일일 한도 + 이용 중 타임락',
          style: IsleText.caption(color: IsleColors.muted),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/instagram-limits'),
      ),
    );
  }
}
