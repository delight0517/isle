class BlockedChannel {
  final String channelId;
  final String channelName;
  final DateTime blockedAt;

  const BlockedChannel({
    required this.channelId,
    required this.channelName,
    required this.blockedAt,
  });

  Map<String, dynamic> toJson() => {
        'channel_id': channelId,
        'channel_name': channelName,
        'blocked_at': blockedAt.toIso8601String(),
      };

  factory BlockedChannel.fromJson(Map<String, dynamic> j) => BlockedChannel(
        channelId: j['channel_id'] as String? ?? '',
        channelName: j['channel_name'] as String? ?? '',
        blockedAt: DateTime.tryParse(j['blocked_at'] as String? ?? '') ?? DateTime.now(),
      );

  bool matches(FeedChannelRef ref) {
    final id = channelId.trim();
    final rid = ref.channelId.trim();
    if (id.isNotEmpty && rid.isNotEmpty) {
      if (id.toLowerCase() == rid.toLowerCase()) return true;
      if (_handleKey(id) == _handleKey(rid)) return true;
    }
    final a = channelName.trim().toLowerCase();
    final b = ref.channelName.trim().toLowerCase();
    return a.isNotEmpty && b.isNotEmpty && a == b;
  }

  static String _handleKey(String s) {
    final l = s.toLowerCase();
    return l.startsWith('@') ? l.substring(1) : l;
  }
}

class FeedChannelRef {
  final String channelId;
  final String channelName;

  const FeedChannelRef({required this.channelId, required this.channelName});
}
