import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'isle_app_log_service.dart';
import 'isle_local_data_sync.dart';

/// 폼·메모 — 60초마다 + 변경 시 디바운스 저장 (최소 10분 분량 유지)
class IsleDraftAutosaveService {
  IsleDraftAutosaveService._();

  static const _boxName = 'isle_drafts';
  static const _debounceMs = 800;
  static const _periodicSeconds = 60;

  static Box<String>? _box;
  static Timer? _periodic;
  static final Map<String, String> _pending = {};
  static final Map<String, Timer?> _debouncers = {};

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
    _periodic ??= Timer.periodic(const Duration(seconds: _periodicSeconds), (_) {
      unawaited(flushAll());
    });
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('IsleDraftAutosaveService not open');
    return b;
  }

  static String? loadDraft(String screenId) => box.get(_key(screenId));

  static Map<String, dynamic>? loadDraftJson(String screenId) {
    final raw = loadDraft(screenId);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {'text': raw};
    }
  }

  static void scheduleSave(String screenId, Map<String, dynamic> fields) {
    _pending[screenId] = jsonEncode({
      ...fields,
      '_saved_at': DateTime.now().toIso8601String(),
    });
    _debouncers[screenId]?.cancel();
    _debouncers[screenId] = Timer(const Duration(milliseconds: _debounceMs), () {
      unawaited(_persist(screenId, _pending[screenId]!));
    });
  }

  static void scheduleSaveText(String screenId, String text) {
    scheduleSave(screenId, {'text': text});
  }

  static Future<void> _persist(String screenId, String payload) async {
    try {
      await box.put(_key(screenId), payload);
      isleNotifyLocalDataChanged();
    } catch (e, st) {
      IsleAppLogService.log('Draft save failed: $screenId', level: IsleLogLevel.warn, error: e, stack: st);
    }
  }

  static Future<void> flushAll() async {
    for (final e in _pending.entries) {
      await _persist(e.key, e.value);
    }
    _pending.clear();
    IsleAppLogService.log('Draft flush (${box.length} keys)', level: IsleLogLevel.debug);
  }

  static Future<void> clearDraft(String screenId) async {
    _pending.remove(screenId);
    await box.delete(_key(screenId));
  }

  static String _key(String screenId) => 'draft_$screenId';
}
