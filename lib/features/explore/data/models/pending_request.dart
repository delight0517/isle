class PendingRequest {
  final String id;
  final String requesterId;
  final String targetUserId;
  final String purpose;
  final String introMessage;
  final String status;
  final DateTime createdAt;
  final String requesterDisplay;
  final String requesterUsername;
  final String targetDisplay;
  final String targetUsername;

  const PendingRequest({
    required this.id,
    required this.requesterId,
    required this.targetUserId,
    required this.purpose,
    required this.introMessage,
    required this.status,
    required this.createdAt,
    required this.requesterDisplay,
    required this.requesterUsername,
    required this.targetDisplay,
    required this.targetUsername,
  });

  factory PendingRequest.fromJson(Map<String, dynamic> j) {
    final requester = Map<String, dynamic>.from((j['requester'] as Map?) ?? const {});
    final target = Map<String, dynamic>.from((j['target'] as Map?) ?? const {});
    return PendingRequest(
      id: j['id'] as String,
      requesterId: j['requester_id'] as String,
      targetUserId: j['target_user_id'] as String,
      purpose: j['purpose'] as String? ?? '',
      introMessage: j['intro_message'] as String? ?? '',
      status: j['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      requesterDisplay: requester['display_name'] as String? ?? '',
      requesterUsername: requester['username'] as String? ?? '',
      targetDisplay: target['display_name'] as String? ?? '',
      targetUsername: target['username'] as String? ?? '',
    );
  }
}
