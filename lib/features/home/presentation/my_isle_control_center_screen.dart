import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/isle_routes.dart';
import '../../../core/navigation/schedule_overlay_navigation.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/navigation/center_nav_long_press.dart';
import '../../../core/social/instagram_web_config.dart';
import '../../../core/youtube/youtube_clipboard_watch.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../feed/presentation/widgets/block_from_link_sheet.dart';
import '../../feed/presentation/widgets/keyword_filter_sheet.dart';
import '../../youtube/presentation/widgets/youtube_block_hub_section.dart';
import '../../youtube/presentation/widgets/youtube_limit_controls.dart';
import '../../youtube/presentation/widgets/isle_youtube_schedule_sheet.dart';
import 'widgets/adult_protection_panel.dart';
import '../../youtube/presentation/widgets/youtube_watch_limit_hub_card.dart';

/// 나의 Isle → 유튜브·SNS 관리 센터.
///
/// 흩어져 있던 컨트롤을 한 화면에 모은다:
///  · 숏폼(Shorts·Reels) 숨기기 토글
///  · 링크 붙여넣기 → 채널/영상 즉시 숨기기
///  · 채널·영상·키워드·분야 차단 ([YoutubeBlockHubSection])
///  · 유튜브/인스타 사용 한도
class MyIsleControlCenterScreen extends ConsumerStatefulWidget {
  const MyIsleControlCenterScreen({super.key});

  @override
  ConsumerState<MyIsleControlCenterScreen> createState() =>
      _MyIsleControlCenterScreenState();
}

