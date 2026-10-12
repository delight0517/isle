import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// 항상-켜짐 URL 패턴 — "mingky05.live" 같은 번호-우회 미러 사이트를
/// 채팅에서 처음 막을 때 자동으로 감지한 어간("mingky")을 저장한다.
/// [ScheduleRuleStore]의 URL 규칙과 달리 특정 스케줄·시간대에 묶이지 않고
/// 24시간 항상 적용되며, Safari Content Blocker에 순수 정규식 트리거로
/// 내보내져 mingky01.live·mingky02.net 같은 아직 안 나온 번호 변형까지
/// 한 번에 막는다(WebContentRuleCompiler 참고).
class AlwaysOnUrlPatternStore {
  AlwaysOnUrlPatternStore._();

  static const _boxName = 'isle_always_on_url_patterns';
  static const _key = 'stems_v1';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get _b {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('AlwaysOnUrlPatternStore.ensureOpen() first');
    }
    return b;
  }

  static List<String> loadStems() {
    final raw = _b.get(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return List<String>.from(jsonDecode(raw) as List)
          .map((e) => e.toString())
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<String> stems) async {
    await _b.put(_key, jsonEncode(stems));
  }

  static Future<bool> addStem(String stem) async {
    final s = stem.toLowerCase().trim();
    if (s.length < 3) return false;
    final current = loadStems();
    if (current.contains(s)) return true;
    await _save([...current, s]);
    return true;
  }

  static Future<void> removeStem(String stem) async {
    final s = stem.toLowerCase().trim();
    await _save(loadStems().where((e) => e != s).toList());
  }
}
