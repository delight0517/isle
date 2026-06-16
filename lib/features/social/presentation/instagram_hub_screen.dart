import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/social/instagram_following_store.dart';
import '../../../core/library/platform_watch_limit_store.dart';
import '../../../core/social/instagram_web_config.dart';
import '../../../core/social/social_share_service.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// 인스타 — 구독 목록 관리 + 앱 내 피드 WebView
class InstagramHubScreen extends StatefulWidget {
  const InstagramHubScreen({super.key});

  @override
  State<InstagramHubScreen> createState() => _InstagramHubScreenState();
}

class _InstagramHubScreenState extends State<InstagramHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<InstagramFollowEntry> _entries = [];
  bool _dmFocus = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _entries = InstagramFollowingStore.loadAll();
      _dmFocus = IsleUserDefaults.instagramDmFocusMode;
    });
  }

  Future<void> _addHandle() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('구독 계정 추가', style: IsleText.subtitle()),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: '@username',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('추가')),
        ],
      ),
    );
    if (ok == true) {
      await InstagramFollowingStore.addHandle(ctrl.text);
      _reload();
    }
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _entries.where((e) => !e.hidden).toList();
    return Scaffold(
      appBar: IsleAppBar(
        title: '인스타그램',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: '스토리 공유',
            onPressed: () => SocialShareService.shareToInstagramStory(
              text: 'Isle에서 공유',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            labelColor: IsleColors.ocean900,
            tabs: const [
              Tab(text: '구독 피드'),
              Tab(text: '구독 관리'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _FeedTab(
                  onOpenDm: () => context.push(InstagramWebConfig.dmBrowserRoute(dmOnly: true)),
                  onOpenFeed: () => context.push(InstagramWebConfig.dmBrowserRoute(dmOnly: false)),
                dmFocus: _dmFocus,
                onToggleDmFocus: (v) async {
                  await IsleUserDefaults.setInstagramDmFocusMode(v);
                  if (!mounted) return;
                  setState(() => _dmFocus = v);
                }),
                _ManageTab(
                  entries: _entries,
                  visibleCount: visible.length,
                  onAdd: _addHandle,
                  onReload: _reload,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({
    required this.onOpenDm,
    required this.onOpenFeed,
    required this.dmFocus,
    required this.onToggleDmFocus,
  });

  final VoidCallback onOpenDm;
  final VoidCallback onOpenFeed;
  final bool dmFocus;
  final ValueChanged<bool> onToggleDmFocus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DM 집중: 메시지·상대 프로필·게시물·스토리는 OK — 홈 피드·탐색·전체 릴스는 막아요.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 10),
          _LimitRow(
            label: '피드 한도',
            chip: PlatformWatchLimitStore.formatRemainChip(PlatformWatchId.instagram),
            onTap: () => context.push('/settings/instagram-limits?scope=feed'),
          ),
          _LimitRow(
            label: 'DM 한도',
            chip: PlatformWatchLimitStore.formatRemainChip(PlatformWatchId.instagramDm),
            onTap: () => context.push('/settings/instagram-limits?scope=dm'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: dmFocus,
            onChanged: onToggleDmFocus,
            title: const Text('Instagram DM 집중 모드'),
            subtitle: const Text('DM + 상대 프로필·포스트 · 탐색/홈 피드 차단'),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onOpenDm,
            icon: const Icon(Icons.forum_outlined),
            label: const Text('DM 받은편지함'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: const Color(0xFFE1306C),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onOpenFeed,
            icon: const Icon(Icons.home_outlined),
            label: const Text('인스타 피드 (전체)'),
          ),
        ],
      ),
    );
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({
    required this.label,
    required this.chip,
    required this.onTap,
  });

  final String label;
  final String chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: IsleText.body()),
      subtitle: Text(chip, style: IsleText.caption(color: IsleColors.muted)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _ManageTab extends StatelessWidget {
  const _ManageTab({
    required this.entries,
    required this.visibleCount,
    required this.onAdd,
    required this.onReload,
  });

  final List<InstagramFollowEntry> entries;
  final int visibleCount;
  final VoidCallback onAdd;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text('표시 $visibleCount · 전체 ${entries.length}', style: IsleText.caption()),
              const Spacer(),
              TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('추가')),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    '구독 @를 추가하세요\n인스타 피드는 「구독 피드」 탭에서 엽니다',
                    textAlign: TextAlign.center,
                    style: IsleText.body(color: IsleColors.muted),
                  ),
                )
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(e.handle.isNotEmpty ? e.handle[0].toUpperCase() : '?'),
                      ),
                      title: Text('@${e.handle}', style: IsleText.body()),
                      subtitle: e.hidden ? const Text('관심 없음 — 숨김') : null,
                      onTap: () => SocialShareService.openInstagramProfile(e.handle),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'hide') {
                            await InstagramFollowingStore.setHidden(e.handle, !e.hidden);
                          } else if (v == 'unfollow') {
                            await SocialShareService.openInstagramUnfollow(e.handle);
                          } else if (v == 'remove') {
                            await InstagramFollowingStore.remove(e.handle);
                          }
                          onReload();
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'hide',
                            child: Text(e.hidden ? '다시 표시' : '관심 없음'),
                          ),
                          const PopupMenuItem(value: 'unfollow', child: Text('인스타에서 언팔로우')),
                          const PopupMenuItem(value: 'remove', child: Text('목록에서 제거')),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
