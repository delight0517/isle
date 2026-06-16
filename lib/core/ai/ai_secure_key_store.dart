import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API 키 — Keychain/Keystore (메모리 캐시, 로그·백업에 평문 미포함)
class AiSecureKeyStore {
  AiSecureKeyStore._();

  static const _storageKey = 'isle_ai_api_key_v1';
  static const _storage = FlutterSecureStorage();

  static String? _cached;

  static Future<void> ensureLoaded({String? legacyHivePlainKey}) async {
    if (_cached != null && _cached!.isNotEmpty) return;

    final secure = await _storage.read(key: _storageKey);
    if (secure != null && secure.isNotEmpty) {
      _cached = secure;
      return;
    }

    final legacy = legacyHivePlainKey?.trim();
    if (legacy != null && legacy.isNotEmpty && !legacy.contains('YOUR')) {
      await save(legacy);
    }
  }

  static String get apiKey => _cached ?? '';

  static String get maskedLast4 {
    final k = apiKey;
    if (k.length <= 4) return k.isEmpty ? '' : '****';
    return '****${k.substring(k.length - 4)}';
  }

  static Future<void> save(String key) async {
    final trimmed = key.trim();
    _cached = trimmed;
    if (trimmed.isEmpty) {
      await _storage.delete(key: _storageKey);
      return;
    }
    await _storage.write(key: _storageKey, value: trimmed);
  }

  static Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: _storageKey);
  }
}
