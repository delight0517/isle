import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/isle_backup_service.dart';
import '../../../shared/widgets/collapsible_backup_code.dart';
import '../../../shared/widgets/isle_sheet.dart';
import '../../../shared/widgets/safe_sheet_close.dart';
import '../../../core/library/personal_library_store.dart';
import '../../../core/youtube/blocked_channel_store.dart';
import '../../../core/youtube/content_filter_store.dart';
import '../../feed/providers/feed_provider.dart';

Future<void> showIsleBackupCodeSheet(BuildContext context, WidgetRef ref) async {
  await showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => _IsleBackupCodeSheet(ref: ref),
  );
}

class _IsleBackupCodeSheet extends StatefulWidget {
  const _IsleBackupCodeSheet({required this.ref});

  final WidgetRef ref;

  @override
  State<_IsleBackupCodeSheet> createState() => _IsleBackupCodeSheetState();
}

class _IsleBackupCodeSheetState extends State<_IsleBackupCodeSheet> {
  final _restoreCtrl = TextEditingController();
  String? _exportCode;
  bool _loadingExport = true;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _loadExport();
  }

  @override
  void dispose() {
    _restoreCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExport() async {
    try {
      final code = await IsleBackupService.exportCode();
      if (mounted) {
        setState(() {
          _exportCode = code;
          _loadingExport = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingExport = false);
    }
  }

  Future<void> _restore(IsleRestoreMode mode) async {
    dismissKeyboard();
    final raw = _restoreCtrl.text;
    if (raw.trim().isEmpty) {
      _snack('복원할 백업 코드를 붙여넣어 주세요');
      return;
    }
    setState(() => _restoring = true);
    try {
      final count = await IsleBackupService.restore(raw, mode);
      await _reloadProviders();
      if (!mounted) return;
      _snack(
        mode == IsleRestoreMode.replaceAll
            ? '전체 복원 완료 (~$count건)'
            : '병합 복원 완료 (~$count건)',
      );
      await safeCloseSheet(context);
    } catch (e) {
      if (mounted) {
        _snack('백업 코드 오류 — ${e.toString().split('\n').first}');
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _reloadProviders() async {
    final ref = widget.ref;
    await ref.read(blockedChannelsProvider.notifier).reload();
    await ref.read(blockedVideosProvider.notifier).reload();
    await ref.read(blockedKeywordsProvider.notifier).reload();
    await ref.read(personalLibraryProvider.notifier).reload();
    await ref.read(connectedSourcesProvider.notifier).reload();
    ref.invalidate(feedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return GestureDetector(
      onTap: dismissKeyboard,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text('백업 코드', style: IsleText.subtitle())),
                  TextButton(onPressed: () => safeCloseSheet(context), child: const Text('닫기')),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '메모·비밀번호 관리자에 붙여넣을 수 있는 한 줄 코드예요. '
                '앱 삭제 전에 복사해 두세요.',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              const SizedBox(height: 16),
              if (_loadingExport)
                const Center(child: CircularProgressIndicator())
              else if (_exportCode != null)
                CollapsibleBackupCode(code: _exportCode!),
              const SizedBox(height: 20),
              Text('코드로 복원', style: IsleText.subtitle()),
              const SizedBox(height: 8),
              TextField(
                controller: _restoreCtrl,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => dismissKeyboard(),
                decoration: const InputDecoration(
                  hintText: '백업 코드 붙여넣기…',
                  border: OutlineInputBorder(),
                ),
              ),
              TextButton.icon(
                onPressed: dismissKeyboard,
                icon: const Icon(Icons.keyboard_hide_outlined, size: 18),
                label: const Text('키보드 숨기기'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _restoring ? null : () => _restore(IsleRestoreMode.replaceAll),
                child: _restoring
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('복원 (전체 덮어쓰기)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _restoring ? null : () => _restore(IsleRestoreMode.merge),
                child: const Text('복원 (병합)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
