import 'dart:io' show File, Platform;

import '../ai/ai_config_store.dart';
import '../auth/google_sign_in_config.dart';
import '../block_schedule/block_schedule_store.dart';
import '../blocking/android_blocking_setup_service.dart';
import '../blocking/blocking_controller_provider.dart';
import '../constants/app_release_info.dart';
import '../focus/kakao_shorts_addiction_store.dart';
import '../focus/kakao_shorts_preset_service.dart';
import '../library/youtube_account_sync_service.dart';
import '../library/youtube_library_service.dart';
import '../platform/isle_apple_platform.dart';
import '../services/isle_user_defaults.dart';
import '../youtube/blocked_channel_store.dart';
import '../youtube/youtube_music_route.dart';
import '../youtube/youtube_podcast_feed_service.dart';
import '../youtube/youtube_podcast_listen_store.dart';
import '../youtube/youtube_podcast_saved_playlist_store.dart';
import '../block_schedule/schedule_target_access_guard.dart';
import '../navigation/isle_routes.dart';
import '../youtube/youtube_access_guard.dart';
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

  static Future<DeviceQaPreflightResult> runOne(String id) async {
    switch (id) {
      case 'youtube_voice':
        return _safe('youtube_voice', _youtubeVoice);
      case 'youtube_channel_block':
        return _safe('youtube_channel_block', _youtubeChannelBlock);
      case 'ai_schedule':
        return _safe('ai_schedule', _aiSchedule);
      case 'ai_isle_yt_schedule':
        return _safe('ai_isle_yt_schedule', _isleYtSchedule);
      case 'youtube_lock_overlay':
        return _safe('youtube_lock_overlay', _youtubeLockOverlay);
      case 'youtube_limits_ui':
        return _safe('youtube_limits_ui', _youtubeLimits);
      case 'pomodoro':
        return _safe('pomodoro', _pomodoro);
      case 'kakao_refill':
        return _safe('kakao_refill', _kakaoRefill);
      case 'youtube_account':
        return _safe('youtube_account', _youtubeAccount);
      case 'android_blocking':
        return _safe('android_blocking', _androidBlocking);
      case 'build_smoke':
        return _safe('build_smoke', _buildSmoke);
      case 'deploy_macos':
        return _safe('deploy_macos', _deployMacos);
      case 'deploy_ios':
        return _safe('deploy_ios', _deployIos);
      case 'deploy_vercel':
        return _safe('deploy_vercel', _deployVercel);
      default:
        return DeviceQaPreflightResult(
          passed: false,
          summary: '알 수 없는 항목',
          hint: id,
        );
    }
  }

  static Future<Map<String, DeviceQaPreflightResult>> runAll() async {
    final results = await Future.wait([
      _safe('youtube_voice', _youtubeVoice),
      _safe('youtube_lock_overlay', _youtubeLockOverlay),
      _safe('youtube_channel_block', _youtubeChannelBlock),
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
      'youtube_lock_overlay',
      'youtube_channel_block',
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

  static Future<DeviceQaPreflightResult> _youtubeLockOverlay() async {
    final routeOk = IsleRoutes.blockSchedulesOutsideShell == '/block/schedules';
    final editOk = IsleRoutes.blockScheduleEditOutsideShell('test_id') ==
        '/block/schedules/test_id';
    final scheduleLock = YoutubeAccessGuard.activeLock() == YoutubeLockReason.schedule;
    final isleBlocked = ScheduleTargetAccessGuard.isIsleYoutubeBlocked;
    final guardsAligned = scheduleLock == isleBlocked;
    final locked = scheduleLock || isleBlocked;

    if (!routeOk || !editOk) {
      return const DeviceQaPreflightResult(
        passed: false,
        summary: '셸 밖 라우트 설정 오류',
        hint: '/block/schedules 경로 확인',
      );
    }
    return DeviceQaPreflightResult(
      passed: guardsAligned,
      summary: locked ? '잠금 ON · 가드 일치' : '잠금 OFF · 라우트 OK',
      hint: locked
          ? '?qa=1에서 오버레이 1개·편집 화면 확인'
          : '스케줄 켠 뒤 YouTube 잠금·편집 버튼 확인',
    );
  }

  static Future<DeviceQaPreflightResult> _youtubeChannelBlock() async {
    final count = BlockedChannelStore.loadAll().length;
    return DeviceQaPreflightResult(
      passed: true,
      summary: count > 0 ? '차단 채널 $count개 · 가드 ON' : '차단 채널 없음 · 가드 ON',
      hint: count > 0
          ? '인앱 watch·음성에서 해당 채널 재생 차단 확인 · iOS YouTube앱=항상 막기'
          : '피드에서 채널 숨긴 뒤 인앱 재생 차단 확인',
    );
  }

  static Future<DeviceQaPreflightResult> _youtubeVoice() async {
    if (!YoutubePodcastListenStore.isOpen) {
      return const DeviceQaPreflightResult(
        passed: false,
        summary: '음성 한도 저장소 미준비',
        hint: '앱을 다시 시작해 주세요',
      );
    }
    final listenLine = YoutubePodcastListenStore.formatStatusLine();
    final musicRouteOk = YoutubeMusicRoute.podcastRouteFor(
          'https://music.youtube.com/watch?v=dQw4w9WgXcQ',
        ) !=
        null;
    var playlistCount = 0;
    if (YoutubePodcastSavedPlaylistStore.isOpen) {
      playlistCount = YoutubePodcastSavedPlaylistStore.loadAll().length;
    }
    final signed = YoutubeLibraryService.currentAccount;
    if (signed != null) {
      try {
        final subs = await YoutubePodcastFeedService.fetchSubscriptionFeed(
          maxChannels: 3,
          perChannel: 1,
        );
        final uploads = await YoutubePodcastFeedService.fetchMyUploads(maxResults: 3);
        final plHint = playlistCount > 0
            ? ' · Isle 재생목록 $playlistCount개'
            : ' · 재생목록 탭에서 링크 추가';
        return DeviceQaPreflightResult(
          passed: musicRouteOk,
          summary:
              'API · ${signed.email} · 구독 ${subs.length} · 내영상 ${uploads.length}$plHint',
          hint: musicRouteOk
              ? '$listenLine · 오디오만·파형·소리 재생 확인'
              : 'YT Music 라우트 오류 · 개발자에게 알려 주세요',
        );
      } catch (e) {
        return DeviceQaPreflightResult(
          passed: false,
          summary: '로그인됨 · 피드 API 실패',
          hint: '$e · 설정 → YouTube 계정 동기화',
        );
      }
    }
    if (YoutubeLibraryService.canAttemptSignIn) {
      return DeviceQaPreflightResult(
        passed: musicRouteOk,
        summary: 'API 로그인 가능 · $listenLine · 재생목록 $playlistCount개',
        hint: musicRouteOk
            ? '로그인 → 구독·내 영상·파형·소리'
            : 'YT Music 라우트 오류',
      );
    }
    return DeviceQaPreflightResult(
      passed: false,
      summary: 'Google OAuth 미설정',
      hint: YoutubeLibraryService.setupHint,
    );
  }

  static Future<DeviceQaPreflightResult> _aiSchedule() async {
    final configured = AiConfigStore.isConfigured;
    final enforced = IsleUserDefaults.apiBudgetEnforced;
    final budget = IsleUserDefaults.apiMonthlyBudgetUsd;
    final budgetBlocked = configured && enforced && budget < 0.5;
    final lastMs = IsleUserDefaults.aiHubLastTestMs;
    final lastOk = IsleUserDefaults.aiHubLastTestOk;
    String? lastLabel;
    if (lastMs != null) {
      final at = DateTime.fromMillisecondsSinceEpoch(lastMs).toLocal();
      lastLabel = lastOk ? '연결 OK' : '연결 실패';
      lastLabel = '$lastLabel · ${at.month}/${at.day} ${at.hour}:${at.minute.toString().padLeft(2, '0')}';
    }
    if (budgetBlocked) {
      return DeviceQaPreflightResult(
        passed: false,
        summary: '키 있음 · 예산 \$${budget.toStringAsFixed(1)} (차단)',
        hint: 'AI 센터 → 예산 \$1+ 또는 예산 강제 OFF',
      );
    }
    return DeviceQaPreflightResult(
      passed: !budgetBlocked,
      summary: configured
          ? 'AI 키 설정됨${lastLabel != null ? " · $lastLabel" : ""}'
          : '로컬 폴백 (키 없음)',
      hint: configured ? '차단 AI 챗 한 줄 테스트' : '키 붙여넣기 → 연결 테스트',
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
      hint: '슬라이더 변경 → sticky 저장 · 배지 자동 lift',
    );
  }

  static Future<DeviceQaPreflightResult> _pomodoro() async {
    try {
      final on = KakaoShortsAddictionStore.pomodoroEnabled;
      if (!on) {
        return const DeviceQaPreflightResult(
          passed: true,
          summary: '포모도로 OFF',
          hint: '포모도로 탭에서 켜기 → 30분 집중·10분 휴식',
        );
      }
      final open = KakaoShortsAddictionStore.openSession();
      final onBreak = KakaoShortsAddictionStore.isOnBreak;
      final workMin = KakaoShortsAddictionStore.workSecondsInCycle ~/ 60;
      final breakLeft = KakaoShortsAddictionStore.breakRemaining;
      final sessionLabel = open != null ? ' · 세션 진행 중' : '';
      if (onBreak && breakLeft != null) {
        return DeviceQaPreflightResult(
          passed: true,
          summary: '휴식 ${breakLeft.inMinutes}분 남음 · OS 카카오 차단$sessionLabel',
          hint: '카카오톡 실행 시 쉴드 확인',
        );
      }
      return DeviceQaPreflightResult(
        passed: true,
        summary: '집중 $workMin/${KakaoShortsAddictionStore.defaultWorkMinutes}분$sessionLabel',
        hint: '30분 채우면 10분 휴식 OS차단',
      );
    } catch (_) {
      return const DeviceQaPreflightResult(
        passed: false,
        summary: '포모도로 저장소 미준비',
        hint: '앱 재시작 후 포모도로 탭 확인',
      );
    }
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
    final wl = YoutubeAccountSyncService.watchLaterInLibraryCount();
    final auto = IsleUserDefaults.youtubeAccountAutoSync;
    return DeviceQaPreflightResult(
      passed: email != null,
      summary: email != null
          ? '로그인: $email · WL $wl개 · 자동${auto ? "ON" : "OFF"}'
          : '미로그인',
      hint: '지금 동기화 → 나중에 볼·플레이list 확인',
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
