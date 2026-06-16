import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/env.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/settings_repository.dart';

final settingsRepoProvider = Provider((_) => SettingsRepository());

final userInterestTagsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return IsleUserDefaults.onboardingInterestTags;
  if (!Env.isSupabaseConfigured) return IsleUserDefaults.onboardingInterestTags;
  try {
    final remote = await ref.read(settingsRepoProvider).listInterestTagNames(user.id);
    if (remote.isNotEmpty) return remote;
  } catch (_) {}
  return IsleUserDefaults.onboardingInterestTags;
});

final userSubscriptionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null || !Env.isSupabaseConfigured) return [];
  return ref.read(settingsRepoProvider).listSubscriptions(user.id);
});
