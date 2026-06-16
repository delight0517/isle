import 'ai_config_store.dart';
import 'ai_provider_catalog.dart';
import 'api_key_detector.dart';
import 'api_key_validator.dart';

enum AiKeySetupPhase { idle, detecting, validating, saving, done, failed }

class AiKeySetupResult {
  const AiKeySetupResult({
    required this.success,
    required this.message,
    this.providerId,
    this.providerName,
    this.validated = false,
    this.detection,
  });

  final bool success;
  final String message;
  final String? providerId;
  final String? providerName;
  final bool validated;
  final ApiKeyDetectionResult? detection;

  factory AiKeySetupResult.failure(String message, {ApiKeyDetectionResult? detection}) =>
      AiKeySetupResult(success: false, message: message, detection: detection);

  factory AiKeySetupResult.ok({
    required String providerId,
    required String message,
    required ApiKeyDetectionResult detection,
  }) {
    final name = AiProviderCatalog.byId(providerId)?.displayName ?? providerId;
    return AiKeySetupResult(
      success: true,
      message: message,
      providerId: providerId,
      providerName: name,
      validated: true,
      detection: detection,
    );
  }
}

/// 붙여넣기 → 감지 → 검증 → 저장
class ApiKeySetupService {
  ApiKeySetupService._();

  static Future<AiKeySetupResult> applyFromPaste(String rawKey) async {
    final key = rawKey.trim();
    if (key.isEmpty) {
      return AiKeySetupResult.failure('API 키를 붙여넣어 주세요.');
    }

    final detected = ApiKeyDetector.detect(key);
    if (!detected.isKnown) {
      return AiKeySetupResult.failure(
        detected.reason,
        detection: detected,
      );
    }

    final tryIds = ApiKeyDetector.fallbackProviderIds(detected);
    final validation = await ApiKeyValidator.validateWithFallbacks(key, tryIds);

    if (!validation.valid) {
      final name = detected.displayName ?? '해당 공급자';
      final detail = validation.errorMessage ?? '키가 만료되었거나 권한이 부족할 수 있습니다.';
      return AiKeySetupResult.failure(
        '$name 형식의 키로 보이지만 연결 테스트에 실패했습니다.\n$detail',
        detection: detected,
      );
    }

    final resolvedId = validation.providerId ?? detected.providerId!;
    final provider = AiProviderCatalog.byId(resolvedId);
    if (provider == null) {
      return AiKeySetupResult.failure('공급자 설정을 찾지 못했습니다.', detection: detected);
    }

    final modelId = detected.suggestedModelId ??
        (provider.models.isNotEmpty ? provider.models.first.id : '');

    await AiConfigStore.setProviderId(resolvedId);
    if (modelId.isNotEmpty) {
      await AiConfigStore.setModelId(modelId);
    }
    await AiConfigStore.setBaseUrlOverride(null);
    await AiConfigStore.setApiKey(key);

    final name = provider.displayName;
    return AiKeySetupResult.ok(
      providerId: resolvedId,
      detection: detected,
      message: '$name API 키가 감지되었습니다.\n연결 테스트에 성공했습니다. 이제 $name 모델을 사용할 수 있습니다.',
    );
  }
}
