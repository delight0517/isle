import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/focus/isle_product_focus.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/services/setup_journey_service.dart';

/// 피드 상단 — 샘플이 아닌 「내 콘텐츠」로 채우도록 동기 부여
class FeedSetupJourneyBanner extends StatefulWidget {
  const FeedSetupJourneyBanner({
    super.key,
    this.onDismissDemo,
    this.compactWhenEmptyFeed = false,
  });

  final VoidCallback? onDismissDemo;
  final bool compactWhenEmptyFeed;

  @override
  State<FeedSetupJourneyBanner> createState() => _FeedSetupJourneyBannerState();
}

class _FeedSetupJourneyBannerState extends State<FeedSetupJourneyBanner> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = !widget.compactWhenEmptyFeed &&
        SetupJourneyService.completedCount < 2;
  }

  @override
  Widget build(BuildContext context) {
    if (IsleProductFocus.hideSecondaryUi ||
        IsleUserDefaults.hideFeedSetupBanner ||
        !SetupJourneyService.shouldHighlightSetup) {
      return const SizedBox.shrink();
    }

    final progress = SetupJourneyService.progress;
    final done = SetupJourneyService.completedCount;
    final total = SetupJourneyService.totalSteps;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Material(
          elevation: 0,
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [IsleColors.ocean900, IsleColors.ocean700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: IsleColors.ocean500.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: IsleColors.gold500.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.flag_rounded, color: IsleColors.gold500, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '지금은 샘플 피드예요',
                                style: IsleText.subtitle(color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '내 콘텐츠를 연결하면 진짜 피드가 채워져요 · $done/$total',
                                style: IsleText.caption(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                          onPressed: () async {
                            await IsleUserDefaults.setHideFeedSetupBanner(true);
                            widget.onDismissDemo?.call();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('셋업 배너를 숨겼어요')),
                              );
                            }
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.05, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(IsleColors.gold500),
                    ),
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(height: 12),
                  _SetupStepRow(
                    done: SetupJourneyService.stepDone('tour'),
                    icon: Icons.explore_outlined,
                    title: '앱 둘러보기',
                    subtitle: 'ISLE이 뭔지 1분 안에',
                    onTap: () => context.push('/app-tour'),
                  ),
                  _SetupStepRow(
                    done: SetupJourneyService.stepDone('interests') ||
                        IsleUserDefaults.onboardingInterestTags.isNotEmpty,
                    icon: Icons.favorite_border,
                    title: '관심 주제 고르기',
                    subtitle: '피드 순위에 반영',
                    onTap: () {
                      SetupJourneyService.markStepDone('interests');
                      context.push('/settings/interests');
                    },
                  ),
                  _SetupStepRow(
                    done: SetupJourneyService.stepDone('import_content'),
                    icon: Icons.library_add_outlined,
                    title: '콘텐츠 가져오기',
                    subtitle: '유튜브·브런치·나중에 볼',
                    highlight: true,
                    onTap: () => context.push('/library/sources'),
                  ),
                  _SetupStepRow(
                    done: SetupJourneyService.stepDone('youtube_focus'),
                    icon: Icons.shield_outlined,
                    title: '유튜브 집중 모드',
                    subtitle: '차단·한도 체험',
                    onTap: () {
                      SetupJourneyService.markStepDone('youtube_focus');
                      context.push('/youtube');
                    },
                  ),
                  _SetupStepRow(
                    done: SetupJourneyService.stepDone('first_archive'),
                    icon: Icons.archive_outlined,
                    title: '첫 콘텐츠 아카이브',
                    subtitle: '피드 스와이프 → 내 섬',
                    onTap: () => context.go('/island'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () async {
                            await IsleUserDefaults.setHideDemoFeedCards(true);
                            widget.onDismissDemo?.call();
                          },
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          child: Text('샘플 숨기기', style: IsleText.caption(color: Colors.white)),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () => context.push('/library/sources'),
                          style: FilledButton.styleFrom(
                            backgroundColor: IsleColors.gold500,
                            foregroundColor: IsleColors.ocean900,
                          ),
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('지금 채우기'),
                        ),
                      ],
                    ),
                  ),
                ] else
                  const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupStepRow extends StatelessWidget {
  const _SetupStepRow({
    required this.done,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final bool done;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: highlight ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      done ? IsleColors.success.withValues(alpha: 0.35) : Colors.white24,
                  child: Icon(
                    done ? Icons.check : icon,
                    size: 20,
                    color: done ? Colors.white : Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: IsleText.body(color: Colors.white).copyWith(
                          fontWeight: done ? FontWeight.w500 : FontWeight.w600,
                        ),
                      ),
                      Text(subtitle, style: IsleText.caption(color: Colors.white70)),
                    ],
                  ),
                ),
                Icon(
                  done ? Icons.check_circle : Icons.chevron_right,
                  color: done ? IsleColors.success : Colors.white70,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
