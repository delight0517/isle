import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/ai/ai_client.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/youtube/channel_genre_ai_service.dart';
import '../../../core/youtube/channel_genre_block_store.dart';
import '../../../shared/widgets/isle_app_bar.dart';

class ChannelGenreSettingsScreen extends ConsumerStatefulWidget {
  const ChannelGenreSettingsScreen({super.key});

  @override
  ConsumerState<ChannelGenreSettingsScreen> createState() => _ChannelGenreSettingsScreenState();
}

class _ChannelGenreSettingsScreenState extends ConsumerState<ChannelGenreSettingsScreen> {
  bool _auto = IsleUserDefaults.genreBlockAutoAnalyze;
  double _minSamples = IsleUserDefaults.genreBlockMinSamples.toDouble();
  double _maxChannels = IsleUserDefaults.genreMaxChannelsPerRun.toDouble();
  bool _busy = false;
  final _topicCtrl = TextEditingController();

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final samples = ChannelGenreBlockStore.loadSamples();
    final profiles = ChannelGenreBlockStore.loadProfiles();
    final lang = ref.watch(appLocaleProvider)?.languageCode ?? 'ko';

    return Scaffold(
      appBar: const IsleAppBar(title: '유형 차단 (AI)'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '「이 유형의 채널도 차단」을 켠 뒤 차단하면 샘플이 쌓입니다. '
            '${_minSamples.round()}개 이상이면 AI가 비슷한 주제·언어의 채널·키워드를 찾아 숨깁니다. '
            'Google 로그인 + YouTube API가 있으면 검색으로 수십 개 채널을 더 차단할 수 있어요.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          if (!AiClient.isConfigured) ...[
            const SizedBox(height: 12),
            Text('env.dart OpenAI 키 없음 → 채널명 단어 추출만 사용', style: IsleText.caption(color: IsleColors.ocean700)),
          ],
          const SizedBox(height: 16),
          Text('분야·주제로 한 번에 차단', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          Text(
            '예: 스타크래프트2, ASMR, 뉴스 — AI가 비슷한 채널·키워드를 찾아 숨깁니다.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _topicCtrl,
            decoration: const InputDecoration(
              labelText: '차단할 분야 이름',
              hintText: '스타크래프트2',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy || _topicCtrl.text.trim().length < 2
                ? null
                : () async {
                    setState(() => _busy = true);
                    final r = await ChannelGenreAiService.applyTopicLabel(
                      ref,
                      topicLabel: _topicCtrl.text.trim(),
                      languageCode: lang,
                    );
                    if (!context.mounted) return;
                    setState(() => _busy = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          r == null
                              ? '분석 실패'
                              : '「${r.genreLabel}」 키워드 ${r.keywordsAdded} · 채널 ${r.channelsAdded}',
                        ),
                      ),
                    );
                    setState(() {});
                  },
            icon: const Icon(Icons.block_flipped),
            label: const Text('이 분야 차단 시작'),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('샘플 충분 시 자동 분석'),
            value: _auto,
            onChanged: (v) async {
              await IsleUserDefaults.setGenreBlockAutoAnalyze(v);
              setState(() => _auto = v);
            },
          ),
          Text('분석 시작 샘플 수: ${_minSamples.round()}', style: IsleText.body()),
          Slider(
            min: 3,
            max: 15,
            divisions: 12,
            value: _minSamples,
            label: _minSamples.round().toString(),
            onChanged: (v) async {
              setState(() => _minSamples = v);
              await IsleUserDefaults.setGenreBlockMinSamples(v.round());
            },
          ),
          Text('1회 최대 자동 차단 채널: ${_maxChannels.round()}', style: IsleText.body()),
          Slider(
            min: 20,
            max: 300,
            divisions: 28,
            value: _maxChannels,
            label: _maxChannels.round().toString(),
            onChanged: (v) async {
              setState(() => _maxChannels = v);
              await IsleUserDefaults.setGenreMaxChannelsPerRun(v.round());
            },
          ),
          FilledButton.icon(
            onPressed: _busy || samples.length < _minSamples.round()
                ? null
                : () async {
                    setState(() => _busy = true);
                    final r = await ChannelGenreAiService.analyzeAndApply(ref, languageCode: lang);
                    if (context.mounted) {
                      setState(() => _busy = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            r == null
                                ? '분석 실패'
                                : '「${r.genreLabel}」 키워드 ${r.keywordsAdded} · 채널 ${r.channelsAdded}',
                          ),
                        ),
                      );
                      setState(() {});
                    }
                  },
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.psychology_outlined),
            label: Text('지금 유형 분석 (${samples.length}개 샘플)'),
          ),
          const SizedBox(height: 24),
          Text('최근 분석', style: IsleText.subtitle()),
          if (profiles.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('아직 없음', style: IsleText.caption(color: IsleColors.muted)),
            ),
          ...profiles.take(5).map(
                (p) => Card(
                  margin: const EdgeInsets.only(top: 10),
                  child: ListTile(
                    title: Text(p.genreLabel),
                    subtitle: Text(
                      '${p.explanation}\n키워드 ${p.keywords.length} · 자동 차단 채널 ${p.channelsAutoBlocked}',
                      maxLines: 4,
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
          const SizedBox(height: 16),
          Text('샘플 채널', style: IsleText.subtitle()),
          ...samples.take(10).map(
                (s) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.channelName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(s.reason ?? s.pageUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
        ],
      ),
    );
  }
}
