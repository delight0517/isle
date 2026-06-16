import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_local_data_sync.dart';
import '../../features/island/data/models/island_snapshot.dart';

class IslandSnapshotStore {
  IslandSnapshotStore._();

  static const _boxName = 'isle_island_snapshots';
  static const _indexKey = 'period_keys';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('IslandSnapshotStore not open');
    return b;
  }

  static String periodKeyFor(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

  static String get currentPeriodKey => periodKeyFor(DateTime.now());

  static List<String> listPeriodKeys() {
    final raw = box.get(_indexKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList()..sort();
    } catch (_) {
      return [];
    }
  }

  static IslandMonthlySnapshot? load(String periodKey) {
    final raw = box.get(periodKey);
    if (raw == null) return null;
    try {
      return IslandMonthlySnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(IslandMonthlySnapshot snapshot) async {
    await box.put(snapshot.periodKey, jsonEncode(snapshot.toJson()));
    final keys = listPeriodKeys().toSet()..add(snapshot.periodKey);
    await box.put(_indexKey, jsonEncode(keys.toList()));
    isleNotifyLocalDataChanged();
  }

  /// 새 달이 되면 이전 달 스냅샷 자동 저장 (1회)
  static Future<void> rolloverIfNeeded(IslandMonthlySnapshot currentLive) async {
    final now = DateTime.now();
    final current = currentPeriodKey;
    final keys = listPeriodKeys();
    if (keys.contains(current)) return;
    if (keys.isNotEmpty && currentLive.shelves.isNotEmpty) {
      final prev = keys.last;
      if (load(prev) == null) {
        await save(
          IslandMonthlySnapshot(
            periodKey: prev,
            savedAt: DateTime(now.year, now.month - 1, 1),
            shelves: currentLive.shelves,
            archivesByShelfId: currentLive.archivesByShelfId,
            interestWeights: currentLive.interestWeights,
            summary: '자동 저장 ($prev)',
          ),
        );
      }
    }
    await save(currentLive);
  }
}
