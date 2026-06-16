import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/archive_repository.dart';

final archiveRepoProvider = Provider((_) => ArchiveRepository());
