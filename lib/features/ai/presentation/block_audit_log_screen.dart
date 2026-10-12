import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ai/block_chat/block_audit_analysis_service.dart';
import '../../../core/ai/block_chat/block_audit_log_store.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import 'block_audit_log_pasteboard.dart';

/// 차단 AI 챗으로 받은 명령·적용 결과 로그 (14일 보관) + AI 문제 분석
class BlockAuditLogScreen extends StatefulWidget {
  const BlockAuditLogScreen({super.key});

  @override
  State<BlockAuditLogScreen> createState() => _BlockAuditLogScreenState();
}

class _BlockAuditLogScreenState extends State<BlockAuditLogScreen> {
  List<BlockAuditLogEntry> _entries = const [];
  bool _loading = true;
  bool _analyzing = false;
  BlockAuditAnalysisResult? _analysis;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await BlockAuditLogStore.ensureOpen();
    if (!mounted) return;
    setState(() {
      _entries = BlockAuditLogStore.loadRecent();
      _loading = false;
    });
  }

  Future<void> _analyze() async {
    setState(() => _analyzing = true);
    final result = await BlockAuditAnalysisService.analyze();
    if (!mounted) return;
    setState(() {
      _analysis = result;
      _analyzing = false;
    });
  }

  Future<void> _copyRecent24h() async {
    final entries = BlockAuditLogStore.loadWithin(const Duration(hours: 24));
    final text = BlockAuditLogStore.buildCopyText(entries, title: '최근 24시간 변경 로그');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          entries.isEmpty
              ? '최근 24시간 내 변경 없음 (빈 로그 복사됨)'
              : '최근 24시간 변경 ${entries.length}건 복사됨 — AI에 붙여넣기 하세요',
        ),
      ),
    );
  }

  /// "지난 2주간 log 전부 복사하기" — 설정 화면 상단 버튼과 동일한 동작
  /// (2026-07-16 사용자 요청 — 리셋 원인 분석용으로 보관 기간 전체를 한 번에).
  Future<void> _copyAll14Days() => BlockAuditLogPasteboard.copyAll(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IsleColors.sand100,
      appBar: IsleAppBar(
        title: '차단 로그 · 14일',
        actions: [
          IconButton(
            tooltip: '최근 24시간 변경만 복사 (디버그용)',
            onPressed: _copyRecent24h,
            icon: const Icon(Icons.copy_all),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '차단 AI 챗으로 받은 명령과 실제 적용된 내용을 14일간 보관해요. '
                  'AI로 분석하면 잘못 적용됐거나 방치된 항목을 찾아드려요. '
                  '우측 상단 복사 버튼은 전체 백업 대신 최근 24시간 변경분만 뽑아요.',
                  style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _copyAll14Days,
                  icon: const Icon(Icons.copy_all),
                  label: const Text('지난 2주간 log 전부 복사하기'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _analyzing ? null : _analyze,
                  icon: _analyzing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_fix_high),
                  label: Text(_analyzing ? '분석하는 중…' : 'AI로 문제 찾기'),
                ),
                if (_analysis != null) ...[
                  const SizedBox(height: 12),
                  _AnalysisCard(result: _analysis!),
                ],
                const SizedBox(height: 20),
                Text('최근 14일 (${_entries.length}건)', style: IsleText.subtitle()),
                const SizedBox(height: 8),
                if (_entries.isEmpty)
                  Text('아직 기록이 없어요.', style: IsleText.body(color: IsleColors.muted))
                else
                  ..._entries.map((e) => _LogTile(entry: e)),
              ],
            ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.result});
  final BlockAuditAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.usedAi ? Icons.smart_toy_outlined : Icons.rule_outlined,
                size: 18,
                color: IsleColors.ocean700,
              ),
              const SizedBox(width: 6),
              Text(
                result.usedAi ? 'AI 분석 결과' : '기본 점검 결과',
                style: IsleText.subtitle(),
              ),
            ],
          ),
          if (result.findings.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final f in result.findings) ...[
              Text('• ${f.title}', style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 6),
                child: Text(f.detail, style: IsleText.caption(color: IsleColors.muted)),
              ),
            ],
          ],
          if (result.aiNote != null && result.aiNote!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(result.aiNote!, style: IsleText.body().copyWith(height: 1.5)),
          ],
          if (result.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('특별한 문제는 안 보여요.', style: IsleText.body(color: IsleColors.muted)),
            ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});
  final BlockAuditLogEntry entry;

  String _timeLabel(DateTime at) {
    final now = DateTime.now();
    final diff = now.difference(at);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: entry.success ? IsleColors.ocean100 : IsleColors.danger.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                entry.success ? Icons.check_circle_outline : Icons.error_outline,
                size: 16,
                color: entry.success ? IsleColors.ocean500 : IsleColors.danger,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text('"${entry.command}"', style: IsleText.body(color: IsleColors.ocean900)),
              ),
              Text(_timeLabel(entry.at), style: IsleText.caption(color: IsleColors.muted)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            entry.appVersion.isEmpty ? '버전 알수없음' : 'v${entry.appVersion}',
            style: IsleText.caption(color: IsleColors.muted).copyWith(fontSize: 10),
          ),
          const SizedBox(height: 6),
          Text(entry.summary, style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4)),
          if (entry.steps.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...entry.steps.take(5).map(
                  (s) => Text('· $s', style: IsleText.caption(color: IsleColors.muted)),
                ),
          ],
        ],
      ),
    );
  }
}
