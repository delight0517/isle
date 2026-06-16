import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/explorer/explorer_site.dart';
import '../../../core/explorer/isle_platform.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// 유튜브·브런치·블로그 — 같은 전체 화면 탐색기
class ContentExplorerHubScreen extends StatefulWidget {
  const ContentExplorerHubScreen({super.key});

  @override
  State<ContentExplorerHubScreen> createState() => _ContentExplorerHubScreenState();
}

class _ContentExplorerHubScreenState extends State<ContentExplorerHubScreen> {
  final _urlCtrl = TextEditingController();

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _openPlatform(IslePlatform platform) {
    final q = <String, String>{
      'site': platform.site.name,
      'url': platform.homeUrl,
    };
    if (platform.id == 'brunch') q['remember_login'] = '1';
    context.push(Uri(path: '/explore/browser', queryParameters: q).toString());
  }

  void _openCustomUrl(String url) {
    context.push(Uri(
      path: '/explore/browser',
      queryParameters: {'site': ExplorerSite.blog.name, 'url': url},
    ).toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IsleAppBar(title: '탐색'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '유튜브·브런치·네이버·Velog 등을 앱 안에서 봅니다. '
            '브런치는 로그인 후 이 기기에 세션이 유지되고, 작가·키워드는 숨길 수 있어요.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 12),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            color: const Color(0xFFFDF2F7),
            child: ListTile(
              leading: const Icon(Icons.hub_outlined, color: Color(0xFFE1306C)),
              title: Text('소셜 허브', style: IsleText.subtitle()),
              subtitle: Text(
                '인스타·페이스북·Isle 프로필·게시',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/social'),
            ),
          ),
          ...PlatformCatalog.platforms.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SiteCard(
                platform: p,
                onTap: () => _openPlatform(p),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _showCustomUrlDialog,
            icon: const Icon(Icons.link),
            label: const Text('다른 URL 열기'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomUrlDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('블로그·웹 열기', style: IsleText.subtitle()),
        content: TextField(
          controller: _urlCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://…',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('열기')),
        ],
      ),
    );
    if (ok == true && mounted) {
      var u = _urlCtrl.text.trim();
      if (u.isNotEmpty && !u.startsWith('http')) u = 'https://$u';
      if (u.isNotEmpty) _openCustomUrl(u);
    }
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({required this.platform, required this.onTap});

  final IslePlatform platform;
  final VoidCallback onTap;

  IconData get _icon {
    switch (platform.iconName) {
      case 'play_circle_filled':
        return Icons.play_circle_filled;
      case 'article_outlined':
        return Icons.article_outlined;
      case 'home_work_outlined':
        return Icons.home_work_outlined;
      case 'code':
        return Icons.code;
      case 'edit_note':
        return Icons.edit_note;
      case 'menu_book_outlined':
        return Icons.menu_book_outlined;
      default:
        return Icons.language;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(platform.brandColor);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(_icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(platform.title, style: IsleText.subtitle()),
                    Text(platform.subtitle, style: IsleText.caption(color: IsleColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: IsleColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
