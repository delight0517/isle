import 'package:dio/dio.dart';

import '../constants/env.dart';
import '../services/isle_user_defaults.dart';
import 'ai_config_store.dart';
import 'ai_provider_catalog.dart';
import 'ai_usage_log_store.dart';
import 'api_budget_store.dart';

class AiChatResult {
  const AiChatResult({
    required this.content,
    required this.usedAi,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.usd = 0,
    this.error,
  });

  final String content;
  final bool usedAi;
  final int inputTokens;
  final int outputTokens;
  final double usd;
  final String? error;
}

/// 모든 AI 기능의 단일 진입점 — 제공자·모델·로그 통합
class AiClient {
  AiClient._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 90),
    ),
  );

  static bool get isConfigured => AiConfigStore.isConfigured || Env.isAiConfigured;

  static double estimateCost({required int inputTokens, required int outputTokens}) {
    final model = AiConfigStore.activeModel;
    if (model != null) {
      return (inputTokens / 1e6) * model.inputPerMillionUsd +
          (outputTokens / 1e6) * model.outputPerMillionUsd;
    }
    return ApiBudgetStore.estimateCostUsd(inputTokens: inputTokens, outputTokens: outputTokens);
  }

  static Future<AiChatResult> chat({
    required String feature,
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 256,
    double temperature = 0.4,
    bool jsonObject = false,
  }) async {
    if (!isConfigured) {
      await _log(
        feature: feature,
        status: 'skipped',
        detail: 'API 키 없음 — 로컬 처리',
        dataTransferred: false,
      );
      return AiChatResult(content: '', usedAi: false);
    }

    final est = estimateCost(inputTokens: 400, outputTokens: maxTokens);
    if (IsleUserDefaults.apiBudgetEnforced && !ApiBudgetStore.canAffordEstimate(est)) {
      await _log(
        feature: feature,
        status: 'skipped',
        detail: '월 예산 한도',
        dataTransferred: false,
      );
      return AiChatResult(content: '', usedAi: false, error: 'budget');
    }

    final provider = AiConfigStore.activeProvider;
    final modelId = AiConfigStore.resolvedModelId;
    final apiKey = AiConfigStore.apiKey;

    try {
      final parsed = switch (provider.apiStyle) {
        AiApiStyle.openAiChat => await _openAiChat(
            baseUrl: AiConfigStore.resolvedBaseUrl,
            apiKey: apiKey,
            model: modelId,
            system: systemPrompt,
            user: userPrompt,
            maxTokens: maxTokens,
            temperature: temperature,
            jsonObject: jsonObject,
            providerId: provider.id,
          ),
        AiApiStyle.anthropicMessages => await _anthropic(
            apiKey: apiKey,
            model: modelId,
            system: systemPrompt,
            user: userPrompt,
            maxTokens: maxTokens,
          ),
        AiApiStyle.geminiGenerate => await _gemini(
            apiKey: apiKey,
            model: modelId,
            system: systemPrompt,
            user: userPrompt,
            maxTokens: maxTokens,
            temperature: temperature,
          ),
      };

      final usd = estimateCost(inputTokens: parsed.$1, outputTokens: parsed.$2);
      await ApiBudgetStore.recordSpend(usd, feature);
      await _log(
        feature: feature,
        status: 'success',
        inputTokens: parsed.$1,
        outputTokens: parsed.$2,
        usd: usd,
        detail: '응답 ${parsed.$2} tokens',
        dataTransferred: true,
        providerId: provider.id,
        modelId: modelId,
      );
      return AiChatResult(
        content: parsed.$3,
        usedAi: true,
        inputTokens: parsed.$1,
        outputTokens: parsed.$2,
        usd: usd,
      );
    } catch (e) {
      await _log(
        feature: feature,
        status: 'error',
        detail: e.toString(),
        dataTransferred: true,
        providerId: provider.id,
        modelId: modelId,
      );
      return AiChatResult(content: '', usedAi: false, error: e.toString());
    }
  }

  static Future<(int, int, String)> _openAiChat({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String system,
    required String user,
    required int maxTokens,
    required double temperature,
    required bool jsonObject,
    required String providerId,
  }) async {
    final url = baseUrl.endsWith('/') ? '${baseUrl}chat/completions' : '$baseUrl/chat/completions';
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    if (providerId == 'openrouter') {
      headers['HTTP-Referer'] = 'https://isle.app';
      headers['X-Title'] = 'Isle';
    }
    final data = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      'temperature': temperature,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
    };
    if (jsonObject) data['response_format'] = {'type': 'json_object'};

    final res = await _dio.post<Map<String, dynamic>>(url, options: Options(headers: headers), data: data);
    return _parseOpenAiUsage(res.data);
  }

  static Future<(int, int, String)> _anthropic({
    required String apiKey,
    required String model,
    required String system,
    required String user,
    required int maxTokens,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      'https://api.anthropic.com/v1/messages',
      options: Options(headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': user},
        ],
      },
    );
    final content = res.data?['content'] as List?;
    final text = content != null && content.isNotEmpty
        ? (content.first as Map)['text'] as String? ?? ''
        : '';
    final usage = res.data?['usage'] as Map?;
    final inTok = (usage?['input_tokens'] as num?)?.toInt() ?? 0;
    final outTok = (usage?['output_tokens'] as num?)?.toInt() ?? 0;
    return (inTok, outTok, text.trim());
  }

  static Future<(int, int, String)> _gemini({
    required String apiKey,
    required String model,
    required String system,
    required String user,
    required int maxTokens,
    required double temperature,
  }) async {
    final base = AiConfigStore.resolvedBaseUrl;
    final url =
        '$base/models/$model:generateContent?key=${Uri.encodeComponent(apiKey)}';
    final res = await _dio.post<Map<String, dynamic>>(
      url,
      data: {
        'systemInstruction': {'parts': [{'text': system}]},
        'contents': [
          {'role': 'user', 'parts': [{'text': user}]},
        ],
        'generationConfig': {
          'maxOutputTokens': maxTokens,
          'temperature': temperature,
        },
      },
    );
    final candidates = res.data?['candidates'] as List?;
    var text = '';
    if (candidates != null && candidates.isNotEmpty) {
      final parts = (candidates.first as Map)['content']?['parts'] as List?;
      if (parts != null && parts.isNotEmpty) {
        text = (parts.first as Map)['text'] as String? ?? '';
      }
    }
    final usage = res.data?['usageMetadata'] as Map?;
    final inTok = (usage?['promptTokenCount'] as num?)?.toInt() ?? 0;
    final outTok = (usage?['candidatesTokenCount'] as num?)?.toInt() ?? 0;
    return (inTok, outTok, text.trim());
  }

  static (int, int, String) _parseOpenAiUsage(Map<String, dynamic>? data) {
    final choices = data?['choices'] as List?;
    final content = choices != null && choices.isNotEmpty
        ? ((choices.first as Map)['message']?['content'] as String?) ?? ''
        : '';
    final usage = data?['usage'] as Map?;
    final inTok = (usage?['prompt_tokens'] as num?)?.toInt() ?? 0;
    final outTok = (usage?['completion_tokens'] as num?)?.toInt() ?? 0;
    return (inTok, outTok, content.trim());
  }

  static Future<void> _log({
    required String feature,
    required String status,
    int inputTokens = 0,
    int outputTokens = 0,
    double usd = 0,
    String detail = '',
    bool dataTransferred = false,
    String? providerId,
    String? modelId,
  }) async {
    await AiUsageLogStore.append(
      AiUsageLogEntry(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        at: DateTime.now(),
        feature: feature,
        providerId: providerId ?? AiConfigStore.providerId,
        modelId: modelId ?? AiConfigStore.resolvedModelId,
        status: status,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        usd: usd,
        detail: detail,
        dataTransferred: dataTransferred,
      ),
    );
  }
}
