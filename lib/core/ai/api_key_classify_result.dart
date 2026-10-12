import 'api_key_detector.dart';
import 'api_key_validator.dart';

/// detect → validate 통합 결과 (붙여넣기 자동 연결용)
class ApiKeyClassifyResult {
  const ApiKeyClassifyResult({
    required this.providerId,
    required this.valid,
    required this.message,
    this.baseUrl,
    this.detection,
    this.validation,
  });

  final String? providerId;
  final bool valid;
  final String message;
  final String? baseUrl;
  final ApiKeyDetectionResult? detection;
  final ApiKeyValidationResult? validation;

  String? get providerName => detection?.displayName;
}
