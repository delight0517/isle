import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/isle_data_export_service.dart';
import '../../../core/services/isle_survival_backup_service.dart';
import '../../../core/library/personal_library_store.dart';
import '../../../core/youtube/blocked_channel_store.dart';
import '../../../core/youtube/content_filter_store.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import 'isle_backup_code_sheet.dart';
import '../../feed/providers/feed_provider.dart';

/// JSON 백업·복원 + 재설치 생존 (Documents/Isle Backup)
class DataBackupScreen extends ConsumerStatefulWidget {
  const DataBackupScreen({super.key});

  @override
  ConsumerState<DataBackupScreen> createState() => _DataBackupScreenState();
}

class _DataBackupScreenState extends ConsumerState<DataBackupScreen> {
  final _pasteCtrl = TextEditingController();
  bool _busy = false;
  String _folderPath = '';
  String _lastSyncLabel = '—';

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final path = await IsleSurvivalBackupService.backupFolderLabel();
    final at = IsleSurvivalBackupService.lastSyncAt;
    if (!mounted) return;
    setState(() {
      _folderPath = path;
      _lastSyncLabel = at == null
          ? '아직 없음'
          : DateFormat('yyyy-MM-dd HH:mm').format(at.toLocal());
    });
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await IsleDataExportService.shareExport();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    try {
      await IsleSurvivalBackupService.syncNow();
      await _refreshStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('백업 폴더에 저장됨')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFromFolder() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('백업에서 복원', style: IsleText.subtitle()),
        content: const Text(
          '현재 기기의 차단·스케줄·라이브러리를 백업 파일 내용으로 덮어씁니다.\n'
          '계속할까요?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('복원')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final n = await IsleSurvivalBackupService.restoreNow(confirm: false);
      await _reloadProviders();
      await _refreshStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('복원 완료 (~$n건)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('복원 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) return;
    _pasteCtrl.text = String.fromCharCodes(bytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일을 불러왔어요 — 「복원」을 눌러 주세요')),
      );
    }
  }

  Future<void> _pickFolder() async {
    setState(() => _busy = true);
    try {
      final path = await IsleSurvivalBackupService.pickBackupFolder();
      await _refreshStatus();
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('백업 폴더: $path')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final raw = _pasteCtrl.text.trim();
    if (raw.isEmpty) return;
    setState(() => _busy = true);
    try {
      final n = await IsleSurvivalBackupService.importSnapshotString(raw);
      await _reloadProviders();
      await IsleSurvivalBackupService.syncNow();
      await _refreshStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('복원 완료 (~$n건)')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JSON 형식을 확인해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reloadProviders() async {
    await ref.read(blockedChannelsProvider.notifier).reload();
    await ref.read(blockedVideosProvider.notifier).reload();
    await ref.read(blockedKeywordsProvider.notifier).reload();
    await ref.read(personalLibraryProvider.notifier).reload();
    await ref.read(connectedSourcesProvider.notifier).reload();
    ref.invalidate(feedProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IsleAppBar(title: '데이터 백업'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : () => showIsleBackupCodeSheet(context, ref),
            icon: const Icon(Icons.qr_code_2),
            label: const Text('백업 코드보내기 / 복원'),
          ),
          const SizedBox(height: 8),
          Text(
            '가장 먼저 여기서 복사·복원하세요. iCloud 폴더 백업은 아래에 있어요.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: IsleColors.ocean100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('재설치해도 데이터 유지', style: IsleText.subtitle(color: IsleColors.ocean900)),
                const SizedBox(height: 8),
                Text(
                  IsleSurvivalBackupService.platformSurvivalHint,
                  style: IsleText.caption(color: IsleColors.ocean700),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  '폴더: $_folderPath\ncurrent.json · 마지막 동기화: $_lastSyncLabel',
                  style: IsleText.caption(color: IsleColors.ocean900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _syncNow,
            icon: const Icon(Icons.save),
            label: const Text('지금 백업 (current.json)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restoreFromFolder,
            icon: const Icon(Icons.restore),
            label: const Text('이 폴더에서 복원'),
          ),
          if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : IsleSurvivalBackupService.openBackupFolderInFinder,
              icon: const Icon(Icons.folder_open),
              label: const Text('백업 폴더 열기'),
            ),
          ],
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickFolder,
            icon: const Icon(Icons.drive_folder_upload_outlined),
            label: const Text('폴더 변경 (iCloud·외장 디스크)'),
          ),
          const Divider(height: 32),
          Text(
            '수동 공유 백업 · export_schema ${IsleDataExportService.exportSchema}',
            style: IsleText.subtitle(),
          ),
          const SizedBox(height: 8),
          Text(
            '차단·키워드·라이브러리·스케줄·섬 스냅샷·AI 설정(키 포함)이 JSON에 들어갑니다.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.ios_share),
            label: const Text('백업 파일 보내기'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickJsonFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('JSON 파일 선택'),
          ),
          const SizedBox(height: 24),
          Text('복원 — JSON 붙여넣기', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          TextField(
            controller: _pasteCtrl,
            maxLines: 6,
            style: IsleText.body(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '{ "blocked_channels": ... }',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) _pasteCtrl.text = data!.text!;
                  },
                  icon: const Icon(Icons.paste),
                  label: const Text('붙여넣기'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _import,
                  child: const Text('복원'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
