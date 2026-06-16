import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/isle_user_defaults.dart';

/// YouTube 링크를 Isle에서 열기 — OS 기본 앱·클립보드 자동 제안
class YoutubeDefaultHandlerScreen extends StatefulWidget {
  const YoutubeDefaultHandlerScreen({super.key});

  @override
  State<YoutubeDefaultHandlerScreen> createState() => _YoutubeDefaultHandlerScreenState();
}

class _YoutubeDefaultHandlerScreenState extends State<YoutubeDefaultHandlerScreen> {
  late bool _openInIsle;
  late bool _clipboardOnResume;
  late bool _podcastMode;

  @override
  void initState() {
    super.initState();
    _openInIsle = IsleUserDefaults.openYoutubeLinksInIsle;
    _clipboardOnResume = IsleUserDefaults.youtubeClipboardLaunchOnResume;
    _podcastMode = IsleUserDefaults.youtubeSharesUsePodcastMode;
  }

  Future<void> _copySchemeExample() async {
    const sample = 'isle://youtube?url=https://www.youtube.com/watch?v=dQw4w9WgXcQ';
    await Clipboard.setData(const ClipboardData(text: sample));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('예시 링크 복사됨 — 단축어·자동화에 붙여넣기')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('YouTube → Isle 열기', style: IsleText.subtitle())),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1538),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: IsleColors.gold500.withValues(alpha: 0.4)),
            ),
            child: Text(
              '다른 앱·Chrome에서 youtube 링크를 누르면 Isle이 뜨게 하려면 '
              'OS에서 「지원 링크 → Isle」을 켜야 합니다. '
              'youtube.com 도메인은 Google 소유라 100% 자동 강제는 불가능합니다.',
              style: IsleText.caption(color: Colors.white70).copyWith(height: 1.45),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('YouTube 링크는 Isle에서 열기'),
            subtitle: const Text('공유·딥링크·isle:// → WebView'),
            value: _openInIsle,
            onChanged: (v) async {
              await IsleUserDefaults.setOpenYoutubeLinksInIsle(v);
              setState(() => _openInIsle = v);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('앱으로 돌아올 때 클립보드 YouTube 제안'),
            subtitle: const Text('Safari에서 링크 복사 후 Isle 복귀 → 바로 열기 (iOS에서 가장 확실)'),
            value: _clipboardOnResume,
            onChanged: (v) async {
              await IsleUserDefaults.setYoutubeClipboardLaunchOnResume(v);
              setState(() => _clipboardOnResume = v);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('YouTube 링크 → 음성 모드'),
            subtitle: const Text('공유·클립보드·딥링크를 듣기 전용으로 열기'),
            value: _podcastMode,
            onChanged: (v) async {
              await IsleUserDefaults.setYoutubeSharesUsePodcastMode(v);
              setState(() => _podcastMode = v);
            },
          ),
          const Divider(height: 28),
          Text('Android', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          _step('1', '설정 → 앱 → Isle → 기본으로 열기 (또는 지원하는 링크)'),
          _step('2', 'youtube.com · youtu.be 가 보이면 Isle 켜기'),
          _step('3', 'Chrome에서 막았다면: 링크 길게 누르기 → 복사 → Isle 열기 (위 스위치)'),
          if (Platform.isIOS) ...[
            const SizedBox(height: 20),
            Text('iPhone', style: IsleText.subtitle()),
            const SizedBox(height: 8),
            _step('1', 'YouTube 링크 → 공유 → Isle (가장 확실)'),
            _step('2', '단축어 앱: URL 열기 → isle://youtube?url=…'),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _copySchemeExample,
            icon: const Icon(Icons.link),
            label: const Text('isle:// 예시 링크 복사'),
          ),
        ],
      ),
    );
  }

  Widget _step(String n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n, style: IsleText.badge(color: IsleColors.ocean500)),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: IsleText.body())),
          ],
        ),
      );
}
