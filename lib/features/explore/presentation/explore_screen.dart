import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/localization/app_strings.dart';
import '../../auth/providers/auth_provider.dart';
import '../../island/data/island_repository.dart';
import '../data/models/explore_user_preview.dart';
import '../providers/explore_provider.dart';
import 'widgets/friend_island_card.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  static List<FriendIslandData> _fallbackFriends() => List.generate(
        6,
        (i) => FriendIslandData(
          name: ['지은', '민수', '준서', '아라', '현우', '소연'][i],
          interests: [
            ['디자인', 'UX'],
            ['기술/IT'],
            ['재무'],
            ['음악', '영화'],
            ['과학'],
            ['자기계발'],
          ][i],
          shelves: IslandRepository.dummyShelves(),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewsAsync = ref.watch(exploreIslandPreviewsProvider);
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(s.t('explore'), style: IsleText.subtitle()),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => context.push('/explore/requests'),
            icon: const Icon(Icons.mark_email_unread_outlined),
            tooltip: s.t('request_inbox'),
          ),
        ],
      ),
      body: previewsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ExploreBody(friends: _fallbackFriends(), suggested: _fallbackFriends()),
        data: (previews) {
          if (previews.isEmpty) {
            final f = _fallbackFriends();
            return _ExploreBody(friends: f, suggested: f);
          }
          final friends = previews.map((p) {
            return FriendIslandData(
              name: p.displayName.isNotEmpty ? p.displayName : p.username,
              interests: p.interests,
              shelves: p.shelves,
              userId: p.id,
            );
          }).toList();
          return _ExploreBody(friends: friends, suggested: previews);
        },
      ),
    );
  }
}

class _ExploreBody extends StatelessWidget {
  final List<FriendIslandData> friends;
  final Object suggested;
  const _ExploreBody({required this.friends, required this.suggested});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isPreview = suggested is List<ExploreUserPreview>;
    final previews = isPreview ? suggested as List<ExploreUserPreview> : null;
    final dummySuggested = !isPreview ? suggested as List<FriendIslandData> : null;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Card(
            color: const Color(0xFFFDF2F7),
            child: ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFFE1306C)),
              title: Text('소셜 · 인스타 · Isle 게시', style: IsleText.subtitle()),
              subtitle: const Text('구독 관리 · 프로필 미리보기'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/social'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(s.t('public_islands'), style: IsleText.subtitle()),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: friends.length,
            itemBuilder: (_, i) => FriendIslandCard(data: friends[i])
                .animate(delay: (i * 60).ms)
                .fadeIn()
                .slideX(begin: 0.15),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(s.t('similar_interests'), style: IsleText.subtitle()),
        ),
        if (previews != null)
          ...previews.asMap().entries.map(
                (e) => _ExploreSuggestedTile(preview: e.value)
                    .animate(delay: (e.key * 50).ms)
                    .fadeIn(),
              )
        else
          ...dummySuggested!.asMap().entries.map(
                (e) => _DummySuggestedTile(data: e.value).animate(delay: (e.key * 50).ms).fadeIn(),
              ),
      ],
    );
  }
}

class _ExploreSuggestedTile extends ConsumerWidget {
  final ExploreUserPreview preview;
  const _ExploreSuggestedTile({required this.preview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final label = preview.displayName.isNotEmpty ? preview.displayName : preview.username;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: IsleColors.ocean100,
        child: Text(label.isNotEmpty ? label[0] : '?', style: IsleText.subtitle(color: IsleColors.ocean500)),
      ),
      title: Text(label, style: IsleText.body()),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(preview.interests.join(', '), style: IsleText.caption(color: IsleColors.muted)),
          const SizedBox(height: 6),
          InterestDnaBars(interests: preview.interests),
        ],
      ),
      trailing: OutlinedButton(
        onPressed: () async {
          final me = ref.read(authStateProvider).value;
          if (me == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(s.t('follow_requires_login'))),
            );
            return;
          }
          try {
            await ref.read(exploreRepoProvider).followUser(followerId: me.id, followingId: preview.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('follow_success'))));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
            }
          }
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          side: const BorderSide(color: IsleColors.ocean500),
        ),
        child: Text(s.t('follow'), style: IsleText.caption(color: IsleColors.ocean500)),
      ),
      onTap: () => _openRequestSheet(
        context,
        targetName: label,
        onSubmit: (purpose, intro) async {
          final me = ref.read(authStateProvider).value;
          if (me == null) {
            throw StateError(s.t('request_requires_login'));
          }
          await ref.read(exploreRepoProvider).createPendingRequest(
                requesterId: me.id,
                targetUserId: preview.id,
                purpose: purpose,
                introMessage: intro,
              );
        },
      ),
    );
  }
}

