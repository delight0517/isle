import 'package:hive_flutter/hive_flutter.dart';

import '../constants/env.dart';
import '../services/isle_local_data_sync.dart';
import 'ai_provider_catalog.dart';
import 'ai_secure_key_store.dart';

/// 사용자가 고른 AI 제공자·모델·API 키 (기기 로컬만 — 서버 전송 없음)
class AiConfigStore {
  AiConfigStore._();

  static const _boxName = 'isle_ai_config';
  static const _providerKey = 'provider_id';
  static const _modelKey = 'model_id';
  static const _apiKeyKey = 'api_key';
  static const _apiKeyLast4Key = 'api_key_last4';
  static const _baseUrlKey = 'base_url_override';
  static const _customModelKey = 'custom_model_id';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
    final legacy = box.get(_apiKeyKey);
    await AiSecureKeyStore.ensureLoaded(legacyHivePlainKey: legacy);
    if (legacy != null && legacy.isNotEmpty && AiSecureKeyStore.apiKey.isNotEmpty) {
      await box.delete(_apiKeyKey);
    }
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('AiConfigStore not open');
    return b;
  }

  static String get providerId =>
      box.get(_providerKey) ?? (Env.isAiConfigured ? 'openai' : 'openai');

  static String get modelId {
    final stored = box.get(_modelKey);
    if (stored != null && stored.isNotEmpty) return stored;
    if (Env.openAiModel.isNotEmpty) return Env.openAiModel;
    return activeProvider.models.first.id;
  }

  static String get customModelId => box.get(_customModelKey) ?? '';

  static String get apiKey {
    final secure = AiSecureKeyStore.apiKey;
    if (secure.isNotEmpty) return secure;
    final legacy = box.get(_apiKeyKey);
    if (legacy != null && legacy.isNotEmpty && !legacy.contains('YOUR')) return legacy;
    if (Env.openAiApiKey.isNotEmpty && !Env.openAiApiKey.contains('YOUR')) {
      return Env.openAiApiKey;
    }
    return '';
  }

  /// 화면 표시용 — 마지막 4자리만
  static String get apiKeyMasked {
    if (!isConfigured) return '';
    final stored = box.get(_apiKeyLast4Key);
    if (stored != null && stored.isNotEmpty) return '****$stored';
    return AiSecureKeyStore.maskedLast4;
  }

  static String? get baseUrlOverride {
    final u = box.get(_baseUrlKey);
    return u != null && u.isNotEmpty ? u : null;
  }

  static AiProviderDefinition get activeProvider =>
      AiProviderCatalog.byId(providerId) ?? AiProviderCatalog.providers.first;

  static AiModelDefinition? get activeModel {
    final p = activeProvider;
    if (p.id == 'custom' && customModelId.isNotEmpty) {
      return AiModelDefinition(id: customModelId, label: customModelId);
    }
    return p.modelById(modelId) ?? (p.models.isNotEmpty ? p.models.first : null);
  }

  static String get resolvedModelId {
    if (activeProvider.id == 'custom' && customModelId.isNotEmpty) {
      return customModelId;
    }
    return activeModel?.id ?? modelId;
  }

  static String get resolvedBaseUrl {
    final override = baseUrlOverride;
    if (override != null && override.isNotEmpty) return override;
    if (Env.openAiBaseUrl.startsWith('http') && providerId == 'openai') {
      return Env.openAiBaseUrl;
    }
    return activeProvider.defaultBaseUrl;
  }

  static bool get isConfigured => apiKey.isNotEmpty;

  static Future<void> setProviderId(String id) async {
    await box.put(_providerKey, id);
    isleNotifyLocalDataChanged();
  }

  static Future<void> setModelId(String id) async {
    await box.put(_modelKey, id);
    isleNotifyLocalDataChanged();
  }

  static Future<void> setApiKey(String key) async {
    final trimmed = key.trim();
    await AiSecureKeyStore.save(trimmed);
    await box.delete(_apiKeyKey);
    if (trimmed.isEmpty) {
      await box.delete(_apiKeyLast4Key);
    } else if (trimmed.length >= 4) {
      await box.put(_apiKeyLast4Key, trimmed.substring(trimmed.length - 4));
    }
    isleNotifyLocalDataChanged();
  }

  static Future<void> clearApiKey() => setApiKey('');

  static Future<void> setBaseUrlOverride(String? url) async {
    if (url == null || url.trim().isEmpty) {
      await box.delete(_baseUrlKey);
    } else {
      await box.put(_baseUrlKey, url.trim());
    }
    isleNotifyLocalDataChanged();
  }

  static Future<void> setCustomModelId(String id) async {
    await box.put(_customModelKey, id.trim());
    isleNotifyLocalDataChanged();
  }
}
