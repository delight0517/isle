import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/insight/depth_match_service.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../../shared/widgets/tag_badge.dart';

/// 심도 기반 네트워킹 — 로컬 휴리스틱 매칭
class DepthMatchScreen extends StatefulWidget {
  const DepthMatchScreen({super.key});

  @override
  State<DepthMatchScreen> createState() => _DepthMatchScreenState();
}

class _DepthMatchScreenState extends State<DepthMatchScreen> {
  List<DepthMatchPeer> _peers = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await DepthMatchService.ensureSeedPeers();
    if (!mounted) return;
    setState(() {
      _peers = DepthMatchService.findMatches();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IsleAppBar(title: '깊이 맞는 사람'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '같은 영상을 봐도 다른 관점의 메모를 남긴 사람을 찾아요. '
                  '키워드 깊이가 비슷할수록 위에 표시됩니다.',
                  style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4),
                ),
                const SizedBox(height: 16),
                if (_peers.isEmpty)
                  Text(
                    '인사이트를 몇 개 발행하면 매칭이 시작돼요.',
                    style: IsleText.body(color: IsleColors.muted),
                  ),
                ..._peers.map(
                  (p) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.displayName, style: IsleText.subtitle()),
                          Text(p.headline, style: IsleText.caption(color: IsleColors.muted)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: p.sharedKeywords
                                .map((k) => TagBadge(label: k, color: IsleColors.ocean500))
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '「${p.sampleTitle}」',
                            style: IsleText.caption(color: IsleColors.ocean700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            p.differentNote,
                            style: IsleText.body().copyWith(height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
