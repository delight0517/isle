import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/youtube/blocked_channel_store.dart';
import 'package:isle/core/youtube/models/blocked_channel.dart';

/// 회귀 테스트 — 피드에서 짧은 시간 안에 채널을 연속으로 차단(또는
/// 차단+해제)하면 scheduleSave()의 400ms 배치 창 안에서 나중 write가
/// loadAll()(아직 디스크에 반영 안 된 stale 상태)을 기준으로 새 리스트를
/// 만들어 앞선 write를 통째로 덮어써 유실시키던 버그(2026-07-20 사용자
/// 제보: "차단해도 반영이 안 됨"). currentList()로 고쳤으므로 여기서
/// 재발을 막는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('isle_blocked_channel_race_test');
    Hive.init(dir.path);
    await BlockedChannelStore.ensureOpen();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('400ms 배치 창 안에서 연속으로 두 채널을 차단하면 둘 다 살아남는다', () async {
    // blockChannel()이 실제로 하는 것과 동일한 패턴: currentList()로 최신
    // in-memory 상태를 얻어 항목을 추가하고 scheduleSave()한다.
    final list1 = BlockedChannelStore.currentList();
    list1.add(BlockedChannel(
      channelId: 'UCaaaaaaaaaaaaaaaaaaaaaa',
      channelName: 'channel-a',
      blockedAt: DateTime.now(),
    ));
    BlockedChannelStore.scheduleSave(list1);

    // 400ms flush가 돌기 전에 두 번째 차단이 들어온다 (빠른 연속 스와이프).
    final list2 = BlockedChannelStore.currentList();
    list2.add(BlockedChannel(
      channelId: 'UCbbbbbbbbbbbbbbbbbbbbbb',
      channelName: 'channel-b',
      blockedAt: DateTime.now(),
    ));
    BlockedChannelStore.scheduleSave(list2);

    await BlockedChannelStore.flushPending();

    final saved = BlockedChannelStore.loadAll();
    final ids = saved.map((c) => c.channelId).toSet();
    expect(ids, containsAll(<String>['UCaaaaaaaaaaaaaaaaaaaaaa', 'UCbbbbbbbbbbbbbbbbbbbbbb']));
    expect(saved, hasLength(2));
  });

  test('배치 창 안에서 차단 후 곧바로 다른 채널을 해제해도 두 변경이 모두 반영된다', () async {
    // 먼저 채널 C를 저장된 상태로 만들어 둔다.
    await BlockedChannelStore.saveAll([
      BlockedChannel(
        channelId: 'UCcccccccccccccccccccccc',
        channelName: 'channel-c',
        blockedAt: DateTime.now(),
      ),
    ]);

    // 채널 D를 차단.
    final afterBlock = BlockedChannelStore.currentList();
    afterBlock.add(BlockedChannel(
      channelId: 'UCdddddddddddddddddddddd',
      channelName: 'channel-d',
      blockedAt: DateTime.now(),
    ));
    BlockedChannelStore.scheduleSave(afterBlock);

    // flush되기 전에 채널 C를 해제 — unblock()과 동일하게 currentList() 기준.
    final afterUnblock = BlockedChannelStore.currentList()
      ..removeWhere((c) => c.channelId == 'UCcccccccccccccccccccccc');
    BlockedChannelStore.scheduleSave(afterUnblock);

    await BlockedChannelStore.flushPending();

    final saved = BlockedChannelStore.loadAll();
    final ids = saved.map((c) => c.channelId).toSet();
    expect(ids, contains('UCdddddddddddddddddddddd'));
    expect(ids, isNot(contains('UCcccccccccccccccccccccc')));
  });
}
