import '../ai/block_chat/block_audit_log_store.dart';
import '../block_schedule/block_schedule_store.dart';
import '../constants/app_release_info.dart';
import 'isle_user_defaults.dart';

/// 부팅마다 "이전 버전 → 이번 버전"과 스케줄 개수를 비교해 감사 로그에 남긴다.
/// 목적은 오직 하나 — 사용자가 겪은 "왜인지 모르게 스케줄이 전부 사라짐"
/// 현상이 **업데이트 자체 때문인지** 가려낼 근거를 남기는 것(2026-07-16 요청).
/// 챗 명령과 달리 이건 사람이 입력한 게 아니라 앱이 스스로 관측한 사실이라
/// [BlockAuditLogStore]에 action='app_update'/'app_boot'로 구분해 남긴다.
class AppUpdateAuditService {
  AppUpdateAuditService._();

  static Future<void> checkAndRecord() async {
    await BlockScheduleStore.ensureOpen();
    await BlockAuditLogStore.ensureOpen();

    final currentVersion = AppReleaseInfo.pubspecVersion;
    final lastVersion = IsleUserDefaults.lastSeenAppVersion;
    final lastCount = IsleUserDefaults.lastKnownScheduleCount;
    final nowCount = BlockScheduleStore.loadAll().length;

    // 첫 설치(비교 대상 없음)면 그냥 기준값만 남기고 끝 — "업데이트"가 아니다.
    if (lastVersion != null && lastVersion != currentVersion) {
      final wipedSuddenly = (lastCount ?? 0) > 0 && nowCount == 0;
      try {
        await BlockAuditLogStore.record(
          command: '(자동) 앱 업데이트 감지: v$lastVersion → v$currentVersion',
          action: 'app_update',
          summary: '스케줄 ${lastCount ?? "?"}개 → $nowCount개'
              '${wipedSuddenly ? ' ⚠️ 업데이트 직후 스케줄이 전부 사라짐 — 이 업데이트가 원인일 가능성 높음' : ''}',
          steps: const [],
          success: !wipedSuddenly,
        );
      } catch (_) {}
    }

    await IsleUserDefaults.setLastSeenAppVersion(currentVersion);
    await IsleUserDefaults.setLastKnownScheduleCount(nowCount);
  }
}
