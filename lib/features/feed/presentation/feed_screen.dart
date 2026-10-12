import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/insight/knowledge_visual_system.dart';
import '../../../core/library/interest_pipeline_service.dart';
import '../../../core/library/personal_library_store.dart';
import '../../../core/services/isle_debug_log_service.dart';
import '../../../core/focus/isle_product_focus.dart';
import '../../../core/services/isle_survival_backup_service.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../shared/widgets/survival_backup_guide_sheet.dart';
import '../../ai/presentation/widgets/ai_activity_strip.dart';
import '../../ai/presentation/widgets/ai_feed_transparency_strip.dart';
import '../../guide/presentation/widgets/feed_setup_journey_banner.dart';
import '../data/feed_repository.dart';
import '../data/models/feed_item.dart';
import '../providers/feed_provider.dart';
import '../providers/feed_search_provider.dart';
import 'widgets/feed_app_bar_actions.dart';
import 'widgets/feed_card.dart';
import 'widgets/feed_card_skeleton.dart';
import '../../insight/presentation/widgets/insight_typography_card.dart';
import 'widgets/interest_filter_chips.dart';
import '../../../shared/widgets/isle_sheet.dart';
import 'widgets/add_feed_subscription_sheet.dart';
import 'widgets/feed_refresh_status_strip.dart';
import 'widgets/feed_swipe_coach_overlay.dart';
import 'widgets/browser_youtube_tracking_banner.dart';
import '../../guide/presentation/widgets/youtube_setup_home_card.dart';
import 'widgets/isle_focus_trio_banner.dart';
import 'widgets/youtube_hub_banner.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  static bool _pipelineBootstrapped = false;
  int _setupBannerKey = 0;
  bool _typographyFeed = IsleUserDefaults.insightTypographyFeed;

  @override
  void initState() {
    super.initState();
    if (!_pipelineBootstrapped) {
      _pipelineBootstrapped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runInterestPipeline());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowOnboarding();
      _maybeShowRestoreNotice();
    });
  }

  void _maybeShowRestoreNotice() {
    final kind = IsleUserDefaults.takePendingRestoreNotice();
    if (kind == null || !mounted) return;
    final msg = switch (kind) {
      'folder' => '백업 폴더에서 데이터를 복원했어요',
      'keychain' => '이전 설정을 Keychain 백업에서 복원했어요 (재설치 감지)',
      _ => '자동 저장본에서 데이터를 복원했어요',
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  Future<void> _maybeShowOnboarding() async {
    if (!mounted) return;
    _showCrashBannerIfNeeded();
    if (!Platform.isAndroid && !IsleUserDefaults.hasCompletedAppTour) {
      await context.push('/app-tour');
    }
    if (!mounted) return;
    await _maybeShowSurvivalBackupGuide();
    if (!mounted) return;
    if (!IsleUserDefaults.hasSeenFeedSwipeCoach) {
      await FeedSwipeCoachOverlay.showIfNeeded(context);
    }
  }

  Future<void> _maybeShowSurvivalBackupGuide() async {
    if (!Platform.isIOS) return;
    if (IsleUserDefaults.survivalBackupGuideDismissed) return;
    if (!IsleSurvivalBackupService.needsIcloudFolderPrompt()) return;
    await showSurvivalBackupGuideSheet(context);
  }

  void _showCrashBannerIfNeeded() {
    final crashes = IsleDebugLogService.crashHistory;
    if (crashes.isEmpty) return;
    final latest = crashes.first;
    if (IsleUserDefaults.lastAcknowledgedCrashId == latest.id) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final open = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('이전 실행 문제', style: IsleText.subtitle()),
          content: Text(
            '앱이 비정상 종료되었을 수 있어요.\n\n${latest.message}',
            style: IsleText.body(color: IsleColors.muted),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('닫기')),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('로그 보기'),
            ),
          ],
        ),
      );
      await IsleUserDefaults.setLastAcknowledgedCrashId(latest.id);
      if (open == true && mounted) context.push('/settings/debugger');
    });
  }

  Future<void> _runInterestPipeline() async {
    final n = await InterestPipelineService.processDueItems();
    if (!mounted || n == 0) return;
    await ref.read(personalLibraryProvider.notifier).reload();
    ref.invalidate(feedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(feedProvider);
    final hasSearch = ref.watch(feedSearchQueryProvider).isNotEmpty;
    final feedEmpty = feedAsync.maybeWhen(
      data: (items) => _itemsForDisplay(items).isEmpty && !hasSearch,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: RefreshIndicator(
        onRefresh: () => ref.read(feedProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: Colors.white,
            foregroundColor: IsleColors.ocean900,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            iconTheme: const IconThemeData(color: IsleColors.ocean900, size: 24),
            actionsIconTheme: const IconThemeData(color: IsleColors.ocean900, size: 24),
            title: Row(children: [
              const Icon(Icons.cabin, color: IsleColors.ocean500, size: 24),
              const SizedBox(width: 8),
              Text('ISLE', style: IsleText.subtitle(color: IsleColors.ocean900)),
            ]),
            actions: [
              FeedAppBarActions(onSearch: () => _openSearchSheet(context, ref)),
            ],
          ),
          SliverToBoxAdapter(child: _KnowledgeFeedBanner(typography: _typographyFeed, onChanged: (v) async {
            await IsleUserDefaults.setInsightTypographyFeed(v);
            setState(() => _typographyFeed = v);
          })),
          const SliverToBoxAdapter(child: _BlockChatHomeCard()),
          if (!feedEmpty) ...[
            const IsleFocusTrioBanner(),
            const SliverToBoxAdapter(child: YoutubeSetupHomeCard()),
            const BrowserYoutubeTrackingBanner(),
            if (!IsleProductFocus.hideSecondaryUi) const YoutubeHubBanner(),
            const FeedRefreshStatusStrip(),
            if (!IsleProductFocus.hideSecondaryUi) ...[
              const SliverToBoxAdapter(child: AiActivityStrip()),
              const SliverToBoxAdapter(child: AiFeedTransparencyStrip()),
            ],
          ] else ...[
            const IsleFocusTrioBanner(),
            const SliverToBoxAdapter(child: YoutubeSetupHomeCard()),
            const FeedRefreshStatusStrip(),
          ],
          if (!IsleProductFocus.hideSecondaryUi)
            FeedSetupJourneyBanner(
            key: ValueKey(_setupBannerKey),
            compactWhenEmptyFeed: feedEmpty,
              onDismissDemo: () {
                setState(() => _setupBannerKey++);
                ref.invalidate(feedProvider);
              },
            ),
          const SliverPersistentHeader(
            pinned: true,
            delegate: _FilterHeaderDelegate(),
          ),
          feedAsync.when(
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => const FeedCardSkeleton(),
                childCount: 5,
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('피드를 불러올 수 없습니다', style: IsleText.body())),
            ),
            data: (items) {
              final display = _itemsForDisplay(items);
              if (display.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FeedEmptyState(hasSearch: hasSearch),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final item = display[i];
                    final card = (_typographyFeed && item.sourceType == 'insight')
                        ? InsightTypographyCard(feedItem: item)
                        : FeedCard(item: item, isDemo: false);
                    return card
                        .animate(delay: (i * 40).ms)
                        .fadeIn()
                        .slideY(begin: 0.08);
                  },
                  childCount: display.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
        ),
      ),
    );
  }

  /// 가짜 샘플( example URL )은 표시하지 않음
  List<FeedItem> _itemsForDisplay(List<FeedItem> items) {
    return items.where((i) => !FeedRepository.isDemoItem(i)).toList();
  }
}

