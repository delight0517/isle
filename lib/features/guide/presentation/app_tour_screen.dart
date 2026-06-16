import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/focus/isle_product_focus.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/intervention/browser_youtube_tracking_prefs.dart';
import '../../../core/platform/platform_block_intent.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/services/setup_journey_service.dart';
import 'widgets/youtube_isle_core_guide.dart';

/// 첫 실행 — Isle 핵심(브라우저 유튜브 차단 → Isle 시청)을 최우선 안내
class AppTourScreen extends StatefulWidget {
  const AppTourScreen({super.key});

  @override
  State<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends State<AppTourScreen> {
  final _pageController = PageController();
  int _index = 0;

  static List<_TourPage> get _pages => [
        _TourPage(
          icon: Icons.play_circle_filled,
          gradient: [const Color(0xFFB71C1C), const Color(0xFFFF0000)],
          title: '유튜브는\nIsle에서만',
          body:
              '대부분 Isle를 까는 이유예요.\n'
              '${PlatformBlockCopy.externalBrowserName}·유튜브 앱에서 youtube.com을 막고, '
              '링크는 Isle WebView로 열면 시청 시간·한도·스케줄이 한곳에 모입니다.',
          hint: '밖에서 본 유튜브는 통계에 안 잡혀요',
          showFlow: true,
        ),
        _TourPage(
          icon: Icons.public_off,
          gradient: [IsleColors.ocean900, IsleColors.ocean500],
          title: '밖의 브라우저는\n차단',
          body:
              'YouTube 앱·Safari는 Screen Time 앱 선택 + Safari 차단 확장으로 막고, '
              '시청은 Isle WebView에서만 하세요. (OS youtube.com 전역 차단은 Isle까지 막습니다.)',
          hint: '설정 마법사 1단계 — YouTube 앱 + Safari',
        ),
        _TourPage(
          icon: Icons.link_rounded,
          gradient: [const Color(0xFF1A3A5C), IsleColors.ocean300],
          title: '링크는\n항상 Isle로',
          body:
              'KakaoTalk·Safari에서 공유 → Isle 선택.\n'
              'YouTube 링크는 자동으로 Isle 유튜브 탭으로 열리고, 클립보드 URL도 제안해요.',
          hint: '공유 시트에 Isle이 보이면 성공',
        ),
        _TourPage(
          icon: Icons.dynamic_feed_rounded,
          gradient: [Color(0xFF1A3A5C), IsleColors.ocean300],
          title: '그다음 —\n나만의 피드',
          body:
              '구독·관심사·시청 기록으로 피드가 채워져요. '
              '지금 보이는 카드는 예시이고, 가져온 콘텐츠로 바뀝니다.',
          hint: '「내 콘텐츠」에서 가져오기',
        ),
        _TourPage(
          icon: Icons.rocket_launch_rounded,
          gradient: [IsleColors.sand900, IsleColors.gold500],
          title: '3분이면\n끝나요',
          body: '아래 버튼으로 설정 마법사를 열면 차단 → Isle 열기 → 시간 기록까지 한 번에 안내돼요.',
          hint: '건너뛰어도 피드·차단 탭에서 다시 열 수 있어요',
          isLast: true,
        ),
      ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish({bool openYoutubeSetup = false}) async {
    await IsleUserDefaults.setHasCompletedAppTour(true);
    await SetupJourneyService.markStepDone('tour');
    if (!mounted) return;
    final home = IsleProductFocus.enabled ? '/home/block' : '/feed';
    context.go(home);
    if (openYoutubeSetup && !BrowserYoutubeTrackingPrefs.hasCompletedEncouragementFlow) {
      await BrowserYoutubeTrackingPrefs.setPostTourSetupPrompted(true);
      if (mounted) {
        await context.push(PlatformBlockCopy.settingsRoute);
      }
    }
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish(openYoutubeSetup: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_index];
    final isLast = _index == _pages.length - 1;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: page.gradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    if (_index > 0)
                      IconButton(
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOut,
                        ),
                        icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      )
                    else
                      const SizedBox(width: 48),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _finish(),
                      child: Text('건너뛰기', style: IsleText.caption(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? IsleColors.gold500 : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemCount: _pages.length,
                  itemBuilder: (_, i) => _TourSlide(page: _pages[i]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: IsleSize.minTouchTarget,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: IsleColors.ocean900,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          isLast ? '유튜브 설정 시작 (3단계)' : '다음',
                          style: IsleText.subtitle(color: IsleColors.ocean900),
                        ),
                      ),
                    ),
                    if (isLast) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => _finish(),
                        child: Text('나중에 · 피드로 바로 가기', style: IsleText.caption(color: Colors.white70)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TourPage {
  const _TourPage({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.body,
    required this.hint,
    this.showFlow = false,
    this.isLast = false,
  });

  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String body;
  final String hint;
  final bool showFlow;
  final bool isLast;
}

class _TourSlide extends StatelessWidget {
  const _TourSlide({required this.page});

  final _TourPage page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (page.showFlow) ...[
            const Material(
              color: Colors.transparent,
              child: YoutubeIsleCoreGuide(compact: true),
            ),
            const SizedBox(height: 20),
          ] else ...[
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: Icon(page.icon, size: 48, color: Colors.white),
            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack).fadeIn(),
            const SizedBox(height: 28),
          ],
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: IsleText.title(color: Colors.white).copyWith(height: 1.15),
          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.08),
          const SizedBox(height: 14),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: IsleText.body(color: Colors.white.withValues(alpha: 0.92)).copyWith(height: 1.45),
          ).animate().fadeIn(delay: 140.ms),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: IsleColors.gold500.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: IsleColors.gold300, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(page.hint, style: IsleText.caption(color: IsleColors.gold300)),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }
}
