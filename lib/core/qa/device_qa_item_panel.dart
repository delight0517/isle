import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_dimensions.dart';
import '../constants/app_typography.dart';
import 'device_qa_preflight_service.dart';
import 'device_qa_store.dart';

class DeviceQaStep {
  const DeviceQaStep({required this.label, required this.done});

  final String label;
  final bool done;
}

/// 실기기 확인 (?qa=1) — 라이브 체크리스트·프리플라이트·완료 체크
class DeviceQaItemPanel extends StatefulWidget {
  const DeviceQaItemPanel({
    super.key,
    required this.itemId,
    required this.title,
    required this.steps,
    this.compact = false,
    this.children = const [],
  });

  final String itemId;
  final String title;
  final List<DeviceQaStep> steps;
  final bool compact;
  final List<Widget> children;

  bool get readyToComplete => steps.every((s) => s.done);

  @override
  State<DeviceQaItemPanel> createState() => _DeviceQaItemPanelState();
}

class _DeviceQaItemPanelState extends State<DeviceQaItemPanel> {
  DeviceQaPreflightResult? _preflight;
  bool _preflightLoading = true;
  bool _markingDone = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPreflight());
  }

  @override
  void didUpdateWidget(covariant DeviceQaItemPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps.length != widget.steps.length ||
        oldWidget.steps.asMap().entries.any(
              (e) => e.value.done != widget.steps[e.key].done,
            )) {
      unawaited(_refreshPreflight());
    }
  }

  Future<void> _refreshPreflight() async {
    if (!mounted) return;
    setState(() => _preflightLoading = true);
    final r = await DeviceQaPreflightService.runOne(widget.itemId);
    if (!mounted) return;
    setState(() {
      _preflight = r;
      _preflightLoading = false;
    });
  }

  Future<void> _markDeviceQaDone() async {
    if (_markingDone || !widget.readyToComplete) return;
    setState(() => _markingDone = true);
    try {
      await DeviceQaStore.setChecked(widget.itemId, true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.title} 실기기 확인을 체크했어요')),
      );
      if (context.canPop()) {
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _markingDone = false);
    }
  }

  Widget _stepRow(DeviceQaStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            step.done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: step.done ? const Color(0xFF2E7D32) : const Color(0xFF81C784),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.label,
              style: IsleText.caption(
                color: step.done ? const Color(0xFF1B5E20) : const Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.readyToComplete;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: widget.compact ? 10 : 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: IsleText.subtitle(color: const Color(0xFF1B5E20)),
          ),
          if (!widget.compact) ...[
            const SizedBox(height: 8),
            ...widget.steps.map(_stepRow),
          ],
          if (widget.children.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...widget.children,
          ],
          if (_preflightLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (_preflight != null) ...[
            const SizedBox(height: 8),
            Text(
              _preflight!.summary,
              style: IsleText.caption(color: const Color(0xFF1B5E20)),
            ),
            if (_preflight!.hint != null && _preflight!.hint!.isNotEmpty)
              Text(
                _preflight!.hint!,
                style: IsleText.caption(color: const Color(0xFF2E7D32)),
              ),
          ],
          if (!widget.compact) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _preflightLoading ? null : _refreshPreflight,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('자동 점검'),
              ),
            ),
          ],
          SizedBox(
            height: IsleSize.minTouchTarget,
            child: FilledButton.icon(
              onPressed: (_markingDone || !ready) ? null : _markDeviceQaDone,
              icon: _markingDone
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.task_alt),
              label: Text(ready ? '실기기 확인 완료' : '단계 완료 후 체크'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                disabledBackgroundColor: const Color(0xFFA5D6A7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
