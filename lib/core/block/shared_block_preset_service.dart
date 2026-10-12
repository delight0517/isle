import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/env.dart';
import 'models/premade_block_pack.dart';

/// 프리셋 "친구에게 공유" — 공유 코드 방식(2026-07-05 결정).
/// 페이로드는 기존 PremadeBlockPackEntry 포맷 그대로 재사용, 새 포맷 발명하지 않음.
/// 스키마: _chat_system/backend/007_shared_presets.sql
class SharedBlockPreset {
  const SharedBlockPreset({
    required this.presetName,
    required this.entries,
    required this.includeSchedule,
    this.scheduleJson,
  });

  final String presetName;
  final List<PremadeBlockPackEntry> entries;
  final bool includeSchedule;
  final Map<String, dynamic>? scheduleJson;
}

class SharedBlockPresetService {
  SharedBlockPresetService._();

  static const _table = 'shared_block_presets';
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 혼동되는 0/O/1/I 제외

  static SupabaseClient get _client => Supabase.instance.client;
  static bool get hasRemote => Env.isSupabaseConfigured;

  static String _generateCode({int length = 6}) {
    final rnd = Random.secure();
    return List.generate(length, (_) => _codeChars[rnd.nextInt(_codeChars.length)]).join();
  }

  /// 프리셋을 공유 테이블에 저장하고 공유 코드를 반환한다.
  static Future<String?> createShareCode({
    required String appId,
    required String presetName,
    required List<PremadeBlockPackEntry> entries,
    bool includeSchedule = false,
    Map<String, dynamic>? scheduleJson,
  }) async {
    if (!hasRemote) return null;
    final userId = _client.auth.currentUser?.id;

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateCode();
      try {
        await _client.from(_table).insert({
          'share_code': code,
          'creator_app_id': appId,
          'creator_user_id': userId,
          'preset_name': presetName,
          'entries': entries.map((e) => e.toJson()).toList(),
          'include_schedule': includeSchedule,
          'schedule_json': includeSchedule ? scheduleJson : null,
        });
        return code;
      } catch (_) {
        // share_code 충돌(극히 드묾) — 재시도. 그 외 실패는 null 반환.
        continue;
      }
    }
    return null;
  }

  /// 코드로 프리셋을 가져온다. 없으면 null.
  static Future<SharedBlockPreset?> importByCode(String code) async {
    if (!hasRemote) return null;
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return null;

    final rows = await _client.from(_table).select().eq('share_code', trimmed).limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    final row = Map<String, dynamic>.from(list.first as Map);

    final entriesRaw = row['entries'] as List? ?? const [];
    final entries = entriesRaw
        .map((e) => PremadeBlockPackEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return SharedBlockPreset(
      presetName: row['preset_name'] as String? ?? '공유 프리셋',
      entries: entries,
      includeSchedule: row['include_schedule'] as bool? ?? false,
      scheduleJson: row['schedule_json'] != null
          ? Map<String, dynamic>.from(row['schedule_json'] as Map)
          : null,
    );
  }
}
