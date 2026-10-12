import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/platform/platform_block_intent.dart';
import '../../../core/platform/platform_feature_gate.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// 기본 브라우저 등록 안내 — iOS(entitlement) · Android(기본 앱)
class DefaultBrowserOnboardingScreen extends StatefulWidget {
  const DefaultBrowserOnboardingScreen({super.key});

  @override
  State<DefaultBrowserOnboardingScreen> createState() =>
      _DefaultBrowserOnboardingScreenState();
}

class _DefaultBrowserOnboardingScreenState
    extends State<DefaultBrowserOnboardingScreen> {
  late bool _hideHint;

  @override
  void initState() {
    super.initState();
    _hideHint = IsleUserDefaults.hideDefaultBrowserOnboardingHint;
  }

  Future<void> _openAppSettings() async {
    final uri = Uri.parse('app-settings:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정 앱에서 Isle를 기본 브라우저로 선택해 주세요')),
      );
    }
  }

  Future<void> _copyEntitlementUrl() async {
    const url = 'https://developer.apple.com/contact/request/default-browser';
    await Clipboard.setData(const ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apple 신청 URL 복사됨')),
      );
    }
  }

  String get _introBody {
    if (Platform.isAndroid) {
      return 'Android에서 기본 브라우저로 등록되면, QR·다른 앱의 http 링크가 '
          '${PlatformBlockCopy.externalBrowserName} 대신 Isle 안전 브라우저로 열려요.\n\n'
          '※ 설정 → 앱 → 기본 앱에서 직접 선택해야 해요.';
    }
    return 'iOS에서 기본 브라우저로 등록되면, 카메라 QR·다른 앱의 http 링크가 '
        'Safari 대신 Isle 안전 브라우저로 열려요.\n\n'
        '※ Apple entitlement 승인 + 사용자가 설정에서 직접 선택해야 해요.';
  }

  String get _stepsTitle {
    if (Platform.isAndroid) return '설정 방법 (Android)';
    return '설정 방법 (iOS)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IsleAppBar(title: '기본 브라우저로 Isle'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, IsleSize.scrollBottomPadding(context)),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IsleColors.ocean100,
              borderRadius: BorderRadius.circular(IsleSize.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('QR·웹 링크를 Isle로', style: IsleText.subtitle()),
                const SizedBox(height: 8),
                Text(
                  _introBody,
                  style: IsleText.body(color: IsleColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(_stepsTitle, style: IsleText.subtitle()),
          const SizedBox(height: 8),
          if (Platform.isAndroid) ...[
            const _Step(n: '1', text: '설정 → 앱 → 기본 앱 → 브라우저 앱'),
            const _Step(n: '2', text: '「Isle」선택'),
            const _Step(n: '3', text: 'QR·링크가 Isle로 열리는지 확인'),
          ] else ...[
            const _Step(n: '1', text: '설정 → 앱 → 기본 앱 → 브라우저'),
            const _Step(n: '2', text: '「Isle」선택'),
            const _Step(n: '3', text: 'QR·링크가 Isle로 열리는지 확인'),
          ],
          const SizedBox(height: 20),
          if (Platform.isIOS || Platform.isAndroid)
            FilledButton.icon(
              onPressed: _openAppSettings,
              icon: const Icon(Icons.settings),
              label: const Text('설정 열기'),
            ),
          if (Platform.isIOS || Platform.isAndroid) const SizedBox(height: 10),
          if (PlatformFeatureGate.appleDefaultBrowserEntitlementGuide) ...[
            OutlinedButton.icon(
              onPressed: () => context.push('/settings/deploy-guide'),
              icon: const Icon(Icons.description_outlined),
              label: const Text('배포·entitlement 가이드'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _copyEntitlementUrl,
              icon: const Icon(Icons.copy),
              label: const Text('Apple 기본 브라우저 신청 URL 복사'),
            ),
            const SizedBox(height: 20),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('안내 다시 보지 않기'),
            subtitle: const Text('차단 탭 힌트에서 숨김'),
            value: _hideHint,
            onChanged: (v) async {
              await IsleUserDefaults.setHideDefaultBrowserOnboardingHint(v);
              if (mounted) setState(() => _hideHint = v);
            },
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: IsleColors.ocean700,
            child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: IsleText.body())),
        ],
      ),
    );
  }
}
