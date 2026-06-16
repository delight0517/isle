import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/blocking/blocking_controller.dart';
import '../../../core/blocking/blocking_controller_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/intervention/app_intervention_service.dart';
import '../../../core/intervention/external_app_shield_store.dart';
import '../../../core/intervention/models/app_intervention_preset.dart';
import '../../../core/platform/isle_apple_platform.dart';
import '../../../core/platform/ios_screen_time_service.dart';
import '../../../core/platform/platform_block_intent.dart';
import '../../../shared/widgets/screen_time_selection_preview.dart';

/// 다른 앱 개입 · 시간 제한 (4vpnBlocker 프리셋 + iOS FamilyActivityPicker)
class ExternalAppControlScreen extends StatefulWidget {
  const ExternalAppControlScreen({super.key});

  @override
  State<ExternalAppControlScreen> createState() => _ExternalAppControlScreenState();
}

class _ExternalAppControlScreenState extends State<ExternalAppControlScreen> {
  bool _busy = false;
  ScreenTimeAuthStatus _authStatus = ScreenTimeAuthStatus.unavailable;
  bool? _available;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (Platform.isAndroid) {
      final c = resolveBlockingController();
      final a = await c.isAvailable();
      final auth = await c.authorizationStatus();
      if (mounted) {
        setState(() {
          _available = a;
          _authStatus = a ? auth : ScreenTimeAuthStatus.unavailable;
        });
      }
      return;
    }
    if (!IsleApplePlatform.isScreenTimeHost) return;
    final a = await IosScreenTimeService.isAvailable();
    final auth = await IosScreenTimeService.authorizationStatus();
    if (mounted) {
      setState(() {
        _available = a;
        _authStatus = a ? auth : ScreenTimeAuthStatus.unavailable;
      });
    }
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) {
        await _refresh();
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _authorize() async {
    if (Platform.isAndroid) {
      final c = resolveBlockingController();
      final result = await c.requestAuthorization();
      await _refresh();
      if (!mounted) return;
      if (result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('접근성 허용됨 — 이제 차단할 앱을 고르세요')),
        );
        await _pickApps();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? '접근성 차단 서비스를 켜 주세요'),
            action: SnackBarAction(
              label: '설정',
              onPressed: () => c.openSystemSettings(),
            ),
          ),
        );
      }
      return;
    }
    final result = await IosScreenTimeService.requestAuthorizationDetailed();
    await _refresh();
    if (!mounted) return;
    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('허용됨 — 이제 「차단할 앱·카테고리 고르기」를 누르세요')),
      );
      await _pickApps();
      return;
    }
    _showAuthFailureSnack(result);
  }

  void _showAuthFailureSnack(ScreenTimeAuthResult result) {
    final messenger = ScaffoldMessenger.of(context);
    final fallback = result.message ?? '권한 요청이 완료되지 않았어요. 다시 시도해 주세요.';
    SnackBarAction? action;
    if (result.needsSettings) {
      action = const SnackBarAction(
        label: '설정',
        onPressed: IosScreenTimeService.openScreenTimeSettings,
      );
    } else if (result.isSimulator) {
      action = SnackBarAction(label: '확인', onPressed: messenger.hideCurrentSnackBar);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(fallback),
        duration: const Duration(seconds: 6),
        action: action,
      ),
    );
  }

  Future<void> _pickApps() async {
    if (_authStatus != ScreenTimeAuthStatus.approved) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Platform.isAndroid
                ? '먼저 접근성 차단 서비스를 켜 주세요'
                : '먼저 Screen Time 권한을 허용하세요',
          ),
        ),
      );
      return;
    }
    final pick = await AppInterventionService.pickApps();
    if (pick == null || !mounted) return;
    await ExternalAppShieldStore.savePickResult(
      encoded: pick.encoded,
      applicationCount: pick.applicationCount,
      categoryCount: pick.categoryCount,
    );
    final ok = await AppInterventionService.applySavedAppShield();
    if (!mounted) return;
    final scheduleOnly = ExternalAppShieldStore.syncWithBlockSchedule;
    final immediateHint = scheduleOnly
        ? '현재는 「차단 스케줄 시간에만 적용」이 켜져 있어, 스케줄 시간이 아닐 때는 즉시 잠기지 않을 수 있어요.'
        : '전역 차단 모드로 즉시 적용됩니다.';
    final browserHint = Platform.isAndroid
        ? (pick.applicationCount == 0
            ? '\nChrome이 안 막히면 Chrome·YouTube 앱을 함께 선택해 주세요.'
            : '')
        : (pick.applicationCount == 0
            ? '\nSafari가 안 막히면 피커에서 Safari 앱 또는 브라우저 카테고리를 함께 선택해 주세요.'
            : '');
    final base = ok
        ? '앱 ${pick.applicationCount}개 · 카테고리 ${pick.categoryCount}개 차단 목록에 저장됨'
        : (Platform.isAndroid
            ? '저장됐지만 OS 적용 실패 — 접근성·VPN 권한을 확인하세요'
            : '저장됐지만 OS 적용 실패 — Screen Time 권한·유료 개발자 팀을 확인하세요');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$base\n$immediateHint$browserHint'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isApple = IsleApplePlatform.isScreenTimeHost;
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      backgroundColor: IsleColors.sand100,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('다른 앱 차단·한도', style: IsleText.subtitle(color: IsleColors.ocean900)),
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                _heroCard(),
                const SizedBox(height: 16),
                if (isApple) ...[
                  _sectionTitle(
                    Platform.isMacOS ? 'macOS — 앱 선택' : 'iOS — 앱 선택',
                  ),
                  _iosAuthCard(),
                  const SizedBox(height: 12),
                  _actionTile(
                    icon: Icons.apps_outlined,
                    title: '차단할 앱·카테고리 고르기',
                    subtitle: ExternalAppShieldStore.hasSelection
                        ? '앱 ${ExternalAppShieldStore.applicationCount} · 카테고리 ${ExternalAppShieldStore.categoryCount}'
                        : 'YouTube · Instagram · TikTok 등',
                    onTap: () => _run(_pickApps),
                  ),
                  if (ExternalAppShieldStore.hasSelection) ...[
                    const SizedBox(height: 8),
                    ScreenTimeSelectionPreview(
                      encoded: ExternalAppShieldStore.encodedSelection,
                      height: 40,
                    ),
                  ],
                  SwitchListTile(
                    value: ExternalAppShieldStore.syncWithBlockSchedule,
                    onChanged: (v) async {
                      await ExternalAppShieldStore.setSyncWithBlockSchedule(v);
                      await AppInterventionService.syncWithActiveSchedules();
                      setState(() {});
                    },
                    title: Text('차단 스케줄 시간에만 적용', style: IsleText.body()),
                    subtitle: Text(
                      '켜짐: 스케줄 시간에만 잠금 / 꺼짐: 지금부터 전역 차단. 앱이 꺼져 있으면 복귀 시 동기화됩니다.',
                      style: IsleText.caption(color: IsleColors.muted),
                    ),
                  ),
                  if (ExternalAppShieldStore.hasSelection)
                    ListTile(
                      leading: const Icon(Icons.remove_circle_outline, color: IsleColors.danger),
                      title: Text('선택 초기화', style: IsleText.body(color: IsleColors.danger)),
                      onTap: () => _run(() async {
                        await AppInterventionService.clearAppShield();
                        await ExternalAppShieldStore.clearSelection();
                      }),
                    ),
                  const SizedBox(height: 8),
                  _actionTile(
                    icon: Icons.track_changes,
                    title: '브라우저 유튜브 → Isle 트래킹',
                    subtitle: 'Safari·Chrome 차단 후 WebView에서 시청·시간 기록',
                    onTap: () => context.push('/settings/browser-youtube-tracking'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => IosScreenTimeService.openScreenTimeSettings(),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(
                      Platform.isMacOS ? 'macOS Screen Time 열기' : 'iOS 스크린 타임 열기',
                    ),
                  ),
                ] else if (isAndroid) ...[
                  _sectionTitle('Android — 앱 선택'),
                  _androidAuthCard(),
                  const SizedBox(height: 12),
                  _actionTile(
                    icon: Icons.apps_outlined,
                    title: '차단할 앱 고르기',
                    subtitle: ExternalAppShieldStore.hasSelection
                        ? '앱 ${ExternalAppShieldStore.applicationCount}개 선택됨'
                        : 'YouTube · Instagram · Chrome 등',
                    onTap: () => _run(_pickApps),
                  ),
                  if (ExternalAppShieldStore.hasSelection) ...[
                    const SizedBox(height: 8),
                    ScreenTimeSelectionPreview(
                      encoded: ExternalAppShieldStore.encodedSelection,
                      height: 40,
                    ),
                  ],
                  SwitchListTile(
                    value: ExternalAppShieldStore.syncWithBlockSchedule,
                    onChanged: (v) async {
                      await ExternalAppShieldStore.setSyncWithBlockSchedule(v);
                      await AppInterventionService.syncWithActiveSchedules();
                      setState(() {});
                    },
                    title: Text('차단 스케줄 시간에만 적용', style: IsleText.body()),
                    subtitle: Text(
                      '켜짐: 스케줄 시간에만 잠금 / 꺼짐: 지금부터 전역 차단',
                      style: IsleText.caption(color: IsleColors.muted),
                    ),
                  ),
                  if (ExternalAppShieldStore.hasSelection)
                    ListTile(
                      leading: const Icon(Icons.remove_circle_outline, color: IsleColors.danger),
                      title: Text('선택 초기화', style: IsleText.body(color: IsleColors.danger)),
                      onTap: () => _run(() async {
                        await AppInterventionService.clearAppShield();
                        await ExternalAppShieldStore.clearSelection();
                      }),
                    ),
                  const SizedBox(height: 8),
                  _actionTile(
                    icon: Icons.shield_outlined,
                    title: 'Android 시스템 차단 (VPN·접근성)',
                    subtitle: '웹사이트 DNS 차단 · 고급 설정',
                    onTap: () => context.push('/settings/android-system-block'),
                  ),
                ] else
                  _androidGuideCard(),
                const SizedBox(height: 20),
                _sectionTitle('프리셋 (4vpnBlocker 스타일)'),
                ...AppInterventionPreset.all.map(_presetCard),
                const SizedBox(height: 12),
                _actionTile(
                  icon: Icons.timer_outlined,
                  title: '앱별 시간 한도 · 개입',
                  subtitle: 'Instagram 20분 등 · iOS·macOS·Android OS 연동',
                  onTap: () => context.push('/settings/app-usage-limits'),
                ),
                const SizedBox(height: 16),
                _actionTile(
                  icon: Icons.schedule,
                  title: '차단 스케줄 편집',
                  subtitle: '요일·시간대 · 유튜브 도메인',
                  onTap: () => context.push('/settings/block-schedules'),
                ),
              ],
            ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [IsleColors.ocean500, IsleColors.ocean700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Colors.white.withValues(alpha: 0.9), size: 32),
          const SizedBox(height: 10),
          Text(
            'Isle 밖 앱도 통제',
            style: IsleText.title(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            '유튜브·SNS·게임을 시스템에서 막고, 보고 싶은 건 Isle WebView와 피드로 모읍니다.',
            style: IsleText.body(color: Colors.white.withValues(alpha: 0.92)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: IsleText.subtitle(color: IsleColors.ocean900)),
      );

  Widget _iosAuthCard() {
    final avail = _available ?? false;
    final authorized = _authStatus == ScreenTimeAuthStatus.approved;
    final statusText = switch (_authStatus) {
      ScreenTimeAuthStatus.approved => '권한 승인됨 — 아래에서 앱 선택',
      ScreenTimeAuthStatus.denied => '거부됨 — 설정 → 스크린 타임',
      ScreenTimeAuthStatus.notDetermined => '권한 필요 (6VPN과 같이 시스템 창이 뜹니다)',
      ScreenTimeAuthStatus.unavailable => avail
          ? '상태 확인 중…'
          : 'Family Controls 미포함 빌드',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  authorized ? Icons.verified_user : Icons.privacy_tip_outlined,
                  color: authorized ? IsleColors.grassDeep : IsleColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Screen Time', style: IsleText.subtitle()),
                      Text(statusText, style: IsleText.caption(color: IsleColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            if (avail) ...[
              const SizedBox(height: 12),
              if (!authorized)
                FilledButton.icon(
                  onPressed: _busy ? null : () => _run(_authorize),
                  icon: const Icon(Icons.lock_open_outlined, size: 18),
                  label: const Text('Screen Time 권한 요청'),
                ),
              if (authorized)
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => _run(_pickApps),
                  icon: const Icon(Icons.apps, size: 18),
                  label: Text(
                    ExternalAppShieldStore.hasSelection
                        ? '앱·카테고리 다시 고르기'
                        : '차단할 앱 선택 (피커 열기)',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _androidAuthCard() {
    final authorized = _authStatus == ScreenTimeAuthStatus.approved;
    final statusText = authorized
        ? '접근성 차단 서비스 켜짐 — 아래에서 앱 선택'
        : '설정 → 접근성 → Isle 차단 서비스를 켜 주세요';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  authorized ? Icons.verified_user : Icons.accessibility_new,
                  color: authorized ? IsleColors.grassDeep : IsleColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(statusText, style: IsleText.body())),
              ],
            ),
            if (!authorized) ...[
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _busy ? null : () => _run(_authorize),
                child: const Text('접근성 설정 열기'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _androidGuideCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Android', style: IsleText.subtitle()),
            const SizedBox(height: 8),
            Text(
              '다른 앱 차단은 디지털 웰빙·DNS 가이드를 따릅니다. Isle WebView 한도는 탐색 화면 상단 칩에서 설정하세요.',
              style: IsleText.body(color: IsleColors.muted),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.push(PlatformBlockCopy.settingsRoute),
              child: Text(PlatformBlockCopy.settingsTileTitle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetCard(AppInterventionPreset p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _run(() async {
          if (p.suggestYoutubeWebBlock && IsleApplePlatform.isNativeBlockHost) {
            if (Platform.isAndroid) {
              await AppInterventionService.ensureAuthorized();
            } else if (await AppInterventionService.ensureAuthorized()) {
              await IosScreenTimeService.clearAllWebContentFilters();
            }
          }
          await _pickApps();
          if (p.suggestScheduleName != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('「${p.suggestScheduleName}」 스케줄을 차단 스케줄에서 추가해 보세요'),
                action: SnackBarAction(
                  label: '열기',
                  onPressed: () => context.push('/settings/block-schedules'),
                ),
              ),
            );
          }
        }),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: p.tint.withValues(alpha: 0.15),
                child: Icon(p.icon, color: p.tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: IsleText.subtitle()),
                    const SizedBox(height: 4),
                    Text(p.detail, style: IsleText.caption(color: IsleColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: IsleColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: IsleColors.ocean500),
        title: Text(title, style: IsleText.body()),
        subtitle: Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
        trailing: const Icon(Icons.chevron_right, color: IsleColors.muted),
        onTap: onTap,
      ),
    );
  }
}
