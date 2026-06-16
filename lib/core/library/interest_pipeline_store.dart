import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_local_data_sync.dart';
import 'models/interest_item.dart';

const _boxName = 'isle_interest_pipeline';
const _itemsKey = 'items_v1';

class InterestPipelineStore {
  InterestPipelineStore._();

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('InterestPipelineStore not open');
    return b;
  }

  static List<InterestItem> loadAll() {
    final raw = box.get(_itemsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => InterestItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<InterestItem> items) async {
    await box.put(_itemsKey, jsonEncode(items.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static Future<InterestItem> enqueue({
    required String url,
    required String title,
    String sourceType = 'youtube',
    String channelName = '',
    required int daysUntilArticle,
  }) async {
    final list = loadAll();
    final id = 'int_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final queued = list.where((e) => e.status == 'queued').toList();
    String? groupId;
    if (queued.isNotEmpty) {
      for (final e in queued) {
        if (e.mergeGroupId != null) {
          groupId = e.mergeGroupId;
          break;
        }
      }
      groupId ??= 'grp_${now.millisecondsSinceEpoch}';
      for (var i = 0; i < list.length; i++) {
        if (list[i].status == 'queued' && list[i].mergeGroupId == null) {
          list[i] = list[i].copyWith(mergeGroupId: groupId);
        }
      }
    }

    final item = InterestItem(
      id: id,
      url: url,
      title: title,
      sourceType: sourceType,
      channelName: channelName,
      markedAt: now,
      publishArticleAt: now.add(Duration(days: daysUntilArticle)),
      status: 'queued',
      mergeGroupId: groupId,
      processLog: [
        '${now.toIso8601String()} 관심 표시 — ${daysUntilArticle}일 후 기사 예정'
            '${groupId != null ? ' · 묶음 $groupId' : ''}',
      ],
    );
    list.add(item);
    await saveAll(list);
    return item;
  }

  static Future<void> update(InterestItem item) async {
    final list = loadAll();
    final idx = list.indexWhere((e) => e.id == item.id);
    if (idx >= 0) list[idx] = item;
    await saveAll(list);
  }
}

final interestPipelineProvider =
    StateNotifierProvider<InterestPipelineNotifier, List<InterestItem>>((ref) {
  return InterestPipelineNotifier();
});

class InterestPipelineNotifier extends StateNotifier<List<InterestItem>> {
  InterestPipelineNotifier() : super(InterestPipelineStore.loadAll());

  Future<void> reload() async {
    state = InterestPipelineStore.loadAll();
  }

  Future<InterestItem> markInterested({
    required String url,
    required String title,
    String sourceType = 'youtube',
    String channelName = '',
    int daysUntilArticle = 3,
  }) async {
    final item = await InterestPipelineStore.enqueue(
      url: url,
      title: title,
      sourceType: sourceType,
      channelName: channelName,
      daysUntilArticle: daysUntilArticle,
    );
    state = InterestPipelineStore.loadAll();
    return item;
  }
}