class _MyIsleControlCenterScreenState
    extends ConsumerState<MyIsleControlCenterScreen> {
  bool _hideShorts = IsleUserDefaults.hideYoutubeShorts;
  bool _hideReels = IsleUserDefaults.hideInstagramReels;
  bool _reelsGuard = IsleUserDefaults.instagramReelsGuardEnabled;
  bool _exploreGuard = IsleUserDefaults.instagramExploreGuardEnabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IsleColors.sand100,
      appBar: const IsleAppBar(title: '유튜브·SNS 관리'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Card(
            color: const Color(0xFFE8F5E9),
            child: ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF2E7D32)),
              title: Text('차단 AI 챗', style: IsleText.subtitle()),
              subtitle: Text(
                '말로 키워드·숏츠·한도·Safari 스케줄 설정',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/block-chat'),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '시간 한도 구조',
            subtitle: '① 유튜브 시청(한도) · ② 유튜브 뮤직/음성(무한) · '
                '③ 인스타 DM(무한) · ④ 인스타 피드(한도)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => openCenterNavYoutube(context),
                        icon: const Icon(Icons.play_circle, color: Color(0xFFFF0000)),
                        label: const Text('유튜브 시청'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/youtube/podcast'),
                        icon: const Icon(Icons.headphones, color: Color(0xFF1DB954)),
                        label: const Text('유튜브 음성'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push(InstagramWebConfig.dmBrowserRoute(dmOnly: true)),
                        icon: const Icon(Icons.forum_outlined),
                        label: const Text('인스타 DM'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE1306C),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(InstagramWebConfig.dmBrowserRoute(dmOnly: false)),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('인스타 피드'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF1A1A1A),
            child: ListTile(
              leading: const Icon(Icons.headphones, color: IsleColors.gold500),
              title: Text('유튜브 음성', style: IsleText.subtitle(color: Colors.white)),
              subtitle: Text(
                '듣기 전용 · YT Music에 없는 영상 · 비공식 재생목록',
                style: IsleText.caption(color: Colors.white60),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () => context.push('/youtube/podcast'),
            ),
          ),
          const SizedBox(height: 16),
          // 1) 숏폼 숨기기 (내가 켜고 끔)
          _SectionCard(
            title: '짧은 영상(숏폼) 숨기기',
            subtitle: '앱 안 유튜브·인스타에서 숏츠·릴 선반을 제거해요. 언제든 다시 켤 수 있어요.',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('YouTube Shorts 숨기기', style: IsleText.body()),
                  subtitle: Text(
                    '홈·피드·검색에서 숏츠 선반 제거',
                    style: IsleText.caption(color: IsleColors.muted),
                  ),
                  value: _hideShorts,
                  onChanged: (v) async {
                    await IsleUserDefaults.setHideYoutubeShorts(v);
                    if (mounted) setState(() => _hideShorts = v);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Instagram Reels 숨기기', style: IsleText.body()),
                  subtitle: Text(
                    '인스타 WebView에서 릴·숏폼 숨김',
                    style: IsleText.caption(color: IsleColors.muted),
                  ),
                  value: _hideReels,
                  onChanged: (v) async {
                    await IsleUserDefaults.setHideInstagramReels(v);
                    if (mounted) setState(() => _hideReels = v);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('릴스 둠스크롤 멈춤', style: IsleText.body()),
                  subtitle: Text(
                    '스크롤로 ${IsleUserDefaults.instagramReelsGuardThreshold}개를 넘기면 멈춤 화면 · '
                    '계속 넘길수록 더 자주·더 길게 막아요',
                    style: IsleText.caption(color: IsleColors.muted),
                  ),
                  value: _reelsGuard,
                  onChanged: (v) async {
                    await IsleUserDefaults.setInstagramReelsGuardEnabled(v);
                    if (mounted) setState(() => _reelsGuard = v);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('탐색(Explore) 둠스크롤 멈춤', style: IsleText.body()),
                  subtitle: Text(
                    '탐색 탭에서 포스트를 ${IsleUserDefaults.instagramExploreGuardThreshold}개 열람하거나 '
                    '그만큼 스크롤하면 멈춤 화면 · 홈 피드·DM은 영향 없음',
                    style: IsleText.caption(color: IsleColors.muted),
                  ),
                  value: _exploreGuard,
                  onChanged: (v) async {
                    await IsleUserDefaults.setInstagramExploreGuardEnabled(v);
                    if (mounted) setState(() => _exploreGuard = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2) 링크 붙여넣기 — 보기 / 숨기기
          _SectionCard(
            title: 'YouTube 링크 붙여넣기',
            subtitle: '복사한 영상은 Isle 유튜브에서 보기 · 채널/영상 숨기기를 한곳에서.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => YoutubeClipboardWatch.pasteAndPlay(context),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('클립보드 링크 — Isle에서 보기'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => showBlockFromLinkSheet(context),
                  icon: const Icon(Icons.block_flipped),
                  label: const Text('링크로 채널·영상 숨기기'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Isle 유튜브 시간 차단',
            subtitle: 'AI 챗 없이도 수동 설정 — 매일 아침까지 앱 안 유튜브 막기',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => showIsleYoutubeScheduleSheet(context),
                  icon: const Icon(Icons.schedule),
                  label: const Text('몇 시까지 막을지 설정'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => pushBlockScheduleList(context),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('스케줄 목록·수정'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3) 채널·영상·키워드·분야 차단 목록 (기존 컴포넌트 재사용)
          const _SectionCard(
            title: '숨김·차단 목록',
            child: YoutubeBlockHubSection(),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '성인 보호',
            subtitle: '보호 필터와 동일 — 끔 · 기본 · 강화',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AdultProtectionPanel(compact: true),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/home/sns/protection-filter'),
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('보호 필터 열기'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '기타 프리셋',
            subtitle: '게임·불법 웹툰 — 스케줄에 연결',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '성인은 위 「성인 보호」에서만 설정해요.',
                  style: IsleText.caption(color: IsleColors.muted),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () => pushBlockScheduleList(context),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('스케줄에서 프리셋 연결'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4) 사용 한도
          _SectionCard(
            title: '사용 한도',
            subtitle: '줄이기는 저장·확인 후 적용 · 늘리기는 타임락 대기 후에만 가능해요.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const YoutubeWatchLimitHubCard(),
                const SizedBox(height: 12),
                const YoutubeLimitControls(compact: true),
                const SizedBox(height: 12),
                _LinkTile(
                  icon: Icons.timelapse,
                  color: const Color(0xFFE1306C),
                  title: 'Instagram 피드 한도',
                  subtitle: 'DM 무제한 · 피드·릴스만 시간 제한',
                  onTap: () => context.push('/settings/instagram-limits?scope=feed'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.push(IsleRoutes.youtubeLimits),
                  icon: const Icon(Icons.tune),
                  label: const Text('YouTube 한도 세부 설정'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5) 빠른 키워드 차단
          _SectionCard(
            title: '키워드로 숨기기',
            subtitle: '제목·채널명에 들어간 단어가 있으면 피드·앱 안 유튜브에서 안 보여요.',
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => showKeywordFilterSheet(context),
                icon: const Icon(Icons.tag),
                label: const Text('키워드 추가·관리'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: IsleText.subtitle()),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: IsleText.caption(color: IsleColors.muted)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IsleColors.sand100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
                    ),
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
