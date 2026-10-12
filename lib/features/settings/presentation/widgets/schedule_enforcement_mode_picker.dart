import 'package:flutter/material.dart';

import '../../../../core/block_schedule/models/schedule_enforcement_mode.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// 스케줄 차단 방식 3종
class ScheduleEnforcementModePicker extends StatelessWidget {
  const ScheduleEnforcementModePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ScheduleEnforcementMode value;
  final ValueChanged<ScheduleEnforcementMode>? onChanged;

  static IconData _icon(ScheduleEnforcementMode mode) => switch (mode) {
        ScheduleEnforcementMode.fullBlock => Icons.lock,
        ScheduleEnforcementMode.limitInSlot => Icons.hourglass_empty,
        ScheduleEnforcementMode.blockInSlotLimitOutside => Icons.lock_clock,
      };

  static Color _iconColor(ScheduleEnforcementMode mode) => switch (mode) {
        ScheduleEnforcementMode.fullBlock => const Color(0xFFE53935),
        ScheduleEnforcementMode.limitInSlot => const Color(0xFFF57C00),
        ScheduleEnforcementMode.blockInSlotLimitOutside => IsleColors.ocean500,
      };

  // 강도 표시: 채워진 점 개수 (1~3)
  static int _strength(ScheduleEnforcementMode mode) => switch (mode) {
        ScheduleEnforcementMode.fullBlock => 3,
        ScheduleEnforcementMode.limitInSlot => 1,
        ScheduleEnforcementMode.blockInSlotLimitOutside => 3,
      };

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioGroup<ScheduleEnforcementMode>(
                  groupValue: value,
                  onChanged: (m) { if (m != null) onChanged?.call(m); },
                  child: Column(
                    children: ScheduleEnforcementMode.values.map((mode) {
                      final selected = mode == value;
                      final color = _iconColor(mode);
                      return InkWell(
                        onTap: onChanged == null ? null : () => onChanged!(mode),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? color.withValues(alpha: 0.09) : Colors.transparent,
                            border: Border.all(
                              color: selected ? color : Colors.transparent,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Radio<ScheduleEnforcementMode>(
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                value: mode,
                                activeColor: color,
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 4),
                              Icon(_icon(mode), size: 20, color: selected ? color : IsleColors.muted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            mode.localizedLabel(lang),
                                            style: IsleText.body().copyWith(
                                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                              color: selected ? color : null,
                                            ),
                                          ),
                                        ),
                                        _StrengthDots(
                                          filled: _strength(mode),
                                          color: color,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      mode.localizedScenario(lang),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: IsleText.caption(color: IsleColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 강도 표시 점 (최대 3개)
class _StrengthDots extends StatelessWidget {
  const _StrengthDots({required this.filled, required this.color});

  final int filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final active = i < filled;
        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color : color.withValues(alpha: 0.18),
          ),
        );
      }),
    );
  }
}
