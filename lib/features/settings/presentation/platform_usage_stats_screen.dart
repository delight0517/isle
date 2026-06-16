import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/library/platform_usage_stats.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// 인스타·유튜브·브런치 — 앱 내 체류 시간
class PlatformUsageStatsScreen extends StatefulWidget {
  const PlatformUsageStatsScreen({super.key});

  @override
  State<PlatformUsageStatsScreen> createState() => _PlatformUsageStatsScreenState();
}

class _PlatformUsageStatsScreenState extends State<PlatformUsageStatsScreen> {
  Map<String, int> _seconds = {};
  int _macBrowserSec = 0;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await PlatformUsageStats.secondsByPlatform();
    final macBrowser = await PlatformUsageStats.macBrowserSecondsToday();
    if (!mounted) return;
    setState(() {
      _seconds = s;
      _macBrowserSec = macBrowser;
      _loading = false;
    });
  }

  static const _icons = {
    'youtube': Icons.ondemand_video,
    'instagram': Icons.camera_alt_outlined,
    'brunch': Icons.article_outlined,
  };

  static const _colors = {
    'youtube': Color(0xFFFF0000),
    'instagram': Color(0xFFE1306C),
    'brunch': Color(0xFF00C6BE),
  };

  @override
  Widget build(BuildContext context) {
    final total = _seconds.values.fold<int>(0, (a, b) => a + b);
    final maxSec = _seconds.values.fold<int>(0, (a, b) => a > b ? a : b);

    return Scaffold(
      appBar: const IsleAppBar(title: '플랫폼 사용 시간'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Isle 앱 안에서 보낸 시간이에요. '
                    '탐색·유튜브 WebView·브런치 브라우저 체류가 합산됩니다.',
                    style: IsleText.caption(color: IsleColors.muted),
                  ),
                  const SizedBox(height: 20),
                  if (total == 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        '아직 기록이 없어요.\n탐색 탭에서 인스타·유튜브·브런치를 열어 보세요.',
                        textAlign: TextAlign.center,
                        style: IsleText.body(color: IsleColors.muted),
                      ),
                    )
                  else
                    if (Platform.isMacOS && _macBrowserSec > 0)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.laptop_mac, color: IsleColors.ocean700),
                          title: Text('Safari·Chrome (Mac)', style: IsleText.subtitle()),
                          subtitle: Text(
                            'Isle 실행 중 브라우저 전면 시간',
                            style: IsleText.caption(color: IsleColors.muted),
                          ),
                          trailing: Text(
                            PlatformUsageStats.formatDuration(_macBrowserSec),
                            style: IsleText.subtitle(color: IsleColors.ocean700),
                          ),
                        ),
                      ),
                    ...PlatformUsageStats.platforms.map((platform) {
                      final sec = _seconds[platform] ?? 0;
                      final ratio = maxSec > 0 ? sec / maxSec : 0.0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _icons[platform] ?? Icons.timer,
                                    color: _colors[platform] ?? IsleColors.ocean500,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    PlatformUsageStats.labelFor(platform),
                                    style: IsleText.subtitle(),
                                  ),
                                  const Spacer(),
                                  Text(
                                    PlatformUsageStats.formatDuration(sec),
                                    style: IsleText.subtitle(color: IsleColors.ocean700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: ratio.clamp(0.05, 1.0),
                                  minHeight: 8,
                                  backgroundColor: IsleColors.ocean100,
                                  color: _colors[platform] ?? IsleColors.ocean500,
                                ),
                              ),
                              if (total > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '전체의 ${(100 * sec / total).round()}%',
                                    style: IsleText.caption(color: IsleColors.muted),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
