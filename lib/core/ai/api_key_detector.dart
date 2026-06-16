import 'ai_provider_catalog.dart';

enum AiKeyDetectionConfidence { high, medium, low }

/// prefix/regex 기반 API 키 공급자 추정 (네트워크 없음)
class ApiKeyDetectionResult {
  const ApiKeyDetectionResult({
    required this.providerId,
    required this.confidence,
    required this.reason,
    this.baseUrl,
    this.suggestedModelId,
  });

  /// [AiProviderCatalog] id — null이면 unknown
  final String? providerId;
  final AiKeyDetectionConfidence confidence;
  final String reason;
  final String? baseUrl;
  final String? suggestedModelId;

  bool get isKnown => providerId != null;

  String? get displayName {
    if (providerId == null) return null;
    return AiProviderCatalog.byId(providerId!)?.displayName;
  }
}

class ApiKeyDetector {
  ApiKeyDetector._();

  static final _openRouter = RegExp(r'^sk-or-v1-[A-Za-z0-9_-]{20,}$');
  static final _openAiProject = RegExp(r'^sk-proj-[A-Za-z0-9_-]{20,}$');
  static final _anthropic = RegExp(r'^sk-ant-[A-Za-z0-9_-]{20,}$');
  static final _groq = RegExp(r'^gsk_[A-Za-z0-9_-]{20,}$');
  static final _gemini = RegExp(r'^AIza[0-9A-Za-z_-]{20,}$');
  static final _legacyOpenAi = RegExp(r'^sk-[A-Za-z0-9_-]{20,}$');

  static ApiKeyDetectionResult detect(String raw) {
    final key = raw.trim();
    if (key.isEmpty) {
      return const ApiKeyDetectionResult(
        providerId: null,
        confidence: AiKeyDetectionConfidence.low,
        reason: 'API 키가 비어 있습니다.',
      );
    }

    if (_openRouter.hasMatch(key)) {
      return const ApiKeyDetectionResult(
        providerId: 'openrouter',
        confidence: AiKeyDetectionConfidence.high,
        reason: 'sk-or-v1- 형식 — OpenRouter 키입니다.',
        baseUrl: 'https://openrouter.ai/api/v1',
        suggestedModelId: 'openai/gpt-4o-mini',
      );
    }

    if (_anthropic.hasMatch(key)) {
      return const ApiKeyDetectionResult(
        providerId: 'anthropic',
        confidence: AiKeyDetectionConfidence.high,
        reason: 'sk-ant- 형식 — Anthropic(Claude) 키입니다.',
        baseUrl: 'https://api.anthropic.com/v1',
        suggestedModelId: 'claude-3-5-haiku-20241022',
      );
    }

    if (_groq.hasMatch(key)) {
      return const ApiKeyDetectionResult(
        providerId: 'groq',
        confidence: AiKeyDetectionConfidence.high,
        reason: 'gsk_ 형식 — Groq 키입니다.',
        baseUrl: 'https://api.groq.com/openai/v1',
        suggestedModelId: 'llama-3.3-70b-versatile',
      );
    }

    if (_openAiProject.hasMatch(key)) {
      return const ApiKeyDetectionResult(
        providerId: 'openai',
        confidence: AiKeyDetectionConfidence.high,
        reason: 'sk-proj- 형식 — OpenAI 프로젝트 키입니다.',
        baseUrl: 'https://api.openai.com/v1',
        suggestedModelId: 'gpt-4o-mini',
      );
    }

    if (_gemini.hasMatch(key)) {
      return const ApiKeyDetectionResult(
        providerId: 'google',
        confidence: AiKeyDetectionConfidence.high,
        reason: 'AIza 형식 — Google(Gemini) API 키입니다.',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        suggestedModelId: 'gemini-2.0-flash',
      );
    }

    if (_legacyOpenAi.hasMatch(key)) {
      return const ApiKeyDetectionResult(
        providerId: 'openai',
        confidence: AiKeyDetectionConfidence.medium,
        reason: 'sk- 형식 — OpenAI 또는 OpenAI 호환 키로 보입니다.',
        baseUrl: 'https://api.openai.com/v1',
        suggestedModelId: 'gpt-4o-mini',
      );
    }

    return const ApiKeyDetectionResult(
      providerId: null,
      confidence: AiKeyDetectionConfidence.low,
      reason: '지원하는 API 키 형식을 찾지 못했습니다.',
    );
  }

  /// sk- 등 모호한 키에 대해 검증 시도할 후보 공급자 (순서대로)
  static List<String> fallbackProviderIds(ApiKeyDetectionResult detected) {
    if (detected.providerId != 'openai' ||
        detected.confidence != AiKeyDetectionConfidence.medium) {
      return detected.providerId == null ? const [] : [detected.providerId!];
    }
    return const ['openai', 'deepseek', 'mistral'];
  }
}
