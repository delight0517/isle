import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_typography.dart';
import '../../../core/social/isle_social_store.dart';
import '../../../core/social/models/isle_post.dart';
import '../../../core/social/social_share_service.dart';
import '../../../shared/widgets/isle_app_bar.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionCtrl = TextEditingController();
  String _mediaPath = '';
  IslePostMediaType _mediaType = IslePostMediaType.text;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(FileType type) async {
    final r = await FilePicker.platform.pickFiles(
      type: type == FileType.image ? FileType.image : FileType.video,
    );
    if (r == null || r.files.isEmpty) return;
    final path = r.files.single.path;
    if (path == null) return;
    setState(() {
      _mediaPath = path;
      _mediaType = type == FileType.image ? IslePostMediaType.image : IslePostMediaType.video;
    });
  }

  Future<void> _publish({bool toInstagram = false}) async {
    final profile = IsleSocialStore.loadProfile();
    final post = IslePost(
      id: 'post_${DateTime.now().microsecondsSinceEpoch}',
      authorId: profile.id,
      caption: _captionCtrl.text.trim(),
      mediaType: _mediaType,
      mediaPath: _mediaPath,
    );
    await IsleSocialStore.addPost(post);
    if (toInstagram) {
      await SocialShareService.shareToInstagramStory(
        imagePath: _mediaType == IslePostMediaType.image ? _mediaPath : null,
        text: _captionCtrl.text.trim(),
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toInstagram ? '게시 + 인스타 공유 시트' : 'Isle에 게시됨')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IsleAppBar(title: '새 게시물'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _captionCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '캡션…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickMedia(FileType.image),
                icon: const Icon(Icons.image),
                label: const Text('사진'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _pickMedia(FileType.video),
                icon: const Icon(Icons.videocam),
                label: const Text('영상'),
              ),
            ],
          ),
          if (_mediaPath.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_mediaPath, style: IsleText.caption(), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _publish(),
            child: const Text('Isle에 게시 (팔로워에게 보임)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _publish(toInstagram: true),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('게시 + 인스타 스토리로 공유'),
          ),
        ],
      ),
    );
  }
}
