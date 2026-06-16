import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// 접기·펼치기 + 복사 — 긴 백업 코드 스크롤 없이
class CollapsibleBackupCode extends StatefulWidget {
  const CollapsibleBackupCode({
    super.key,
    required this.code,
    this.previewLength = 56,
  });

  final String code;
  final int previewLength;

  @override
  State<CollapsibleBackupCode> createState() => _CollapsibleBackupCodeState();
}

class _CollapsibleBackupCodeState extends State<CollapsibleBackupCode> {
  bool _expanded = false;

  String get _preview {
    if (widget.code.length <= widget.previewLength) return widget.code;
    return '${widget.code.substring(0, widget.previewLength)}…';
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('백업 코드가 복사됐어요')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _expanded ? '전체 백업 코드' : '백업 코드 (접힘)',
                style: IsleText.subtitle(),
              ),
            ),
            TextButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('복사'),
            ),
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? '접기' : '펼치기'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: IsleColors.ocean100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: IsleColors.ocean500.withValues(alpha: 0.2)),
            ),
            child: SelectableText(
              _preview,
              style: IsleText.caption().copyWith(fontFamily: 'monospace'),
            ),
          ),
          secondChild: Container(
            constraints: const BoxConstraints(maxHeight: 140),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: IsleColors.ocean100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                widget.code,
                style: IsleText.caption().copyWith(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
