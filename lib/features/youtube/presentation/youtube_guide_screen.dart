import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import 'widgets/guide_step_illustration.dart';

/// iPhone — 30초 만에 익히는 단계별 가이드 (짧은 문장 + 그림)
class YoutubeGuideScreen extends StatefulWidget {
  const YoutubeGuideScreen({super.key});

  @override
  State<YoutubeGuideScreen> createState() => _YoutubeGuideScreenState();
}

class _YoutubeGuideScreenState extends State<YoutubeGuideScreen> {
  final _page = PageController();
  int _step = 0;

  static const _steps = [
    _GuideStep(
      title: '1. 유튜브 열기',
      body: '아래 버튼으로 앱 안 유튜브를 켭니다.',
      icon: Icons.play_circle_filled,
      accent: Color(0xFFFF0000),
    ),
    _GuideStep(
      title: '2. 로그인',
      body: '구글 계정으로 로그인하면 내 구독·추천이 보입니다.',
      icon: Icons.account_circle,
      accent: IsleColors.ocean500,
    ),
    _GuideStep(
      title: '3. 채널 차단',
      body: '보기 싫은 영상 위에서 차단 버튼을 누르세요.',
      icon: Icons.block,
      accent: IsleColors.danger,
    ),
    _GuideStep(
      title: '4. 피드에서도',
      body: '카드를 오른쪽으로 밀면 같은 차단이 됩니다.',
      icon: Icons.swipe_right,
      accent: IsleColors.ocean700,
      showSwipe: true,
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await IsleUserDefaults.setHasSeenYoutubeGuide(true);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final last = _step == _steps.length - 1;
    return Scaffold(
      appBar: const IsleAppBar(title: '사용법'),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _StepDots(count: _steps.length, index: _step),
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: _steps.length,
              onPageChanged: (i) => setState(() => _step = i),
              itemBuilder: (_, i) {
                final s = _steps[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    children: [
                      Text(s.title, style: IsleText.title()),
                      const SizedBox(height: 8),
                      Text(
                        s.body,
                        textAlign: TextAlign.center,
                        style: IsleText.body(color: IsleColors.muted),
                      ),
                      const SizedBox(height: 28),
                      GuideStepIllustration(
                        icon: s.icon,
                        caption: s.title,
                        accent: s.accent,
                        overlays: s.showSwipe ? const [SwipeGuideOverlay()] : null,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!last)
                  FilledButton(
                    onPressed: () => _page.nextPage(
                      duration: 350.ms,
                      curve: Curves.easeOutCubic,
                    ),
                    child: const Text('다음'),
                  )
                else ...[
                  FilledButton(
                    onPressed: () {
                      _finish();
                      context.push('/youtube/login-guide');
                    },
                    child: const Text('로그인 시작'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _finish,
                    child: const Text('나중에'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideStep {
  final String title;
  final String body;
  final IconData icon;
  final Color accent;
  final bool showSwipe;

  const _GuideStep({
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
    this.showSwipe = false,
  });
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
          width: on ? 24 : 8,
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
