import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/social/isle_social_store.dart';
import '../../../core/social/models/isle_post.dart';
import '../../../shared/widgets/isle_app_bar.dart';

class IsleSocialFeedScreen extends StatefulWidget {
  const IsleSocialFeedScreen({super.key});

  @override
  State<IsleSocialFeedScreen> createState() => _IsleSocialFeedScreenState();
}

class _IsleSocialFeedScreenState extends State<IsleSocialFeedScreen> {
  @override
  Widget build(BuildContext context) {
    final profile = IsleSocialStore.loadProfile();
    final posts = IsleSocialStore.postsForFeed();

    return Scaffold(
      appBar: IsleAppBar(
        title: 'Isle 피드',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/social/post/new'),
          ),
        ],
      ),
      body: posts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('팔로워에게 보일 게시물이 없어요', style: IsleText.body(color: IsleColors.muted)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.push('/social/post/new'),
                    child: const Text('첫 게시물'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: posts.length,
              itemBuilder: (ctx, i) {
                final p = posts[i];
                final isMe = p.authorId == profile.id;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (p.mediaType == IslePostMediaType.image &&
                          p.mediaPath.isNotEmpty &&
                          File(p.mediaPath).existsSync())
                        AspectRatio(
                          aspectRatio: 1,
                          child: Image.file(File(p.mediaPath), fit: BoxFit.cover),
                        ),
                      if (p.mediaType == IslePostMediaType.video && p.mediaPath.isNotEmpty)
                        Container(
                          height: 120,
                          color: IsleColors.ocean100,
                          alignment: Alignment.center,
                          child: const Icon(Icons.play_circle_outline, size: 48),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isMe ? profile.displayName : '팔로잉', style: IsleText.subtitle()),
                            if (p.caption.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(p.caption, style: IsleText.body()),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    p.likedByMe ? Icons.favorite : Icons.favorite_border,
                                    color: p.likedByMe ? IsleColors.danger : null,
                                  ),
                                  onPressed: () async {
                                    await IsleSocialStore.toggleLike(p.id);
                                    setState(() {});
                                  },
                                ),
                                Text('${p.likeCount}', style: IsleText.caption()),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
