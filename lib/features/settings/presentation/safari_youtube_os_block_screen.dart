import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
import '../../../core/services/isle_app_log_service.dart';

/// Safari·YouTube 앱 차단 안내 — OS `webContent` 도메인 차단은 Isle WebView까지 막아 사용 안 함.
class SafariYoutubeOsBlockScreen extends StatefulWidget {
  const SafariYoutubeOsBlockScreen({super.key});

  @override
  State<SafariYoutubeOsBlockScreen> createState() => _SafariYoutubeOsBlockScreenState();
}

class _SafariYoutubeOsBlockScreenState extends State<SafariYoutubeOsBlockScreen> {
  bool _busy = false;
  bool? _available;
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!IsleApplePlatform.isScreenTimeHost) return;
    final a = await IosScreenTimeService.isAvailable();
    final auth = await IosScreenTimeService.isAuthorized();
    if (mounted) {
      setState(() {
        _available = a;
        _authorized = auth;
      });
    }
  }

  Future<void> _requestAuth() async {
    setState(() => _busy = true);
    final ok = await IosScreenTimeService.requestAuthorization();
    IsleAppLogService.log('Safari block auth: $ok');
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _clearOsWebFilter() async {
    setState(() => _busy = true);
    await IosScreenTimeService.clearAllWebContentFilters();
    await BrowserYoutubeTrackingPrefs.setOsWebBlockApplied(false);
    IsleAppLogService.log('clearAllWebContentFilters (Isle WebView recovery)');
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OS youtube.com 차단을 해제했어요. Isle WebView를 새로고침하세요.')),
      );
    }
  }

  Future<void> _setupSafariOnlyBlock() async {
    setState(() => _busy = true);
    try {
      await AppInterventionService.ensureAuthorized();
      await IosScreenTimeService.clearAllWebContentFilters();
      await BrowserYoutubeTrackingPrefs.setOsWebBlockApplied(false);
      await IosRulesExportService.exportNow();
      final pick = await AppInterventionService.pickApps();
      if (pick != null) {
        await ExternalAppShieldStore.savePickResult(
          encoded: pick.encoded,
          applicationCount: pick.applicationCount,
          categoryCount: pick.categoryCount,
        );
        await AppInterventionService.applySavedAppShield();
      }
      await IosExtensionStatus.openSafariSettings();
      if (mounted && pick != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'YouTube 앱 ${pick.applicationCount}개 저장·적용. Safari는 설정에서 차단을 확인하세요.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black87;
    final hint = isDark ? Colors.white54 : Colors.black45;

    if (!IsleApplePlatform.isScreenTimeHost) {
      return Scaffold(
        appBar: AppBar(title: Text('시스템 차단', style: IsleText.subtitle())),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('iOS·macOS 전용입니다.', style: IsleText.body()),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        foregroundColor: fg,
        title: Text('Safari·YouTube 앱 차단', style: IsleText.subtitle(color: fg)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: IsleColors.danger.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '예전 「youtube.com OS 차단」은 Isle 앱 안 WebView까지 막습니다 '
                '(「Website Not Allowed」). 이 화면에서는 더 이상 켜지 않습니다.',
                style: IsleText.body(color: fg).copyWith(height: 1.45),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: IsleColors.ocean100,
            child: ListTile(
              leading: const Icon(Icons.track_changes, color: IsleColors.ocean700),
              title: Text('Isle 핵심 설정 (3단계)', style: IsleText.subtitle()),
              subtitle: Text(
                '앱 차단 → Isle로 열기 → 시청 기록',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/browser-youtube-tracking'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '권장: Screen Time으로 YouTube 앱을 선택하고, Safari 설정에서 Isle Content Blocker를 켭니다. '
            '시청·통계는 Isle WebView에서만 잡힙니다.',
            style: IsleText.body(color: fg).copyWith(height: 1.45),
          ),
          const SizedBox(height: 24),
          if (_available == false)
            Text('이 빌드에서 Screen Time 브리지를 쓸 수 없습니다.', style: IsleText.body(color: Colors.red.shade300)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Screen Time 권한', style: IsleText.body(color: fg)),
            subtitle: Text(_authorized ? '허용됨' : '미허용', style: IsleText.caption(color: hint)),
            trailing: _busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FilledButton(
                    onPressed: _authorized ? null : _requestAuth,
                    child: const Text('요청'),
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: IsleSize.minTouchTarget,
            child: FilledButton(
              onPressed: _busy || !_authorized ? null : _setupSafariOnlyBlock,
              child: Text(
                Platform.isMacOS ? 'YouTube 앱 + Safari 확장 설정' : 'YouTube 앱 + Safari 확장 설정',
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: IsleSize.minTouchTarget,
            child: OutlinedButton(
              onPressed: _busy ? null : _clearOsWebFilter,
              child: const Text('Isle WebView 막힘 해제 (OS 도메인 차단)'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: IsleSize.minTouchTarget,
            child: TextButton(
              onPressed: _busy ? null : IosExtensionStatus.openSafariSettings,
              child: Text(
                Platform.isMacOS ? 'Safari 확장 설정 열기' : '설정 → Safari → 확장 프로그램',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
