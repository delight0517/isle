import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:isle/core/qa/device_qa_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Hive.init('./test/tmp_hive_device_qa');
    await DeviceQaStore.ensureOpen();
    await DeviceQaStore.clearAll();
  });

  tearDown(() async {
    await DeviceQaStore.box.clear();
    await DeviceQaStore.box.close();
  });

  test('toggle and load checked ids', () async {
    expect(DeviceQaStore.loadChecked(), isEmpty);
    await DeviceQaStore.setChecked('youtube_voice', true);
    await DeviceQaStore.setChecked('pomodoro', true);
    expect(DeviceQaStore.isChecked('youtube_voice'), isTrue);
    expect(DeviceQaStore.isChecked('pomodoro'), isTrue);
    expect(DeviceQaStore.countChecked(['youtube_voice', 'pomodoro', 'ai_schedule']), 2);
    await DeviceQaStore.setChecked('youtube_voice', false);
    expect(DeviceQaStore.isChecked('youtube_voice'), isFalse);
  });
}
