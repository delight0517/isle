import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../constants/app_release_info.dart';

/// 차단 AI 챗 — 받은 명령·적용 결과 기록 (14일 보관, 이후 원인 분석용).
/// "언제·어디서·어떤 커맨드가 스케줄을 리셋했는지" 추적이 목적이라 — 키워드·URL
/// 원본 목록 같은 대용량 데이터는 절대 담지 않고 항상 짧은 요약만 남긴다.
class BlockAuditLogEntry {
  const BlockAuditLogEntry({
    required this.id,
    required this.at,
    required this.command,
    required this.action,
    required this.summary,
    required this.steps,
    required this.success,
    this.appVersion = '',
  });

  final String id;
  final DateTime at;
  /// 사용자가 챗에 입력한 원문 (자동 트리거는 "(자동) …"로 시작)
  final String command;
  /// 파싱된 action 종류 (예: block_channel, add_keyword, morning_schedule,
  /// reset_all_blocks, reset_all_blocks_deferred, app_update …)
  final String action;
  /// 적용 결과 한 줄 요약 — 원본 키워드·URL 목록이 아니라 항상 개수·범위만.
  final String summary;
  /// 실제 반영된 항목들 ("title: detail" 형태, 마찬가지로 짧은 요약만)
  final List<String> steps;
  final bool success;
  /// 이 항목이 기록된 시점의 앱 버전 (`AppReleaseInfo.pubspecVersion`) —
  /// 업데이트가 리셋을 유발했는지 앞뒤 항목의 버전을 비교해 알 수 있다.
  final String appVersion;

  factory BlockAuditLogEntry.fromJson(Map<String, dynamic> j) => BlockAuditLogEntry(
        id: j['id'] as String? ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        command: j['command'] as String? ?? '',
        action: j['action'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        steps: (j['steps'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        success: j['success'] as bool? ?? true,
        // 구버전 로그(필드 도입 전)는 빈 문자열 — UI에서 "알수없음"으로 표시.
        appVersion: j['appVersion'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'command': command,
        'action': action,
        'summary': summary,
        'steps': steps,
        'success': success,
        'appVersion': appVersion,
      };
}

class BlockAuditLogStore {
  BlockAuditLogStore._();

  static const _boxName = 'isle_block_audit_log';
  static const _logKey = 'entries_v1';
  /// 사용자 요청(2026-07-16) — 리셋 원인 분석을 위해 최소 2주는 항상 남겨둔다.
  /// 어떤 "전체 초기화" 경로도 이 박스는 절대 건드리면 안 된다
  /// ([BlockChatExecutor.performFullReset] 참고 — 이 store는 그 함수가 여는
  /// 박스 목록에 의도적으로 없다).
  static const retention = Duration(days: 14);

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('BlockAuditLogStore.ensureOpen() first');
    return b;
  }

  static bool get isOpen => _box != null && _box!.isOpen;

  static Future<void> record({
    required String command,
    required String action,
    required String summary,
    required List<String> steps,
    required bool success,
  }) async {
    final list = _loadAllUnpruned();
    list.insert(
      0,
      BlockAuditLogEntry(
        id: 'log_${DateTime.now().microsecondsSinceEpoch}',
        at: DateTime.now(),
        command: command,
        action: action,
        summary: summary,
        steps: steps,
        success: success,
        appVersion: AppReleaseInfo.pubspecVersion,
      ),
    );
    await _save(_prune(list));
  }

  /// 최근 14일(retention) 이내 항목만 (오래된 항목은 다음 write 때 실제로 삭제됨)
  static List<BlockAuditLogEntry> loadRecent() => _prune(_loadAllUnpruned());

  /// [window] 이내 항목만 — 예: 최근 24시간만 뽑아 디버그 복사용으로 쓸 때
  static List<BlockAuditLogEntry> loadWithin(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return loadRecent().where((e) => e.at.isAfter(cutoff)).toList();
  }

  /// 전체 백업(수십 개 박스)과 달리 — 실제로 바뀐 것만 사람이 읽을 텍스트로.
  /// 명령·적용 요약·단계까지 포함해 AI에 붙여넣어 디버깅하기 좋은 형태.
  static String buildCopyText(List<BlockAuditLogEntry> entries, {String title = '최근 변경 로그'}) {
    final buf = StringBuffer();
    buf.writeln('=== Isle $title ===');
    buf.writeln('App: ${AppReleaseInfo.label}');
    buf.writeln('내보낸 시각: ${DateTime.now().toIso8601String()}');
    buf.writeln('건수: ${entries.length}');
    buf.writeln();
    for (final e in entries) {
      final ver = e.appVersion.isEmpty ? '버전 알수없음' : 'v${e.appVersion}';
      buf.writeln('[${e.at.toIso8601String()}] $ver ${e.success ? "성공" : "실패"} · ${e.action}');
      buf.writeln('명령: "${e.command}"');
      buf.writeln('적용: ${e.summary}');
      for (final s in e.steps) {
        buf.writeln('  - $s');
      }
      buf.writeln('---');
    }
    return buf.toString();
  }

  static List<BlockAuditLogEntry> _loadAllUnpruned() {
    final raw = box.get(_logKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => BlockAuditLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<BlockAuditLogEntry> _prune(List<BlockAuditLogEntry> list) {
    final cutoff = DateTime.now().subtract(retention);
    return list.where((e) => e.at.isAfter(cutoff)).toList();
  }

  static Future<void> _save(List<BlockAuditLogEntry> list) async {
    await box.put(_logKey, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<void> pruneNow() async => _save(_prune(_loadAllUnpruned()));

  static Future<void> clear() => box.delete(_logKey);
}
