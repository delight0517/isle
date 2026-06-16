import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/env.dart';
import 'models/blocked_channel.dart';

class BlockedChannelsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  bool get hasRemote => Env.isSupabaseConfigured;

  Future<List<BlockedChannel>> fetchAll(String userId) async {
    if (!hasRemote) return [];
    final res = await _client
        .from('blocked_channels')
        .select()
        .eq('user_id', userId)
        .order('blocked_at', ascending: false);
    return (res as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return BlockedChannel(
        channelId: m['channel_id'] as String? ?? '',
        channelName: m['channel_name'] as String? ?? '',
        blockedAt: DateTime.tryParse(m['blocked_at'] as String? ?? '') ?? DateTime.now(),
      );
    }).toList();
  }

  Future<void> upsert({
    required String userId,
    required String channelId,
    required String channelName,
    required DateTime blockedAt,
  }) async {
    if (!hasRemote) return;
    await _client.from('blocked_channels').upsert({
      'user_id': userId,
      'channel_id': channelId,
      'channel_name': channelName,
      'blocked_at': blockedAt.toIso8601String(),
    }, onConflict: 'user_id,channel_id');
  }

  Future<void> delete({
    required String userId,
    required String channelId,
  }) async {
    if (!hasRemote || channelId.isEmpty) return;
    await _client
        .from('blocked_channels')
        .delete()
        .eq('user_id', userId)
        .eq('channel_id', channelId);
  }
}
