import 'explorer_site.dart';

/// 피드·탐색에서 열 수 있는 플랫폼
class IslePlatform {
  const IslePlatform({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.site,
    required this.homeUrl,
    this.loginUrl,
    this.iconName = 'language',
    this.brandColor = 0xFF2B4A8C,
  });

  final String id;
  final String title;
  final String subtitle;
  final ExplorerSite site;
  final String homeUrl;
  final String? loginUrl;
  final String iconName;
  final int brandColor;

  String get exploreQuery => 'site=${site.name}&url=${Uri.encodeComponent(homeUrl)}';
}

class PlatformCatalog {
  PlatformCatalog._();

  static const platforms = [
    IslePlatform(
      id: 'safari',
      title: 'Safari',
      subtitle: '앱 안 웹 브라우저',
      site: ExplorerSite.custom,
      homeUrl: 'https://www.google.com',
      iconName: 'explore_outlined',
      brandColor: 0xFF0A84FF,
    ),
    IslePlatform(
      id: 'youtube',
      title: '유튜브',
      subtitle: '시청 · 채널 차단',
      site: ExplorerSite.youtube,
      homeUrl: 'https://m.youtube.com',
      iconName: 'play_circle_filled',
      brandColor: 0xFFFF0000,
    ),
    IslePlatform(
      id: 'brunch',
      title: '브런치',
      subtitle: '로그인 유지 · 작가 차단',
      site: ExplorerSite.brunch,
      homeUrl: 'https://brunch.co.kr',
      loginUrl: 'https://brunch.co.kr/ko/login',
      iconName: 'article_outlined',
      brandColor: 0xFF00C389,
    ),
    IslePlatform(
      id: 'naver_blog',
      title: '네이버 블로그',
      subtitle: 'blog.naver.com',
      site: ExplorerSite.naver,
      homeUrl: 'https://m.blog.naver.com',
      iconName: 'home_work_outlined',
      brandColor: 0xFF03C75A,
    ),
    IslePlatform(
      id: 'velog',
      title: 'Velog',
      subtitle: '개발·기술 블로그',
      site: ExplorerSite.blog,
      homeUrl: 'https://velog.io',
      iconName: 'code',
      brandColor: 0xFF20C997,
    ),
    IslePlatform(
      id: 'tistory',
      title: '티스토리',
      subtitle: 'tistory.com',
      site: ExplorerSite.blog,
      homeUrl: 'https://www.tistory.com',
      iconName: 'edit_note',
      brandColor: 0xFFEB531F,
    ),
    IslePlatform(
      id: 'medium',
      title: 'Medium',
      subtitle: '영문 글',
      site: ExplorerSite.blog,
      homeUrl: 'https://medium.com',
      iconName: 'menu_book_outlined',
      brandColor: 0xFF000000,
    ),
    IslePlatform(
      id: 'instagram',
      title: '인스타그램',
      subtitle: '구독 피드 · 스토리 · Isle 게시',
      site: ExplorerSite.instagram,
      homeUrl: 'https://www.instagram.com/',
      loginUrl: 'https://www.instagram.com/accounts/login/',
      iconName: 'camera_alt_outlined',
      brandColor: 0xFFE1306C,
    ),
    IslePlatform(
      id: 'facebook',
      title: '페이스북',
      subtitle: '피드 · 친구',
      site: ExplorerSite.facebook,
      homeUrl: 'https://m.facebook.com/',
      loginUrl: 'https://m.facebook.com/login/',
      iconName: 'facebook',
      brandColor: 0xFF1877F2,
    ),
  ];

  static IslePlatform? byId(String id) {
    for (final p in platforms) {
      if (p.id == id) return p;
    }
    return null;
  }
}
