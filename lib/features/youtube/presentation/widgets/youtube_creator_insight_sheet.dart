import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/youtube/models/youtube_creator_insight.dart';
import '../../../../core/youtube/youtube_creator_insight_service.dart';
import '../../../../core/youtube/youtube_creator_insight_store.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../shared/widgets/isle_sheet.dart';
import '../../../../shared/widgets/safe_sheet_close.dart';

/// 유튜브 URL → CC·AI 크리에이터 분석
Future<void> showYoutubeCreatorInsightSheet(
  BuildContext context,
  WidgetRef ref, {
  String? initialUrl,
}) async {
  await showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => _YoutubeCreatorInsightSheet(initialUrl: initialUrl),
  );
}

class _YoutubeCreatorInsightSheet extends ConsumerStatefulWidget {
  const _YoutubeCreatorInsightSheet({this.initialUrl});

  final String? initialUrl;

  @override
  ConsumerState<_YoutubeCreatorInsightSheet> createState() => _YoutubeCreatorInsightSheetState();
}

class _YoutubeCreatorInsightSheetState extends ConsumerState<_YoutubeCreatorInsightSheet> {
  late final TextEditingController _urlCtrl;
  YoutubeCreatorInsight? _result;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.initialUrl ?? '');
    if (widget.initialUrl != null && widget.initialUrl!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    dismissKeyboard();
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final tags = await ref.read(userInterestTagsProvider.future);
      final insight = await YoutubeCreatorInsightService.analyzeUrl(url, userInterests: tags);
      await YoutubeCreatorInsightStore.save(insight);
      if (!mounted) return;
      setState(() => _result = insight);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final r = _result;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('크리에이터 분석', style: IsleText.subtitle())),
                IconButton(
                  onPressed: () => safeCloseSheet(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              '자막(CC)과 내 관심 분야를 바탕으로 차별점·핵심·적용 아이디어를 뽑아요.',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _urlCtrl,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _analyze(),
              decoration: const InputDecoration(
                hintText: 'https://youtube.com/watch?v=…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _analyze,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_busy ? 'CC·AI 분석 중…' : '분석하기'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: IsleText.caption(color: IsleColors.danger)),
            ],
            if (r != null) ...[
              const SizedBox(height: 20),
              _BadgeRow(usedCaptions: r.usedCaptions, usedAi: r.usedAi),
              const SizedBox(height: 12),
              Text(r.title, style: IsleText.subtitle()),
              if (r.channelName.isNotEmpty)
                Text(r.channelName, style: IsleText.caption(color: IsleColors.muted)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: IsleColors.gold500.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(r.oneLiner, style: IsleText.body()),
              ),
              const SizedBox(height: 16),
              _Section(title: '차별점 (CC·콘텐츠)', items: r.differentiationPoints),
              const SizedBox(height: 12),
              _Section(title: '핵심 포인트', items: r.keyPoints),
              const SizedBox(height: 12),
              Text('내 관심 분야에 적용', style: IsleText.subtitle()),
              const SizedBox(height: 8),
              ...r.applications.map((a) => _ApplicationCard(app: a)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/youtube/browser?url=${Uri.encodeComponent(r.sourceUrl)}');
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('이 영상 보기'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.usedCaptions, required this.usedAi});

  final bool usedCaptions;
  final bool usedAi;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        Chip(
          avatar: Icon(
            usedCaptions ? Icons.closed_caption : Icons.closed_caption_disabled,
            size: 16,
          ),
          label: Text(usedCaptions ? 'CC 사용' : 'CC 없음'),
        ),
        Chip(
          avatar: Icon(usedAi ? Icons.auto_awesome : Icons.offline_bolt, size: 16),
          label: Text(usedAi ? 'AI 분석' : '로컬 분석'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: IsleText.subtitle()),
        const SizedBox(height: 6),
        ...items.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 16)),
                Expanded(child: Text(t, style: IsleText.body())),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.app});

  final CreatorApplication app;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(app.interest, style: IsleText.subtitle(color: IsleColors.ocean700)),
            const SizedBox(height: 4),
            Text(app.application, style: IsleText.body()),
            if (app.actionIdea.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('💡 ${app.actionIdea}', style: IsleText.caption(color: IsleColors.ocean900)),
            ],
          ],
        ),
      ),
    );
  }
}
