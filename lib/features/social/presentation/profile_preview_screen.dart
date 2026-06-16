import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/social/isle_social_store.dart';
import '../../../core/social/models/isle_post.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// 다른 사람이 보는 내 프로필 (읽기 전용 미리보기)
class ProfilePreviewScreen extends StatelessWidget {
  const ProfilePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = IsleSocialStore.loadProfile();
    final posts = IsleSocialStore.loadPosts().where((p) => p.authorId == profile.id).toList();

    return Scaffold(
      appBar: const IsleAppBar(title: '다른 사람 시점'),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: IsleColors.ocean100,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.white,
                    backgroundImage: profile.avatarPath.isNotEmpty && File(profile.avatarPath).existsSync()
                        ? FileImage(File(profile.avatarPath))
                        : null,
                    child: profile.avatarPath.isEmpty
                        ? const Icon(Icons.person, size: 44, color: IsleColors.ocean500)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(profile.displayName, style: IsleText.subtitle(color: IsleColors.ocean900)),
                  if (profile.bio.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(profile.bio, style: IsleText.body(color: IsleColors.ocean700), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${posts.length}개 게시 · 팔로워 ${IsleSocialStore.loadFollowers().length}명',
                    style: IsleText.caption(color: IsleColors.muted),
                  ),
                ],
              ),
            ),
          ),
          if (posts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text('아직 게시물이 없어요', style: IsleText.body(color: IsleColors.muted)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _PostThumb(post: posts[i]),
                  childCount: posts.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PostThumb extends StatelessWidget {
  const _PostThumb({required this.post});

  final IslePost post;

  @override
  Widget build(BuildContext context) {
    if (post.mediaType == IslePostMediaType.image &&
        post.mediaPath.isNotEmpty &&
        File(post.mediaPath).existsSync()) {
      return Image.file(File(post.mediaPath), fit: BoxFit.cover);
    }
    return ColoredBox(
      color: IsleColors.sand100,
      child: Center(
        child: Icon(
          post.mediaType == IslePostMediaType.video ? Icons.videocam : Icons.article,
          color: IsleColors.muted,
        ),
      ),
    );
  }
}
