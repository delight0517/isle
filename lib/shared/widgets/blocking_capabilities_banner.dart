import 'package:flutter/material.dart';

import '../../core/blocking/blocking_controller.dart';
import '../../core/blocking/blocking_controller_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// [Bridge] 플랫폼별 차단 강제력 — OS 강제 vs 보조 차단을 정직히 표시.
class BlockingCapabilitiesBanner extends StatelessWidget {
  const BlockingCapabilitiesBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final caps = resolveBlockingController().capabilities;
    final label = resolveBlockingController().platformLabel;

    if (compact) {
      return _CompactChip(label: label, caps: caps);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IsleColors.ocean100.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IsleColors.ocean500.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: IsleColors.ocean700),
              const SizedBox(width: 8),
              Text('차단 강제력 · $label', style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _EnforcementChip(label: '앱', level: caps.appBlock),
              _EnforcementChip(label: '웹', level: caps.webBlock),
              _EnforcementChip(label: '스케줄 잠금', level: caps.scheduleLock),
            ],
          ),
          if (caps.note != null && caps.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              caps.note!,
              style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactChip extends StatelessWidget {
  const _CompactChip({required this.label, required this.caps});
  final String label;
  final BlockingCapabilities caps;

  @override
  Widget build(BuildContext context) {
    final isOs = caps.appBlock == BlockEnforcement.osEnforced;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isOs ? IsleColors.ocean500 : IsleColors.gold500).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isOs ? IsleColors.ocean500 : IsleColors.gold500).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOs ? Icons.verified_user : Icons.shield_outlined,
            size: 14,
            color: isOs ? IsleColors.ocean700 : IsleColors.gold500,
          ),
          const SizedBox(width: 6),
          Text(
            isOs ? 'OS 강제 차단' : '보조 차단',
            style: IsleText.caption(
              color: isOs ? IsleColors.ocean700 : IsleColors.ocean900,
            ).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EnforcementChip extends StatelessWidget {
  const _EnforcementChip({required this.label, required this.level});
  final String label;
  final BlockEnforcement level;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (level) {
      BlockEnforcement.osEnforced => ('OS 강제', IsleColors.ocean700),
      BlockEnforcement.bestEffort => ('보조', IsleColors.gold500),
      BlockEnforcement.unsupported => ('미지원', IsleColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label · $text', style: IsleText.caption(color: color)),
    );
  }
}
