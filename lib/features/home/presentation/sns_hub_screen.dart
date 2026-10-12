import 'package:flutter/material.dart';
import '../../../core/localization/moa_strings.dart';
import '../../../core/localization/reading_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/explorer/explorer_site.dart';
import '../../../core/library/platform_usage_stats.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/social/instagram_web_config.dart';
import '../../../core/youtube/blocked_channel_store.dart';
import '../../../core/youtube/blocked_url_store.dart';
import '../../../core/youtube/content_filter_store.dart';
import '../../../core/youtube/youtube_content_open_guard.dart';

/// SNS 허브 탭 — 모아 앱의 메인 화면. 플랫폼을 바로 열기.
class SnsHubScreen extends ConsumerStatefulWidget {
  const SnsHubScreen({super.key});

  @override
  ConsumerState<SnsHubScreen> createState() => _SnsHubScreenState();
}

class _SnsHubScreenState extends ConsumerState<SnsHubScreen> {
  Map<String, int> _todaySec = {};
  int _totalToday = 0;
  Set<String> _hiddenIds = const {};

  static const _platforms = [
    _Platform(
      id: 'youtube',
      title: '유튜브',
      emoji: '▶',
      color: Color(0xFFFF0000),
      bgColor: Color(0xFFFFF1F1),
      site: ExplorerSite.youtube,
      url: 'https://m.youtube.com',
    ),
    _Platform(
      id: 'instagram',
      title: '인스타그램',
      emoji: '📷',
      color: Color(0xFFE1306C),
      bgColor: Color(0xFFFFF0F5),
      site: ExplorerSite.instagram,
      url: 'https://www.instagram.com/',
    ),
    // "메신저(메시지만)"와 "피드(인스타 모든 기능)"가 아이콘 하나로 뭉쳐 있어
    // 구분이 안 된다는 실사용 제보(2026-07-13, 홈 화면 스크린샷) — DM 전용
    // 진입점(InstagramWebConfig.dmBrowserRoute, instagramDmOnly=true)은
    // 코드엔 이미 있었지만 다른 탭(share_home_screen.dart)에만 노출돼
    // 있었고 이 SNS 허브 화면엔 없었다. 여기에도 별도 아이콘으로 추가.
    _Platform(
      id: 'instagram_dm',
      title: '인스타 메신저',
      emoji: '💬',
      color: Color(0xFFE1306C),
      bgColor: Color(0xFFFFF0F5),
      site: ExplorerSite.instagram,
      url: 'https://www.instagram.com/direct/inbox/',
    ),
    _Platform(
      id: 'brunch',
      title: '브런치',
      emoji: '✍',
      color: Color(0xFF00C389),
      bgColor: Color(0xFFF0FDF4),
      site: ExplorerSite.brunch,
      url: 'https://brunch.co.kr',
    ),
    _Platform(
      id: 'naver',
      title: '네이버 블로그',
      emoji: 'N',
      color: Color(0xFF03C75A),
      bgColor: Color(0xFFF0FDF4),
      site: ExplorerSite.naver,
      url: 'https://m.blog.naver.com',
    ),
    _Platform(
      id: 'facebook',
      title: '페이스북',
      emoji: 'f',
      color: Color(0xFF1877F2),
      bgColor: Color(0xFFEEF2FF),
      site: ExplorerSite.facebook,
      url: 'https://m.facebook.com/',
    ),
    _Platform(
      id: 'browser',
      title: '브라우저',
      emoji: '🌐',
      color: IsleColors.purple700,
      bgColor: IsleColors.purple100,
      site: ExplorerSite.custom,
      url: 'https://www.google.com',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _hiddenIds = IsleUserDefaults.hiddenSnsHubPlatformIds;
    _loadStats();
  }

  Future<void> _loadStats() async {
    final today = await PlatformUsageStats.todayByPlatform();
    if (!mounted) return;
    final total = today.values.fold(0, (a, b) => a + b);
    setState(() {
      _todaySec = today;
      _totalToday = total;
    });
  }

  /// 안 쓰는 앱(브런치·Facebook 등)을 사용자가 직접 골라서 홈 아이콘만 숨기는
  /// 기능(2026-07-13 신설). 차단 대상 카탈로그·채팅 파서엔 영향 없음 — "바로
  /// 열기" 그리드에서만 뺀다. 롱프레스로 숨기고, 전부 숨겼을 때만 뜨는
  /// "숨긴 앱 관리"에서 다시 꺼낼 수 있다.
  Future<void> _hidePlatform(_Platform p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${p.title} 아이콘을 홈에서 숨길까요?'),
        content: const Text('차단 설정에는 영향 없어요. 언제든 "숨긴 앱 관리"에서 다시 꺼낼 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('숨기기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final next = {..._hiddenIds, p.id};
    setState(() => _hiddenIds = next);
    await IsleUserDefaults.setHiddenSnsHubPlatformIds(next);
  }

  Future<void> _manageHiddenPlatforms() async {
    final hidden = _platforms.where((p) => _hiddenIds.contains(p.id)).toList();
    if (hidden.isEmpty) return;
    final restored = await showModalBottomSheet<Set<String>>(
      context: context,
      builder: (ctx) => _HiddenPlatformsSheet(hidden: hidden),
    );
    if (restored == null || !mounted) return;
    final next = _hiddenIds.difference(restored);
    setState(() => _hiddenIds = next);
    await IsleUserDefaults.setHiddenSnsHubPlatformIds(next);
  }

  void _open(_Platform p) {
    if (p.id == 'youtube') {
      if (!YoutubeContentOpenGuard.showDenialOrAllow(context, url: p.url)) {
        return;
      }
      context.push('/youtube/browser');
      return;
    }
    if (p.id == 'instagram') {
      context.push(
        '/explore/browser?site=instagram&url=${Uri.encodeComponent(InstagramWebConfig.homeUrl)}',
      );
      return;
    }
    if (p.id == 'instagram_dm') {
      context.push(InstagramWebConfig.dmBrowserRoute());
      return;
    }
    context.push('/explore/browser?${p.exploreQuery}');
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: IsleColors.purple100,
      body: RefreshIndicator(
        color: IsleColors.purple700,
        onRefresh: _loadStats,
        child: CustomScrollView(
          slivers: [
            _MoaAppBar(topPad: topPad),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  // ── 오늘 요약 카드 ──────────────────────────
                  if (_totalToday > 0) ...[
                    _TodaySummaryCard(todaySec: _todaySec, total: _totalToday),
                    const SizedBox(height: 16),
                  ],
                  // ── 플랫폼 그리드 ───────────────────────────
                  Row(
                    children: [
                      Expanded(
                          child: _SectionLabel(
                              MoaStrings.of(context).t('quick_open'))),
                      if (_hiddenIds.isNotEmpty)
                        TextButton(
                          onPressed: _manageHiddenPlatforms,
                          child: Text(MoaStrings.of(context).t('hidden_apps',
                              args: {'count': '${_hiddenIds.length}'})),
                        )
                      else
                        // 안 쓰는 앱을 길게 눌러 숨기는 기능은 아무 표시 없이
                        // 롱프레스로만 발견되는 구조라, 하나도 안 숨긴 상태에선
                        // 존재 자체를 몰랐다는 실사용 제보(2026-07-13) — 힌트를
                        // 보여줄 작은 버튼을 항상 노출한다.
                        IconButton(
                          onPressed: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('안 쓰는 앱은 아이콘을 길게 눌러서 홈에서 숨길 수 있어요'),
                            ),
                          ),
                          icon: const Icon(Icons.info_outline, size: 20),
                          tooltip: '안 쓰는 앱 숨기기 안내',
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PlatformGrid(
                    platforms: _platforms
                        .where((p) => !_hiddenIds.contains(p.id))
                        .toList(),
                    todaySec: _todaySec,
                    onTap: _open,
                    onLongPress: _hidePlatform,
                  ),
                  const SizedBox(height: 20),
                  const _ProtectionFilterEntry(),
                  const SizedBox(height: 20),
                  // ── 빠른 도구 ──────────────────────────────
                  _SectionLabel(MoaStrings.of(context).t('tools')),
                  const SizedBox(height: 10),
                  const _QuickToolsRow(),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: () => context.push('/reading/topics'),
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(ReadingStrings.of(context).t('title'))),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── App Bar ───────────────────────────────────────

class _MoaAppBar extends StatelessWidget {
  const _MoaAppBar({required this.topPad});
  final double topPad;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(20, topPad + 12, 16, 14),
        child: Row(
          children: [
            // 앱 아이콘 + 이름
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [IsleColors.purple700, IsleColors.purple500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'M',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              MoaStrings.of(context).t('brand'),
              style: IsleText.title(color: IsleColors.purple900)
                  .copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            const Spacer(),
            _IconBtn(
              icon: Icons.search_rounded,
              onTap: () => context.push(
                '/explore/browser?site=custom&url=${Uri.encodeComponent("https://www.google.com")}',
              ),
            ),
            const SizedBox(width: 6),
            _IconBtn(
              icon: Icons.settings_outlined,
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: IsleColors.purple100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: IsleColors.purple700),
      ),
    );
  }
}

// ─────────────────────────── Today Summary ──────────────────────────────────

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({required this.todaySec, required this.total});
  final Map<String, int> todaySec;
  final int total;

  static const _platformColors = {
    'youtube': Color(0xFFFF0000),
    'instagram': Color(0xFFE1306C),
    'brunch': Color(0xFF00C6BE),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [IsleColors.purple700, IsleColors.purple500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: IsleColors.purple700.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MoaStrings.of(context).t('today_moa'),
            style:
                IsleText.caption(color: Colors.white.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 2),
          Text(
            MoaStrings.of(context).duration(total),
            style: IsleText.title(color: Colors.white)
                .copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 10),
          // 미니 바 차트
          Row(
            children: PlatformUsageStats.platforms.map((p) {
              final sec = todaySec[p] ?? 0;
              if (sec == 0) return const SizedBox.shrink();
              final ratio = total > 0 ? sec / total : 0.0;
              final color = _platformColors[p] ?? Colors.white;
              return Expanded(
                flex: sec,
                child: Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: 0.25 + ratio * 0.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            PlatformUsageStats.labelFor(p),
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Platform Grid ──────────────────────────────────

class _PlatformGrid extends StatelessWidget {
  const _PlatformGrid({
    required this.platforms,
    required this.todaySec,
    required this.onTap,
    this.onLongPress,
  });
  final List<_Platform> platforms;
  final Map<String, int> todaySec;
  final void Function(_Platform) onTap;
  final void Function(_Platform)? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // The outer scroll view already handles the phone's safe area.
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: platforms.length,
      itemBuilder: (_, i) {
        final p = platforms[i];
        final sec = todaySec[p.id] ?? 0;
        return _PlatformTile(
          platform: p,
          todaySec: sec,
          onTap: () => onTap(p),
          onLongPress: onLongPress == null ? null : () => onLongPress!(p),
        );
      },
    );
  }
}

class _PlatformTile extends StatelessWidget {
  const _PlatformTile({
    required this.platform,
    required this.todaySec,
    required this.onTap,
    this.onLongPress,
  });
  final _Platform platform;
  final int todaySec;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: platform.color.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: platform.bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  platform.emoji,
                  style: TextStyle(
                    fontSize: platform.emoji.length == 1 &&
                            platform.emoji.codeUnitAt(0) < 256
                        ? 22
                        : 26,
                    color: platform.emoji.length == 1 &&
                            platform.emoji.codeUnitAt(0) < 256
                        ? platform.color
                        : null,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                MoaStrings.of(context).t('platform_${platform.id}'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1a1a2e),
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              todaySec > 0
                  ? MoaStrings.of(context).duration(todaySec)
                  : MoaStrings.of(context).t('open'),
              style: TextStyle(
                fontSize: 10,
                color: todaySec > 0 ? platform.color : IsleColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Protection Filter ────────────────────────────────

class _ProtectionFilterEntry extends ConsumerWidget {
  const _ProtectionFilterEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(blockedChannelsProvider).length;
    final videos = ref.watch(blockedVideosProvider).length;
    final keywords = ref.watch(blockedKeywordsProvider).length;
    final urls = ref.watch(blockedUrlsProvider).length;
    final total = channels + videos + keywords + urls;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/home/sns/protection-filter'),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [IsleColors.purple700, IsleColors.purple500],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: IsleColors.purple700.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(MoaStrings.of(context).t('protect_filters'),
                          style: IsleText.subtitle(color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(
                        total == 0
                            ? MoaStrings.of(context).t('protect_summary')
                            : MoaStrings.of(context)
                                .t('rules_active', args: {'count': '$total'}),
                        style: IsleText.caption(
                            color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
                if (total > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$total',
                      style: IsleText.badge(color: IsleColors.purple700),
                    ),
                  ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Quick Tools ────────────────────────────────────

class _QuickToolsRow extends StatelessWidget {
  const _QuickToolsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToolCard(
            icon: Icons.qr_code_scanner_rounded,
            label: 'QR 스캔',
            color: IsleColors.purple700,
            onTap: () => context.push('/home/share/qr'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ToolCard(
            icon: Icons.timer_rounded,
            label: MoaStrings.of(context).t('time'),
            color: const Color(0xFF0EA5E9),
            onTap: () => context.go('/home/time'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ToolCard(
            icon: Icons.library_books_outlined,
            label: MoaStrings.of(context).t('my_moa'),
            color: const Color(0xFF10B981),
            onTap: () => context.go('/home/my-isle'),
          ),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1a1a2e),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Helpers ────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: IsleColors.purple700,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _Platform {
  const _Platform({
    required this.id,
    required this.title,
    required this.emoji,
    required this.color,
    required this.bgColor,
    required this.site,
    required this.url,
  });

  final String id;
  final String title;
  final String emoji;
  final Color color;
  final Color bgColor;
  final ExplorerSite site;
  final String url;

  String get exploreQuery =>
      'site=${site.name}&url=${Uri.encodeComponent(url)}';
}

/// "숨긴 앱 관리" 바텀시트 — 체크한 앱을 다시 홈 그리드에 꺼내준다.
class _HiddenPlatformsSheet extends StatefulWidget {
  const _HiddenPlatformsSheet({required this.hidden});
  final List<_Platform> hidden;

  @override
  State<_HiddenPlatformsSheet> createState() => _HiddenPlatformsSheetState();
}

class _HiddenPlatformsSheetState extends State<_HiddenPlatformsSheet> {
  final Set<String> _toRestore = {};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '숨긴 앱 관리',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              '다시 보이게 할 앱을 체크하세요.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8a8a99)),
            ),
            const SizedBox(height: 12),
            ...widget.hidden.map((p) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _toRestore.contains(p.id),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _toRestore.add(p.id);
                    } else {
                      _toRestore.remove(p.id);
                    }
                  }),
                  title: Text('${p.emoji} ${p.title}'),
                )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _toRestore.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_toRestore),
                child: const Text('선택한 앱 다시 보이기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
