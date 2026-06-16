/// Instagram DM 집중 모드 — 허용 URL (DM · 상대 프로필 · 포스트 · 스토리)
class InstagramDmPathPolicy {
  InstagramDmPathPolicy._();

  static const _reservedFirstSegment = <String>{
    'direct',
    'explore',
    'reels',
    'accounts',
    'p',
    'reel',
    'tv',
    'stories',
    'legal',
    'privacy',
    'terms',
    'about',
    'developer',
    'directory',
    'landing',
    'email',
    'help',
    'session',
    'challenge',
    'consent',
    'nametag',
    'ar',
    'web',
    'static',
  };

  static const _profileSubpaths = <String>{'reels', 'tagged', 'channel', 'guides'};

  /// DM 1:1 스레드 (`/direct/t/{id}/` 등)
  static bool isDmThreadPath(String path) {
    final p = path.toLowerCase();
    if (!p.startsWith('/direct/')) return false;
    if (p == '/direct/' || p == '/direct/inbox/' || p.endsWith('/inbox/')) return false;
    return true;
  }

  /// 공유 링크 포스트·릴스·IGTV
  static bool isSharedMediaPath(String path) {
    final p = path.toLowerCase();
    return p.startsWith('/p/') ||
        p.startsWith('/reel/') ||
        p.startsWith('/tv/') ||
        (p.startsWith('/reels/') && p != '/reels/');
  }

  /// 상대 프로필 · 프로필 탭(릴스/태그) · 스토리
  static bool isProfileOrStoriesPath(String path) {
    final segments =
        path.toLowerCase().split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return false;

    if (segments.first == 'stories' && segments.length >= 2) {
      final user = segments[1];
      return user.isNotEmpty && !_reservedFirstSegment.contains(user);
    }

    final user = segments.first;
    if (user.isEmpty || _reservedFirstSegment.contains(user)) return false;

    if (segments.length == 1) return true;
    if (segments.length == 2 && _profileSubpaths.contains(segments[1])) {
      return true;
    }
    return false;
  }

  /// DM 모드 WebView에서 이동 허용
  static bool isAllowedInDmFocusMode(String path) {
    final p = path.toLowerCase();
    if (p.startsWith('/direct')) return true;
    if (p.startsWith('/accounts')) return true;
    if (p.startsWith('/challenge')) return true;
    if (p.startsWith('/consent')) return true;
    if (isSharedMediaPath(p)) return true;
    if (isProfileOrStoriesPath(p)) return true;
    return false;
  }

  /// 상단 크롬 부제목용
  static String? chromeHintForPath(String path) {
    if (isDmThreadPath(path)) return 'DM 대화';
    if (isProfileOrStoriesPath(path)) {
      final seg = path.split('/').where((s) => s.isNotEmpty).toList();
      if (seg.isEmpty) return '프로필';
      if (seg.first == 'stories' && seg.length >= 2) {
        return '@${seg[1]} · 스토리';
      }
      return '@${seg.first} · 프로필·게시물';
    }
    if (isSharedMediaPath(path)) return '공유한 게시물';
    if (path.startsWith('/direct')) return '메시지함';
    return null;
  }
}
