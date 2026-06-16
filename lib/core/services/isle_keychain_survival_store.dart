import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'isle_app_log_service.dart';

/// iOS/Android — 앱 삭제 후 재설치해도 Keychain/Keystore에 남는 미러 백업.
/// Delete Fix 등으로 샌드박스가 지워져도 부팅 시 자동 복원.
class IsleKeychainSurvivalStore {
  IsleKeychainSurvivalStore._();

  static const _metaKey = 'isle_survival_meta_v1';
  static const _chunkPrefix = 'isle_survival_chunk_';
  static const _chunkChars = 180000;

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<bool> hasSnapshot() async {
    final meta = await _readMeta();
    return meta != null && (meta['chunks'] as int? ?? 0) > 0;
  }

  static Future<bool> saveSnapshotJson(String json) async {
    if (json.trim().length < 32) return false;
    try {
      final compressed = gzip.encode(utf8.encode(json));
      final payload = base64Encode(compressed);
      await clear();
      final chunks = (payload.length / _chunkChars).ceil();
      for (var i = 0; i < chunks; i++) {
        final start = i * _chunkChars;
        final end = (start + _chunkChars).clamp(0, payload.length);
        await _storage.write(
          key: '$_chunkPrefix$i',
          value: payload.substring(start, end),
        );
      }
      await _storage.write(
        key: _metaKey,
        value: jsonEncode({
          'chunks': chunks,
          'gzip_bytes': compressed.length,
          'saved_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      return true;
    } catch (e, st) {
      IsleAppLogService.log(
        'Keychain survival save failed: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
      return false;
    }
  }

  static Future<String?> loadSnapshotJson() async {
    try {
      final meta = await _readMeta();
      if (meta == null) return null;
      final chunks = meta['chunks'] as int? ?? 0;
      if (chunks <= 0) return null;
      final buffer = StringBuffer();
      for (var i = 0; i < chunks; i++) {
        final part = await _storage.read(key: '$_chunkPrefix$i');
        if (part == null || part.isEmpty) return null;
        buffer.write(part);
      }
      final bytes = base64Decode(buffer.toString());
      return utf8.decode(gzip.decode(bytes));
    } catch (e, st) {
      IsleAppLogService.log(
        'Keychain survival load failed: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
      return null;
    }
  }

  static Future<void> clear() async {
    final meta = await _readMeta();
    if (meta != null) {
      final n = meta['chunks'] as int? ?? 0;
      for (var i = 0; i < n; i++) {
        await _storage.delete(key: '$_chunkPrefix$i');
      }
    }
    await _storage.delete(key: _metaKey);
  }

  static Future<DateTime?> lastSavedAt() async {
    final meta = await _readMeta();
    if (meta == null) return null;
    return DateTime.tryParse(meta['saved_at']?.toString() ?? '');
  }

  static Future<Map<String, dynamic>?> _readMeta() async {
    final raw = await _storage.read(key: _metaKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }
}
