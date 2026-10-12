import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../lib/core/localization/locale_controller.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('moa-locale-');
    Hive.init(directory.path);
    await Hive.openBox<String>('isle_cache');
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test('saved region language survives controller recreation and default reset', () async {
    final controller = AppLocaleController();
    expect(controller.state?.languageCode, 'ko');
    await controller.setLocaleCode('EN_us');
    expect(controller.state?.languageCode, 'en');
    controller.dispose();
    final restored = AppLocaleController();
    expect(restored.state?.languageCode, 'en');
    expect(AppLocaleController.savedCodeOrDefault, 'en');
    await restored.setLocaleCode(null);
    expect(restored.state?.languageCode, 'ko');
    expect(AppLocaleController.savedCodeOrDefault, 'ko');
    restored.dispose();
  });
  test('legacy invalid preference cannot leak an unsupported language', () async {
    await Hive.box<String>('isle_cache').put('app_locale_code_v1', 'unsupported');
    final controller = AppLocaleController();
    expect(controller.state?.languageCode, 'ko');
    expect(AppLocaleController.savedCodeOrDefault, 'ko');
    controller.dispose();
  });
}
