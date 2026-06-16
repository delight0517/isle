import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/env.dart';

class SettingsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  bool get hasRemote => Env.isSupabaseConfigured;

  Future<List<String>> listInterestTagNames(String userId) async {
    if (!Env.isSupabaseConfigured) return [];
    final res = await _client.from('interest_tags').select('tag_name').eq('user_id', userId);
    return (res as List).map((e) => (e as Map)['tag_name'] as String).toList();
  }

  Future<void> replaceInterestTags(String userId, List<String> tagNames) async {
    if (!Env.isSupabaseConfigured) return;
    await _client.from('interest_tags').delete().eq('user_id', userId);
    if (tagNames.isEmpty) return;
    await _client.from('interest_tags').insert(
          tagNames.map((n) => {'user_id': userId, 'tag_name': n}).toList(),
        );
  }

  Future<List<Map<String, dynamic>>> listSubscriptions(String userId) async {
    if (!Env.isSupabaseConfigured) return [];
    final res = await _client
        .from('subscriptions')
        .select()
        .eq('user_id', userId)
        .order('connected_at', ascending: false);
    return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> addSubscription({
    required String userId,
    required String platform,
    required String channelId,
    required String channelName,
    String? channelThumbnail,
  }) async {
    if (!Env.isSupabaseConfigured) return;
    await _client.from('subscriptions').insert({
      'user_id': userId,
      'platform': platform,
      'channel_id': channelId,
      'channel_name': channelName,
      'channel_thumbnail': channelThumbnail,
    });
  }

  Future<void> deleteSubscription(String subscriptionId) async {
    if (!Env.isSupabaseConfigured) return;
    await _client.from('subscriptions').delete().eq('id', subscriptionId);
  }
}
