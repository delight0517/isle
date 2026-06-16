/// YouTube WebView URL — 시청 vs 탐색(검색·홈·채널) 구분
class YoutubeNavPolicy {
  YoutubeNavPolicy._();

  static bool hostIsYoutube(String url) =>
      url.toLowerCase().contains('youtube.com') || url.toLowerCase().contains('youtu.be');

  static bool isWatchUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('watch?v=') ||
        lower.contains('/shorts/') ||
        lower.contains('/embed/');
  }

  static bool isSearchResultsUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('search_query=') || lower.contains('/results');
  }

  /// 시청 페이지가 아닌 탐색면 — 검색 결과·홈·채널 등
  static bool isBrowseSurface(String url) {
    if (!hostIsYoutube(url)) return false;
    return !isWatchUrl(url);
  }

  /// 채널 홈 (/channel, /@handle, /c/, /user/)
  static bool isChannelUrl(String url) {
    if (!hostIsYoutube(url) || isWatchUrl(url)) return false;
    final lower = url.toLowerCase();
    return lower.contains('youtube.com/channel/') ||
        lower.contains('youtube.com/@') ||
        lower.contains('youtube.com/c/') ||
        lower.contains('youtube.com/user/');
  }
}
