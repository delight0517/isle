import 'dart:io' show File, Platform;

import '../ai/ai_client.dart';
import '../auth/google_sign_in_config.dart';
import '../block_schedule/block_schedule_store.dart';
import '../blocking/android_blocking_setup_service.dart';
import '../blocking/blocking_controller_provider.dart';
import '../constants/app_release_info.dart';
import '../focus/kakao_shorts_addiction_store.dart';
import '../focus/kakao_shorts_preset_service.dart';
import '../library/youtube_library_service.dart';
import '../platform/isle_apple_platform.dart';
import '../services/isle_user_defaults.dart';
import '../youtube/youtube_podcast_listen_store.dart';
import '../youtube/youtube_watch_timer_store.dart';

/// TODO §1 — 앱 내 자동 점검 (실기기 수동 확인 전 프리플라이트)
class DeviceQaPreflightResult {
  const DeviceQaPreflightResult({
    required this.passed,
    required this.summary,
    this.hint,
  });

  final bool passed;
  final String summary;
  final String? hint;

  static const na = DeviceQaPreflightResult(
    passed: true,
    summary: '이 기기에서는 해당 없음',
  );
}

class DeviceQaPreflightService {
  DeviceQaPreflightService._();

  static Future<Map<String, DeviceQaPreflightResult>> runAll() async {
    final results = await Future.wait([
      _safe('youtube_voice', _youtubeVoice),
      _safe('ai_schedule', _aiSchedule),
      _safe('ai_isle_yt_schedule', _isleYtSchedule),
      _safe('youtube_limits_ui', _youtubeLimits),
      _safe('pomodoro', _pomodoro),
      _safe('kakao_refill', _kakaoRefill),
      _safe('youtube_account', _youtubeAccount),
      _safe('android_blocking', _androidBlocking),
      _safe('build_smoke', _buildSmoke),
      _safe('deploy_macos', _deployMacos),
      _safe('deploy_ios', _deployIos),
      _safe('deploy_vercel', _deployVercel),
    ]);
  const ids = [
      'youtube_voice',
      'ai_schedule',
      'ai_isle_yt_schedule',
      'youtube_limits_ui',
      'pomodoro',
      'kakao_refill',
      'youtube_account',
      'android_blocking',
      'build_smoke',
      'deploy_macos',
      'deploy_ios',
      'deploy_vercel',
    ];
    return Map<String, DeviceQaPreflightResult>.fromIterables(ids, results);
  }

  static Future<DeviceQaPreflightResult> _safe(
    String tag,
    Future<DeviceQaPreflightResult> Function() fn,
  ) async {
    try {
      return await fn();
    } catch (e) {
      return DeviceQaPreflightResult(
        passed: false,
        summary: '점검 오류',
        hint: '$tag: $e',
      );
    }
  }

  static Future<DeviceQaPreflightResult> _youtubeVoice() async {
    if (!YoutubePodcastListenStore.isOpen) {
      return const DeviceQaPreflightResult(
        passed: false,
        summary: '음성 한도 저장소 미준비',
        hint: '앱을 다시 시작해 주세요',
      );
    }
    final signed = YoutubeLibraryService.currentAccount;
    if (signed != null) {
      return DeviceQaPreflightResult(
        passed: true,
        summary: 'Google API 로그인됨 · ${signed.email}',
      );
    }
    if (YoutubeLibraryService.canAttemptSignIn) {
      return const DeviceQaPreflightResult(
        passed: true,
        summary: 'API 로그인 가능 · 구독/내영상 탭에서 로그인',
        hint: 'WebView 로그인은 화면 상단 버튼',
      );
    }
    return DeviceQaPreflightResult(
      passed: false,
      summary: 'Google OAuth 미설정',
      hint: YoutubeLibraryService.setupHint,
    );
  }

  static Future<DeviceQaPreflightResult> _aiSchedule() async {
    final key = AiClient.isConfigured;
    return DeviceQaPreflightResult(
      passed: true,
      summary: key ? 'AI API 키 설정됨' : '로컬 폴백 (키 없음)',
      hint: key ? 'AI 센터에서 연결 테스트' : '키 붙여넣기 후 연결 테스트',
    );
  }

  static Future<DeviceQaPreflightResult> _isleYtSchedule() async {
    final on = IsleUserDefaults.youtubeScheduleLockEnabled;
    final n = BlockScheduleStore.loadAll().length;
    return DeviceQaPreflightResult(
      passed: true,
      summary: on ? 'Isle 유튜브 스케줄 ON · $n개' : '스케줄 마스터 OFF · $n개',
      hint: '시트에서 슬롯 저장 후 WebView 차단 확인',
    );
  }

  static Future<DeviceQaPreflightResult> _youtubeLimits() async {
    final enabled = YoutubeWatchTimerStore.isEnabled;
    final interval = IsleUserDefaults.youtubeLimitUsesInterval;
    final min = interval
        ? IsleUserDefaults.youtubeIntervalAllowMinutes
        : IsleUserDefaults.youtubeDailyLimitMinutes;
    return DeviceQaPreflightResult(
      passed: true,
      summary: enabled
          ? '${interval ? "주기" : "일일"} ${min}분 한도 ON'
          : '한도 OFF',
      hint: '슬라이더 변경 → 하단 저장 버튼(sticky)',
    );
  }

