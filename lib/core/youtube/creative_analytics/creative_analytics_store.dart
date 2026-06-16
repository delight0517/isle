import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'models/bench_channel.dart';
import 'models/channel_video_snapshot.dart';
import 'models/growth_path_bundle.dart';
import 'models/narrative_report.dart';
import 'models/outlier_hit.dart';

class CreativeAnalyticsStore {
  CreativeAnalyticsStore._();

  static const _boxName = 'isle_yt_creative_analytics';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('CreativeAnalyticsStore.ensureOpen() first');
    return b;
  }

  static List<BenchChannel> loadChannels() {
    final raw = box.get('channels_v1');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => BenchChannel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveChannels(List<BenchChannel> list) async {
    await box.put('channels_v1', jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<void> upsertChannel(BenchChannel ch) async {
    final list = loadChannels();
    list.removeWhere((e) => e.id == ch.id);
    list.insert(0, ch);
    await saveChannels(list);
  }

  static Future<void> removeChannel(String id) async {
    final list = loadChannels()..removeWhere((e) => e.id == id);
    await saveChannels(list);
    await box.delete('videos_$id');
    await box.delete('outliers_$id');
  }

  static Future<void> saveVideos(String channelId, List<ChannelVideoSnapshot> videos) async {
    await box.put(
      'videos_$channelId',
      jsonEncode(videos.map((e) => e.toJson()).toList()),
    );
  }

  static List<ChannelVideoSnapshot> loadVideos(String channelId) {
    final raw = box.get('videos_$channelId');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ChannelVideoSnapshot.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveOutliers(String channelId, List<OutlierHit> hits) async {
    await box.put(
      'outliers_$channelId',
      jsonEncode(hits.map((e) => e.toJson()).toList()),
    );
  }

  static List<OutlierHit> loadOutliers(String channelId) {
    final raw = box.get('outliers_$channelId');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => OutlierHit.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveNarrative(NarrativeReport report) async {
    final raw = box.get('narratives_v1');
    final list = <NarrativeReport>[];
    if (raw != null) {
      try {
        for (final item in jsonDecode(raw) as List) {
          if (item is Map) {
            list.add(NarrativeReport.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      } catch (_) {}
    }
    list.removeWhere((e) => e.videoId == report.videoId);
    list.insert(0, report);
    await box.put(
      'narratives_v1',
      jsonEncode(list.take(24).map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> saveGrowthPathBundle(GrowthPathBundle bundle) async {
    await box.put('growth_path_v1', jsonEncode(bundle.toJson()));
  }

  static GrowthPathBundle? loadGrowthPathBundle() {
    final raw = box.get('growth_path_v1');
    if (raw == null) return null;
    try {
      return GrowthPathBundle.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static NarrativeReport? narrativeFor(String videoId) {
    final raw = box.get('narratives_v1');
    if (raw == null) return null;
    try {
      for (final item in jsonDecode(raw) as List) {
        if (item is! Map) continue;
        final r = NarrativeReport.fromJson(Map<String, dynamic>.from(item));
        if (r.videoId == videoId) return r;
      }
    } catch (_) {}
    return null;
  }
}
