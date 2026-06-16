import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ai/ai_config_store.dart';
import '../../../../core/ai/api_key_detector.dart';
import '../../../../core/ai/api_key_setup_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';

/// API 키 붙여넣기 → 자동 감지·검증·저장
class AiKeyAutoSetupCard extends StatefulWidget {
  const AiKeyAutoSetupCard({
    super.key,
    required this.onApplied,
  });

  final VoidCallback onApplied;

  @override
  State<AiKeyAutoSetupCard> createState() => _AiKeyAutoSetupCardState();
}

class _AiKeyAutoSetupCardState extends State<AiKeyAutoSetupCard> {
  final _pasteCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  ApiKeyDetectionResult? _preview;
  String? _resultMessage;
  bool? _resultOk;

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  void _onPasteChanged(String v) {
    final detected = ApiKeyDetector.detect(v);
    setState(() {
      _preview = v.trim().isEmpty ? null : detected;
      _resultMessage = null;
      _resultOk = null;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _pasteCtrl.text = text;
    _onPasteChanged(text);
  }

  Future<void> _apply() async {
    final key = _pasteCtrl.text.trim();
    if (key.isEmpty) {
      setState(() {
        _resultOk = false;
        _resultMessage = 'API 키를 붙여넣어 주세요.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _resultMessage = null;
      _resultOk = null;
    });

    final result = await ApiKeySetupService.applyFromPaste(key);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _resultOk = result.success;
      _resultMessage = result.message;
      if (result.success) {
        _pasteCtrl.clear();
        _preview = null;
      }
    });

    if (result.success) {
      widget.onApplied();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.providerName} 연결 완료')),
      );
    }
  }

  Future<void> _clearKey() async {
    await AiConfigStore.clearApiKey();
    if (!mounted) return;
    setState(() {
      _pasteCtrl.clear();
      _preview = null;
      _resultMessage = 'API 키가 삭제되었습니다.';
      _resultOk = true;
    });
    widget.onApplied();
  }

  @override
  Widget build(BuildContext context) {
    final configured = AiConfigStore.isConfigured;
    final masked = AiConfigStore.apiKeyMasked;

    return Card(
      elevation: 0,
      color: IsleColors.ocean100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
        side: BorderSide(color: IsleColors.ocean500.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.vpn_key_outlined, color: IsleColors.ocean700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('API 키 자동 연결', style: IsleText.subtitle(color: IsleColors.ocean900)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '키를 붙여넣기만 하면 공급자를 자동으로 감지하고 연결 상태를 확인합니다.\n'
              '지원: OpenAI · Gemini · OpenRouter · Anthropic · Groq 등',
              style: IsleText.caption(color: IsleColors.ocean700),
            ),
            if (configured && masked.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: IsleColors.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${AiConfigStore.activeProvider.displayName} 연결됨 · $masked',
                        style: IsleText.body(),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _clearKey,
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _pasteCtrl,
              obscureText: _obscure,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: 'API 키 붙여넣기',
                hintText: 'sk-… · AIza… · sk-or-v1-…',
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onChanged: _onPasteChanged,
            ),
            if (_preview != null && _preview!.isKnown) ...[
              const SizedBox(height: 8),
              _DetectionChip(preview: _preview!),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_go),
                  label: const Text('클립보드'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _apply,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_fix_high),
                    label: Text(_busy ? '감지·연결 중…' : '붙여넣고 연결'),
                  ),
                ),
              ],
            ),
            if (_resultMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _resultMessage!,
                style: IsleText.caption(
                  color: _resultOk == true ? IsleColors.success : const Color(0xFFB71C1C),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetectionChip extends StatelessWidget {
  const _DetectionChip({required this.preview});

  final ApiKeyDetectionResult preview;

  @override
  Widget build(BuildContext context) {
    final confidence = switch (preview.confidence) {
      AiKeyDetectionConfidence.high => '높음',
      AiKeyDetectionConfidence.medium => '보통',
      AiKeyDetectionConfidence.low => '낮음',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.radar, size: 18, color: IsleColors.ocean500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${preview.displayName ?? '알 수 없음'} 감지 (신뢰도 $confidence)',
              style: IsleText.caption(color: IsleColors.ocean900),
            ),
          ),
        ],
      ),
    );
  }
}
