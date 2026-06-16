import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../features/island/data/models/shelf.dart';
import '../services/isle_local_data_sync.dart';

/// Supabase 없이·오프라인에서도 책장 추가 (로컬 Hive)
class LocalShelfStore {
  LocalShelfStore._();

  static const _boxName = 'isle_local_shelves';
  static const _keyPrefix = 'uid_';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('LocalShelfStore not open');
    return b;
  }

  static String _key(String userId) => '$_keyPrefix${userId.isEmpty ? 'local' : userId}';

  static List<Shelf> load(String userId) {
    final raw = box.get(_key(userId));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Shelf.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Shelf> add({
    required String userId,
    required String title,
    required String iconEmoji,
    required int positionX,
    required int positionY,
  }) async {
    final list = load(userId);
    final shelf = Shelf(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId.isEmpty ? 'local' : userId,
      title: title,
      iconEmoji: iconEmoji,
      positionX: positionX,
      positionY: positionY,
      createdAt: DateTime.now(),
    );
    list.add(shelf);
    await saveAll(userId, list);
    return shelf;
  }

  static Future<void> saveAll(String userId, List<Shelf> shelves) async {
    await box.put(_key(userId), jsonEncode(shelves.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }
}
