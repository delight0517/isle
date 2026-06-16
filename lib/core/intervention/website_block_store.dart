import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../youtube/block_keyword_policy.dart';

/// Safari Content Blocker용 항상-차단 도메인 목록.
/// OS ManagedSettings 도메인 쉴드는 Isle WebView까지 막으므로 사용하지 않는다(§8).
/// 대신 이 목록을 IosRulesExportService가 content_blocker_v1.json에 포함시키며,
/// Safari Content Blocker 확장이 활성화된 경우에만 Safari에서 차단된다.
class WebsiteBlockStore {
  WebsiteBlockStore._();

  static const _boxName = 'isle_website_blocks';
  static const _domainsKey = 'blocked_v1';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get _b {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('WebsiteBlockStore.ensureOpen() first');
    return b;
  }

  static List<String> loadDomains() {
    final raw = _b.get(_domainsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final parsed = List<String>.from(jsonDecode(raw) as List);
      return BlockKeywordPolicy.sanitizeStoredWebsiteDomains(parsed);
    } catch (_) {
      return [];
    }
  }

  static Future<void> ensureDomainsSanitized() async {
    final raw = _b.get(_domainsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final parsed = List<String>.from(jsonDecode(raw) as List);
      final clean = BlockKeywordPolicy.sanitizeStoredWebsiteDomains(parsed);
      if (clean.length != parsed.length) {
        await saveDomains(clean);
      }
    } catch (_) {}
  }

  static Future<void> saveDomains(List<String> domains) async {
    final clean = BlockKeywordPolicy.sanitizeStoredWebsiteDomains(domains);
    await _b.put(_domainsKey, jsonEncode(clean));
  }

  static bool isBlocked(String domain) => loadDomains().contains(domain);

  static Future<void> toggle(String domain) async {
    final current = loadDomains();
    if (current.contains(domain)) {
      await saveDomains(current.where((d) => d != domain).toList());
    } else {
      await saveDomains([...current, domain]);
    }
  }

  /// `https://www.foo.com/path` → `foo.com`
  static String? normalizeDomain(String input) {
    var d = input.trim().toLowerCase();
    if (d.isEmpty) return null;
    d = d.replaceFirst(RegExp(r'^https?://'), '');
    d = d.split('/').first.split('?').first;
    if (d.startsWith('www.')) d = d.substring(4);
    if (!d.contains('.') || d.contains(' ') || d.length < 4) return null;
    return d;
  }

  static Future<bool> addCustomDomain(String raw) async {
    final d = normalizeDomain(raw);
    if (d == null) return false;
    final current = loadDomains();
    if (current.contains(d)) return true;
    await saveDomains([...current, d]);
    return true;
  }

  static Future<void> removeDomain(String domain) async {
    await saveDomains(loadDomains().where((d) => d != domain).toList());
  }

  static List<String> customDomainsOnly() {
    final catalogSet = catalog.map((c) => c.domain).toSet();
    return loadDomains().where((d) => !catalogSet.contains(d)).toList()..sort();
  }

  /// 사전 정의 차단 가능 도메인 카탈로그
  static const catalog = <WebsiteDef>[
    WebsiteDef(domain: 'youtube.com',   label: 'YouTube',       note: 'youtube.com · m.youtube.com'),
    WebsiteDef(domain: 'instagram.com', label: 'Instagram',     note: 'instagram.com'),
    WebsiteDef(domain: 'x.com',         label: 'X (트위터)',    note: 'x.com · twitter.com'),
    WebsiteDef(domain: 'tiktok.com',    label: 'TikTok',        note: 'tiktok.com'),
    WebsiteDef(domain: 'facebook.com',  label: 'Facebook',      note: 'facebook.com · m.facebook.com'),
    WebsiteDef(domain: 'reddit.com',    label: 'Reddit',        note: 'reddit.com'),
    WebsiteDef(domain: 'kakao.com',     label: 'Kakao',         note: '웹 쇼츠·카카오 (Safari만)'),
  ];
}

class WebsiteDef {
  const WebsiteDef({
    required this.domain,
    required this.label,
    required this.note,
  });
  final String domain;
  final String label;
  final String note;
}
