import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_user_defaults.dart';
import '../services/isle_local_data_sync.dart';
import 'models/channel_genre_profile.dart';
import 'models/channel_genre_sample.dart';

const _boxName = 'isle_channel_genre';
const _samplesKey = 'samples_v1';
const _profilesKey = 'profiles_v1';

class ChannelGenreBlockStore {
  ChannelGenreBlockStore._();

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('ChannelGenreBlockStore not open');
    return b;
  }

  static List<ChannelGenreSample> loadSamples() {
    final raw = box.get(_samplesKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => ChannelGenreSample.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSamples(List<ChannelGenreSample> list) async {
    await box.put(_samplesKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static List<ChannelGenreProfile> loadProfiles() {
    final raw = box.get(_profilesKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => ChannelGenreProfile.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveProfiles(List<ChannelGenreProfile> list) async {
    await box.put(_profilesKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static Future<void> addSample({
    required String channelId,
    required String channelName,
    required String pageUrl,
    String? reason,
  }) async {
    final list = loadSamples();
    list.add(
      ChannelGenreSample(
        channelId: channelId,
        channelName: channelName,
        pageUrl: pageUrl,
        reason: reason,
        recordedAt: DateTime.now(),
      ),
    );
    if (list.length > 200) list.removeRange(0, list.length - 200);
    await saveSamples(list);
  }

  static int get sampleCount => loadSamples().length;

  static bool get shouldRunAutoAnalyze =>
      sampleCount >= IsleUserDefaults.genreBlockMinSamples;

  static Future<void> addProfile(ChannelGenreProfile profile) async {
    final list = loadProfiles();
    list.insert(0, profile);
    if (list.length > 30) list.length = 30;
    await saveProfiles(list);
  }
}
