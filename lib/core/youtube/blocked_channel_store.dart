import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../ai/block_chat/block_audit_log_store.dart';
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

  /// [Volt] scheduleSave()로 아직 디스크에 flush되지 않은 변경이 있으면 그걸,
  /// 없으면 loadAll()(디스크)을 반환한다. 400ms 배치 창 안에서 두 번째
  /// write가 loadAll()(아직 이전 write가 반영 안 된 stale 디스크 상태)을
  /// 기준으로 새 리스트를 만들면 첫 번째 write가 통째로 유실된다 — 피드에서
  /// 채널을 빠르게 연속 차단하면 마지막 것만 남고 나머지는 사라지는 버그의
  /// 근본 원인이었다(2026-07-20). 모든 write 경로는 반드시 이 메서드를
  /// 기준으로 다음 리스트를 만들어야 한다.
  static List<BlockedChannel> currentList() =>
      _pending != null ? List<BlockedChannel>.from(_pending!) : loadAll();

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
      await BlockedChannelStore.flushPending();
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

    final list = BlockedChannelStore.currentList();
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
    await _logChannelChange(
      action: 'block_channel',
      summary: '「${entry.channelName}」 채널 차단 (${existing >= 0 ? "갱신" : "신규"})',
    );

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
    final removed = BlockedChannelStore.currentList().where((c) {
      return c.channelId.toLowerCase() == key || c.channelName.toLowerCase() == key;
    }).toList();

    final list = BlockedChannelStore.currentList()
      ..removeWhere(
        (c) =>
            c.channelId.toLowerCase() == key ||
            c.channelName.toLowerCase() == key,
      );
    BlockedChannelStore.scheduleSave(list);
    state = list;
    YoutubeBlockRulesSync.scheduleExport();
    if (removed.isNotEmpty) {
      await _logChannelChange(
        action: 'unblock_channel',
        summary: '채널 차단 해제: ${removed.map((c) => c.channelName).join(" · ")}',
      );
    }

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

  /// 채팅 경로(BlockChatExecutor)는 이미 자체적으로 BlockAuditLogStore에
  /// 기록한다 — 이건 피드 스와이프·차단 시트 등 채팅을 거치지 않는 직접
  /// UI 경로용. "왜 이 채널이 차단/해제됐는지" AI가 진단할 때 채팅으로
  /// 바뀐 것만 보이고 이 경로는 안 보이면 원인 분석에 구멍이 생긴다
  /// (2026-07-20 사용자 요청).
  Future<void> _logChannelChange({
    required String action,
    required String summary,
  }) async {
    try {
      await BlockAuditLogStore.ensureOpen();
      await BlockAuditLogStore.record(
        command: '(채널 UI) $action',
        action: action,
        summary: summary,
        steps: const [],
        success: true,
      );
    } catch (_) {
      // 로그 기록 실패가 실제 차단 동작을 막으면 안 됨.
    }
  }
}
