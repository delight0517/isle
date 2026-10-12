import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app_locale_policy.dart';

final appLocaleProvider = StateNotifierProvider<AppLocaleController, Locale?>(
  (_) => AppLocaleController(),
);

class AppLocaleController extends StateNotifier<Locale?> {
  AppLocaleController() : super(_loadSaved());

  static const _key = 'app_locale_code_v1';

  /// 저장된 언어 코드 — Riverpod 밖(정적 서비스)에서 AI 프롬프트 언어 결정에 사용
  static String get savedCodeOrDefault {
    try {
      final box = Hive.box<String>('isle_cache');
      final code = box.get(_key);
      return AppLocalePolicy.normalize(code);
    } catch (_) {
      return 'ko';
    }
  }

  static Locale? _loadSaved() {
    try {
      final box = Hive.box<String>('isle_cache');
      final code = box.get(_key);
      return Locale(AppLocalePolicy.normalize(code));
    } catch (_) {
      return const Locale(AppLocalePolicy.defaultCode);
    }
  }

  Future<void> setLocaleCode(String? code) async {
    final normalized = AppLocalePolicy.normalize(code);
    state = Locale(normalized);
    try {
      final box = Hive.box<String>('isle_cache');
      if (code == null || code.isEmpty) {
        await box.delete(_key);
        return;
      }
      await box.put(_key, normalized);
    } catch (_) {
      if (code == null || code.isEmpty) {
        state = const Locale(AppLocalePolicy.defaultCode);
        return;
      }
    }
  }
}
