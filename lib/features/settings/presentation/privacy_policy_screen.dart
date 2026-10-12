import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_legal_info.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// 개인정보처리방침 — 앱 내 전문 + 웹 URL.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <({String title, String body})>[
      (
        title: '1. 개요',
        body:
            'Isle(이하 「앱」)은 사용자가 선택한 콘텐츠와 시간 관리 규칙을 기기에서 관리하는 도구입니다.',
      ),
      (
        title: '2. 수집·저장하는 정보',
        body:
            '• 기기 로컬: 피드·차단 목록·스케줄·시청 통계·설정\n'
            '• 선택 로그인 시: 이메일·이름·프로필(Supabase)\n'
            '• WebView 로그인 세션 쿠키([REDACTED]'
            '• 사용자가 입력한 AI API 키(기기 암호화 저장)\n'
            '• Firebase Analytics(Android)',
      ),
      (
        title: '3. 권한',
        body:
            '${AppLegalInfo.accessibilityPermissionNotice}\n'
            '${AppLegalInfo.vpnPermissionNotice}\n'
            '${AppLegalInfo.usageStatsPermissionNotice}',
      ),
      (
        title: '4. 백업',
        body:
            'Android에서 Google 백업이 켜져 있으면 앱 데이터 일부가 Google 계정 백업에 포함될 수 있습니다.',
      ),
      (
        title: '5. 삭제',
        body:
            '설정 → 계정·데이터 삭제에서 세션·로컬·계정(로그인 시) 삭제를 요청할 수 있습니다. '
            '이메일: ${AppLegalInfo.supportEmail}',
      ),
    ];

    return Scaffold(
      appBar: const IsleAppBar(title: '개인정보처리방침'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton.icon(
            onPressed: () => launchUrl(
              AppLegalInfo.privacyPolicyUri,
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('웹에서 보기'),
          ),
          const SizedBox(height: 12),
          Text('문의: ${AppLegalInfo.supportEmail}', style: IsleText.caption(color: IsleColors.muted)),
          const SizedBox(height: 16),
          ...sections.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: IsleText.subtitle()),
                  const SizedBox(height: 6),
                  Text(s.body, style: IsleText.body(color: IsleColors.muted).copyWith(height: 1.45)),
                ],
              ),
            ),
          ),
          Text(AppLegalInfo.thirdPartyDisclaimer, style: IsleText.caption(color: IsleColors.muted)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.push('/settings/account-deletion'),
            child: const Text('계정·데이터 삭제'),
          ),
        ],
      ),
    );
  }
}
