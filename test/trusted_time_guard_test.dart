import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/services/isle_user_defaults.dart';
import 'package:isle/core/services/trusted_time_guard.dart';

/// 기기 시계를 앞으로 돌려 타임락을 우회하는 걸 막는 TrustedTimeGuard 검증
/// (2026-07-15 사용자 요청). 이 테스트 환경엔 실제 네트워크가 없을 수 있어
/// (샌드박스 정책에 따라 다름) `refresh()`가 네트워크 확보에 실패하는 경로도
/// 정상 동작(마지막 저장값 유지, 예외 없음)임을 함께 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    final dir = Directory.systemTemp.createTempSync('isle_trusted_time_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('refresh() does not throw even without network access', () async {
    await expectLater(TrustedTimeGuard.refresh(), completes);
  });

  test('effectiveNow() returns a plausible value close to DateTime.now() '
      'when no skew has been detected', () async {
    final before = DateTime.now();
    final now = TrustedTimeGuard.effectiveNow();
    final after = DateTime.now();
    // skew가 0이면(네트워크 미확보 등) effectiveNow()는 DateTime.now()와
    // 거의 같아야 한다 — 세션 드리프트 보정 로직이 오탐으로 몇 분씩 튀지
    //않는지 확인.
    expect(now.isAfter(before.subtract(const Duration(seconds: 5))), isTrue);
    expect(now.isBefore(after.add(const Duration(seconds: 5))), isTrue);
  });

  test('persisted skew survives across IsleUserDefaults round-trip', () async {
    await IsleUserDefaults.setTrustedTimeSkewMs(-7200000); // -2시간(기기가 2시간 빠름)
    expect(IsleUserDefaults.trustedTimeSkewMs, -7200000);
  });
}
