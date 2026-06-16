import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/block_schedule/block_schedule_enforcement_service.dart';
import '../../../../core/block_schedule/url_rules/schedule_rule.dart';
import '../../../../core/block_schedule/url_rules/schedule_rule_kind.dart';
import '../../../../core/block_schedule/url_rules/schedule_rule_smart_input.dart';
import '../../../../core/block_schedule/url_rules/schedule_rule_store.dart';
import '../../../../core/block_schedule/url_rules/url_rule_detector.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/platform/ios_rules_export_service.dart';
import 'smart_rule_input_section.dart';

/// 스케줄 편집 — URL 규칙 목록·스마트 입력·일괄 붙여넣기
class ScheduleRulesSection extends StatefulWidget {
  const ScheduleRulesSection({
    super.key,
    required this.scheduleId,
    required this.canEdit,
  });

  final String scheduleId;
  final bool canEdit;

  @override
  State<ScheduleRulesSection> createState() => ScheduleRulesSectionState();
}

class ScheduleRulesSectionState extends State<ScheduleRulesSection> {
  List<ScheduleRule> _rules = const [];
  final _bulkCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _busy = false;
  String? _lastFeedback;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _bulkCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    await ScheduleRuleStore.ensureOpen();
    if (!mounted) return;
    setState(() => _rules = ScheduleRuleStore.loadForSchedule(widget.scheduleId));
  }

  Future<void> _afterChange({String? feedback}) async {
    await _reload();
    await BlockScheduleEnforcementService.syncPlatformEnforcement();
    await IosRulesExportService.exportNow();
    if (!mounted) return;
    setState(() => _lastFeedback = feedback);
  }

  Future<void> _insert(String raw, DetectedScheduleRule detected) async {
    final r = await ScheduleRuleSmartInput.insert(
      scheduleId: widget.scheduleId,
      detected: detected,
      rawInput: raw,
      skipWholeSiteConfirm: true,
    );
    await _afterChange(feedback: r.feedback ?? _resultLine(r));
  }

  Future<void> _addVariation(String stem) async {
    final r = await ScheduleRuleSmartInput.addUrlContains(
      scheduleId: widget.scheduleId,
      stem: stem,
    );
    await _afterChange(feedback: r.feedback ?? '주소 포함 규칙 추가됨');
  }

  Future<void> _bulkAdd() async {
    if (_busy || !widget.canEdit) return;
    setState(() => _busy = true);
    try {
      final r = await ScheduleRuleSmartInput.addBulkSmart(
        scheduleId: widget.scheduleId,
        text: _bulkCtrl.text,
      );
      _bulkCtrl.clear();
      await _afterChange(feedback: r.feedback ?? _resultLine(r));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _resultLine(ScheduleRuleInsertResult r) {
    if (r.added == 0 && r.duplicates == 0) return '추가된 규칙 없음';
    final p = <String>[];
    if (r.added > 0) p.add('${r.added}개 추가');
    if (r.duplicates > 0) p.add('중복 ${r.duplicates}');
    return p.join(' · ');
  }

  Future<void> _delete(ScheduleRule rule) async {
    await ScheduleRuleStore.delete(rule.id);
    await _afterChange(feedback: '규칙 삭제됨');
  }

  Future<void> _exportHosts() async {
    final hosts = _rules
        .where((r) => r.kind.appliesDns)
        .map((r) => r.pattern)
        .toList();
    if (hosts.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: hosts.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('host·wildcard 목록을 복사했어요')),
    );
  }

  List<ScheduleRule> get _filteredRules {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _rules;
    return _rules
        .where((r) => r.pattern.contains(q) || r.kind.labelKo.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRules;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SmartRuleInputSection(
          enabled: widget.canEdit && !_busy,
          onSubmit: _insert,
          onAddVariation: widget.canEdit ? _addVariation : null,
        ),
        if (_lastFeedback != null) ...[
          const SizedBox(height: 8),
          _RuleAddFeedbackBanner(message: _lastFeedback!),
        ],
        const SizedBox(height: 8),
        Text(
          '키워드는 피드·검색 숨김 · host는 Safari·DNS · 포함: 은 유사 URL',
          style: IsleText.badge(color: IsleColors.muted),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            labelText: '목록에서 찾기 (추가 아님)',
            prefixIcon: Icon(Icons.search, size: 20),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        const SizedBox(height: 8),
        if (_rules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'URL·단어를 붙여넣으면 자동 분류됩니다',
              style: IsleText.caption(color: IsleColors.muted),
            ),
          )
        else
          ...filtered.map(
            (r) => _RuleTile(
              rule: r,
              canEdit: widget.canEdit,
              onDelete: () => _delete(r),
            ),
          ),
        if (_rules.isNotEmpty && filtered.isEmpty)
          Text('검색 결과 없음', style: IsleText.caption(color: IsleColors.muted)),
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('여러 URL · 파일 · 고급', style: IsleText.caption()),
          children: [
            TextField(
              controller: _bulkCtrl,
              enabled: widget.canEdit && !_busy,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '# 주석 가능\nhttps://mingky01.live\n*darkgirl*\n포함:linkdamoa',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.canEdit && !_busy ? _bulkAdd : null,
                    child: const Text('목록 추가'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _rules.any((r) => r.kind.appliesDns) ? _exportHosts : null,
                  child: const Text('host 내보내기'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _RuleAddFeedbackBanner extends StatelessWidget {
  const _RuleAddFeedbackBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: IsleColors.ocean100,
        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
      ),
      child: Text(message, style: IsleText.caption(color: IsleColors.ocean900)),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.canEdit,
    required this.onDelete,
  });

  final ScheduleRule rule;
  final bool canEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(_iconFor(rule.kind), size: 18, color: IsleColors.ocean500),
      title: Text(rule.pattern, style: IsleText.body()),
      subtitle: Text(rule.kind.labelKo, style: IsleText.badge(color: IsleColors.muted)),
      trailing: canEdit
          ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDelete,
            )
          : null,
    );
  }

  IconData _iconFor(ScheduleRuleKind k) => switch (k) {
        ScheduleRuleKind.host || ScheduleRuleKind.wildcard => Icons.language,
        ScheduleRuleKind.urlContains => Icons.link_off,
        ScheduleRuleKind.keyword || ScheduleRuleKind.genreKeyword => Icons.search_off,
        ScheduleRuleKind.channelUrl => Icons.subscriptions_outlined,
        ScheduleRuleKind.videoUrl => Icons.play_disabled,
      };
}
