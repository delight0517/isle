import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ai/block_chat/block_audit_log_store.dart';

/// "지난 2주간 log 전부 복사하기" — 설정 화면 상단 버튼과 로그 화면 양쪽에서
/// 똑같이 쓰는 공용 동작(2026-07-16 사용자 요청). 스케줄/차단 변경 기록만
/// 담고(키워드·URL 원본은 안 담음) 14일 보관분 전체를 클립보드에 복사한다 —
/// "언제·어디서·어떤 커맨드가 스케줄을 통째로 리셋했는지" 원인 분석용.
class BlockAuditLogPasteboard {
  BlockAuditLogPasteboard._();

  static Future<void> copyAll(BuildContext context) async {
    await BlockAuditLogStore.ensureOpen();
    final entries = BlockAuditLogStore.loadRecent();
    final text = BlockAuditLogStore.buildCopyText(entries, title: '최근 14일 변경 로그');
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          entries.isEmpty
              ? '지난 14일간 변경 기록 없음 (빈 로그 복사됨)'
              : '지난 14일 변경 ${entries.length}건 복사됨 — AI에 붙여넣기 하세요',
        ),
      ),
    );
  }
}
