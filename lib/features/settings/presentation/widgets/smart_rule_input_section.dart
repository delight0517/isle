import 'package:flutter/material.dart';

import '../../../../core/block_schedule/url_rules/url_rule_detector.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';

typedef SmartRuleSubmit = Future<void> Function(String raw, DetectedScheduleRule detected);

/// 스케줄 편집 — URL / 단어 한 칸 (Blueprint SmartRuleInputSection)
class SmartRuleInputSection extends StatefulWidget {
  const SmartRuleInputSection({
    super.key,
    required this.enabled,
    required this.onSubmit,
    this.onAddVariation,
  });

  final bool enabled;
  final SmartRuleSubmit onSubmit;
  final Future<void> Function(String stem)? onAddVariation;

  @override
  State<SmartRuleInputSection> createState() => _SmartRuleInputSectionState();
}

class _SmartRuleInputSectionState extends State<SmartRuleInputSection> {
  final _ctrl = TextEditingController();
  String? _hint;
  String? _variationStem;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    final trimmed = v.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _hint = null;
        _variationStem = null;
      });
      return;
    }
    final detected = UrlRuleDetector.detect(trimmed);
    setState(() {
      _hint = detected.hint;
      _variationStem = detected.secondaryHost == null ? detected.variationStem : null;
    });
  }

  Future<void> _submit() async {
    if (_busy || !widget.enabled) return;
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;
    final detected = UrlRuleDetector.detect(raw);

    if (UrlRuleDetector.needsWholeSiteConfirmation(detected)) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('YouTube 전체 차단'),
          content: const Text(
            'youtube.com 전체를 차단하면 Isle 인앱 유튜브·Safari 모두 영향을 받을 수 있어요.\n계속할까요?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('차단')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busy = true);
    try {
      await widget.onSubmit(raw, detected);
      _ctrl.clear();
      if (mounted) {
        setState(() {
          _hint = null;
          _variationStem = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('URL / 단어 입력', style: IsleText.caption(color: IsleColors.muted)),
        const SizedBox(height: 6),
        TextField(
          controller: _ctrl,
          enabled: widget.enabled && !_busy,
          decoration: InputDecoration(
            hintText: 'gambling · 야동 · pornhub.com',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_circle_outline),
              onPressed: _busy ? null : _submit,
            ),
          ),
          textInputAction: TextInputAction.done,
          onChanged: _onChanged,
          onSubmitted: (_) => _submit(),
        ),
        if (_hint != null && _hint!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_hint!, style: IsleText.caption(color: IsleColors.ocean700)),
        ],
        if (_variationStem != null && widget.onAddVariation != null) ...[
          const SizedBox(height: 8),
          _VariationBanner(
            stem: _variationStem!,
            onTap: widget.enabled && !_busy
                ? () async {
                    setState(() => _busy = true);
                    try {
                      await widget.onAddVariation!(_variationStem!);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  }
                : null,
          ),
        ],
      ],
    );
  }
}

class _VariationBanner extends StatelessWidget {
  const _VariationBanner({required this.stem, this.onTap});

  final String stem;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF3E0),
      borderRadius: BorderRadius.circular(IsleSize.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: IsleColors.gold500, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '주소에 \'$stem\' 들어가면 모두 차단',
                  style: IsleText.caption(color: IsleColors.ocean900),
                ),
              ),
              if (onTap != null)
                Text('추가', style: IsleText.caption(color: IsleColors.ocean700)),
            ],
          ),
        ),
      ),
    );
  }
}
