import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/explorer/safari_web_config.dart';
import '../../../core/insight/knowledge_visual_system.dart';
import '../../../core/library/my_isle_content_groups.dart';
import '../../../core/library/models/library_entry.dart';
import '../../../core/library/personal_library_store.dart';
import '../../../core/navigation/center_nav_long_press.dart';
import '../../../core/youtube/youtube_clipboard_watch.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import 'widgets/my_isle_entry_tile.dart';
import 'widgets/my_isle_hub_extras.dart';

/// 홈 중앙 — 나만의 Isle SNS (기사·리포트·유튜브) + Safari·유튜브 바로가기
class MyIsleHubScreen extends ConsumerStatefulWidget {
  const MyIsleHubScreen({super.key});

  @override
  ConsumerState<MyIsleHubScreen> createState() => _MyIsleHubScreenState();
}

class _MyIsleHubScreenState extends ConsumerState<MyIsleHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(personalLibraryProvider.notifier).reload());
    });
  }

  void _openEntry(LibraryEntry e) {
    if (e.url.isEmpty) return;
    if (e.sourceType == 'youtube' || e.url.contains('youtube.com') || e.url.contains('youtu.be')) {
      context.push('/youtube/podcast?url=${Uri.encodeComponent(e.url)}');
      return;
    }
    context.push('/viewer?url=${Uri.encodeComponent(e.url)}&title=${Uri.encodeComponent(e.title)}');
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(personalLibraryProvider);
    final groups = MyIsleContentGroups.fromEntries(entries);

    return Scaffold(
      backgroundColor: IsleColors.sand100,
      appBar: const IsleAppBar(title: '나의 Isle'),
      body: RefreshIndicator(
        onRefresh: () => ref.read(personalLibraryProvider.notifier).reload(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const _HeroCard(),
            const SizedBox(height: 12),
            _ManageCard(onTap: () => context.push('/home/my-isle/manage')),
            const SizedBox(height: 12),
            const MyIsleYoutubeTimeCard(),
            const SizedBox(height: 10),
            const MyIsleWatchLaterCard(),
            const SizedBox(height: 10),
            const KakaoFreezePromoCard(),
            const SizedBox(height: 16),
            Text('바로 열기', style: IsleText.subtitle(color: IsleColors.ocean900)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _QuickOpenCard(
                    icon: Icons.explore_outlined,
                    color: const Color(0xFF0A84FF),
                    label: 'Safari',
                    subtitle: '앱 안 브라우저',
                    onTap: () => SafariWebConfig.open(context),
                    onLongPress: () => SafariWebConfig.showUrlSheet(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickOpenCard(
                    icon: Icons.headphones,
                    color: const Color(0xFF1DB954),
                    label: '음성',
                    subtitle: '썸네일·소리만',
                    onTap: () => context.push('/youtube/podcast'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _QuickOpenCard(
                    icon: Icons.play_circle,
                    color: const Color(0xFFFF0000),
                    label: 'YouTube',
                    subtitle: '길게: DM·선택',
                    onTap: () => openCenterNavYoutube(context),
                    onLongPress: () => handleCenterNavLongPress(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => YoutubeClipboardWatch.pasteAndPlay(context),
                    icon: const Icon(Icons.content_paste_go),
                    label: const Text('YouTube 붙여넣기'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => SafariWebConfig.showUrlSheet(context),
                    icon: const Icon(Icons.link),
                    label: const Text('Safari 주소'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...MyIsleFeedKind.values.map(
              (kind) => _FeedSection(
                kind: kind,
                entries: groups[kind] ?? const [],
                onOpen: _openEntry,
                onImport: () => context.push('/library/sources'),
                onSwipe: kind == MyIsleFeedKind.articles
                    ? () => context.push('/knowledge/swipe')
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => context.push('/home/share'),
              icon: const Icon(Icons.inbox_outlined),
              label: const Text('링크 받기 · DM (받기 탭)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            KnowledgeVisual.surface,
            IsleColors.ocean100.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KnowledgeVisual.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '나만의 콘텐츠 허브',
            style: KnowledgeVisual.editorialBody(
              color: KnowledgeVisual.ink,
              fontSize: 20,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '외부 SNS 피드가 아니라, Isle에 모아 둔 기사·리포트·유튜브를 '
            '한곳에서 읽어요.',
            style: IsleText.body(color: IsleColors.muted).copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ManageCard extends StatelessWidget {
  const _ManageCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IsleColors.ocean900,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.tune, color: Colors.white, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '유튜브·SNS 관리',
                      style: IsleText.body(color: Colors.white)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '숏폼 숨기기 · 채널/키워드 차단 · 사용 한도',
                      style: IsleText.caption(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickOpenCard extends StatelessWidget {
  const _QuickOpenCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 6),
              Text(label, style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
              Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedSection extends StatelessWidget {
  const _FeedSection({
    required this.kind,
    required this.entries,
    required this.onOpen,
    required this.onImport,
    this.onSwipe,
  });

  final MyIsleFeedKind kind;
  final List<LibraryEntry> entries;
  final void Function(LibraryEntry) onOpen;
  final VoidCallback onImport;
  final VoidCallback? onSwipe;

  static const _previewMax = 6;

  @override
  Widget build(BuildContext context) {
    final preview = entries.take(_previewMax).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(kind.icon, color: IsleColors.ocean700, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kind.title, style: IsleText.subtitle()),
                  Text(kind.subtitle, style: IsleText.caption(color: IsleColors.muted)),
                ],
              ),
            ),
            Text('${entries.length}개', style: IsleText.caption(color: IsleColors.muted)),
          ],
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '아직 없어요',
                    style: IsleText.body(color: IsleColors.muted),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: onImport,
                    child: const Text('출처 연결 · 가져오기'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          ...preview.map((e) => MyIsleEntryTile(entry: e, onTap: () => onOpen(e))),
          if (entries.length > _previewMax)
            TextButton(
              onPressed: onImport,
              child: Text('${entries.length - _previewMax}개 더 · 라이브러리에서 보기'),
            ),
          if (onSwipe != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onSwipe,
                icon: const Icon(Icons.swipe),
                label: const Text('스와이프로 읽기'),
              ),
            ),
        ],
      ],
    );
  }
}
