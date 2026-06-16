import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_local_data_sync.dart';
import 'models/connected_source.dart';
import 'models/library_entry.dart';

const _boxName = 'isle_personal_library';
const _sourcesKey = 'connected_sources_v1';
const _entriesKey = 'library_entries_v1';

class PersonalLibraryStore {
  PersonalLibraryStore._();

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('PersonalLibraryStore not initialized');
    }
    return b;
  }

  static List<ConnectedSource> loadSources() => _decodeList(
        box.get(_sourcesKey),
        (m) => ConnectedSource.fromJson(m),
      );

  static Future<void> saveSources(List<ConnectedSource> list) async {
    await box.put(_sourcesKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static List<LibraryEntry> loadEntries() => _decodeList(
        box.get(_entriesKey),
        (m) => LibraryEntry.fromJson(m),
      );

  static Future<void> saveEntries(List<LibraryEntry> list) async {
    await box.put(_entriesKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static Future<int> upsertEntries(List<LibraryEntry> incoming) async {
    final list = loadEntries();
    var added = 0;
    for (final e in incoming) {
      final idx = list.indexWhere((x) => x.url == e.url);
      if (idx >= 0) {
        list[idx] = e;
      } else {
        list.add(e);
        added++;
      }
    }
    await saveEntries(list);
    return added;
  }

  static Future<void> removeEntryByUrl(String url) async {
    final list = loadEntries()..removeWhere((e) => e.url == url);
    await saveEntries(list);
  }

  static List<T> _decodeList<T>(String? raw, T Function(Map<String, dynamic>) fromJson) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }
}

final personalLibraryProvider =
    StateNotifierProvider<PersonalLibraryNotifier, List<LibraryEntry>>((ref) {
  return PersonalLibraryNotifier();
});

final connectedSourcesProvider =
    StateNotifierProvider<ConnectedSourcesNotifier, List<ConnectedSource>>((ref) {
  return ConnectedSourcesNotifier();
});

class PersonalLibraryNotifier extends StateNotifier<List<LibraryEntry>> {
  PersonalLibraryNotifier() : super(PersonalLibraryStore.loadEntries());

  Future<void> reload() async {
    state = PersonalLibraryStore.loadEntries();
  }

  Future<int> merge(List<LibraryEntry> incoming) async {
    final n = await PersonalLibraryStore.upsertEntries(incoming);
    state = PersonalLibraryStore.loadEntries();
    return n;
  }

  Future<void> updateSummary(String url, String summary) async {
    final list = PersonalLibraryStore.loadEntries();
    final idx = list.indexWhere((e) => e.url == url);
    if (idx < 0) return;
    final old = list[idx];
    list[idx] = LibraryEntry(
      id: old.id,
      title: old.title,
      url: old.url,
      thumbnailUrl: old.thumbnailUrl,
      sourceType: old.sourceType,
      channelId: old.channelId,
      channelName: old.channelName,
      summary: summary,
      origin: old.origin,
      sourceId: old.sourceId,
      importedAt: old.importedAt,
      publishedAt: old.publishedAt,
    );
    await PersonalLibraryStore.saveEntries(list);
    state = list;
  }
}

class ConnectedSourcesNotifier extends StateNotifier<List<ConnectedSource>> {
  ConnectedSourcesNotifier() : super(PersonalLibraryStore.loadSources());

  Future<void> reload() async {
    state = PersonalLibraryStore.loadSources();
  }

  Future<void> add(ConnectedSource source) async {
    final list = List<ConnectedSource>.from(state);
    if (list.any((s) => s.profileUrl == source.profileUrl)) return;
    list.add(source);
    await PersonalLibraryStore.saveSources(list);
    state = list;
  }

  Future<void> markSynced(String sourceId) async {
    final list = state.map((s) {
      if (s.id != sourceId) return s;
      return s.copyWith(lastSyncedAt: DateTime.now());
    }).toList();
    await PersonalLibraryStore.saveSources(list);
    state = list;
  }

  Future<void> remove(String id) async {
    final list = state.where((s) => s.id != id).toList();
    await PersonalLibraryStore.saveSources(list);
    state = list;
  }
}
