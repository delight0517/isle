import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/ai/api_key_detector.dart';

void main() {
  group('ApiKeyDetector', () {
    test('detects OpenRouter sk-or-v1', () {
      final r = ApiKeyDetector.detect('sk-or-v1-abcdefghijklmnopqrstuvwxyz123456');
      expect(r.providerId, 'openrouter');
      expect(r.confidence, AiKeyDetectionConfidence.high);
      expect(r.baseUrl, 'https://openrouter.ai/api/v1');
    });

    test('detects OpenAI sk-proj', () {
      final r = ApiKeyDetector.detect('sk-proj-abcdefghijklmnopqrstuvwxyz123456');
      expect(r.providerId, 'openai');
      expect(r.confidence, AiKeyDetectionConfidence.high);
    });

    test('detects Gemini AIza', () {
      final r = ApiKeyDetector.detect('AIzaSyabcdefghijklmnopqrstuvwxyz123456');
      expect(r.providerId, 'google');
      expect(r.confidence, AiKeyDetectionConfidence.high);
    });

    test('detects Anthropic sk-ant', () {
      final r = ApiKeyDetector.detect('sk-ant-api03-abcdefghijklmnopqrstuvwxyz123456');
      expect(r.providerId, 'anthropic');
      expect(r.confidence, AiKeyDetectionConfidence.high);
    });

    test('detects Groq gsk_', () {
      final r = ApiKeyDetector.detect('gsk_abcdefghijklmnopqrstuvwxyz1234567890');
      expect(r.providerId, 'groq');
      expect(r.confidence, AiKeyDetectionConfidence.high);
    });

    test('legacy sk- is medium confidence openai', () {
      final r = ApiKeyDetector.detect('sk-abcdefghijklmnopqrstuvwxyz1234567890');
      expect(r.providerId, 'openai');
      expect(r.confidence, AiKeyDetectionConfidence.medium);
    });

    test('OpenRouter wins over generic sk-', () {
      final r = ApiKeyDetector.detect('sk-or-v1-abcdefghijklmnopqrstuvwxyz123456');
      expect(r.providerId, isNot('openai'));
    });

    test('unknown key returns null provider', () {
      final r = ApiKeyDetector.detect('not-a-real-key');
      expect(r.providerId, isNull);
      expect(r.confidence, AiKeyDetectionConfidence.low);
    });

    test('fallback chain for medium sk-', () {
      final detected = ApiKeyDetector.detect('sk-abcdefghijklmnopqrstuvwxyz1234567890');
      final ids = ApiKeyDetector.fallbackProviderIds(detected);
      expect(ids, ['openai', 'deepseek', 'mistral']);
    });
  });
}
