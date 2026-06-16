import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/social/isle_social_store.dart';
import '../../../core/social/models/isle_profile.dart';
import '../../../shared/widgets/isle_app_bar.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late IsleProfile _profile;
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _profile = IsleSocialStore.loadProfile();
    _nameCtrl.text = _profile.displayName;
    _bioCtrl.text = _profile.bio;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image);
    if (r == null || r.files.isEmpty) return;
    final path = r.files.single.path;
    if (path == null) return;
    _profile = _profile.copyWith(avatarPath: path);
    await IsleSocialStore.saveProfile(_profile);
    setState(() {});
  }

  Future<void> _save() async {
    _profile = _profile.copyWith(
      displayName: _nameCtrl.text.trim().isEmpty ? '나의 Isle' : _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
    );
    await IsleSocialStore.saveProfile(_profile);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 저장됨')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = IsleSocialStore.loadPosts().where((p) => p.authorId == _profile.id).length;
    return Scaffold(
      appBar: IsleAppBar(
        title: '내 프로필',
        actions: [
          TextButton(
            onPressed: () => context.push('/social/profile/preview'),
            child: const Text('미리보기'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: IsleColors.ocean100,
                backgroundImage: _profile.avatarPath.isNotEmpty && File(_profile.avatarPath).existsSync()
                    ? FileImage(File(_profile.avatarPath))
                    : null,
                child: _profile.avatarPath.isEmpty
                    ? const Icon(Icons.person, size: 48, color: IsleColors.ocean500)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(onPressed: _pickAvatar, child: const Text('프로필 사진 변경')),
          ),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '소개', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Text('게시물 $posts개', style: IsleText.caption(color: IsleColors.muted)),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('저장')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/social/post/new'),
            icon: const Icon(Icons.add),
            label: const Text('새 게시물'),
          ),
          OutlinedButton.icon(
            onPressed: () => context.push('/social/feed'),
            icon: const Icon(Icons.grid_on),
            label: const Text('내 피드 보기'),
          ),
        ],
      ),
    );
  }
}
