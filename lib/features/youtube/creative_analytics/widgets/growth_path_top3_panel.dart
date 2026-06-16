import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/youtube/creative_analytics/models/growth_path_bundle.dart';

/// 예측 쇼핑형 Top 3 성장 코스 카드
class GrowthPathTop3Panel extends StatefulWidget {
  const GrowthPathTop3Panel({
    super.key,
    required this.bundle,
    this.onRefresh,
    this.onAnalyzeVideo,
    this.loading = false,
  });

  final GrowthPathBundle bundle;
  final VoidCallback? onRefresh;
  final void Function(String videoId)? onAnalyzeVideo;
  final bool loading;

  @override
  State<GrowthPathTop3Panel> createState() => _GrowthPathTop3PanelState();
}

class _GrowthPathTop3PanelState extends State<GrowthPathTop3Panel> {
  late final TextEditingController _nicheCtrl;

  @override
  void initState() {
    super.initState();
    _nicheCtrl = TextEditingController(text: IsleUserDefaults.creatorNicheNote);
  }

  @override
  void dispose() {
    _nicheCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNicheAndRefresh() async {
    await IsleUserDefaults.setCreatorNicheNote(_nicheCtrl.text);
    widget.onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bundle = widget.bundle;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '관심 소재에 맞춰 「가장 쉬운 벤치마킹 루트」 Top 3를 골라 드려요.',
          style: IsleText.caption(color: IsleColors.muted),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nicheCtrl,
          decoration: const InputDecoration(
            labelText: '내가 다루는 소재 (선택)',
            hintText: '예: 3D·Blender 튜토리얼, 대학생 브이로그',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _saveNicheAndRefresh(),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: widget.loading ? null : _saveNicheAndRefresh,
          icon: widget.loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(widget.loading ? '조사 중…' : 'Top 3 코스 계산'),
        ),
        const SizedBox(height: 20),
        _greetingCard(bundle),
        const SizedBox(height: 16),
        ...bundle.picks.map((p) => _pathCard(context, p)),
        if (bundle.usedAi)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'AI가 주인님 소재에 맞게 문장을 다듬었어요.',
              style: IsleText.caption(color: IsleColors.ocean700),
            ),
          ),
      ],
    );
  }

  Widget _greetingCard(GrowthPathBundle bundle) {
    return Card(
      color: IsleColors.ocean100.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bundle.greeting, style: IsleText.subtitle(color: IsleColors.ocean900)),
            const SizedBox(height: 8),
            Text(bundle.materialLine, style: IsleText.body()),
            const SizedBox(height: 8),
            Text(
              '아래는 합리적으로 조사한 벤치마킹 패키지예요. '
              '구조만 가져가고, 예시·말투·경험은 주인님 것으로 바꿔 주세요.',
              style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pathCard(BuildContext context, GrowthPathPick p) {
    final medal = switch (p.rank) {
      1 => '🥇',
      2 => '🥈',
      _ => '🥉',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(medal, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${p.rank}위 · ${p.channelName}', style: IsleText.subtitle()),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: IsleColors.ocean100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '적합 ${p.matchPercent}%',
                    style: IsleText.caption(color: IsleColors.ocean700)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _chipRow(Icons.bolt, '훅', p.hookStyle),
            _chipRow(Icons.description_outlined, '대본', p.scriptStyle),
            _chipRow(Icons.videocam_outlined, '촬영·편집', p.cameraEditing),
            if (p.storyFormula != null && p.storyFormula!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('공식: ${p.storyFormula}', style: IsleText.caption(color: IsleColors.muted)),
            ],
            const SizedBox(height: 10),
            Text('왜 이 길이 쉬운가', style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
            Text(p.whyEasiest, style: IsleText.caption().copyWith(height: 1.4)),
            const SizedBox(height: 10),
            Text('조사·실행 패키지', style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
            for (final step in p.researchSteps)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(step, style: IsleText.caption()),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (p.topVideoId != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/youtube/browser?url=${Uri.encodeComponent('https://youtu.be/${p.topVideoId}')}',
                      ),
                      icon: const Icon(Icons.play_circle_outline, size: 20),
                      label: const Text('대표 영상'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, IsleSize.minTouchTarget),
                      ),
                    ),
                  ),
                if (p.topVideoId != null) const SizedBox(width: 8),
                if (p.topVideoId != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => widget.onAnalyzeVideo?.call(p.topVideoId!),
                      icon: const Icon(Icons.biotech_outlined, size: 20),
                      label: const Text('해부하기'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, IsleSize.minTouchTarget),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: IsleColors.ocean500),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(label, style: IsleText.caption(color: IsleColors.muted)),
          ),
          Expanded(child: Text(value, style: IsleText.body())),
        ],
      ),
    );
  }
}
