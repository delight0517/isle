import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/block/models/premade_block_pack.dart';
import 'package:isle/core/block/shared_block_preset_service.dart';

/// Env.supabaseUrl/anonKey 는 아직 플레이스홀더라 hasRemote=false —
/// 실 네트워크 호출 없이 안전하게 no-op 되는지만 검증(라이브 프로젝트 연결은 별도 작업).
void main() {
  test('원격 미설정이면 공유 코드 생성이 조용히 null 반환(네트워크 호출 없음)', () async {
    final code = await SharedBlockPresetService.createShareCode(
      appId: 'moa',
      presetName: '내 프리셋',
      entries: const [PremadeBlockPackEntry(pattern: 'example.com', kind: 'domain')],
    );
    expect(code, isNull);
  });

  test('원격 미설정이면 코드로 가져오기도 조용히 null 반환', () async {
    final preset = await SharedBlockPresetService.importByCode('ABC123');
    expect(preset, isNull);
  });
}
