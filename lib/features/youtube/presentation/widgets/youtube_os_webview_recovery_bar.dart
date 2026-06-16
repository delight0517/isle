import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/intervention/browser_youtube_tracking_prefs.dart';
import '../../../../core/platform/isle_apple_platform.dart';
import '../../../../core/platform/ios_extension_status.dart';
import '../../../../core/platform/ios_screen_time_service.dart';
import '../../../../core/platform/ios_rules_export_service.dart';
import '../../../../core/services/isle_app_log_service.dart';
import '../../../../core/services/isle_user_defaults.dart';

/// iOS `webContent.blockedByFilter`가 Isle WKWebView까지 막을 때만 표시 (항상 띄우지 않음).
class YoutubeOsWebviewRecoveryBar extends StatefulWidget {
  const YoutubeOsWebviewRecoveryBar({super.key, this.onRecovered});

  final VoidCallback? onRecovered;

  @override
  State<YoutubeOsWebviewRecoveryBar> createState() => _YoutubeOsWebviewRecoveryBarState();
}

class _YoutubeOsWebviewRecoveryBarState extends State<YoutubeOsWebviewRecoveryBar> {
  bool _busy = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _loadVisibility();
  }

  Future<void> _loadVisibility() async {
    if (!IsleApplePlatform.isScreenTimeHost) return;
    if (IsleUserDefaults.youtubeOsRecoveryBarDismissed) return;
    if (!BrowserYoutubeTrackingPrefs.osWebBlockApplied) return;
    if (mounted) setState(() => _visible = true);
  }

  Future<void> _recover() async {
    if (!IsleApplePlatform.isScreenTimeHost || _busy) return;
    setState(() => _busy = true);
    try {
      await IosScreenTimeService.clearAllWebContentFilters();
      await BrowserYoutubeTrackingPrefs.setOsWebBlockApplied(false);
      await IsleUserDefaults.setYoutubeOsRecoveryBarDismissed(true);
      await IosRulesExportService.exportNow();
      IsleAppLogService.log('YouTube OS web filter cleared for Isle WebView');
      widget.onRecovered?.call();
      if (mounted) {
        setState(() => _visible = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '기기 전역 youtube.com 차단을 해제했어요. 페이지를 새로고침하세요. '
              'Safari만 막으려면 설정 → Isle 핵심 설정을 따르세요.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismiss() async {
    await IsleUserDefaults.setYoutubeOsRecoveryBarDismissed(true);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Material(
      color: IsleColors.ocean900.withValues(alpha: 0.92),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.lock_open_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '「Website Not Allowed」? 예전 OS 차단이 Isle까지 막은 상태예요.',
                  style: IsleText.caption(color: Colors.white70).copyWith(height: 1.3),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _recover,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(IsleSize.minTouchTarget, IsleSize.minTouchTarget),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('해제'),
              ),
              IconButton(
                tooltip: 'Safari 확장 설정',
                onPressed: IosExtensionStatus.openSafariSettings,
                icon: const Icon(Icons.settings_outlined, color: Colors.white54, size: 20),
              ),
              IconButton(
                tooltip: '닫기',
                onPressed: _dismiss,
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
