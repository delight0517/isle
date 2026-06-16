import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/youtube/youtube_session.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../../shared/widgets/isle_hub_more_section.dart';
import '../../../shared/widgets/isle_quick_launcher.dart';
import '../../../shared/widgets/robot_link_swallow_animation.dart';
import '../../../core/youtube/youtube_clipboard_watch.dart';
import '../../feed/presentation/widgets/youtube_channel_search_sheet.dart';
import 'widgets/youtube_focus_panel.dart';
import 'widgets/youtube_creator_insight_sheet.dart';
import 'widgets/youtube_block_hub_section.dart';
import 'widgets/youtube_timelock_card.dart';
import 'widgets/youtube_watch_limit_hub_card.dart';

/// iPhone — 유튜브·차단 기능 진입 허브 (큰 버튼, 설명 최소)
class YoutubeHubScreen extends ConsumerStatefulWidget {
  const YoutubeHubScreen({super.key});

  @override
  ConsumerState<YoutubeHubScreen> createState() => _YoutubeHubScreenState();
}

class _YoutubeHubScreenState extends ConsumerState<YoutubeHubScreen> {
  bool _hideYtShorts = IsleUserDefaults.hideYoutubeShorts;
  bool _hideIgReels = IsleUserDefaults.hideInstagramReels;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowGuide());
  }

  Future<void> _maybeShowGuide() async {
    if (!IsleUserDefaults.hasSeenYoutubeGuide &&
        !IsleUserDefaults.youtubeWebLoginRemembered &&
        mounted) {
      await context.push('/youtube/guide');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: IsleAppBar(
        title: '유튜브',
        actions: [
          IconButton(
            icon: const Icon(Icons.apps),
            tooltip: '무엇을 할까요?',
            onPressed: () => showIsleQuickLauncher(context, ref: ref),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => context.push('/youtube/guide'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showIsleQuickLauncher(context, ref: ref),
        tooltip: '기능 모음',
        child: const Icon(Icons.apps),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
        children: [
          const _YoutubeResumeBanner(),
          _HomePlayHero(onPlay: () => context.push('/youtube/browser')),
          const SizedBox(height: 10),
          Card(
            color: const Color(0xFF1A1A1A),
            child: ListTile(
              leading: const Icon(Icons.headphones, color: Color(0xFF1DB954)),
              title: const Text('유튜브 음성', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                '썸네일 + 소리만 · 영상 화면 없음',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () => context.push('/youtube/podcast'),
            ),
          ),
          const SizedBox(height: 12),
          const YoutubeWatchLimitHubCard(),
          const SizedBox(height: 16),
          const YoutubeBlockHubSection(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.analytics_outlined,
                  label: '크리에이티브',
                  onTap: () => context.push('/youtube/creative-analytics?tab=growth'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickTile(
                  icon: Icons.search,
                  label: '유튜버 검색',
                  onTap: () => showYoutubeChannelSearchSheet(context, ref),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('YouTube Shorts 숨기기'),
                  subtitle: const Text('홈·피드·검색에서 숏츠·릴 선반 제거'),
                  value: _hideYtShorts,
                  onChanged: (v) async {
                    await IsleUserDefaults.setHideYoutubeShorts(v);
                    setState(() => _hideYtShorts = v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Instagram Reels 숨기기'),
                  subtitle: const Text('인스타 WebView에서 릴·숏폼 숨김'),
                  value: _hideIgReels,
                  onChanged: (v) async {
                    await IsleUserDefaults.setHideInstagramReels(v);
                    setState(() => _hideIgReels = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const YoutubeFocusPanel(),
          const SizedBox(height: 16),
          IsleHubMoreSection(
            children: [
              _HubCard(
                icon: Icons.spa_outlined,
                color: Colors.black87,
                title: '3초 몰입 모드',
                subtitle: '검색만 · 알고리즘 제로',
                onTap: () => context.push('/youtube-focus'),
              ),
              const SizedBox(height: 12),
              const YoutubeTimelockCard(),
              const SizedBox(height: 12),
              _HubCard(
                icon: Icons.auto_awesome,
                color: IsleColors.ocean700,
                title: '영상 1개 인사이트',
                subtitle: 'CC·AI',
                onTap: () => showYoutubeCreatorInsightSheet(context, ref),
              ),
              const SizedBox(height: 12),
              _HubCard(
                icon: Icons.search,
                color: const Color(0xFFFF0000),
                title: '유튜버 검색',
                subtitle: '구독 추가',
                onTap: () => showYoutubeChannelSearchSheet(context, ref),
              ),
              const SizedBox(height: 12),
              _HubCard(
                icon: Icons.schedule,
                color: Colors.red.shade700,
                title: '차단 스케줄',
                subtitle: '요일·시간',
                onTap: () => context.push('/settings/block-schedules'),
              ),
              const SizedBox(height: 12),
              _HubCard(
                icon: Icons.settings_outlined,
                color: IsleColors.muted,
                title: '설정',
                subtitle: '한도·앱 차단·고급',
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 이전 시청 세션 — 브라우저를 닫거나 다른 탭으로 나가도 WebView 유지
class _YoutubeResumeBanner extends StatelessWidget {
  const _YoutubeResumeBanner();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: YoutubeSession.instance,
      builder: (_, __) {
        final s = YoutubeSession.instance;
        if (!s.hasParkedSession) return const SizedBox.shrink();
        final title = s.probed.videoTitle.isNotEmpty
            ? s.probed.videoTitle
            : (s.displayTitle.isNotEmpty ? s.displayTitle : '유튜브');
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.push('/youtube/browser'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_filled, color: Color(0xFFFF0000), size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '이어서 보기',
                            style: IsleText.caption(color: IsleColors.gold500)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(title, style: IsleText.body(color: Colors.white), maxLines: 2),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomePlayHero extends StatefulWidget {
  const _HomePlayHero({required this.onPlay});
  final VoidCallback onPlay;

  @override
  State<_HomePlayHero> createState() => _HomePlayHeroState();
}

class _HomePlayHeroState extends State<_HomePlayHero> {
  bool _swallowing = false;

  Future<void> _pasteAndPlay(BuildContext ctx) async {
    setState(() => _swallowing = true);
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    setState(() => _swallowing = false);
    if (mounted) YoutubeClipboardWatch.pasteAndPlay(ctx);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFF0000),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF0000).withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Isle에서 유튜브 보기', style: IsleText.title(color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            '시청 시간·한도·차단 스케줄이 여기서만 기록됩니다.',
            style: IsleText.caption(color: Colors.white.withValues(alpha: 0.9)).copyWith(height: 1.35),
          ),
          const SizedBox(height: 14),
          // 로봇 — 링크를 삼키는 애니메이션
          GestureDetector(
            onTap: () => _pasteAndPlay(context),
            child: RobotLinkSwallowAnimation(
              animating: _swallowing,
              label: 'YouTube 링크 붙여넣기 (탭)',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: widget.onPlay,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFFF0000),
              minimumSize: const Size.fromHeight(IsleSize.minTouchTarget),
            ),
            icon: const Icon(Icons.play_arrow, size: 28),
            label: const Text('지금 재생', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFFFF0000), size: 28),
              const SizedBox(height: 4),
              Text(label, style: IsleText.caption().copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: IsleText.subtitle()),
                    Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: IsleColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
