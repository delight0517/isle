import 'package:hive_flutter/hive_flutter.dart';

/// 로그아웃 상태에서 수신한 공유 URL을 보관했다가, 로그인 후 아카이브 플로우로 전달합니다.
class PendingShareUrlStore {
  PendingShareUrlStore._();

  static const _key = 'pending_share_url_v1';
  static Box<String> get _box => Hive.box<String>('isle_cache');

  static Future<void> save(String url) => _box.put(_key, url);

  static Future<void> clear() => _box.delete(_key);

  static String? peek() {
    final u = _box.get(_key);
    if (u == null || u.isEmpty) return null;
    return u;
  }

  /// 비어 있지 않으면 제거한 뒤 그 URL을 반환합니다.
  static String? take() {
    final u = peek();
    if (u == null) return null;
    _box.delete(_key);
    return u;
  }
}
