import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/explore_repository.dart';
import '../data/models/explore_user_preview.dart';
import '../data/models/pending_request.dart';

final exploreRepoProvider = Provider((_) => ExploreRepository());

final exploreIslandPreviewsProvider = FutureProvider.autoDispose<List<ExploreUserPreview>>((ref) async {
  final uid = ref.watch(authStateProvider).value?.id;
  return ref.read(exploreRepoProvider).listPublicIslandPreviews(excludeUserId: uid);
});

final incomingPendingRequestsProvider = FutureProvider.autoDispose<List<PendingRequest>>((ref) async {
  final uid = ref.watch(authStateProvider).value?.id;
  if (uid == null) return [];
  return ref.read(exploreRepoProvider).listIncomingPendingRequests(uid);
});

final canOpenChatProvider = FutureProvider.autoDispose.family<bool, String>((ref, peerUserId) async {
  final uid = ref.watch(authStateProvider).value?.id;
  if (uid == null || peerUserId.isEmpty) return false;
  return ref.read(exploreRepoProvider).canOpenChat(myUserId: uid, peerUserId: peerUserId);
});
