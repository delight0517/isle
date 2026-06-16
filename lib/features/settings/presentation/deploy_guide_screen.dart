import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_release_info.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/copy_text_row.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// 멀티플랫폼 빌드·Web Deploy 안내 (TODO §2 배포)
class DeployGuideScreen extends StatelessWidget {
  const DeployGuideScreen({super.key});

  static const _projectRoot =
      '/Users/rogan/Desktop/appDev/library-content-sns/11-1Isle';

  @override
  Widget build(BuildContext context) {
    final ver = AppReleaseInfo.pubspecVersion;

    return Scaffold(
      appBar: const IsleAppBar(title: '배포 가이드'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, IsleSize.scrollBottomPadding(context)),
        children: [
          Text(
            '플랫폼별 빌드는 해당 OS에서만 실행하세요. 업데이트 시 applicationId·번들 ID를 바꾸지 않으면 데이터가 유지됩니다.',
            style: IsleText.body(color: IsleColors.muted),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Android APK',
            icon: Icons.android,
            lines: [
              '산출물: Isle_v${ver}_android.apk',
              'applicationId: com.isle.app (full flavor)',
            ],
            command:
                'cd "$_projectRoot/isle" && flutter build apk --release --flavor full',
          ),
          _Section(
            title: 'macOS DMG',
            icon: Icons.laptop_mac,
            lines: [
              'Xcode → macOS Runner → Signing (팀 V3J8MR637G)',
              'Family Controls·App Group capability 필요',
            ],
            command: 'cd "$_projectRoot" && ./deploy/scripts/release_mac.sh',
          ),
          _Section(
            title: 'iOS 실기기 (dev)',
            icon: Icons.phone_iphone,
            lines: [
              '자동: web-browser 제거 · Team V3J8MR637G · Automatic signing',
              '【1】 Xcode → Accounts → Apple ID 추가 (필수)',
              '【2】 developer.apple.com → App Groups group.com.isle.app',
              '【3】 web-browser 승인 후 entitlements.with-web-browser 복구',
            ],
            command:
                'cd "$_projectRoot" && ./deploy/scripts/ios_dev_signing_fix.sh',
          ),
          _Section(
            title: 'Windows Setup',
            icon: Icons.desktop_windows,
            lines: [
              'Windows PC에서만 빌드 (Mac/Linux 크로스 빌드 금지)',
              'Inno Setup → Isle_Setup_v${ver}_windows.exe',
            ],
            command: 'cd isle && flutter build windows --release',
          ),
          _Section(
            title: 'iOS TestFlight',
            icon: Icons.flight_takeoff,
            lines: [
              'TestFlight entitlements (web-browser 제외)',
              'App Group·Family Controls — Developer Portal 필수',
            ],
            command:
                'cd "$_projectRoot" && ./deploy/scripts/build_ipa_testflight.sh',
          ),
          _Section(
            title: 'Web Deploy (APK + Vercel)',
            icon: Icons.public,
            lines: [
              '① release_android_web.sh — APK·apps.json·Desktop 복사',
              '② deploy_vercel.sh — vercel --prod',
            ],
            command:
                'cd "$_projectRoot" && ./deploy/scripts/release_android_web.sh && ./deploy/scripts/deploy_vercel.sh',
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('웹 배포 폴더'),
              subtitle: Text('$_projectRoot/deploy/web_deploy'),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => Clipboard.setData(
                  const ClipboardData(text: '$_projectRoot/deploy/web_deploy'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.lines,
    required this.command,
  });

  final String title;
  final IconData icon;
  final List<String> lines;
  final String command;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: IsleColors.ocean700),
                const SizedBox(width: 10),
                Text(title, style: IsleText.subtitle()),
              ],
            ),
            const SizedBox(height: 8),
            ...lines.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l, style: IsleText.caption(color: IsleColors.muted)),
              ),
            ),
            const SizedBox(height: 10),
            CopyTextRow(label: '명령', value: command),
          ],
        ),
      ),
    );
  }
}
