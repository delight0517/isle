import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/intervention/website_block_store.dart';
import '../../../core/navigation/isle_routes.dart';
import '../../../core/youtube/blocked_channel_store.dart';
import '../../../core/youtube/blocked_url_store.dart';
import '../../../core/youtube/content_filter_store.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../../shared/widgets/rule_removal_lock_controls.dart';
import '../../feed/presentation/widgets/block_from_link_sheet.dart';
import '../../feed/presentation/widgets/blocked_url_sheet.dart';
import '../../feed/presentation/widgets/keyword_filter_sheet.dart';
import '../../youtube/presentation/widgets/premade_block_pack_section.dart';
import '../../youtube/presentation/widgets/youtube_block_hub_section.dart';
import 'widgets/adult_protection_panel.dart';
import 'widgets/website_block_section.dart';

/// SNS 허브 「보호 필터」 — 유튜브·키워드·URL·도메인·프리셋을 한곳에서 관리.
class ProtectionFilterScreen extends ConsumerStatefulWidget {
  const ProtectionFilterScreen({super.key});

  @override
  ConsumerState<ProtectionFilterScreen> createState() =>
      _ProtectionFilterScreenState();
}

class _ProtectionFilterScreenState
    extends ConsumerState<ProtectionFilterScreen> {
  int _domainCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadExtras());
  }

  Future<void> _loadExtras() async {
    await WebsiteBlockStore.ensureOpen();
    if (!mounted) return;
    setState(() {
      _domainCount = WebsiteBlockStore.loadDomains().length;
    });
  }

  int _totalFilters({
    required int channels,
    required int videos,
    required int keywords,
    required int urls,
  }) =>
      channels + videos + keywords + urls + _domainCount;

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(blockedChannelsProvider).length;
    final videos = ref.watch(blockedVideosProvider).length;
    final keywords = ref.watch(blockedKeywordsProvider).length;
    final urls = ref.watch(blockedUrlsProvider).length;
    final total = _totalFilters(
      channels: channels,
      videos: videos,
      keywords: keywords,
      urls: urls,
    );

    return Scaffold(
      backgroundColor: IsleColors.purple100,
      appBar: const IsleAppBar(title: '보호 필터'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          IsleSize.scrollBottomPadding(context),
        ),
        children: [
          _SummaryHero(
            total: total,
            channels: channels,
            videos: videos,
            keywords: keywords,
            urls: urls,
            domains: _domainCount,
          ),
          const SizedBox(height: 16),
          _QuickActionRow(
            onLinkBlock: () => showBlockFromLinkSheet(context),
            onUrlBlock: () => showBlockedUrlSheet(context),
            onKeyword: () => showKeywordFilterSheet(context),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phonelink_lock_outlined),
              title: const Text('iPhone 앱 차단'),
              subtitle:
                  const Text('Screen Time으로 YouTube·Safari 등 앱별 차단과 시간표 설정'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/home/sns/app-blocks'),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionCard(
            icon: Icons.inventory_2_outlined,
            iconColor: IsleColors.gold500,
            title: '프리셋 차단 팩',
            subtitle: '버튼 한 번 — 유튜브 채널·영상·키워드·URL 일괄 차단 · 4VPN 동일 카탈로그',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RuleRemovalLockControls(compact: true),
                SizedBox(height: 10),
                PremadeBlockPackSection(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _SectionCard(
            icon: Icons.play_circle_outline,
            iconColor: Color(0xFFFF0000),
            title: '유튜브 · 피드',
            subtitle: '채널·영상·키워드·분야 — 피드와 앱 안 유튜브에서 숨김',
            child: YoutubeBlockHubSection(),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            icon: Icons.link_off_rounded,
            iconColor: IsleColors.ocean700,
            title: 'URL 차단',
            subtitle: '특정 주소·패턴 — 브라우저·피드 링크에서 열리지 않음',
            child: _UrlBlockPanel(
              count: urls,
              onManage: () => showBlockedUrlSheet(context),
            ),
          ),
          const SizedBox(height: 14),
          const _SectionCard(
            icon: Icons.language_rounded,
            iconColor: IsleColors.purple700,
            title: 'Safari 도메인',
            subtitle: 'Safari 전용 · Chrome 등 다른 브라우저는 별도 설정 필요',
            child: WebsiteBlockSection(),
          ),
          const SizedBox(height: 14),
          const _SectionCard(
            icon: Icons.visibility_off,
            iconColor: IsleColors.danger,
            title: '성인 보호',
            subtitle: '끔 · 기본(SafeSearch) · 강화(400+ 규칙) — 단일 설정',
            child: AdultProtectionPanel(),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            icon: Icons.schedule_rounded,
            iconColor: IsleColors.ocean700,
            title: '스케줄 · AI',
            subtitle: '시간대별 차단 · 말로 설정',
            child: _ScheduleToolsPanel(
              onOpenSchedules: () =>
                  context.push(IsleRoutes.blockSchedulesOutsideShell),
              onOpenChat: () => context.push('/settings/block-chat'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({
    required this.total,
    required this.channels,
    required this.videos,
    required this.keywords,
    required this.urls,
    required this.domains,
  });

  final int total;
  final int channels;
  final int videos;
  final int keywords;
  final int urls;
  final int domains;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [IsleColors.purple700, IsleColors.purple500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
        boxShadow: [
          BoxShadow(
            color: IsleColors.purple700.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '활성 보호 규칙',
                      style: IsleText.caption(
                          color: Colors.white.withValues(alpha: 0.85)),
                    ),
                    Text(
                      total == 0 ? '아직 없음' : '$total개 적용 중',
                      style: IsleText.title(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (channels > 0) _HeroChip(label: '채널 $channels'),
                if (videos > 0) _HeroChip(label: '영상 $videos'),
                if (keywords > 0) _HeroChip(label: '키워드 $keywords'),
                if (urls > 0) _HeroChip(label: 'URL $urls'),
                if (domains > 0) _HeroChip(label: '도메인 $domains'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: IsleText.badge(color: Colors.white)),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.onLinkBlock,
    required this.onUrlBlock,
    required this.onKeyword,
  });

  final VoidCallback onLinkBlock;
  final VoidCallback onUrlBlock;
  final VoidCallback onKeyword;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickChip(
            icon: Icons.content_paste_go_rounded,
            label: '링크 숨기기',
            onTap: onLinkBlock,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickChip(
            icon: Icons.link_off_rounded,
            label: 'URL 차단',
            onTap: onUrlBlock,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickChip(
            icon: Icons.tag_rounded,
            label: '키워드',
            onTap: onKeyword,
          ),
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
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
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: IsleSize.minTouchTarget),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: IsleColors.purple700, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: IsleText.badge(color: IsleColors.ocean900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: IsleText.subtitle())),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _UrlBlockPanel extends StatelessWidget {
  const _UrlBlockPanel({required this.count, required this.onManage});

  final int count;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IsleColors.sand100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onManage,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.list_alt_rounded, color: IsleColors.ocean700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '차단 URL 목록',
                      style:
                          IsleText.body().copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      count == 0 ? '주소를 추가해 보세요' : '$count개 URL · 탭해서 관리',
                      style: IsleText.caption(color: IsleColors.muted),
                    ),
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

class _ScheduleToolsPanel extends StatelessWidget {
  const _ScheduleToolsPanel({
    required this.onOpenSchedules,
    required this.onOpenChat,
  });

  final VoidCallback onOpenSchedules;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '성인 보호는 위 「성인 보호」에서 · 게임·웹툰 프리셋은 「프리셋 차단 팩」에서 설정해요.',
          style: IsleText.caption(color: IsleColors.muted),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: onOpenSchedules,
          icon: const Icon(Icons.schedule_rounded),
          label: const Text('스케줄 · 프리셋 연결'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onOpenChat,
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('말로 차단 설정 (AI 챗)'),
        ),
      ],
    );
  }
}
