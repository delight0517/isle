import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/env.dart';
import '../../island/data/island_repository.dart';
import '../../island/data/models/shelf.dart';
import 'models/explore_user_preview.dart';
import 'models/pending_request.dart';

class ExploreRepository {
  SupabaseClient get _client => Supabase.instance.client;

  bool get ready => Env.isSupabaseConfigured;

  /// 공개 프로필 + 관심 태그 + 책장(없으면 더미 섬)
  Future<List<ExploreUserPreview>> listPublicIslandPreviews({String? excludeUserId, int limit = 12}) async {
    if (!Env.isSupabaseConfigured) return [];
    var q = _client.from('profiles').select('id, display_name, username').eq('is_public', true);
    if (excludeUserId != null) {
      q = q.neq('id', excludeUserId);
    }
    final rows = await q.limit(limit);
    final out = <ExploreUserPreview>[];
    for (final raw in rows as List) {
      final m = Map<String, dynamic>.from(raw as Map);
      final id = m['id'] as String;
      final tagRes = await _client.from('interest_tags').select('tag_name').eq('user_id', id).limit(6);
      final tags = (tagRes as List).map((e) => (e as Map)['tag_name'] as String).toList();
      List<dynamic> shelvesRaw;
      try {
        shelvesRaw = await _client.from('shelves').select().eq('user_id', id).limit(8);
      } catch (_) {
        shelvesRaw = [];
      }
      final shelfList = List<dynamic>.from(shelvesRaw);
      final shelves = shelfList.isEmpty
          ? IslandRepository.dummyShelves()
          : shelfList.map((e) => Shelf.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      out.add(ExploreUserPreview(
        id: id,
        displayName: m['display_name'] as String? ?? '',
        username: m['username'] as String? ?? '',
        interests: tags.isNotEmpty ? tags : const ['관심사 미등록'],
        shelves: shelves,
      ));
    }
    return out;
  }

  Future<void> followUser({required String followerId, required String followingId}) async {
    if (!Env.isSupabaseConfigured) return;
    await _client.from('follows').insert({
      'follower_id': followerId,
      'following_id': followingId,
    });
  }

  /// Request 기반 소셜 진입: 수락 전에는 채팅/대화 스트림을 열지 않기 위한 대기 요청 생성
  Future<void> createPendingRequest({
    required String requesterId,
    required String targetUserId,
    required String purpose,
    required String introMessage,
  }) async {
    if (!Env.isSupabaseConfigured) {
      throw StateError('Supabase가 설정되지 않았습니다.');
    }
    await _client.from('pending_requests').insert({
      'requester_id': requesterId,
      'target_user_id': targetUserId,
      'purpose': purpose,
      'intro_message': introMessage,
      'status': 'pending',
    });
  }

  Future<List<PendingRequest>> listIncomingPendingRequests(String myUserId) async {
    if (!Env.isSupabaseConfigured || myUserId.isEmpty) return [];
    final rows = await _client
        .from('pending_requests')
        .select('id, requester_id, target_user_id, purpose, intro_message, status, created_at, requester:profiles!pending_requests_requester_id_fkey(display_name, username)')
        .eq('target_user_id', myUserId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => PendingRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> updatePendingRequestStatus({
    required String requestId,
    required String status,
  }) async {
    if (!Env.isSupabaseConfigured) return;
    await _client
        .from('pending_requests')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', requestId);
  }

  Future<bool> canOpenChat({
    required String myUserId,
    required String peerUserId,
  }) async {
    if (!Env.isSupabaseConfigured) return false;
    final rows = await _client
        .from('pending_requests')
        .select('id')
        .eq('status', 'accepted')
        .or('and(requester_id.eq.$myUserId,target_user_id.eq.$peerUserId),and(requester_id.eq.$peerUserId,target_user_id.eq.$myUserId)')
        .limit(1);
    return (rows as List).isNotEmpty;
  }
}
