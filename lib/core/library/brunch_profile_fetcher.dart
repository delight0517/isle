import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../utils/url_parser.dart';
import 'models/library_entry.dart';

/// 브런치 프로필 URL에서 글 목록 추출 (로컬 저장용, 수동 동기화)
class BrunchProfileFetcher {
  BrunchProfileFetcher._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 12),
      headers: {'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15'},
    ),
  );

  /// `https://brunch.co.kr/@handle` 형식
  static String? normalizeProfileUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return null;
    if (!u.startsWith('http')) u = 'https://$u';
    final uri = Uri.tryParse(u);
    if (uri == null || !uri.host.contains('brunch.co.kr')) return null;
    final path = uri.path;
    final m = RegExp(r'^/@([\w.-]+)/?$').firstMatch(path);
    if (m == null) return null;
    return 'https://brunch.co.kr/@${m.group(1)}';
  }

  static String handleFromUrl(String profileUrl) {
    final m = RegExp(r'/@([\w.-]+)').firstMatch(profileUrl);
    return m?.group(1) ?? '';
  }

  static Future<List<LibraryEntry>> fetchArticles(String profileUrl, {int maxArticles = 24}) async {
    final base = normalizeProfileUrl(profileUrl);
    if (base == null) return [];
    final handle = handleFromUrl(base);

    final res = await _dio.get<String>(base);
    final html = res.data ?? '';
    final doc = html_parser.parse(html);

    final articlePaths = <String>{};
    final pathRegex = RegExp(r'^/@${RegExp.escape(handle)}/(\d+)$');
    for (final a in doc.querySelectorAll('a[href]')) {
      final href = a.attributes['href'] ?? '';
      final path = href.startsWith('/') ? href : '/$href';
      final m = pathRegex.firstMatch(path);
      if (m != null) articlePaths.add('/@$handle/${m.group(1)}');
    }

    final regex = RegExp(r'/@${RegExp.escape(handle)}/(\d+)', caseSensitive: false);
    for (final m in regex.allMatches(html)) {
      articlePaths.add('/@$handle/${m.group(1)}');
    }

    final limited = articlePaths.take(maxArticles).toList();
    final entries = <LibraryEntry>[];

    for (final path in limited) {
      final url = 'https://brunch.co.kr$path';
      try {
        final meta = await UrlParser.fetchMeta(url);
        var title = meta.title;
        if (title.contains('|')) {
          title = title.split('|').first.trim();
        }
        entries.add(
          LibraryEntry.fromBrunch(
            articleUrl: url,
            title: title.isEmpty ? url : title,
            thumbnailUrl: meta.thumbnailUrl,
            author: handle,
            sourceId: path,
          ),
        );
      } catch (_) {
        entries.add(
          LibraryEntry.fromBrunch(
            articleUrl: url,
            title: '브런치 글',
            author: handle,
            sourceId: path,
          ),
        );
      }
    }
    return entries;
  }
}
