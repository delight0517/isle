import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';
import '../data/models/user_profile.dart';

final authRepoProvider = Provider((_) => AuthRepository());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepoProvider).authStream;
});

final currentUserProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.watch(authRepoProvider).getProfile(user.id);
});
