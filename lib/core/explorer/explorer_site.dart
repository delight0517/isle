/// 인앱 브라우저 사이트 종류
enum ExplorerSite {
  youtube,
  brunch,
  naver,
  blog,
  instagram,
  facebook,
  custom;

  static ExplorerSite fromQuery(String? raw) {
    switch (raw) {
      case 'brunch':
        return ExplorerSite.brunch;
      case 'naver':
        return ExplorerSite.naver;
      case 'blog':
        return ExplorerSite.blog;
      case 'instagram':
        return ExplorerSite.instagram;
      case 'facebook':
        return ExplorerSite.facebook;
      case 'custom':
        return ExplorerSite.custom;
      default:
        return ExplorerSite.youtube;
    }
  }

  bool get isYoutube => this == ExplorerSite.youtube;
  bool get isBrunch => this == ExplorerSite.brunch;
  bool get isInstagram => this == ExplorerSite.instagram;
  bool get isFacebook => this == ExplorerSite.facebook;

  bool get isReadableSite =>
      isYoutube ||
      isBrunch ||
      isInstagram ||
      isFacebook ||
      this == ExplorerSite.naver ||
      this == ExplorerSite.blog;

  String get defaultHomeUrl {
    switch (this) {
      case ExplorerSite.youtube:
        return 'https://m.youtube.com';
      case ExplorerSite.brunch:
        return 'https://brunch.co.kr';
      case ExplorerSite.naver:
        return 'https://m.blog.naver.com';
      case ExplorerSite.instagram:
        return 'https://www.instagram.com/';
      case ExplorerSite.facebook:
        return 'https://m.facebook.com/';
      case ExplorerSite.blog:
      case ExplorerSite.custom:
        return 'https://';
    }
  }

  String get displayTitle {
    switch (this) {
      case ExplorerSite.youtube:
        return '유튜브';
      case ExplorerSite.brunch:
        return '브런치';
      case ExplorerSite.naver:
        return '네이버 블로그';
      case ExplorerSite.instagram:
        return '인스타그램';
      case ExplorerSite.facebook:
        return '페이스북';
      case ExplorerSite.blog:
        return '블로그';
      case ExplorerSite.custom:
        return 'Safari';
    }
  }
}