void _openSearchSheet(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController(text: ref.read(feedSearchQueryProvider));
  showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('제목 검색', style: IsleText.subtitle()),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '키워드 입력',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  ref.read(feedSearchQueryProvider.notifier).state = '';
                  Navigator.pop(ctx);
                },
                child: const Text('초기화'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  ref.read(feedSearchQueryProvider.notifier).state = controller.text.trim();
                  Navigator.pop(ctx);
                },
                child: const Text('적용'),
              ),
            ],
          ),
        ],
      ),
    ),
  ).whenComplete(controller.dispose);
}

class _FeedEmptyState extends ConsumerWidget {
  const _FeedEmptyState({required this.hasSearch});

  final bool hasSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hasSearch) {
      return Center(child: Text('검색 결과가 없습니다', style: IsleText.body(color: IsleColors.muted)));
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cabin_outlined, size: 48, color: IsleColors.ocean500),
          const SizedBox(height: 16),
          Text('피드를 채워 보세요', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          Text(
            '하루 1–2번 읽을 글·영상만 모아 둡니다.\n'
            '구독한 채널·블로그에서 3시간마다 자동으로 가져와요.',
            textAlign: TextAlign.center,
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => showAddFeedSubscriptionSheet(context, ref),
            style: FilledButton.styleFrom(
              backgroundColor: IsleColors.ocean500,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.rss_feed),
            label: const Text('구독 추가 (YouTube·브런치·RSS)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push('/settings/subscriptions'),
            icon: const Icon(Icons.list),
            label: const Text('구독 목록 관리'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => context.push('/library/sources'),
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('가져온 콘텐츠 · 요약'),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeFeedBanner extends StatelessWidget {
  const _KnowledgeFeedBanner({required this.typography, required this.onChanged});

  final bool typography;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: KnowledgeVisual.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KnowledgeVisual.hairline),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '인사이트 노드 피드',
              style: KnowledgeVisual.editorialCaption(color: KnowledgeVisual.ink),
            ),
            const SizedBox(height: 2),
            Text(
              '에디토리얼 카드 · 썸네일 최소',
              style: KnowledgeVisual.editorialMonoHint(color: KnowledgeVisual.caption),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => context.push('/knowledge/profile'),
                    child: Text(
                      '지식 명함',
                      style: KnowledgeVisual.editorialCaption(
                        color: KnowledgeVisual.intelligentBlue,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/knowledge/swipe'),
                  child: Text(
                    '정독',
                    style: KnowledgeVisual.editorialCaption(
                      color: KnowledgeVisual.intelligentBlue,
                    ),
                  ),
                ),
                Switch(
                  value: typography,
                  onChanged: onChanged,
                  activeTrackColor: KnowledgeVisual.intelligentBlue.withValues(alpha: 0.4),
                  activeThumbColor: KnowledgeVisual.intelligentBlue,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 메인 피드 홈 — 채팅으로 차단·한도 설정 진입 카드
class _BlockChatHomeCard extends StatelessWidget {
  const _BlockChatHomeCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/settings/block-chat'),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.24),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chat_bubble_outline,
                      color: Colors.white, size: 21),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('채팅으로 차단 설정',
                          style: IsleText.subtitle(color: Colors.white)
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                        '"매일 9시까지 유튜브·Safari 막아줘" — 확인만 누르면 적용',
                        style: IsleText.caption(
                            color: Colors.white.withValues(alpha: 0.82)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    color: Colors.white.withValues(alpha: 0.7), size: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FilterHeaderDelegate();

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: const InterestFilterChips(),
    );
  }

  @override
  double get maxExtent => 52;

  @override
  double get minExtent => 52;

  @override
  bool shouldRebuild(_) => false;
}
