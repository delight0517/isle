import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/focus/isle_product_focus.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/services/setup_journey_service.dart';
import 'widgets/android_tutorial_diagrams.dart';

/// 안드로이드 — 앱 목적·기능을 그림 위주로 1회 안내 (업데이트마다 뜨지 않음)
class AndroidVisualTutorialScreen extends StatefulWidget {
  const AndroidVisualTutorialScreen({super.key});

  @override
  State<AndroidVisualTutorialScreen> createState() => _AndroidVisualTutorialScreenState();
}

class _AndroidVisualTutorialScreenState extends State<AndroidVisualTutorialScreen> {
  final _pageController = PageController();
  int _index = 0;

  static const _slides = <_AndroidTutorialSlide>[
    _AndroidTutorialSlide(
      stepLabel: '1 / 6',
      title: 'Isle은\n「내 섬」이에요',
      oneLiner: '바깥 알고리즘 대신, 내가 고른 콘텐츠만 모아 둡니다.',
      visual: _SlideVisual.island,
      gradient: [IsleColors.ocean900, IsleColors.ocean500],
    ),
    _AndroidTutorialSlide(
      stepLabel: '2 / 6',
      title: '피드 =\n나만의 신문',
      oneLiner: '구독·관심·시청 기록으로 카드가 채워져요. 싫으면 길게 눌러 숨겨요.',
      visual: _SlideVisual.feed,
      gradient: [Color(0xFF1A3A5C), IsleColors.ocean300],
    ),
    _AndroidTutorialSlide(
      stepLabel: '3 / 6',
      title: '유튜브는\nIsle 안에서',
      oneLiner: 'Chrome·유튜브 앱 말고, 가운데 빨간 버튼에서 보면 시간이 기록돼요.',
      visual: _SlideVisual.youtube,
      gradient: [Color(0xFFB71C1C), Color(0xFFFF0000)],
    ),
    _AndroidTutorialSlide(
      stepLabel: '4 / 6',
      title: '다른 앱\n막기',
      oneLiner: '차단 탭에서 인스타·틱톡 등을 고르고, 접근성·VPN 안내를 따라가요.',
      visual: _SlideVisual.block,
      gradient: [IsleColors.ocean900, IsleColors.ocean700],
      footnote: '안드로이드는 iOS보다 우회가 쉬워요 — 그래도 습관 보조로 씁니다.',
    ),
    _AndroidTutorialSlide(
      stepLabel: '5 / 6',
      title: '아래 3버튼만\n기억하세요',
      oneLiner: '차단 · 유튜브(가운데) · 받기(링크·DM). 길게 누르면 앱 바로 열기.',
      visual: _SlideVisual.nav,
      gradient: [IsleColors.sand900, IsleColors.gold500],
    ),
    _AndroidTutorialSlide(
      stepLabel: '6 / 6',
      title: '링크는\nIsle로 보내기',
      oneLiner: '카톡·Chrome에서 「공유」→ Isle. 다시 보기: 설정 → Isle 쉬운 설명.',
      visual: _SlideVisual.share,
      gradient: [IsleColors.ocean700, IsleColors.ocean300],
      isLast: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await IsleUserDefaults.setHasCompletedAndroidVisualTutorial(true);
    await IsleUserDefaults.setHasCompletedAppTour(true);
    await SetupJourneyService.markStepDone('tour');
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(IsleProductFocus.enabled ? '/home/block' : '/feed');
  }

  void _next() {
    if (_index < _slides.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 360), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_index];
    final isLast = slide.isLast;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: slide.gradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    if (_index > 0)
                      IconButton(
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                        icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        slide.stepLabel,
                        textAlign: TextAlign.center,
                        style: IsleText.caption(color: Colors.white70),
                      ),
                    ),
                    TextButton(
                      onPressed: _finish,
                      child: Text('건너뛰기', style: IsleText.caption(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 24 : 8,
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
                  itemCount: _slides.length,
                  itemBuilder: (_, i) => _SlideBody(slide: _slides[i]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                          isLast ? '알겠어요 · 시작' : '다음',
                          style: IsleText.subtitle(color: IsleColors.ocean900),
                        ),
                      ),
                    ),
                    if (isLast)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '업데이트할 때마다 다시 뜨지 않아요',
                          textAlign: TextAlign.center,
                          style: IsleText.caption(color: Colors.white60),
                        ),
                      ),
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

enum _SlideVisual { island, feed, youtube, block, nav, share }

class _AndroidTutorialSlide {
  const _AndroidTutorialSlide({
    required this.stepLabel,
    required this.title,
    required this.oneLiner,
    required this.visual,
    required this.gradient,
    this.footnote,
    this.isLast = false,
  });

  final String stepLabel;
  final String title;
  final String oneLiner;
  final _SlideVisual visual;
  final List<Color> gradient;
  final String? footnote;
  final bool isLast;
}

class _SlideBody extends StatelessWidget {
  const _SlideBody({required this.slide});

  final _AndroidTutorialSlide slide;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          _buildVisual().animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0),
          const SizedBox(height: 20),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: IsleText.title(color: Colors.white).copyWith(height: 1.12),
          ).animate().fadeIn(delay: 80.ms),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              slide.oneLiner,
              textAlign: TextAlign.center,
              style: IsleText.body(color: Colors.white.withValues(alpha: 0.95)).copyWith(height: 1.45),
            ),
          ).animate().fadeIn(delay: 120.ms),
          if (slide.footnote != null) ...[
            const SizedBox(height: 10),
            Text(
              slide.footnote!,
              textAlign: TextAlign.center,
              style: IsleText.caption(color: IsleColors.gold300),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisual() {
    switch (slide.visual) {
      case _SlideVisual.island:
        return AndroidTutorialDiagrams.islandMetaphor();
      case _SlideVisual.feed:
        return AndroidTutorialDiagrams.feedCardsPreview();
      case _SlideVisual.youtube:
        return AndroidTutorialDiagrams.youtubeFlow();
      case _SlideVisual.block:
        return AndroidTutorialDiagrams.blockAppsFlow();
      case _SlideVisual.nav:
        return AndroidTutorialDiagrams.bottomNavPreview();
      case _SlideVisual.share:
        return AndroidTutorialDiagrams.shareToIsle();
    }
  }
}

/// 피드 첫 진입 시 안드로이드만 1회 표시
Future<void> maybeShowAndroidVisualTutorial(BuildContext context) async {
  if (!Platform.isAndroid) return;
  if (IsleUserDefaults.hasCompletedAndroidVisualTutorial) return;
  if (!context.mounted) return;
  await context.push('/guide/android-visual');
}
