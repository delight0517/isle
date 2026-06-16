import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/isle_sheet.dart';
import '../../../core/insight/insight_crafter_service.dart';
import '../../../core/insight/insight_extractor_remote_service.dart';
import '../../../core/insight/insight_portfolio_store.dart';
import '../../../core/insight/knowledge_visual_system.dart';
import '../../../core/insight/models/insight_card.dart';
import '../../feed/providers/feed_provider.dart';
import '../application/insight_crafter_provider.dart';
import '../providers/insight_portfolio_provider.dart';

/// 거친 메모 → (클라우드 Edge) AI 정제 → 포트폴리오 발행
Future<void> showInsightComposeSheet(
  BuildContext context,
  WidgetRef ref, {
  required InsightCard card,
}) async {
  await showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => _InsightComposeSheet(initial: card, parentRef: ref),
  );
  invalidateInsightPortfolio(ref);
  ref.invalidate(feedProvider);
}

class _InsightComposeSheet extends StatefulWidget {
  const _InsightComposeSheet({required this.initial, required this.parentRef});
  final InsightCard initial;
  final WidgetRef parentRef;

  @override
  State<_InsightComposeSheet> createState() => _InsightComposeSheetState();
}

class _InsightComposeSheetState extends State<_InsightComposeSheet> {
  late final TextEditingController _noteCtrl;
  late InsightCard _card;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _card = widget.initial;
    _noteCtrl = TextEditingController(text: _card.userNote);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _polish() async {
    setState(() => _busy = true);
    final polished = await InsightCrafterService.polishUserNote(
      roughNote: _noteCtrl.text,
      title: _card.title,
      channelName: _card.channelName,
      contextLines: _card.aiSummaryLines,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _noteCtrl.text = polished;
    });
  }

  Future<void> _cloudCraft() async {
    setState(() => _busy = true);
    final updated = await widget.parentRef.read(insightCrafterProvider.notifier).craftInsight(
          _card.url,
          _noteCtrl.text,
          preferCloud: true,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (updated != null) {
        _card = updated;
        if (_noteCtrl.text.trim().isEmpty && updated.userNote.isNotEmpty) {
          _noteCtrl.text = updated.userNote;
        }
      }
    });
    final err = widget.parentRef.read(insightCrafterProvider).error;
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.toString())),
      );
    }
  }

  Future<void> _saveAndPublish() async {
    setState(() => _busy = true);
    final c = _card.copyWith(userNote: _noteCtrl.text.trim());
    await InsightPortfolioStore.upsert(c);
    await InsightPortfolioStore.publish(c.id);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('포트폴리오에 발행됐어요 · 피드·명함에 반영')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cloudReady = InsightExtractorRemoteService.canUse;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '인사이트 카드',
            style: KnowledgeVisual.editorialBody(color: KnowledgeVisual.ink, fontSize: 20)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          if (cloudReady)
            Text(
              '클라우드 분석 ON · 자막·AI는 서버에서 처리',
              style: KnowledgeVisual.editorialMonoHint(color: KnowledgeVisual.intelligentBlue),
            ),
          const SizedBox(height: 8),
          Text(_card.title, style: IsleText.subtitle()),
          const SizedBox(height: 12),
          ..._card.aiSummaryLines.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('· $l', style: IsleText.body()),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '나의 한 줄 통찰 (거친 메모 OK)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          if (cloudReady)
            OutlinedButton.icon(
              onPressed: _busy ? null : _cloudCraft,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_outlined),
              label: Text(_busy ? '서버에서 분석 중…' : '클라우드에서 다시 분석'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _polish,
            child: const Text('AI로 문장 다듬기 (기기)'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _saveAndPublish,
            style: FilledButton.styleFrom(
              backgroundColor: KnowledgeVisual.intelligentBlue,
            ),
            child: const Text('포트폴리오에 발행'),
          ),
        ],
      ),
    );
  }
}
