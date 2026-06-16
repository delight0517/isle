import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ai/ai_client.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/env.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/youtube/creative_analytics/video_narrative_remote_service.dart';
import '../../../../core/youtube/creative_analytics/creative_analytics_service.dart';
import '../../../../core/youtube/creative_analytics/creative_analytics_store.dart';
import '../../../../core/youtube/creative_analytics/growth_path_advisor_service.dart';
import '../../../../core/youtube/creative_analytics/models/growth_path_bundle.dart';
import '../../../../core/youtube/creative_analytics/models/bench_channel.dart';
import '../../../../core/youtube/creative_analytics/models/channel_video_snapshot.dart';
import '../../../../core/youtube/creative_analytics/models/narrative_report.dart';
import '../../../../core/youtube/creative_analytics/models/outlier_hit.dart';
import '../../../../core/youtube/creative_analytics/outlier_engine.dart';
import '../widgets/growth_path_top3_panel.dart';
import '../widgets/matchup_radar_chart.dart';
import '../widgets/narrative_timeline_bar.dart';
import '../widgets/originality_panel.dart';

/// 크리에이티브 분석 — 흥행 레이더 · 시나리오 해부 · 채널 매치업
class CreativeAnalyticsScreen extends StatefulWidget {
  const CreativeAnalyticsScreen({super.key, this.initialTabIndex = 0});

  /// 0=맞춤 Top3 · 1=흥행 · 2=시나리오 · 3=매치업
  final int initialTabIndex;

  @override
  State<CreativeAnalyticsScreen> createState() => _CreativeAnalyticsScreenState();
}

