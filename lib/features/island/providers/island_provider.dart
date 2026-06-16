import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/island_repository.dart';
import '../data/models/shelf.dart';
import '../../auth/providers/auth_provider.dart';

final islandRepoProvider = Provider((_) => IslandRepository());

final shelvesProvider = FutureProvider<List<Shelf>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return IslandRepository.dummyShelves();
  return ref.watch(islandRepoProvider).getShelves(user.id);
});
