import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/navigation/youtube_explorer_launch.dart';
import '../../../core/youtube/youtube_safari_launch_guard.dart';
import '../../../core/youtube/youtube_system_auth_service.dart';
import '../../../core/services/isle_external_launch_guard.dart';
import '../../../core/youtube/youtube_webview_factory.dart';
import '../../../shared/widgets/copy_text_row.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import 'widgets/guide_step_illustration.dart';

/// iPhone — 유튜브 로그인만 단계별 (큰 버튼, 복사, Safari 폴백)
class YoutubeLoginGuideScreen extends StatefulWidget {
  const YoutubeLoginGuideScreen({super.key});

  @override
  State<YoutubeLoginGuideScreen> createState() => _YoutubeLoginGuideScreenState();
}

class _YoutubeLoginGuideScreenState extends State<YoutubeLoginGuideScreen> {
  int _step = 0;

  Future<void> _openInAppLogin() async {
    await IsleUserDefaults.setHasSeenYoutubeGuide(true);
    if (!mounted) return;
    YoutubeExplorerLaunch.push(context, autoLogin: true);
  }

  Future<void> _openSystemGoogleLogin() async {
    final r = await YoutubeSystemAuthService.signInForYoutubeApi();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    if (r.success) setState(() => _step = 2);
  }

  Future<void> _openInAppBrowserLogin() async {
    final ok = await YoutubeSystemAuthService.openGoogleLoginInAppBrowser(
      context: context,
    );
    if (!mounted) return;
    if (ok) setState(() => _step = 2);
  }

  Future<void> _openSafariLogin() async {
    final uri = YoutubeWebviewFactory.signInUrl();
    final launched = await IsleExternalLaunchGuard.launch(context, uri);
    if (!mounted) return;
    if (launched) setState(() => _step = 2);
  }

  Future<void> _openIOSSettings() async {
    final uri = Uri.parse('app-settings:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정 → Safari → 고급에서 쿠키 허용을 확인해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final safariBlocked = YoutubeSafariLaunchGuard.isEscapeBlocked;
    return Scaffold(
      appBar: const IsleAppBar(title: '유튜브 로그인'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    _StepDots(count: 3, index: _step),
                    const SizedBox(height: 24),
                    if (_step == 0) ...[
                      const GuideStepIllustration(
                        icon: Icons.login,
                        caption: '앱 안에서 로그인 (추천)',
                        accent: IsleColors.ocean500,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() => _step = 1);
                          _openInAppLogin();
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('1. 로그인 화면 열기'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                    ],
                    if (_step == 1) ...[
                      const GuideStepIllustration(
                        icon: Icons.mark_email_read_outlined,
                        caption: '구글 계정 선택 → 계속',
                        accent: Color(0xFF4285F4),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        YoutubeSystemAuthService.webViewLoginHint,
                        style: IsleText.caption(color: IsleColors.muted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: _openSystemGoogleLogin,
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('시스템 Google 로그인 (추천)'),
                      ),
                      const SizedBox(height: 8),
                      if (safariBlocked) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: IsleColors.ocean100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '지금은 YouTube 차단·한도가 켜져 있어 Safari 로그인을 쓸 수 없어요. '
                            '위 「시스템 Google 로그인」만 사용하세요 (시청 우회 없음).',
                            style: IsleText.caption(color: IsleColors.ocean700),
                          ),
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          onPressed: _openInAppBrowserLogin,
                          icon: const Icon(Icons.public),
                          label: const Text('인앱 Safari로 로그인'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _openSafariLogin,
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('외부 Safari'),
                        ),
                      ],
                    ],
                    if (_step == 2) ...[
                      const GuideStepIllustration(
                        icon: Icons.refresh,
                        caption: '유튜브 화면에서 ↻ 새로고침',
                        accent: IsleColors.ocean500,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => YoutubeExplorerLaunch.push(context),
                        icon: const Icon(Icons.ondemand_video),
                        label: const Text('유튜브로 돌아가기'),
                      ),
                    ],
                    if (Platform.isIOS) ...[
                      const SizedBox(height: 28),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        '로그인이 막히면',
                        style: IsleText.subtitle(),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _openIOSSettings,
                        icon: const Icon(Icons.settings),
                        label: const Text('iPhone 설정 열기'),
                      ),
                      const SizedBox(height: 12),
                      const CopyTextRow(
                        label: '로그인 주소 (필요 시 복사)',
                        value: 'https://accounts.google.com',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_step < 2)
              Padding(
                padding: const EdgeInsets.all(20),
                child: TextButton(
                  onPressed: () => setState(() => _step = (_step + 1).clamp(0, 2)),
                  child: Text('다음 단계 보기 (${_step + 1}/3)'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int count;
  final int index;

  const _StepDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == index;
        return AnimatedContainer(
          duration: 250.ms,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: on ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: on ? IsleColors.ocean500 : IsleColors.ocean100,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
