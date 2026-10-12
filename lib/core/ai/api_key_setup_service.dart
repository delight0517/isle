import 'ai_config_store.dart';
import 'ai_provider_catalog.dart';
import 'api_key_classify_result.dart';
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

/// 붙여넣기 → 감지 → 검증 → Keychain 저장 (키는 Isle 서버로 전송하지 않음)
class ApiKeySetupService {
  ApiKeySetupService._();

  /// 1차 prefix 감지 → 2차 공급자 검증 → (apply 시) 암호화 저장
  static Future<ApiKeyClassifyResult> classifyAndValidateApiKey(String rawKey) async {
    final key = ApiKeyDetector.extractFromPaste(rawKey);
    if (key.isEmpty) {
      return const ApiKeyClassifyResult(
        providerId: null,
        valid: false,
        message: 'API 키를 붙여넣어 주세요.',
      );
    }

    final detected = ApiKeyDetector.detect(key);
    if (!detected.isKnown) {
      return ApiKeyClassifyResult(
        providerId: null,
        valid: false,
        message: detected.reason,
        detection: detected,
      );
    }

    final tryIds = ApiKeyDetector.fallbackProviderIds(detected);
    final validation = await ApiKeyValidator.validateWithFallbacks(key, tryIds);

    if (!validation.valid) {
      final name = detected.displayName ?? '해당 공급자';
      final detail = validation.errorMessage ?? '키가 만료되었거나 권한이 부족할 수 있습니다.';
      return ApiKeyClassifyResult(
        providerId: detected.providerId,
        valid: false,
        message: '$name 형식의 키로 보이지만 연결 테스트에 실패했습니다.\n$detail',
        baseUrl: detected.baseUrl,
        detection: detected,
        validation: validation,
      );
    }

    final resolvedId = validation.providerId ?? detected.providerId!;
    final name = AiProviderCatalog.byId(resolvedId)?.displayName ?? resolvedId;
    return ApiKeyClassifyResult(
      providerId: resolvedId,
      valid: true,
      message: '$name API 키가 감지되었습니다.\n연결 테스트에 성공했습니다. 이제 $name 모델을 사용할 수 있습니다.',
      baseUrl: detected.baseUrl,
      detection: detected,
      validation: validation,
    );
  }

  static Future<AiKeySetupResult> applyFromPaste(String rawKey) async {
    final key = ApiKeyDetector.extractFromPaste(rawKey);
    if (key.isEmpty) {
      return AiKeySetupResult.failure('API 키를 붙여넣어 주세요.');
    }

    final classified = await classifyAndValidateApiKey(key);
    final detected = classified.detection;
    if (detected == null || !detected.isKnown) {
      return AiKeySetupResult.failure(classified.message, detection: detected);
    }

    if (!classified.valid) {
      return AiKeySetupResult.failure(classified.message, detection: detected);
    }

    final resolvedId = classified.providerId!;
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

    return AiKeySetupResult.ok(
      providerId: resolvedId,
      detection: detected,
      message: classified.message,
    );
  }
}
