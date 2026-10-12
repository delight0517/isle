import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ai/ai_config_store.dart';
import '../../../../core/ai/api_key_detector.dart';
import '../../../../core/ai/api_key_setup_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/isle_sheet.dart';

/// API 키 붙여넣기 → 자동 감지·검증·Keychain 저장 (공급자 수동 선택 불필요)
class AiKeyAutoSetupCard extends StatefulWidget {
  const AiKeyAutoSetupCard({
    super.key,
    required this.onApplied,
    this.autoConnectClipboard = true,
  });

  final VoidCallback onApplied;
  final bool autoConnectClipboard;

  @override
  State<AiKeyAutoSetupCard> createState() => _AiKeyAutoSetupCardState();
}

/// 설정·피드 등 어디서든 붙여넣기 전용 시트
Future<void> showApiKeyPasteSheet(BuildContext context) async {
  await showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
      child: AiKeyAutoSetupCard(
        autoConnectClipboard: true,
        onApplied: () {
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    ),
  );
}

class _AiKeyAutoSetupCardState extends State<AiKeyAutoSetupCard> {
  final _pasteCtrl = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _autoApplyTimer;
  bool _busy = false;
  bool _obscure = true;
  ApiKeyDetectionResult? _preview;
  String? _resultMessage;
  bool? _resultOk;
  String? _phaseLabel;

  @override
  void initState() {
    super.initState();
    if (widget.autoConnectClipboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_tryClipboardAutoConnect()));
    }
  }

  @override
  void dispose() {
    _autoApplyTimer?.cancel();
    _pasteCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPasteChanged(String v) {
    final extracted = ApiKeyDetector.extractFromPaste(v);
    final detected = ApiKeyDetector.detect(extracted);
    setState(() {
      _preview = extracted.isEmpty ? null : detected;
      _resultMessage = null;
      _resultOk = null;
    });

    _autoApplyTimer?.cancel();
    if (!_busy && ApiKeyDetector.shouldAutoApply(v)) {
      _autoApplyTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) unawaited(_apply(autoTriggered: true));
      });
    }
  }

  Future<void> _tryClipboardAutoConnect() async {
    if (!mounted || _busy || AiConfigStore.isConfigured) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || !ApiKeyDetector.looksLikeApiKey(text)) return;
    _pasteCtrl.text = ApiKeyDetector.extractFromPaste(text);
    _onPasteChanged(_pasteCtrl.text);
    if (ApiKeyDetector.shouldAutoApply(text)) {
      await _apply(autoTriggered: true);
    } else if (mounted) {
      setState(() {
        _resultMessage = '클립보드에서 API 키를 찾았어요. 붙여넣기를 확인한 뒤 연결합니다.';
        _resultOk = null;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _pasteCtrl.text = text;
    _onPasteChanged(text);
    if (ApiKeyDetector.shouldAutoApply(text)) {
      await _apply(autoTriggered: true);
    }
  }

  Future<void> _apply({bool autoTriggered = false}) async {
    final key = ApiKeyDetector.extractFromPaste(_pasteCtrl.text);
    if (key.isEmpty) {
      if (!autoTriggered) {
        setState(() {
          _resultOk = false;
          _resultMessage = 'API 키를 붙여넣어 주세요.';
        });
      }
      return;
    }

    _autoApplyTimer?.cancel();
    setState(() {
      _busy = true;
      _resultMessage = null;
      _resultOk = null;
      _phaseLabel = '공급자 감지 중…';
    });

    setState(() => _phaseLabel = '연결 테스트 중…');
    final result = await ApiKeySetupService.applyFromPaste(key);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _phaseLabel = null;
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
        SnackBar(content: Text('${result.providerName} 연결 완료 · ${AiConfigStore.apiKeyMasked}')),
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
                  child: Text('API 키 붙여넣기', style: IsleText.subtitle(color: IsleColors.ocean900)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'API 키를 입력하세요. 자동으로 공급자를 감지하고 연결 상태를 확인합니다.\n'
              '지원: OpenAI · Gemini · OpenRouter · Anthropic · Groq\n'
              '키는 Keychain에만 저장 · 화면에는 마지막 4자리만 표시',
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
              focusNode: _focusNode,
              obscureText: _obscure,
              enabled: !_busy,
              autofocus: !configured,
              decoration: InputDecoration(
                labelText: '여기에 붙여넣기 (Cmd+V)',
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
            if (_phaseLabel != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(_phaseLabel!, style: IsleText.caption(color: IsleColors.ocean700)),
                ],
              ),
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
                    onPressed: _busy ? null : () => _apply(),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.link),
                    label: Text(_busy ? '연결 중…' : '연결'),
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
              '${preview.displayName ?? '알 수 없음'} 감지 (신뢰도 $confidence) — 붙여넣으면 자동 연결',
              style: IsleText.caption(color: IsleColors.ocean900),
            ),
          ),
        ],
      ),
    );
  }
}
