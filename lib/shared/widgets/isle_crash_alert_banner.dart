import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_typography.dart';
import '../../core/navigation/isle_navigation.dart';
import '../../core/services/isle_debug_log_service.dart';
import '../../core/services/isle_user_defaults.dart';

/// 최근 크래시·flutter_error — 즉시 복사 · 디버그 화면
class IsleCrashAlertBanner extends StatefulWidget {
  const IsleCrashAlertBanner({super.key});

  @override
  State<IsleCrashAlertBanner> createState() => _IsleCrashAlertBannerState();
}

class _IsleCrashAlertBannerState extends State<IsleCrashAlertBanner> {
  CrashReport? _latest;
  late final void Function(IsleLogEntry) _logListener;

  @override
  void initState() {
    super.initState();
    _syncLatest();
    _logListener = (_) => _syncLatest();
    IsleDebugLogService.addListener(_logListener);
    IsleDebugLogService.addCrashListener(_onCrash);
  }

  @override
  void dispose() {
    IsleDebugLogService.removeListener(_logListener);
    IsleDebugLogService.removeCrashListener(_onCrash);
    super.dispose();
  }

  void _onCrash(CrashReport c) {
    if (!mounted) return;
    setState(() => _latest = c);
  }

  void _syncLatest() {
    final list = IsleDebugLogService.crashHistory;
    if (list.isEmpty) {
      setState(() => _latest = null);
      return;
    }
    final c = list.first;
    final ack = IsleUserDefaults.lastAcknowledgedCrashId;
    setState(() => _latest = c.id == ack ? null : c);
  }

  Future<void> _copyCrash() async {
    final c = _latest;
    if (c == null) return;
    final text = await IsleDebugLogService.buildCopyAllText();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('크래시 로그 복사됨'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _dismiss() async {
    final c = _latest;
    if (c != null) await IsleUserDefaults.setLastAcknowledgedCrashId(c.id);
    if (mounted) setState(() => _latest = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = _latest;
    if (c == null) return const SizedBox.shrink();

    final top = MediaQuery.paddingOf(context).top;
    final preview = c.message.length > 72 ? '${c.message.substring(0, 72)}…' : c.message;

    return Positioned(
      top: top + 4,
      left: 12,
      right: 12,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF3D1515),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '오류 발생 (${c.kind})',
                      style: IsleText.caption(color: Colors.white).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: _dismiss,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Text(preview, style: IsleText.caption(color: Colors.white70), maxLines: 2),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: _copyCrash,
                    icon: const Icon(Icons.copy, size: 16, color: Colors.white),
                    label: const Text('크래시 로그 복사', style: TextStyle(color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: () {
                      IsleNavigation.push('/settings/debugger');
                      _dismiss();
                    },
                    child: const Text('로그 열기', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
