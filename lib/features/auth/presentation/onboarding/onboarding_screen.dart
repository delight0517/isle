import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/focus/isle_product_focus.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/services/pending_share_navigation.dart';
import '../../../../core/services/setup_journey_service.dart';
import '../../../../core/constants/app_typography.dart';
import 'step_interests.dart';
import 'step_island_setup.dart';
import 'step_subscribe.dart';
import 'step_system_time_lock.dart';
import 'step_welcome.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;
  final _interestsKey = GlobalKey<StepInterestsState>();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await IsleUserDefaults.setHasCompletedAppTour(true);
    await SetupJourneyService.markStepDone('tour');
    final tags = _interestsKey.currentState?.selectedTags ?? [];
    if (tags.isNotEmpty) {
      await IsleUserDefaults.setOnboardingInterestTags(tags);
      await SetupJourneyService.markStepDone('interests');
    }
    if (!mounted) return;
    context.go(IsleProductFocus.enabled ? '/home/block' : '/feed');
    PendingShareNavigation.tryNavigateFromStoredPending();
  }

  void _next() {
    if (_index < 4) {
      _pageController.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IsleColors.sand100,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i <= _index ? IsleColors.ocean500 : IsleColors.ocean100,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _finish,
            child: Text('건너뛰기', style: IsleText.caption(color: IsleColors.muted)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                const StepWelcome(),
                const StepSystemTimeLock(),
                StepInterests(key: _interestsKey),
                const StepSubscribe(),
                const StepIslandSetup(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(backgroundColor: IsleColors.ocean500),
                child: Text(
                  _index < 4 ? '다음' : '시작하기',
                  style: IsleText.subtitle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
