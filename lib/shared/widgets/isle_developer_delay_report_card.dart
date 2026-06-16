import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/perf/isle_perf_log_service.dart';

/// 개발자용 — 딜레이·렉 로그를 Cursor에 붙여넣기 (눈에 띄는 CTA)
class IsleDeveloperDelayReportCard extends StatefulWidget {
  const IsleDeveloperDelayReportCard({
    super.key,
    this.compact = false,
  });

  /// true면 한 줄 버튼만
  final bool compact;

  @override
  State<IsleDeveloperDelayReportCard> createState() =>
      _IsleDeveloperDelayReportCardState();
}

class _IsleDeveloperDelayReportCardState extends State<IsleDeveloperDelayReportCard> {
  int? _issueCount;
  bool _copying = false;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    final n = await IslePerfLogService.delayIssueCount();
    if (mounted) setState(() => _issueCount = n);
  }

  Future<void> _copyDelayReport() async {
    if (_copying) return;
    setState(() => _copying = true);
    try {
      final text = await IslePerfLogService.buildDelayReportForCursor();
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('딜레이 로그 복사됨 — Cursor 채팅에 붙여넣기'),
          duration: Duration(seconds: 4),
        ),
      );
      await _refreshCount();
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return SizedBox(
        width: double.infinity,
        height: IsleSize.minTouchTarget,
        child: FilledButton.icon(
          onPressed: _copying ? null : _copyDelayReport,
          style: FilledButton.styleFrom(
            backgroundColor: IsleColors.gold500,
            foregroundColor: IsleColors.ocean900,
          ),
          icon: _copying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(_issueCount != null && _issueCount! > 0
              ? '딜레이 로그 보내기 ($_issueCount건)'
              : '딜레이 로그 보내기 (개발자용)'),
        ),
      );
    }

    return Material(
      color: IsleColors.ocean900,
      borderRadius: BorderRadius.circular(IsleSize.cardRadius),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
        onTap: _copying ? null : _copyDelayReport,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: IsleColors.gold500.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.speed,
                      color: IsleColors.gold500,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '딜레이 로그 보내기',
                          style: IsleText.subtitle(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '개발자용 · 반복 렉·멈춤 기록을 Cursor에 붙여넣기',
                          style: IsleText.caption(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  if (_issueCount != null && _issueCount! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: IsleColors.gold500,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$_issueCount',
                        style: IsleText.badge(color: IsleColors.ocean900),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _copying ? null : _copyDelayReport,
                style: FilledButton.styleFrom(
                  backgroundColor: IsleColors.gold500,
                  foregroundColor: IsleColors.ocean900,
                  minimumSize: const Size.fromHeight(IsleSize.minTouchTarget),
                ),
                icon: _copying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.content_copy),
                label: const Text('복사해서 Cursor에 보내기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
