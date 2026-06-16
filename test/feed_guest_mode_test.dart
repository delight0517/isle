import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/constants/env.dart';

/// 게스트·Supabase 미설정 시 피드가 원격 호출 없이 동작하는지 (게이트만 검증)
void main() {
  test('Env.isSupabaseConfigured is false without loaded keys', () {
    expect(Env.isSupabaseConfigured, isFalse);
  });
}
