import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_local_data_sync.dart';
import '../utils/topic_matcher.dart';
import 'models/feed_boost_preference.dart';

const _boxName = 'isle_feed_boost';
const _channelsKey = 'channels_v1';
const _genresKey = 'genres_v1';

class FeedBoostStore {
  FeedBoostStore._();

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('FeedBoostStore not open');
    return b;
  }

  static List<FeedBoostChannel> loadChannels() => _decodeList(
        box.get(_channelsKey),
        FeedBoostChannel.fromJson,
      );

  static List<FeedBoostGenre> loadGenres() => _decodeList(
        box.get(_genresKey),
        FeedBoostGenre.fromJson,
      );

  static List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveChannels(List<FeedBoostChannel> list) async {
    await box.put(_channelsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static Future<void> saveGenres(List<FeedBoostGenre> list) async {
    await box.put(_genresKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  /// 영상 맥락에서 장르·키워드 추론 (로컬, API 없음)
  static FeedBoostGenre inferGenre({
    required String videoTitle,
    required String channelName,
    required String videoUrl,
  }) {
    final topics = TopicMatcher.detectTopics('$videoTitle $channelName');
    final words = videoTitle
        .replaceAll(RegExp(r'[^\w\s가-힣]'), ' ')
        .split(RegExp(r'\s+'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.length >= 2)
        .where((e) => !_stopWords.contains(e))
        .take(8)
        .toList();
    final label = topics.isNotEmpty ? topics.join(' · ') : (words.isNotEmpty ? words.first : '이 스타일');
    return FeedBoostGenre(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      topics: topics,
      keywords: words,
      sourceVideoUrl: videoUrl,
      sourceVideoTitle: videoTitle,
      savedAt: DateTime.now(),
    );
  }

  static const _stopWords = {
    'the', 'and', 'for', 'with', 'video', 'official', 'mv', 'ep', 'ft',
    '영상', '쇼츠', 'shorts', 'full',
  };
}

final feedBoostChannelsProvider =
    StateNotifierProvider<FeedBoostChannelsNotifier, List<FeedBoostChannel>>((ref) {
  return FeedBoostChannelsNotifier();
});

final feedBoostGenresProvider =
    StateNotifierProvider<FeedBoostGenresNotifier, List<FeedBoostGenre>>((ref) {
  return FeedBoostGenresNotifier();
});

class FeedBoostChannelsNotifier extends StateNotifier<List<FeedBoostChannel>> {
  FeedBoostChannelsNotifier() : super(FeedBoostStore.loadChannels());

  Future<void> reload() async {
    state = FeedBoostStore.loadChannels();
  }

  Future<void> addFromWatch({
    required String channelId,
    required String channelName,
    required String videoUrl,
    required String videoTitle,
  }) async {
    final list = List<FeedBoostChannel>.from(state);
    final idx = list.indexWhere(
      (c) => c.matches(id: channelId, name: channelName),
    );
    if (idx >= 0) {
      final prev = list[idx];
      list[idx] = prev.copyWith(weight: (prev.weight + 1).clamp(1, 5));
    } else {
      list.insert(
        0,
        FeedBoostChannel(
          channelId: channelId,
          channelName: channelName,
          sourceVideoUrl: videoUrl,
          sourceVideoTitle: videoTitle,
          savedAt: DateTime.now(),
        ),
      );
    }
    if (list.length > 80) list.length = 80;
    await FeedBoostStore.saveChannels(list);
    state = list;
  }

  Future<void> removeAt(int index) async {
    final list = List<FeedBoostChannel>.from(state)..removeAt(index);
    await FeedBoostStore.saveChannels(list);
    state = list;
  }
}

class FeedBoostGenresNotifier extends StateNotifier<List<FeedBoostGenre>> {
  FeedBoostGenresNotifier() : super(FeedBoostStore.loadGenres());

  Future<void> reload() async {
    state = FeedBoostStore.loadGenres();
  }

  Future<void> addGenre(FeedBoostGenre genre) async {
    final list = List<FeedBoostGenre>.from(state);
    final idx = list.indexWhere((g) => g.label == genre.label);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(weight: (list[idx].weight + 1).clamp(1, 5));
    } else {
      list.insert(0, genre);
    }
    if (list.length > 40) list.length = 40;
    await FeedBoostStore.saveGenres(list);
    state = list;
  }

  Future<void> removeAt(int index) async {
    final list = List<FeedBoostGenre>.from(state)..removeAt(index);
    await FeedBoostStore.saveGenres(list);
    state = list;
  }
}
