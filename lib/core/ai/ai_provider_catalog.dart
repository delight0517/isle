/// 지원 AI 제공자·모델 카탈로그 (사용자가 설정에서 선택)
enum AiApiStyle {
  openAiChat,
  anthropicMessages,
  geminiGenerate,
}

class AiModelDefinition {
  const AiModelDefinition({
    required this.id,
    required this.label,
    this.inputPerMillionUsd = 0.15,
    this.outputPerMillionUsd = 0.60,
  });

  final String id;
  final String label;
  final double inputPerMillionUsd;
  final double outputPerMillionUsd;
}

class AiProviderDefinition {
  const AiProviderDefinition({
    required this.id,
    required this.displayName,
    required this.apiStyle,
    required this.defaultBaseUrl,
    required this.models,
    this.hint,
    this.docsUrl,
  });

  final String id;
  final String displayName;
  final AiApiStyle apiStyle;
  final String defaultBaseUrl;
  final List<AiModelDefinition> models;
  final String? hint;
  final String? docsUrl;

  AiModelDefinition? modelById(String modelId) {
    for (final m in models) {
      if (m.id == modelId) return m;
    }
    return models.isNotEmpty ? models.first : null;
  }
}

class AiProviderCatalog {
  AiProviderCatalog._();

  static const providers = <AiProviderDefinition>[
    AiProviderDefinition(
      id: 'openai',
      displayName: 'OpenAI',
      apiStyle: AiApiStyle.openAiChat,
      defaultBaseUrl: 'https://api.openai.com/v1',
      docsUrl: 'https://platform.openai.com/api-keys',
      models: [
        AiModelDefinition(id: 'gpt-4o', label: 'GPT-4o', inputPerMillionUsd: 2.5, outputPerMillionUsd: 10),
        AiModelDefinition(id: 'gpt-4o-mini', label: 'GPT-4o mini', inputPerMillionUsd: 0.15, outputPerMillionUsd: 0.60),
        AiModelDefinition(id: 'gpt-4-turbo', label: 'GPT-4 Turbo', inputPerMillionUsd: 10, outputPerMillionUsd: 30),
        AiModelDefinition(id: 'o1-mini', label: 'o1-mini', inputPerMillionUsd: 3, outputPerMillionUsd: 12),
      ],
    ),
    AiProviderDefinition(
      id: 'anthropic',
      displayName: 'Anthropic (Claude)',
      apiStyle: AiApiStyle.anthropicMessages,
      defaultBaseUrl: 'https://api.anthropic.com/v1',
      docsUrl: 'https://console.anthropic.com/settings/keys',
      models: [
        AiModelDefinition(id: 'claude-3-5-sonnet-20241022', label: 'Claude 3.5 Sonnet', inputPerMillionUsd: 3, outputPerMillionUsd: 15),
        AiModelDefinition(id: 'claude-3-5-haiku-20241022', label: 'Claude 3.5 Haiku', inputPerMillionUsd: 0.8, outputPerMillionUsd: 4),
        AiModelDefinition(id: 'claude-3-opus-20240229', label: 'Claude 3 Opus', inputPerMillionUsd: 15, outputPerMillionUsd: 75),
      ],
    ),
    AiProviderDefinition(
      id: 'google',
      displayName: 'Google (Gemini)',
      apiStyle: AiApiStyle.geminiGenerate,
      defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      docsUrl: 'https://aistudio.google.com/apikey',
      models: [
        AiModelDefinition(id: 'gemini-2.0-flash', label: 'Gemini 2.0 Flash', inputPerMillionUsd: 0.10, outputPerMillionUsd: 0.40),
        AiModelDefinition(id: 'gemini-1.5-pro', label: 'Gemini 1.5 Pro', inputPerMillionUsd: 1.25, outputPerMillionUsd: 5),
        AiModelDefinition(id: 'gemini-1.5-flash', label: 'Gemini 1.5 Flash', inputPerMillionUsd: 0.075, outputPerMillionUsd: 0.30),
      ],
    ),
    AiProviderDefinition(
      id: 'groq',
      displayName: 'Groq',
      apiStyle: AiApiStyle.openAiChat,
      defaultBaseUrl: 'https://api.groq.com/openai/v1',
      docsUrl: 'https://console.groq.com/keys',
      models: [
        AiModelDefinition(id: 'llama-3.3-70b-versatile', label: 'Llama 3.3 70B'),
        AiModelDefinition(id: 'mixtral-8x7b-32768', label: 'Mixtral 8x7B'),
      ],
    ),
    AiProviderDefinition(
      id: 'deepseek',
      displayName: 'DeepSeek',
      apiStyle: AiApiStyle.openAiChat,
      defaultBaseUrl: 'https://api.deepseek.com/v1',
      docsUrl: 'https://platform.deepseek.com/api_keys',
      models: [
        AiModelDefinition(id: 'deepseek-chat', label: 'DeepSeek Chat'),
        AiModelDefinition(id: 'deepseek-reasoner', label: 'DeepSeek Reasoner'),
      ],
    ),
    AiProviderDefinition(
      id: 'mistral',
      displayName: 'Mistral',
      apiStyle: AiApiStyle.openAiChat,
      defaultBaseUrl: 'https://api.mistral.ai/v1',
      docsUrl: 'https://console.mistral.ai/api-keys',
      models: [
        AiModelDefinition(id: 'mistral-large-latest', label: 'Mistral Large'),
        AiModelDefinition(id: 'mistral-small-latest', label: 'Mistral Small'),
      ],
    ),
    AiProviderDefinition(
      id: 'openrouter',
      displayName: 'OpenRouter',
      apiStyle: AiApiStyle.openAiChat,
      defaultBaseUrl: 'https://openrouter.ai/api/v1',
      hint: '한 키로 여러 모델 라우팅',
      docsUrl: 'https://openrouter.ai/keys',
      models: [
        AiModelDefinition(id: 'openai/gpt-4o-mini', label: 'OpenAI GPT-4o mini (via OR)'),
        AiModelDefinition(id: 'anthropic/claude-3.5-sonnet', label: 'Claude 3.5 Sonnet (via OR)'),
        AiModelDefinition(id: 'google/gemini-2.0-flash-001', label: 'Gemini 2.0 Flash (via OR)'),
        AiModelDefinition(id: 'meta-llama/llama-3.3-70b-instruct', label: 'Llama 3.3 70B (via OR)'),
      ],
    ),
    AiProviderDefinition(
      id: 'together',
      displayName: 'Together AI',
      apiStyle: AiApiStyle.openAiChat,
      defaultBaseUrl: 'https://api.together.xyz/v1',
      docsUrl: 'https://api.together.xyz/settings/api-keys',
      models: [
        AiModelDefinition(id: 'meta-llama/Llama-3.3-70B-Instruct-Turbo', label: 'Llama 3.3 70B Turbo'),
      ],
    ),
    AiProviderDefinition(
      id: 'xai',
      displayName: 'xAI (Grok)',
      apiStyle: AiApiStyle.openAiChat,
      defaultBaseUrl: 'https://api.x.ai/v1',
      docsUrl: 'https://console.x.ai/',
      models: [
        AiModelDefinition(id: 'grok-2-latest', label: 'Grok 2'),
      ],
    ),
    AiProviderDefinition(
      id: 'ollama',
      displayName: 'Ollama (로컬)',
      apiStyle: AiApiStyle.openAiChat,
      defaultBaseUrl: 'http://localhost:11434/v1',
      hint: 'Mac에서 Ollama 실행 필요',
      models: [
        AiModelDefinition(id: 'llama3.2', label: 'llama3.2'),
        AiModelDefinition(id: 'mistral', label: 'mistral'),
      ],
    ),
    AiProviderDefinition(
      id: 'custom',
      displayName: 'OpenAI 호환 (직접 URL)',
      apiStyle: AiApiStyle.openAiChat,
      defaultBaseUrl: 'https://api.openai.com/v1',
      hint: 'Base URL·모델 ID를 직접 입력',
      models: [
        AiModelDefinition(id: 'custom-model', label: '사용자 지정 모델 ID'),
      ],
    ),
  ];

  static AiProviderDefinition? byId(String id) {
    for (final p in providers) {
      if (p.id == id) return p;
    }
    return null;
  }
}
