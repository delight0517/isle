import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/social/instagram_auth_service.dart';
import '../../../../core/social/instagram_web_config.dart';

/// 받기·소통 ① — Instagram DM (답장 채널, 피드 스크롤 아님)
class ShareInstagramDmSection extends StatefulWidget {
  const ShareInstagramDmSection({super.key});

  @override
  State<ShareInstagramDmSection> createState() => _ShareInstagramDmSectionState();
}

class _ShareInstagramDmSectionState extends State<ShareInstagramDmSection> {
  bool _loggedIn = IsleUserDefaults.instagramLoginRemembered;

  void _openDm() {
    context.push(InstagramWebConfig.dmBrowserRoute(dmOnly: true));
  }

  void _openInboxNew() {
    context.push(
      '/explore/browser?site=instagram&dm=1&url=${Uri.encodeComponent('${InstagramWebConfig.dmInboxUrl}?compose=1')}',
    );
  }

  Future<void> _safariLogin() async {
    await InstagramAuthService.openLoginInSafari();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Safari에서 로그인 후 「DM 열기」를 눌러 주세요'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _markLoggedIn() async {
    await IsleUserDefaults.setInstagramLoginRemembered(true);
    if (!mounted) return;
    setState(() => _loggedIn = true);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFFFFF5F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFE1306C).withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.forum_outlined, color: Color(0xFFE1306C), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Instagram DM', style: IsleText.subtitle()),
                      Text(
                        _loggedIn
                            ? 'DM·상대 프로필·게시물·스토리 — 홈 피드·탐색은 막혀 있어요'
                            : '로그인 후 DM만 열어요 (SNS 피드 아님)',
                        style: IsleText.caption(color: IsleColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: IsleSize.minTouchTarget,
              child: FilledButton.icon(
                onPressed: _openDm,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE1306C),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.inbox_outlined),
                label: const Text('DM 받은편지함 열기'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: IsleSize.minTouchTarget,
              child: OutlinedButton.icon(
                onPressed: _openInboxNew,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('새 메시지 보내기'),
              ),
            ),
            const SizedBox(height: 12),
            if (!_loggedIn) ...[
              OutlinedButton.icon(
                onPressed: _safariLogin,
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Safari로 로그인 (권장)'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _markLoggedIn,
                child: const Text('로그인 완료했어요'),
              ),
            ] else
              TextButton.icon(
                onPressed: () async {
                  await IsleUserDefaults.setInstagramLoginRemembered(false);
                  if (!mounted) return;
                  setState(() => _loggedIn = false);
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('로그아웃 표시로 바꾸기'),
              ),
            const SizedBox(height: 4),
            Text(
              '카카오톡 등에서 받은 인스타 링크는 「다른 앱에서 링크 보내기」로 열 수 있어요.',
              style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
