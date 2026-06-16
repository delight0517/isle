import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import '../services/isle_local_data_sync.dart';
import 'models/isle_post.dart';
import 'models/isle_profile.dart';

/// Isle 자체 프로필·게시·팔로워 (로컬 — iOS/Android 동일)
class IsleSocialStore {
  IsleSocialStore._();

  static const _boxName = 'isle_social';
  static const _profileKey = 'my_profile';
  static const _postsKey = 'posts_v1';
  static const _followersKey = 'followers_v1';
  static const _followingKey = 'following_isle_v1';

  static Box<String>? _box;

  static String _newId() => 'isle_${DateTime.now().microsecondsSinceEpoch}';

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
    if (_box!.get(_profileKey) == null) {
      await saveProfile(
        IsleProfile(
          id: _newId(),
          displayName: '나의 Isle',
          bio: '팔로워에게만 보이는 섬',
        ),
      );
    }
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('IsleSocialStore not open');
    return b;
  }

  static IsleProfile loadProfile() {
    final raw = box.get(_profileKey);
    if (raw == null) {
      return IsleProfile(id: _newId(), displayName: '나의 Isle');
    }
    return IsleProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> saveProfile(IsleProfile p) async {
    await box.put(_profileKey, jsonEncode(p.toJson()));
    isleNotifyLocalDataChanged();
  }

  static List<IslePost> loadPosts() {
    final raw = box.get(_postsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => IslePost.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    } catch (_) {
      return [];
    }
  }

  static List<IslePost> postsForFeed() {
    final me = loadProfile().id;
    final following = loadFollowingIsleIds();
    final ids = {...following, me};
    return loadPosts().where((p) => ids.contains(p.authorId)).toList();
  }

  static Future<void> addPost(IslePost post) async {
    final list = loadPosts()..add(post);
    await box.put(_postsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static Future<void> toggleLike(String postId) async {
    final list = loadPosts();
    final i = list.indexWhere((p) => p.id == postId);
    if (i < 0) return;
    final p = list[i];
    final liked = !p.likedByMe;
    list[i] = p.copyWith(
      likedByMe: liked,
      likeCount: (p.likeCount + (liked ? 1 : -1)).clamp(0, 999999),
    );
    await box.put(_postsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static List<String> loadFollowers() {
    final raw = box.get(_followersKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>).map((e) => e.toString()).toList();
  }

  static List<String> loadFollowingIsleIds() {
    final raw = box.get(_followingKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>).map((e) => e.toString()).toList();
  }

  static Map<String, dynamic> exportBundle() => {
        'profile': loadProfile().toJson(),
        'posts': loadPosts().map((e) => e.toJson()).toList(),
        'followers': loadFollowers(),
        'following_isle_ids': loadFollowingIsleIds(),
      };

  static Future<void> importBundle(Map<String, dynamic>? raw) async {
    if (raw == null) return;
    final profile = raw['profile'];
    if (profile is Map) {
      await saveProfile(IsleProfile.fromJson(Map<String, dynamic>.from(profile)));
    }
    final posts = raw['posts'];
    if (posts is List) {
      final list = posts
          .whereType<Map>()
          .map((e) => IslePost.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (list.isNotEmpty) {
        await box.put(_postsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
      }
    }
    final followers = raw['followers'];
    if (followers is List) {
      await box.put(_followersKey, jsonEncode(followers.map((e) => e.toString()).toList()));
    }
    isleNotifyLocalDataChanged();
  }

  static Future<void> addFollower(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    final list = loadFollowers();
    if (!list.contains(n)) {
      list.add(n);
      await box.put(_followersKey, jsonEncode(list));
      isleNotifyLocalDataChanged();
    }
  }
}