  static Future<DeviceQaPreflightResult> _pomodoro() async {
    final on = KakaoShortsAddictionStore.pomodoroEnabled;
    return DeviceQaPreflightResult(
      passed: true,
      summary: on ? '포모도로 ON' : '포모도로 OFF',
      hint: '30분 집중·10분 휴식 OS차단은 실기기 확인',
    );
  }

  static Future<DeviceQaPreflightResult> _kakaoRefill() async {
    final hasRefill = BlockScheduleStore.loadAll().any(
      (s) => s.name == KakaoShortsPresetService.microRefillScheduleName,
    );
    final master = IsleUserDefaults.youtubeScheduleLockEnabled && hasRefill;
    return DeviceQaPreflightResult(
      passed: hasRefill,
      summary: hasRefill
          ? '5분 리필 스케줄 있음 · 마스터 ${master ? "ON" : "OFF"}'
          : '5분 리필 스케줄 없음',
      hint: hasRefill
          ? 'iOS=매시간 5분 · Android=5분 창'
          : '포모도로 탭에서 카카오 리필 설정',
    );
  }

  static Future<DeviceQaPreflightResult> _youtubeAccount() async {
    if (!YoutubeLibraryService.canAttemptSignIn) {
      return DeviceQaPreflightResult(
        passed: false,
        summary: 'Google OAuth 미설정',
        hint: GoogleSignInConfig.platformSetupHint,
      );
    }
    final email = YoutubeLibraryService.currentAccount?.email;
    return DeviceQaPreflightResult(
      passed: email != null,
      summary: email != null ? '로그인: $email' : '미로그인',
      hint: 'YouTube 계정 동기화에서 WL 가져오기',
    );
  }

  static Future<DeviceQaPreflightResult> _androidBlocking() async {
    if (!Platform.isAndroid) {
      if (IsleApplePlatform.isScreenTimeHost) {
        final caps = resolveBlockingController().capabilities;
        return DeviceQaPreflightResult(
          passed: true,
          summary: 'iOS · 앱 ${caps.appBlock.name}',
          hint: '차단 탭에서 FamilyControls 권한',
        );
      }
      return DeviceQaPreflightResult.na;
    }
    final s = await AndroidBlockingSetupService.load();
    final web = resolveBlockingController().capabilities.webBlock.name;
    return DeviceQaPreflightResult(
      passed: s.isReady,
      summary:
          '접근성 ${s.accessibilityOn ? "ON" : "OFF"} · 배터리 ${s.batteryIgnored ? "예외" : "최적화"}',
      hint: s.isReady ? 'VPN 웹차단($web) Chrome 실기기 확인' : 'Android 차단 체크리스트 완료',
    );
  }

  static Future<DeviceQaPreflightResult> _buildSmoke() async {
    return DeviceQaPreflightResult(
      passed: true,
      summary: AppReleaseInfo.label,
      hint: Platform.isAndroid ? '--flavor full' : 'flutter run',
    );
  }

  static Future<DeviceQaPreflightResult> _deployMacos() async {
    if (!Platform.isMacOS) {
      return DeviceQaPreflightResult.na;
    }
    final dmg = File(
      '${Platform.environment['HOME']}/Desktop/Isle_v${AppReleaseInfo.pubspecVersion}_macos.dmg',
    );
    return DeviceQaPreflightResult(
      passed: dmg.existsSync(),
      summary: dmg.existsSync() ? 'Desktop DMG 있음' : 'DMG 없음',
      hint: './deploy/scripts/release_mac.sh',
    );
  }

  static Future<DeviceQaPreflightResult> _deployIos() async {
    if (!IsleApplePlatform.isScreenTimeHost) {
      return DeviceQaPreflightResult.na;
    }
    final caps = resolveBlockingController().capabilities;
    return DeviceQaPreflightResult(
      passed: true,
      summary: 'iOS 빌드 준비 · 앱차단 ${caps.appBlock.name}',
      hint: 'ios_dev_signing_fix.sh → build_ipa_testflight.sh',
    );
  }

  static Future<DeviceQaPreflightResult> _deployVercel() async {
    if (!Platform.isMacOS) {
      return const DeviceQaPreflightResult(
        passed: true,
        summary: 'Mac에서 APK·vercel 배포',
        hint: 'release_android_web.sh → deploy_vercel.sh',
      );
    }
    final apk = File(
      '${Platform.environment['HOME']}/Desktop/Isle_v${AppReleaseInfo.pubspecVersion}_android.apk',
    );
    return DeviceQaPreflightResult(
      passed: apk.existsSync(),
      summary: apk.existsSync() ? 'Desktop APK 동기화됨' : 'APK 미빌드',
      hint: './deploy/scripts/release_android_web.sh',
    );
  }
}
