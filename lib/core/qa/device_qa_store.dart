import 'package:hive_flutter/hive_flutter.dart';

/// 실기기 확인 체크리스트 (TODO §1) — 로컬만
class DeviceQaStore {
  DeviceQaStore._();

  static const _boxName = 'isle_device_qa';
  static const _checkedKey = 'checked_ids_v1';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('DeviceQaStore not open');
    return b;
  }

  static Set<String> loadChecked() {
    final raw = box.get(_checkedKey);
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((e) => e.isNotEmpty).toSet();
  }

  static Future<void> setChecked(String id, bool checked) async {
    final set = loadChecked();
    if (checked) {
      set.add(id);
    } else {
      set.remove(id);
    }
    await box.put(_checkedKey, set.join(','));
  }

  static Future<void> clearAll() async {
    await box.delete(_checkedKey);
  }

  static bool isChecked(String id) => loadChecked().contains(id);

  static int countChecked(Iterable<String> allIds) =>
      allIds.where(isChecked).length;
}
