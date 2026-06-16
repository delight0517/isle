import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final appLocaleProvider = StateNotifierProvider<AppLocaleController, Locale?>(
  (_) => AppLocaleController(),
);

class AppLocaleController extends StateNotifier<Locale?> {
  AppLocaleController() : super(_loadSaved());

  static const _key = 'app_locale_code_v1';

  static Locale? _loadSaved() {
    try {
      final box = Hive.box<String>('isle_cache');
      final code = box.get(_key);
      if (code == null || code.isEmpty) return null;
      return Locale(code);
    } catch (_) {
      return null;
    }
  }

  void setLocaleCode(String? code) {
    try {
      final box = Hive.box<String>('isle_cache');
      if (code == null || code.isEmpty) {
        box.delete(_key);
        state = null;
        return;
      }
      box.put(_key, code);
    } catch (_) {
      if (code == null || code.isEmpty) {
        state = null;
        return;
      }
    }
    state = Locale(code);
  }
}
