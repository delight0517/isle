import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../core/blocking/android_blocking_setup_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_legal_info.dart';
import '../../core/constants/app_typography.dart';

/// Android — 접근성·배터리 예외 설정 체크리스트 (삼성/샤오미 백그라운드 킬 방지)
class AndroidBlockingSetupChecklist extends StatefulWidget {
  const AndroidBlockingSetupChecklist({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<AndroidBlockingSetupChecklist> createState() =>
      _AndroidBlockingSetupChecklistState();
}

class _AndroidBlockingSetupChecklistState extends State<AndroidBlockingSetupChecklist> {
  AndroidBlockingSetupStatus? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final s = await AndroidBlockingSetupService.load();
    if (!mounted) return;
    setState(() {
      _status = s;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return const SizedBox.shrink();

    final s = _status;
    if (_loading || s == null) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    if (s.isReady) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.check_circle, color: IsleColors.grassDeep),
        title: Text('Android 차단 준비 완료', style: IsleText.body()),
        subtitle: Text(
          '접근성 · 배터리 예외 설정됨',
          style: IsleText.caption(color: IsleColors.muted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Android 차단 설정 (${s.completedSteps}/2)',
          style: IsleText.subtitle(),
        ),
        const SizedBox(height: 6),
        Text(
          '삼성·샤오미 등은 배터리 최적화가 접근성 서비스를 끄면 차단이 풀려요.',
          style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
        ),
        const SizedBox(height: 8),
        _step(
          done: s.accessibilityOn,
          title: '접근성 → Isle 차단 서비스',
          subtitle: AppLegalInfo.accessibilityPermissionNotice,
          onTap: () async {
            await AndroidBlockingSetupService.openAccessibilitySettings();
            await _reload();
            widget.onChanged?.call();
          },
        ),
        _step(
          done: s.batteryIgnored,
          title: '배터리 최적화 예외',
          subtitle: '「제한 없음」 또는 「최적화 안 함」',
          onTap: () async {
            await AndroidBlockingSetupService.openBatterySettings();
            await _reload();
            widget.onChanged?.call();
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () async {
              await AndroidBlockingSetupService.openManufacturerBatterySettings();
            },
            child: const Text('삼성·샤오미 배터리 설정 열기'),
          ),
        ),
      ],
    );
  }

  Widget _step({
    required bool done,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: done ? IsleColors.ocean100.withValues(alpha: 0.4) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: done ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? IsleColors.grassDeep : IsleColors.muted,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: IsleText.body()),
                      if (subtitle != null)
                        Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
                    ],
                  ),
                ),
                if (!done)
                  TextButton(
                    onPressed: onTap,
                    child: const Text('설정'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
