import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/isle_routes.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/intervention/app_intervention_service.dart';
import '../../../core/intervention/browser_youtube_tracking_prefs.dart';
import '../../../core/intervention/external_app_shield_store.dart';
import '../../../core/platform/isle_apple_platform.dart';
import '../../../core/platform/ios_extension_status.dart';
import '../../../core/platform/ios_rules_export_service.dart';
import '../../../core/platform/ios_screen_time_service.dart';
import '../../../core/platform/platform_block_intent.dart';
import '../../../core/services/isle_app_log_service.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/services/setup_journey_service.dart';

/// 브라우저 유튜브 차단 → Isle에서만 보기 → 시청 시간 트래킹
class BrowserYoutubeTrackingScreen extends StatefulWidget {
  const BrowserYoutubeTrackingScreen({super.key});

  @override
  State<BrowserYoutubeTrackingScreen> createState() => _BrowserYoutubeTrackingScreenState();
}

class _BrowserYoutubeTrackingScreenState extends State<BrowserYoutubeTrackingScreen> {
  bool _busy = false;
  bool _iosAuth = false;
  bool _openInIsle = true;
  bool _clipboard = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _openInIsle = IsleUserDefaults.openYoutubeLinksInIsle;
    _clipboard = IsleUserDefaults.youtubeClipboardLaunchOnResume;
    if (IsleApplePlatform.isScreenTimeHost) {
      _iosAuth = await IosScreenTimeService.isAuthorized();
    }
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) {
        await _load();
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _applyAndroidBlock() async {
    if (!await AppInterventionService.ensureAuthorized()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정 → 접근성 → Isle 차단 서비스를 켜 주세요')),
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
    final ok = await AppInterventionService.applySavedAppShield();
    await BrowserYoutubeTrackingPrefs.setOsWebBlockApplied(true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Chrome·YouTube 앱 ${pick.applicationCount}개 차단 적용'
              : '저장됐지만 적용 실패 — 접근성 권한을 확인하세요',
        ),
      ),
    );
  }

  Future<void> _applyIosBlock() async {
    if (!IsleApplePlatform.isScreenTimeHost) return;
    await AppInterventionService.ensureAuthorized();
    await IosScreenTimeService.clearAllWebContentFilters();
    await BrowserYoutubeTrackingPrefs.setOsWebBlockApplied(false);
    await IosRulesExportService.exportNow();

    final pick = await AppInterventionService.pickApps();
    if (pick == null) return; // 사용자가 피커를 취소함
    await ExternalAppShieldStore.savePickResult(
      encoded: pick.encoded,
      applicationCount: pick.applicationCount,
      categoryCount: pick.categoryCount,
    );
    final ok = await AppInterventionService.applySavedAppShield();
    IsleAppLogService.log(
      'browser YT: app shield apply=$ok apps=${pick.applicationCount} cats=${pick.categoryCount}',
    );

    await IosExtensionStatus.openSafariSettings();
    if (mounted) {
      final base = ok
          ? 'YouTube 앱 ${pick.applicationCount}개 차단 목록에 저장·적용됐어요.'
          : '저장됐지만 OS 적용 실패 — Screen Time 권한·유료 개발자 팀을 확인하세요.';
      final safariHint = pick.applicationCount == 0
          ? '\n앱이 안 막히면 피커에서 YouTube 앱(또는 브라우저 카테고리)을 함께 선택해 주세요.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$base$safariHint\nSafari에서 Isle 차단 확장도 켜 주세요. '
            'Isle WebView에서는 계속 시청할 수 있어요.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _completeFlow() async {
    await BrowserYoutubeTrackingPrefs.setCompletedEncouragementFlow(true);
    await SetupJourneyService.markStepDone('browser_youtube_tracking');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정 완료 — 유튜브 시청은 Isle에서 기록됩니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final browser = PlatformBlockCopy.externalBrowserName;

    return Scaffold(
      backgroundColor: IsleColors.sand100,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Isle 핵심 설정', style: IsleText.subtitle(color: IsleColors.ocean900)),
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                _flowHero(browser),
                const SizedBox(height: 20),
                _stepCard(
                  step: 1,
                  title: '$browser에서 유튜브 막기',
                  body:
                      'Safari·Chrome·YouTube 앱은 Screen Time 앱 선택 + Safari 차단 확장으로 막습니다. '
                      'youtube.com OS 전역 차단은 Isle WebView까지 막히므로 사용하지 않습니다.',
                  child: IsleApplePlatform.isScreenTimeHost
                      ? _iosBlockPanel()
                      : _androidBlockPanel(),
                ),
                _stepCard(
                  step: 2,
                  title: '링크는 Isle로 열기',
                  body: '차단 후에도 복사한 URL은 Isle WebView에서 바로 재생할 수 있어요.',
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('YouTube 링크 → Isle', style: IsleText.body()),
                        subtitle: Text('공유·isle:// 딥링크', style: IsleText.caption(color: IsleColors.muted)),
                        value: _openInIsle,
                        onChanged: (v) async {
                          await IsleUserDefaults.setOpenYoutubeLinksInIsle(v);
                          setState(() => _openInIsle = v);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('클립보드 URL 자동 제안', style: IsleText.body()),
                        subtitle: Text(
                          '$browser에서 링크 복사 → Isle 복귀 시 「열기」',
                          style: IsleText.caption(color: IsleColors.muted),
                        ),
                        value: _clipboard,
                        onChanged: (v) async {
                          await IsleUserDefaults.setYoutubeClipboardLaunchOnResume(v);
                          setState(() => _clipboard = v);
                        },
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => context.push('/settings/youtube-default-open'),
                          child: const Text('고급 · 기본 앱 연결 안내'),
                        ),
                      ),
                    ],
                  ),
                ),
                _stepCard(
                  step: 3,
                  title: 'Isle에서 시청 · 시간 기록',
                  body: '피드·탐색 WebView에서만 시청 분이 쌓입니다. 일일 한도·차단 스케줄도 여기서 적용돼요.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.push('/youtube/browser'),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('유튜브 WebView 열기'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF0000),
                          minimumSize: const Size.fromHeight(IsleSize.minTouchTarget),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/settings/platform-stats'),
                        icon: const Icon(Icons.bar_chart_outlined),
                        label: const Text('시청 시간 통계 보기'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => context.push(IsleRoutes.youtubeLimits),
                        icon: const Icon(Icons.timer_outlined),
                        label: const Text('일일 시청 한도 설정'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: IsleSize.minTouchTarget,
                  child: FilledButton(
                    onPressed: _completeFlow,
                    style: FilledButton.styleFrom(backgroundColor: IsleColors.ocean500),
                    child: const Text('3단계 완료 — 트래킹 시작'),
                  ),
                ),
                if (BrowserYoutubeTrackingPrefs.hasCompletedEncouragementFlow)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '설정 흐름을 완료했어요',
                      style: IsleText.caption(color: IsleColors.grassDeep),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _flowHero(String browser) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IsleColors.ocean100),
        boxShadow: [
          BoxShadow(
            color: IsleColors.ocean500.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _flowNode(Icons.public_off, '$browser\n유튜브', muted: true),
              _flowArrow(),
              _flowNode(Icons.shield, '차단', accent: true),
              _flowArrow(),
              _flowNode(Icons.sailing, 'Isle\nWebView', accent: true),
              _flowArrow(),
              _flowNode(Icons.timer, '시간\n기록', accent: true),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '밖에서 본 유튜브는 통계에 안 잡혀요. '
            '브라우저만 막고 Isle에서 보시면 한도·스케줄·피드가 한곳에 모입니다.',
            style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _flowNode(IconData icon, String label, {bool muted = false, bool accent = false}) {
    final bg = muted
        ? IsleColors.sand100
        : accent
            ? IsleColors.ocean100
            : IsleColors.sand100;
    final fg = muted ? IsleColors.muted : IsleColors.ocean700;
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: fg),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: IsleText.caption(color: fg).copyWith(fontSize: 10, height: 1.2),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _flowArrow() => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Icon(Icons.arrow_forward, size: 16, color: IsleColors.ocean300),
      );

  Widget _stepCard({
    required int step,
    required String title,
    required String body,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: IsleColors.ocean500,
                  child: Text('$step', style: IsleText.caption(color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: IsleText.subtitle())),
              ],
            ),
            const SizedBox(height: 8),
            Text(body, style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _iosBlockPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _iosAuth ? 'Screen Time 연결됨' : 'Screen Time 권한이 필요합니다',
          style: IsleText.caption(color: _iosAuth ? IsleColors.grassDeep : IsleColors.muted),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _iosAuth ? () => _run(_applyIosBlock) : () => _run(() async {
                await AppInterventionService.ensureAuthorized();
              }),
          child: const Text('YouTube 앱 + Safari 차단 설정'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _run(() async {
            await IosScreenTimeService.clearAllWebContentFilters();
            await BrowserYoutubeTrackingPrefs.setOsWebBlockApplied(false);
          }),
          child: const Text('Isle WebView 막힘 해제 (OS 도메인 차단)'),
        ),
        TextButton(
          onPressed: IosScreenTimeService.openScreenTimeSettings,
          child: const Text('iOS Screen Time 열기'),
        ),
        Text(
          '예전 「youtube.com OS 차단」을 켰다면 Isle에서도 「Website Not Allowed」가 뜹니다. '
          '위 「Isle WebView 막힘 해제」를 누른 뒤 WebView를 새로고침하세요.',
          style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
        ),
      ],
    );
  }

  Widget _androidBlockPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Chrome·YouTube 앱은 디지털 웰빙 또는 DNS로 줄이고, '
          '시청은 Isle WebView에서 하세요.',
          style: IsleText.body().copyWith(height: 1.4),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () => _run(_applyAndroidBlock),
          child: const Text('Chrome·YouTube 앱 즉시 차단'),
        ),
        OutlinedButton(
          onPressed: () => context.push('/settings/android-system-block'),
          child: const Text('Android 차단 · VPN 설정'),
        ),
        OutlinedButton(
          onPressed: () async {
            await BrowserYoutubeTrackingPrefs.setOsWebBlockApplied(true);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('가이드대로 설정했다고 표시했어요')),
              );
            }
          },
          child: const Text('브라우저·YouTube 앱 제한 완료'),
        ),
      ],
    );
  }
}
