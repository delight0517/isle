import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/explorer/isle_platform.dart';
import '../../core/navigation/explorer_entry_guard.dart';
import '../../core/library/models/connected_source.dart';
import '../../core/library/personal_library_store.dart';

enum IslePlatformPickerOrigin { feed, bottomNav }

/// 피드 ⋮ — 플랫폼 열기 (인스타·페이스북 제외)
void showFeedPlatformPickerSheet(BuildContext context) {
  showIslePlatformPickerSheet(context, origin: IslePlatformPickerOrigin.feed);
}

/// 하단 「유튜브」 길게 누르기 — 설정·연결 출처 + 인스타 등
void showBottomNavPlatformPickerSheet(BuildContext context) {
  showIslePlatformPickerSheet(context, origin: IslePlatformPickerOrigin.bottomNav);
}

void showIslePlatformPickerSheet(
  BuildContext context, {
  required IslePlatformPickerOrigin origin,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    builder: (ctx) {
      final platforms = _platformsFor(origin);
      final sources = origin == IslePlatformPickerOrigin.bottomNav
          ? PersonalLibraryStore.loadSources()
          : const <ConnectedSource>[];

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                origin == IslePlatformPickerOrigin.bottomNav ? '플랫폼 바로 열기' : '플랫폼 열기',
                style: IsleText.subtitle(color: IsleColors.ocean900),
              ),
              const SizedBox(height: 6),
              Text(
                origin == IslePlatformPickerOrigin.bottomNav
                    ? '짧게 누르면 유튜브 허브 · 길게 누르면 이 목록'
                    : '앱 안에서 바로 보기 · 세션이 유지됩니다',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              if (origin == IslePlatformPickerOrigin.bottomNav) ...[
                const SizedBox(height: 12),
                _QuickRow(
                  label: '유튜브 허브',
                  icon: Icons.play_circle_filled,
                  color: const Color(0xFFFF0000),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/home/my-isle');
                  },
                ),
              ],
              const SizedBox(height: 16),
              _PlatformGrid(platforms: platforms, origin: origin),
              if (sources.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('연결한 출처', style: IsleText.body(color: IsleColors.ocean900)),
                const SizedBox(height: 10),
                ...sources.map(
                  (s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: IsleColors.ocean100,
                      child: Icon(_sourceIcon(s.type), color: IsleColors.ocean700, size: 22),
                    ),
                    title: Text(
                      s.displayName.isNotEmpty ? s.displayName : s.profileUrl,
                      style: IsleText.body(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(s.type, style: IsleText.caption(color: IsleColors.muted)),
                    trailing: const Icon(Icons.open_in_new, size: 20),
                    onTap: () => _openConnectedSource(ctx, s),
                  ),
                ),
              ],
              if (origin == IslePlatformPickerOrigin.feed) ...[
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push('/library/sources');
                        },
                        icon: const Icon(Icons.library_books_outlined),
                        label: const Text('내 콘텐츠'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: IsleColors.ocean700,
                          minimumSize: const Size(0, IsleSize.minTouchTarget),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push('/settings/subscriptions');
                        },
                        icon: const Icon(Icons.rss_feed),
                        label: const Text('구독 관리'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: IsleColors.ocean700,
                          minimumSize: const Size(0, IsleSize.minTouchTarget),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _PlatformGrid extends StatelessWidget {
  const _PlatformGrid({required this.platforms, required this.origin});

  final List<IslePlatform> platforms;
  final IslePlatformPickerOrigin origin;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    for (final p in platforms) {
      tiles.add(IslePlatformTile(platform: p));
      if (origin == IslePlatformPickerOrigin.bottomNav && p.id == 'instagram') {
        tiles.add(const IsleInstagramDmTile());
      }
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 18,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) => tiles[i],
    );
  }
}

List<IslePlatform> _platformsFor(IslePlatformPickerOrigin origin) {
  if (origin == IslePlatformPickerOrigin.feed) {
    return PlatformCatalog.platforms
        .where((p) => p.id != 'instagram' && p.id != 'facebook')
        .toList();
  }
  final order = <String>[
    'youtube',
    'instagram',
    'brunch',
    'naver_blog',
    'velog',
    'tistory',
    'medium',
  ];
  final byId = {for (final p in PlatformCatalog.platforms) p.id: p};
  final list = <IslePlatform>[];
  for (final id in order) {
    final p = byId[id];
    if (p != null) list.add(p);
  }
  return list;
}

IconData _sourceIcon(String type) {
  switch (type) {
    case 'youtube':
      return Icons.play_circle_filled;
    case 'brunch':
      return Icons.article_outlined;
    default:
      return Icons.link;
  }
}

void _openConnectedSource(BuildContext context, ConnectedSource source) {
  Navigator.pop(context);
  final catalog = switch (source.type) {
    'youtube' => PlatformCatalog.byId('youtube'),
    'brunch' => PlatformCatalog.byId('brunch'),
    _ => null,
  };
  if (catalog != null) {
    IslePlatformNavigator.open(context, catalog, profileUrl: source.profileUrl);
    return;
  }
  if (source.profileUrl.startsWith('http')) {
    context.push(
      Uri(
        path: '/explore/browser',
        queryParameters: {'site': 'blog', 'url': source.profileUrl},
      ).toString(),
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IsleColors.ocean100.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: IsleText.body())),
              const Icon(Icons.chevron_right, color: IsleColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// 플랫폼 타일 + 라우팅
class IslePlatformTile extends StatelessWidget {
  const IslePlatformTile({
    super.key,
    required this.platform,
    this.subtitle,
    this.onBeforeOpen,
  });

  final IslePlatform platform;
  final String? subtitle;
  final VoidCallback? onBeforeOpen;

  @override
  Widget build(BuildContext context) {
    final color = Color(platform.brandColor);
    final isLight = ThemeData.estimateBrightnessForColor(color) == Brightness.light;
    final iconColor = isLight ? Colors.black87 : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        onBeforeOpen?.call();
        final deny = ExplorerEntryGuard.denyMessageForPlatform(platform);
        if (deny != null) {
          ExplorerEntryGuard.showDenial(
            context,
            deny,
            url: platform.homeUrl,
            site: platform.site,
          );
          return;
        }
        Navigator.pop(context);
        IslePlatformNavigator.open(context, platform);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, Color.lerp(color, Colors.black, 0.18) ?? color],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(_iconFor(platform.iconName), color: iconColor, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle ?? platform.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: IsleText.caption(color: IsleColors.ocean900)
                .copyWith(fontWeight: FontWeight.w500, height: 1.2),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(String iconName) {
  switch (iconName) {
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
    case 'camera_alt_outlined':
      return Icons.camera_alt_outlined;
    case 'facebook':
      return Icons.facebook;
    default:
      return Icons.language;
  }
}

/// DM 전용 타일 (인스타 메시지함)
class IsleInstagramDmTile extends StatelessWidget {
  const IsleInstagramDmTile({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.pop(context);
        context.push(
          Uri(
            path: '/explore/browser',
            queryParameters: {
              'site': 'instagram',
              'dm': '1',
              'url': 'https://www.instagram.com/direct/inbox/',
            },
          ).toString(),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE1306C), Color(0xFFC13584)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.forum_outlined, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            '인스타 DM',
            textAlign: TextAlign.center,
            maxLines: 2,
            style: IsleText.caption(color: IsleColors.ocean900)
                .copyWith(fontWeight: FontWeight.w500, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class IslePlatformNavigator {
  IslePlatformNavigator._();

  static void open(BuildContext context, IslePlatform platform, {String? profileUrl}) {
    if (platform.id == 'youtube') {
      final url = profileUrl?.trim();
      if (url != null && url.isNotEmpty && url.startsWith('http')) {
        context.push('/youtube/browser?url=${Uri.encodeComponent(url)}');
      } else {
        context.push('/youtube/browser');
      }
      return;
    }
    if (platform.id == 'instagram') {
      final base = profileUrl?.trim().isNotEmpty == true
          ? profileUrl!.trim()
          : 'https://www.instagram.com/';
      context.push(
        Uri(
          path: '/explore/browser',
          queryParameters: {'site': 'instagram', 'url': base},
        ).toString(),
      );
      return;
    }
    final q = <String, String>{
      'site': platform.site.name,
      'url': profileUrl?.trim().isNotEmpty == true ? profileUrl!.trim() : platform.homeUrl,
    };
    if (platform.id == 'brunch') q['remember_login'] = '1';
    context.push(Uri(path: '/explore/browser', queryParameters: q).toString());
  }
}
