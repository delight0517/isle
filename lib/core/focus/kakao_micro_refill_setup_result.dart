import '../block_schedule/models/block_schedule.dart';

/// 카카오 5분 리필 설정 결과 — UI 안내용
class KakaoMicroRefillSetupResult {
  const KakaoMicroRefillSetupResult({
    required this.schedule,
    required this.masterEnabled,
    required this.limitMinutes,
    required this.windowMinutes,
    required this.screenTimeAppCount,
    required this.limitRuleRegistered,
    required this.pickerAttempted,
  });

  final BlockSchedule schedule;
  final bool masterEnabled;
  final int limitMinutes;
  final int windowMinutes;
  final int screenTimeAppCount;
  final bool limitRuleRegistered;
  final bool pickerAttempted;

  bool get needsScreenTimePick => screenTimeAppCount == 0;

  bool get isReadyForIosLimit =>
      masterEnabled && screenTimeAppCount > 0 && limitRuleRegistered;

  String statusMessage({required bool isIos}) {
    if (!masterEnabled) return '스케줄 마스터가 꺼져 있었어요 — 켰습니다';
    if (needsScreenTimePick) {
      return isIos
          ? '카카오톡을 Screen Time에서 선택해야 실제로 막혀요'
          : '접근성·사용량 권한을 확인해 주세요';
    }
    if (!limitRuleRegistered) return 'OS 한도 등록에 실패했어요 — 앱 로그를 확인해 주세요';
    if (isIos && windowMinutes == 60) {
      return '매시간 ${limitMinutes}분까지 카카오톡 허용 (iOS 방식)';
    }
    return '${windowMinutes}분마다 ${limitMinutes}분만 카카오톡 허용';
  }
}
