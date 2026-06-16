import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/isle_user_defaults.dart';

/// Safari·Chrome 등 **Isle 밖** YouTube 링크 → Isle WebView / 음성 모드
///
/// iOS는 youtube.com 링크를 시스템 Safari가 독점 처리해 **자동 가로채기 불가**.
/// 공유·클립보드·단축어(isle://)만 지원 — 한계를 UI에 명시.
class SafariYoutubeInboundSection extends StatefulWidget {
  const SafariYoutubeInboundSection({super.key});

  @override
  State<SafariYoutubeInboundSection> createState() =>
      _SafariYoutubeInboundSectionState();
}

class _SafariYoutubeInboundSectionState extends State<SafariYoutubeInboundSection> {
  late bool _clipboardOnResume;
  late bool _podcastMode;
  late bool _openInIsle;

  @override
  void initState() {
    super.initState();
    _syncFromDefaults();
  }

  void _syncFromDefaults() {
    _openInIsle = IsleUserDefaults.openYoutubeLinksInIsle;
    _clipboardOnResume = IsleUserDefaults.youtubeClipboardLaunchOnResume;
    _podcastMode = IsleUserDefaults.youtubeSharesUsePodcastMode;
  }

  Future<void> _copyShortcutHint() async {
    const sample = 'isle://youtube?url=';
    await Clipboard.setData(const ClipboardData(text: sample));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('단축어 접두어 복사 — 뒤에 YouTube URL을 붙이세요'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.link, color: Color(0xFFFF0000), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Safari 링크 → Isle 유튜브',
                    style: IsleText.subtitle(color: IsleColors.ocean900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1538),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                Platform.isIOS
                    ? 'iPhone은 Safari·YouTube 앱 링크를 Isle이 자동으로 가로챌 수 없어요. '
                        '아래 방법(공유 · 클립보드 · 단축어)을 써 주세요.'
                    : 'Android는 「기본으로 열기」에서 youtube.com을 Isle에 연결할 수 있어요. '
                        '안 되면 공유·클립보드 방법을 쓰세요.',
                style: IsleText.caption(color: Colors.white70).copyWith(height: 1.45),
              ),
            ),
            const SizedBox(height: 12),
            _MethodTile(
              icon: Icons.ios_share,
              title: '1. 공유 → Isle',
              subtitle: 'Safari·YouTube 앱에서 링크 공유 버튼 → Isle 선택 (가장 확실)',
            ),
            _MethodTile(
              icon: Icons.content_paste_go_outlined,
              title: '2. 링크 복사 후 Isle 열기',
              subtitle: 'Safari에서 URL 복사 → Isle로 돌아오면 바로 열기 제안',
              trailing: Switch(
                value: _clipboardOnResume,
                onChanged: (v) async {
                  await IsleUserDefaults.setYoutubeClipboardLaunchOnResume(v);
                  setState(() => _clipboardOnResume = v);
                },
              ),
            ),
            _MethodTile(
              icon: Icons.headphones,
              title: '3. 음성 모드로 열기',
              subtitle: '공유·클립보드·딥링크를 듣기 전용(/youtube/podcast)으로',
              trailing: Switch(
                value: _podcastMode,
                onChanged: (v) async {
                  await IsleUserDefaults.setYoutubeSharesUsePodcastMode(v);
                  setState(() => _podcastMode = v);
                },
              ),
            ),
            if (Platform.isIOS) ...[
              const SizedBox(height: 4),
              _MethodTile(
                icon: Icons.shortcut,
                title: '4. 단축어 (고급)',
                subtitle: '「URL 열기」→ isle://youtube?url=… (Safari 공유와 병행)',
                onTap: _copyShortcutHint,
              ),
            ],
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('YouTube 링크는 Isle에서 열기'),
              subtitle: const Text('공유·isle:// · Android 기본 앱'),
              value: _openInIsle,
              onChanged: (v) async {
                await IsleUserDefaults.setOpenYoutubeLinksInIsle(v);
                setState(() => _openInIsle = v);
              },
            ),
            SizedBox(
              width: double.infinity,
              height: IsleSize.minTouchTarget,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/settings/youtube-default-open'),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('자세한 설정 · Android 기본 앱'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: IsleColors.ocean700),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
