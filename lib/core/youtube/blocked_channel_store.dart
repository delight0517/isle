import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_local_data_sync.dart';
import '../services/isle_user_defaults.dart';
import 'blocked_channels_repository.dart';
import 'models/blocked_channel.dart';
import 'youtube_block_rules_sync.dart';
import '../../features/auth/providers/auth_provider.dart';

const _boxName = 'isle_blocked_channels';
const _listKey = 'channels_v1';

class BlockedChannelStore {
  BlockedChannelStore._();

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('BlockedChannelStore not initialized. Call ensureOpen() in main().');
    }
    return b;
  }

  static List<BlockedChannel> loadAll() {
    final raw = box.get(_listKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => BlockedChannel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<BlockedChannel> channels) async {
    final payload = channels.map((e) => e.toJson()).toList();
    await box.put(_listKey, jsonEncode(payload));
    isleNotifyLocalDataChanged();
  }

  static List<BlockedChannel>? _pending;
  static Future<void>? _flushFuture;

  /// [Volt] 디스크 I/O 배치 — 400ms 내 연속 저장은 한 번만
  static void scheduleSave(List<BlockedChannel> channels) {
    _pending = List.from(channels);
    _flushFuture ??= Future<void>.delayed(const Duration(milliseconds: 400), () async {
      _flushFuture = null;
      final snapshot = _pending;
      _pending = null;
      if (snapshot != null) await saveAll(snapshot);
    });
  }

  static Future<void> flushPending() async {
    if (_flushFuture != null) await _flushFuture;
    if (_pending != null) await saveAll(_pending!);
    _pending = null;
  }

  static List<BlockedChannel> mergeLists(
    List<BlockedChannel> local,
    List<BlockedChannel> remote,
  ) {
    final byKey = <String, BlockedChannel>{};
    for (final c in [...local, ...remote]) {
      final key = c.channelId.isNotEmpty
          ? c.channelId.toLowerCase()
          : c.channelName.toLowerCase();
      if (key.isEmpty) continue;
      final prev = byKey[key];
      if (prev == null || c.blockedAt.isAfter(prev.blockedAt)) {
        byKey[key] = c;
      }
    }
    final merged = byKey.values.toList()
      ..sort((a, b) => b.blockedAt.compareTo(a.blockedAt));
    return merged;
  }
}

final blockedChannelsRepoProvider = Provider((_) => BlockedChannelsRepository());

final blockedChannelsProvider =
    StateNotifierProvider<BlockedChannelsNotifier, List<BlockedChannel>>(
  BlockedChannelsNotifier.new,
);

class BlockedChannelsNotifier extends StateNotifier<List<BlockedChannel>> {
  BlockedChannelsNotifier(this._ref) : super(BlockedChannelStore.loadAll());

  final Ref _ref;

  Future<void> reload() async {
    await BlockedChannelStore.flushPending();
    state = BlockedChannelStore.loadAll();
  }

  Future<void> syncWithCloud() async {
    if (!IsleUserDefaults.syncBlockedChannelsToCloud) return;
    final user = _ref.read(authStateProvider).value;
    final repo = _ref.read(blockedChannelsRepoProvider);
    if (user == null || !repo.hasRemote) return;

    try {
      final local = BlockedChannelStore.loadAll();
      final remote = await repo.fetchAll(user.id);
      final merged = BlockedChannelStore.mergeLists(local, remote);
      await BlockedChannelStore.saveAll(merged);
      state = merged;

      final toUpload = remote.isEmpty && local.isNotEmpty ? local : merged;
      for (final c in toUpload) {
        await repo.upsert(
          userId: user.id,
          channelId: c.channelId,
          channelName: c.channelName,
          blockedAt: c.blockedAt,
        );
      }
    } catch (_) {
      // 오프라인·미설정 시 로컬만 유지
    }
  }

  Future<void> blockChannel({
    required String channelId,
    required String channelName,
  }) async {
    final id = channelId.trim();
    final name = channelName.trim();
    if (id.isEmpty && name.isEmpty) return;

    final list = BlockedChannelStore.loadAll();
    final existing = list.indexWhere(
      (c) =>
          (id.isNotEmpty && c.channelId == id) ||
          (name.isNotEmpty && c.channelName.toLowerCase() == name.toLowerCase()),
    );
    final entry = BlockedChannel(
      channelId: id.isNotEmpty ? id : name,
      channelName: name.isNotEmpty ? name : id,
      blockedAt: DateTime.now(),
    );
    if (existing >= 0) {
      list[existing] = entry;
    } else {
      list.add(entry);
    }
    BlockedChannelStore.scheduleSave(list);
    state = list;
    YoutubeBlockRulesSync.scheduleExport();

    final user = _ref.read(authStateProvider).value;
    final repo = _ref.read(blockedChannelsRepoProvider);
    if (user != null &&
        repo.hasRemote &&
        IsleUserDefaults.syncBlockedChannelsToCloud) {
      try {
        await repo.upsert(
          userId: user.id,
          channelId: entry.channelId,
          channelName: entry.channelName,
          blockedAt: entry.blockedAt,
        );
      } catch (_) {}
    }
  }

  Future<void> unblock(String channelIdOrName) async {
    final key = channelIdOrName.trim().toLowerCase();
    final removed = BlockedChannelStore.loadAll().where((c) {
      return c.channelId.toLowerCase() == key || c.channelName.toLowerCase() == key;
    }).toList();

    final list = BlockedChannelStore.loadAll()
      ..removeWhere(
        (c) =>
            c.channelId.toLowerCase() == key ||
            c.channelName.toLowerCase() == key,
      );
    BlockedChannelStore.scheduleSave(list);
    state = list;
    YoutubeBlockRulesSync.scheduleExport();

    final user = _ref.read(authStateProvider).value;
    final repo = _ref.read(blockedChannelsRepoProvider);
    if (user != null &&
        repo.hasRemote &&
        IsleUserDefaults.syncBlockedChannelsToCloud) {
      for (final c in removed) {
        try {
          await repo.delete(userId: user.id, channelId: c.channelId);
        } catch (_) {}
      }
    }
  }

  bool isBlocked(FeedChannelRef ref) => state.any((c) => c.matches(ref));
}