class _CreativeAnalyticsScreenState extends State<CreativeAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<BenchChannel> _channels = [];
  String? _selectedId;
  List<ChannelVideoSnapshot> _videos = [];
  List<OutlierHit> _outliers = [];
  bool _scanning = false;
  String? _error;

  ChannelVideoSnapshot? _anatomyVideo;
  NarrativeReport? _narrative;
  bool _analyzing = false;

  BenchChannel? _matchA;
  BenchChannel? _matchB;
  bool _cloudEnabled = false;
  GrowthPathBundle? _growthPaths;
  bool _pathLoading = false;

  @override
  void initState() {
    super.initState();
    final tab = widget.initialTabIndex.clamp(0, 3);
    _tabs = TabController(length: 4, vsync: this, initialIndex: tab);
    _cloudEnabled = IsleUserDefaults.creativeAnalyticsCloudEnabled;
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    await CreativeAnalyticsStore.ensureOpen();
    final ch = CreativeAnalyticsStore.loadChannels();
    if (!mounted) return;
    setState(() {
      _channels = ch;
      if (_selectedId == null && ch.isNotEmpty) _selectedId = ch.first.id;
    });
    _loadCache();
    setState(() => _growthPaths = CreativeAnalyticsStore.loadGrowthPathBundle());
  }

  Future<void> _computeGrowthPaths() async {
    setState(() => _pathLoading = true);
    try {
      final bundle = await GrowthPathAdvisorService.recommend();
      if (!mounted) return;
      setState(() {
        _growthPaths = bundle;
        _pathLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _pathLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: IsleColors.danger),
      );
    }
  }

  void _openAnatomyForVideo(String videoId) {
    final videos = _videos;
    final fromOutliers = _outliers.map((h) => h.video).toList();
    final all = [...fromOutliers, ...videos];
    final v = all.where((e) => e.videoId == videoId).firstOrNull;
    if (v != null) {
      _tabs.animateTo(2);
      _runAnatomy(v);
      return;
    }
    _tabs.animateTo(2);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('흥행 레이더에서 해당 채널을 스캔한 뒤 해부해 주세요.')),
    );
  }

  void _loadCache() {
    final id = _selectedId;
    if (id == null) {
      setState(() {
        _videos = [];
        _outliers = [];
      });
      return;
    }
    setState(() {
      _videos = CreativeAnalyticsStore.loadVideos(id);
      _outliers = CreativeAnalyticsStore.loadOutliers(id);
    });
  }

  BenchChannel? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final c in _channels) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _addChannel() async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('벤치마킹 채널', style: IsleText.subtitle()),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'https://youtube.com/@channel 또는 /channel/UC…',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('등록')),
        ],
      ),
    );
    ctrl.dispose();
    if (url == null || url.isEmpty || !mounted) return;
    try {
      final ch = await CreativeAnalyticsService.addChannel(url);
      setState(() => _selectedId = ch.id);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${ch.name}」 등록됨 — 스캔을 눌러 대박 영상을 찾아보세요')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: IsleColors.danger),
      );
    }
  }

  Future<void> _scan() async {
    final ch = _selected;
    if (ch == null) return;
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final result = await CreativeAnalyticsService.scanChannel(ch);
      if (!mounted) return;
      setState(() {
        _videos = result.videos;
        _outliers = result.hits;
        _scanning = false;
      });
      if (_outliers.isEmpty && _videos.any((v) => v.viewCount > 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('평균 대비 200% 이상 급등 영상이 없어요. 기간·샘플 수를 늘려 보세요.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _runAnatomy(ChannelVideoSnapshot video) async {
    setState(() {
      _anatomyVideo = video;
      _analyzing = true;
      _narrative = CreativeAnalyticsStore.narrativeFor(video.videoId);
    });
    try {
      final report = await CreativeAnalyticsService.analyzeNarrative(
        video: video,
        channelName: _selected?.name,
      );
      if (!mounted) return;
      setState(() {
        _narrative = report;
        _analyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('크리에이티브 분석', style: IsleText.subtitle(color: IsleColors.ocean900)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: IsleColors.ocean900,
          unselectedLabelColor: IsleColors.muted,
          indicatorColor: IsleColors.ocean500,
          tabs: const [
            Tab(text: '맞춤 Top 3'),
            Tab(text: '흥행 레이더'),
            Tab(text: '시나리오 해부'),
            Tab(text: '채널 매치업'),
          ],
        ),
      ),
      body: Column(
        children: [
          _channelStrip(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _top3Tab(),
                _radarTab(),
                _anatomyTab(),
                _matchupTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelStrip() {
    return Material(
      color: IsleColors.ocean100.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final ch in _channels)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(ch.name, style: IsleText.caption()),
                          selected: ch.id == _selectedId,
                          onSelected: (_) {
                            setState(() => _selectedId = ch.id);
                            _loadCache();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: '채널 등록',
              onPressed: _addChannel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _top3Tab() {
    if (_growthPaths == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '벤치마킹 채널을 등록·스캔하면\n주인님 소재에 맞는 Top 3 루트를 추천해요.',
                textAlign: TextAlign.center,
                style: IsleText.body(color: IsleColors.muted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _pathLoading ? null : _computeGrowthPaths,
                icon: const Icon(Icons.route),
                label: const Text('Top 3 코스 받기'),
              ),
            ],
          ),
        ),
      );
    }
    return GrowthPathTop3Panel(
      bundle: _growthPaths!,
      loading: _pathLoading,
      onRefresh: _computeGrowthPaths,
      onAnalyzeVideo: _openAnatomyForVideo,
    );
  }

  Widget _radarTab() {
    if (_channels.isEmpty) {
      return _emptyPrompt('채널 URL을 등록하면 최근 6개월 데이터에서 대박 영상을 찾아요.');
    }
    final median = OutlierEngine.medianViews(_videos);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '채널 중앙값 대비 200% 이상 조회 급등 = 「대박」 후보',
          style: IsleText.caption(color: IsleColors.muted),
        ),
        if (Env.isSupabaseConfigured) ...[
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('클라우드 분석 (Edge)', style: IsleText.body()),
            subtitle: Text(
              '자막·AI는 서버에서 처리 · 결과는 Supabase 캐시(재분석 비용↓) · API 키는 앱에 없음',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            value: _cloudEnabled,
            onChanged: (v) async {
              await IsleUserDefaults.setCreativeAnalyticsCloudEnabled(v);
              setState(() => _cloudEnabled = v);
            },
          ),
        ] else if (!AiClient.isConfigured)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Supabase·AI 미연결 — 로컬 추정만. AI 센터 또는 Supabase 설정 후 정밀 분석.',
              style: IsleText.caption(color: IsleColors.ocean700),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _scanning ? null : _scan,
          icon: _scanning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.radar),
          label: Text(_scanning ? '스캔 중…' : '채널 스캔 (6개월)'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: IsleText.caption(color: IsleColors.danger)),
        ],
        if (_videos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('조회 분포', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          _viewsSparkline(_videos, median),
          Text(
            '중앙값 ${_fmt(median)} · 영상 ${_videos.length}개',
            style: IsleText.caption(color: IsleColors.muted),
          ),
        ],
        const SizedBox(height: 16),
        Text('대박 영상', style: IsleText.subtitle()),
        if (_outliers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('스캔 후 목록이 채워져요.', style: IsleText.caption(color: IsleColors.muted)),
          )
        else
          ..._outliers.map((h) => _outlierTile(h)),
      ],
    );
  }

  Widget _anatomyTab() {
    final candidates = _outliers.isNotEmpty
        ? _outliers.map((h) => h.video).toList()
        : _videos.take(12).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '대박 영상의 훅·본론·CTA 구조와 스토리 공식',
          style: IsleText.caption(color: IsleColors.muted),
        ),
        const SizedBox(height: 12),
        if (candidates.isEmpty)
          _emptyPrompt('흥행 레이더에서 스캔한 뒤 영상을 선택하세요.')
        else ...[
          DropdownButtonFormField<String>(
            value: _anatomyVideo?.videoId ?? candidates.first.videoId,
            decoration: const InputDecoration(
              labelText: '분석할 영상',
              border: OutlineInputBorder(),
            ),
            items: candidates
                .map(
                  (v) => DropdownMenuItem(
                    value: v.videoId,
                    child: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (id) {
              final v = candidates.where((e) => e.videoId == id).firstOrNull;
              if (v != null) _runAnatomy(v);
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _analyzing || candidates.isEmpty
                ? null
                : () => _runAnatomy(
                      _anatomyVideo ??
                          candidates.firstWhere(
                            (v) => v.videoId == (_anatomyVideo?.videoId ?? candidates.first.videoId),
                            orElse: () => candidates.first,
                          ),
                    ),
            icon: _analyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.biotech_outlined),
            label: Text(_analyzing ? '해부 중…' : '시나리오 해부 실행'),
          ),
          if (_narrative != null) ...[
            const SizedBox(height: 20),
            Text(_narrative!.title, style: IsleText.subtitle()),
            const SizedBox(height: 12),
            NarrativeTimelineBar(
              acts: _narrative!.acts,
              totalSeconds: _anatomyVideo?.durationSeconds ?? 0,
            ),
            const SizedBox(height: 16),
            _insightCard('스토리 공식', _narrative!.storyFormula),
            _insightCard('리듬', '${_narrative!.rhythmSummary}\nWPM ≈ ${_narrative!.wordsPerMinute}'),
            _insightCard('왜 터졌는지 (구조)', _narrative!.structuralInsight),
            const SizedBox(height: 12),
            OriginalityPanel(report: _narrative!),
            if (_narrative!.analyzedViaEdge)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _narrative!.fromCache
                      ? '클라우드 캐시에서 불러옴 (다른 사용자가 분석한 영상)'
                      : 'Supabase Edge에서 새로 분석함',
                  style: IsleText.caption(color: IsleColors.ocean700),
                ),
              ),
            for (final act in _narrative!.acts) ...[
              const SizedBox(height: 8),
              _insightCard(
                '${act.phase.toUpperCase()} · ${act.emotionLabel}',
                '${act.summary}\n키워드: ${act.keywords.join(', ')}',
              ),
            ],
            if (!_narrative!.usedAi && !VideoNarrativeRemoteService.canUse)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: () => context.push('/settings/ai-hub'),
                  child: const Text('로컬 AI 또는 클라우드 분석 켜기'),
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _matchupTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '두 채널의 대박 영상 스토리 전개·훅 길이 비교',
          style: IsleText.caption(color: IsleColors.muted),
        ),
        const SizedBox(height: 12),
        _matchPicker('채널 A', _matchA, (c) => setState(() => _matchA = c)),
        const SizedBox(height: 8),
        _matchPicker('채널 B', _matchB, (c) => setState(() => _matchB = c)),
        if (_matchA != null && _matchB != null) ...[
          const SizedBox(height: 20),
          _matchupCompare(_matchA!, _matchB!),
        ],
      ],
    );
  }

  Widget _matchPicker(String label, BenchChannel? value, ValueChanged<BenchChannel?> onPick) {
    return DropdownButtonFormField<String>(
      value: value?.id,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: _channels
          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
          .toList(),
      onChanged: (id) {
        onPick(_channels.where((c) => c.id == id).firstOrNull);
      },
    );
  }

  Widget _matchupCompare(BenchChannel a, BenchChannel b) {
    final ma = CreativeAnalyticsService.matchupMetrics(a.id);
    final mb = CreativeAnalyticsService.matchupMetrics(b.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ma != null && mb != null) ...[
              MatchupRadarChart(
                labelA: a.name,
                labelB: b.name,
                hookSecA: ma.hookSec,
                hookSecB: mb.hookSec,
                wpmA: ma.wpm,
                wpmB: mb.wpm,
                bodyRatioA: ma.bodyRatio,
                bodyRatioB: mb.bodyRatio,
              ),
              const SizedBox(height: 20),
            ],
            Text('훅·공식 대조', style: IsleText.subtitle()),
            const SizedBox(height: 12),
            _compareRow('훅 길이', '${ma?.hookSec ?? "—"}초', '${mb?.hookSec ?? "—"}초'),
            _compareRow('WPM', '${ma?.wpm ?? "—"}', '${mb?.wpm ?? "—"}'),
            const SizedBox(height: 8),
            Text(a.name, style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
            Text(ma?.formula ?? '시나리오 해부실에서 대박 영상 분석 필요', style: IsleText.caption()),
            const SizedBox(height: 8),
            Text(b.name, style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
            Text(mb?.formula ?? '시나리오 해부실에서 대박 영상 분석 필요', style: IsleText.caption()),
            const SizedBox(height: 16),
            Text('타임라인 오버레이 (훅 구간)', style: IsleText.caption(color: IsleColors.muted)),
            const SizedBox(height: 8),
            _overlayBars(ma?.hookSec ?? 7, mb?.hookSec ?? 7),
          ],
        ),
      ),
    );
  }

  Widget _compareRow(String label, String left, String right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: IsleText.caption())),
          Expanded(child: Text(left, style: IsleText.body())),
          Expanded(child: Text(right, style: IsleText.body(), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _overlayBars(int hookA, int hookB) {
    const maxSec = 30;
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 48, child: Text('A', style: TextStyle(fontSize: 12))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (hookA / maxSec).clamp(0.05, 1.0),
                  minHeight: 12,
                  backgroundColor: IsleColors.ocean100,
                  color: const Color(0xFFE1306C),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 48, child: Text('B', style: TextStyle(fontSize: 12))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (hookB / maxSec).clamp(0.05, 1.0),
                  minHeight: 12,
                  backgroundColor: IsleColors.ocean100,
                  color: IsleColors.ocean700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _outlierTile(OutlierHit h) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            h.video.thumbnailUrl ?? '',
            width: 72,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.play_circle, color: Color(0xFFFF0000)),
          ),
        ),
        title: Text(h.video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '조회 ${_fmt(h.video.viewCount)} · 채널 대비 +${h.boostPercent}%',
          style: IsleText.caption(color: IsleColors.muted),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.biotech_outlined),
          tooltip: '해부',
          onPressed: () {
            _tabs.animateTo(2);
            _runAnatomy(h.video);
          },
        ),
        onTap: () => context.push('/youtube/browser?url=${Uri.encodeComponent('https://youtu.be/${h.video.videoId}')}'),
      ),
    );
  }

  Widget _viewsSparkline(List<ChannelVideoSnapshot> videos, int median) {
    final sorted = List<ChannelVideoSnapshot>.from(videos)
      ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
    final top = sorted.take(12).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final maxV = top.first.viewCount.clamp(1, 999999999);

    return SizedBox(
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in top)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: (80 * v.viewCount / maxV).clamp(4, 80),
                      decoration: BoxDecoration(
                        color: v.viewCount >= median * 2
                            ? const Color(0xFFFF0000)
                            : IsleColors.ocean500.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _insightCard(String title, String body) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(body, style: IsleText.caption().copyWith(height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _emptyPrompt(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(msg, textAlign: TextAlign.center, style: IsleText.body(color: IsleColors.muted)),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
