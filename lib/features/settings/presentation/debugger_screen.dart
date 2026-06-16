import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/qa/device_qa_store.dart';
import '../../../core/perf/isle_perf_log_service.dart';
import '../../../core/services/isle_debug_log_service.dart';
import '../../../features/settings/presentation/device_qa_screen.dart';
import '../../../shared/widgets/copy_text_row.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../../shared/widgets/isle_developer_delay_report_card.dart';

/// 디버그 · 크래시 타임라인 — 복사 · 삭제 · Mac 폴더 경로
class DebuggerScreen extends StatefulWidget {
  const DebuggerScreen({super.key});

  @override
  State<DebuggerScreen> createState() => _DebuggerScreenState();
}

class _DebuggerScreenState extends State<DebuggerScreen> {
  int _tab = 0;
  late final void Function(IsleLogEntry) _listener;

  @override
  void initState() {
    super.initState();
    unawaited(IslePerfLogService.ensureReady());
    _listener = (_) {
      if (mounted) setState(() {});
    };
    IsleDebugLogService.addListener(_listener);
  }

  @override
  void dispose() {
    IsleDebugLogService.removeListener(_listener);
    super.dispose();
  }

  Future<void> _copyAll() async {
    final text = await IsleDebugLogService.buildCopyAllText();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전체 로그·크래시 기록 복사됨 — AI에 붙여넣기 하세요')),
      );
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('로그 삭제', style: IsleText.subtitle()),
        content: Text(
          '메모리·파일·타임라인의 로그가 모두 지워집니다.',
          style: IsleText.body(color: IsleColors.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            style: FilledButton.styleFrom(backgroundColor: IsleColors.danger),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await IsleDebugLogService.clearAllLogs();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = IsleDebugLogService.entries.reversed.toList();
    final crashes = IsleDebugLogService.crashHistory;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: const IsleAppBar(title: '디버그 · 크래시'),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: IsleDeveloperDelayReportCard(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Material(
              color: IsleColors.ocean100,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: const Icon(Icons.checklist_rtl, color: IsleColors.ocean700),
                title: Text('실기기 확인', style: IsleText.body()),
                subtitle: Text(
                  '${DeviceQaStore.countChecked(DeviceQaScreen.qaItemIds)} / ${DeviceQaScreen.qaItemIds.length} · TODO §1',
                  style: IsleText.caption(color: IsleColors.muted),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/device-qa'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                _TabChip(label: '로그', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                const SizedBox(width: 8),
                _TabChip(
                  label: '크래시 ${crashes.isNotEmpty ? "(${crashes.length})" : ""}',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (IsleDebugLogService.debugFolderPath != null)
                  CopyTextRow(
                    label: 'Mac·iCloud 폴더',
                    value: IsleDebugLogService.debugFolderPath!,
                  ),
                if (IslePerfLogService.filePath.isNotEmpty)
                  CopyTextRow(label: '렉·CPU 로그', value: IslePerfLogService.filePath),
                const SizedBox(height: 8),
              Text(
                '시각은 초·밀리초까지 표시됩니다. 앱이 꺼져도 파일에 남습니다.',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              const SizedBox(height: 8),
              Text(
                'Delete Fix / devicectl: Debug 빌드는 즉시 종료(SIGSEGV)됩니다. '
                'Profile 빌드만 홈 화면·devicectl 실행 가능 → 터미널에서 '
                'isle/tool/ios_device_profile.sh',
                style: IsleText.caption(color: IsleColors.danger),
              ),
              ],
            ),
          ),
          Expanded(
            child: _tab == 0 ? _LogList(logs: logs) : _CrashList(crashes: crashes),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: IsleDeveloperDelayReportCard(compact: true),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('로그 비우기'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _copyAll,
                    style: FilledButton.styleFrom(
                      backgroundColor: IsleColors.ocean500,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.copy_all),
                    label: const Text('전체 복사 (AI용)'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? IsleColors.ocean500 : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: IsleText.caption(
              color: selected ? Colors.white : IsleColors.ocean900,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({required this.logs});

  final List<IsleLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Center(child: Text('로그 없음', style: IsleText.body(color: IsleColors.muted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: logs.length,
      itemBuilder: (_, i) {
        final e = logs[i];
        final isErr = e.level == IsleLogLevel.error;
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          color: isErr ? IsleColors.danger.withValues(alpha: 0.08) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SelectableText(
              e.formatLine(),
              style: IsleText.caption(
                color: isErr ? IsleColors.danger : IsleColors.ocean900,
              ).copyWith(fontFamily: 'monospace', fontSize: 11, height: 1.35),
            ),
          ),
        );
      },
    );
  }
}

class _CrashList extends StatelessWidget {
  const _CrashList({required this.crashes});

  final List<CrashReport> crashes;

  @override
  Widget build(BuildContext context) {
    if (crashes.isEmpty) {
      final ignored = IsleDebugLogService.ignoredCrashCount;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            ignored > 0
                ? '표시할 실제 크래시 없음\n(폰트·백업·구버전 노이즈 $ignored건은 숨김)'
                : '크래시 기록 없음',
            textAlign: TextAlign.center,
            style: IsleText.body(color: IsleColors.muted),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: crashes.length,
      itemBuilder: (_, i) {
        final c = crashes[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            title: Text(c.kind, style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text(
              c.message,
              style: IsleText.caption(color: IsleColors.muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  c.formatBlock(),
                  style: IsleText.caption().copyWith(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: IsleColors.ocean900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