class _DummySuggestedTile extends StatelessWidget {
  final FriendIslandData data;
  const _DummySuggestedTile({required this.data});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: CircleAvatar(
          backgroundColor: IsleColors.ocean100,
          child: Text(data.name[0], style: IsleText.subtitle(color: IsleColors.ocean500)),
        ),
        title: Text(data.name, style: IsleText.body()),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.interests.join(', '), style: IsleText.caption(color: IsleColors.muted)),
            const SizedBox(height: 6),
            InterestDnaBars(interests: data.interests),
          ],
        ),
        trailing: OutlinedButton(
          onPressed: () => _openRequestSheet(context, targetName: data.name),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            side: const BorderSide(color: IsleColors.ocean500),
          ),
          child: Text(AppStrings.of(context).t('request_send'), style: IsleText.caption(color: IsleColors.ocean500)),
        ),
        onTap: () => _openRequestSheet(context, targetName: data.name),
      );
}

class InterestDnaBars extends StatelessWidget {
  final List<String> interests;
  const InterestDnaBars({super.key, required this.interests});

  static const _palette = [
    Color(0xFF4D89FF),
    Color(0xFFE85693),
    Color(0xFFF4C542),
    Color(0xFF52C88D),
    Color(0xFF8F7DF2),
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final count = interests.isEmpty ? 1 : interests.length;
    final segments = interests.isEmpty ? [s.t('discovering')] : interests.take(4).toList();
    final unit = 1 / segments.length;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Row(
              children: segments.asMap().entries.map((e) {
                return Expanded(
                  flex: (unit * 100).round(),
                  child: Container(
                    height: 7,
                    color: _palette[e.key % _palette.length].withValues(alpha: count > 3 ? 0.95 : 0.8),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${(100 / count).round()}%', style: IsleText.badge(color: IsleColors.muted)),
      ],
    );
  }
}

void _openRequestSheet(
  BuildContext context, {
  required String targetName,
  Future<void> Function(String purpose, String intro)? onSubmit,
}) {
  final s = AppStrings.of(context);
  final purposeCtrl = TextEditingController();
  final introCtrl = TextEditingController();
  var sending = false;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Padding(
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
            Text(s.t('request_send_title', args: {'name': targetName}), style: IsleText.subtitle()),
            const SizedBox(height: 12),
            TextField(
              controller: purposeCtrl,
              decoration: InputDecoration(
                labelText: s.t('request_purpose'),
                hintText: s.t('request_purpose_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: introCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: s.t('request_message'),
                hintText: s.t('request_message_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: sending
                  ? null
                  : () async {
                      final purpose = purposeCtrl.text.trim();
                      final intro = introCtrl.text.trim();
                      if (purpose.isEmpty) return;
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        setModalState(() => sending = true);
                        if (onSubmit != null) {
                          await onSubmit(purpose, intro);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(content: Text(s.t('request_sent'))),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      } finally {
                        if (ctx.mounted) {
                          setModalState(() => sending = false);
                        }
                      }
                    },
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(s.t('request_send')),
            ),
          ],
        ),
      ),
    ),
  ).whenComplete(() {
    purposeCtrl.dispose();
    introCtrl.dispose();
  });
}
