import 'package:dio/dio.dart';

import 'ai_provider_catalog.dart';

class ApiKeyValidationResult {
  const ApiKeyValidationResult({
    required this.valid,
    this.statusCode,
    this.errorMessage,
    this.providerId,
  });

  final bool valid;
  final int? statusCode;
  final String? errorMessage;
  final String? providerId;
}

/// 공급자별 가벼운 연결 검증 (키는 로그에 남기지 않음)
class ApiKeyValidator {
  ApiKeyValidator._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (_) => true,
    ),
  );

  static Future<ApiKeyValidationResult> validateForProvider(
    String providerId,
    String apiKey,
  ) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      return const ApiKeyValidationResult(
        valid: false,
        errorMessage: 'API 키가 비어 있습니다.',
      );
    }

    final provider = AiProviderCatalog.byId(providerId);
    if (provider == null) {
      return ApiKeyValidationResult(
        valid: false,
        errorMessage: '알 수 없는 공급자: $providerId',
        providerId: providerId,
      );
    }

    switch (providerId) {
      case 'openai':
        return _validateOpenAiCompatible(
          key,
          baseUrl: provider.defaultBaseUrl,
          providerId: providerId,
        );
      case 'openrouter':
        return _validateOpenRouter(key);
      case 'google':
        return _validateGemini(key);
      case 'anthropic':
        return _validateAnthropic(key);
      case 'groq':
        return _validateOpenAiCompatible(
          key,
          baseUrl: provider.defaultBaseUrl,
          providerId: providerId,
        );
      case 'deepseek':
        return _validateOpenAiCompatible(
          key,
          baseUrl: provider.defaultBaseUrl,
          providerId: providerId,
        );
      case 'mistral':
        return _validateOpenAiCompatible(
          key,
          baseUrl: provider.defaultBaseUrl,
          providerId: providerId,
        );
      default:
        return Future.value(
          ApiKeyValidationResult(
            valid: false,
            errorMessage: '${provider.displayName}는 자동 검증을 지원하지 않습니다.',
            providerId: providerId,
          ),
        );
    }
  }

  static Future<ApiKeyValidationResult> validateWithFallbacks(
    String apiKey,
    List<String> providerIds,
  ) async {
    ApiKeyValidationResult? last;
    for (final id in providerIds) {
      final r = await validateForProvider(id, apiKey);
      if (r.valid) return r;
      last = r;
    }
    return last ??
        const ApiKeyValidationResult(
          valid: false,
          errorMessage: '연결 테스트에 실패했습니다.',
        );
  }

  static Future<ApiKeyValidationResult> _validateOpenAiCompatible(
    String apiKey, {
    required String baseUrl,
    required String providerId,
  }) async {
    final root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final res = await _dio.get<Map<String, dynamic>>(
      '$root/models',
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
    );
    return _fromStatus(res.statusCode, res.data, providerId);
  }

  static Future<ApiKeyValidationResult> _validateOpenRouter(String apiKey) async {
    final res = await _dio.get<Map<String, dynamic>>(
      'https://openrouter.ai/api/v1/key',
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
    );
    return _fromStatus(res.statusCode, res.data, 'openrouter');
  }

  static Future<ApiKeyValidationResult> _validateGemini(String apiKey) async {
    final res = await _dio.get<Map<String, dynamic>>(
      'https://generativelanguage.googleapis.com/v1beta/models',
      queryParameters: {'key': apiKey},
    );
    return _fromStatus(res.statusCode, res.data, 'google');
  }

  static Future<ApiKeyValidationResult> _validateAnthropic(String apiKey) async {
    final res = await _dio.post<Map<String, dynamic>>(
      'https://api.anthropic.com/v1/messages',
      options: Options(headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': 'claude-3-5-haiku-20241022',
        'max_tokens': 1,
        'messages': [
          {'role': 'user', 'content': 'ping'},
        ],
      },
    );
    final code = res.statusCode ?? 0;
    if (code == 200 || code == 429) {
      return const ApiKeyValidationResult(valid: true, providerId: 'anthropic');
    }
    return ApiKeyValidationResult(
      valid: false,
      statusCode: code,
      errorMessage: _readError(res.data) ?? 'Anthropic 연결 실패 ($code)',
      providerId: 'anthropic',
    );
  }

  static ApiKeyValidationResult _fromStatus(
    int? statusCode,
    Map<String, dynamic>? data,
    String providerId,
  ) {
    final code = statusCode ?? 0;
    if (code >= 200 && code < 300) {
      return ApiKeyValidationResult(valid: true, statusCode: code, providerId: providerId);
    }
    return ApiKeyValidationResult(
      valid: false,
      statusCode: code,
      errorMessage: _readError(data) ?? '연결 실패 (HTTP $code)',
      providerId: providerId,
    );
  }

  static String? _readError(Map<String, dynamic>? data) {
    if (data == null) return null;
    final err = data['error'];
    if (err is Map) {
      return err['message']?.toString() ?? err.toString();
    }
    return err?.toString();
  }
}
