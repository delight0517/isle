import 'dart:async';
import 'dart:io';

import 'isle_app_log_service.dart';
import 'isle_user_defaults.dart';

/// 기기 시계를 앞으로 돌려서 타임락(커밋먼트 락)·예약된 대기를 우회하는 걸
/// 막는다(2026-07-15 사용자 요청 — "기기에서 시간 설정을 바꿔서 쉽게
/// 우회되게 하지 마라").
///
/// 두 겹으로 감지한다:
/// 1. **세션 간(앱을 껐다 켬)** — 앱 재실행/포그라운드 복귀 시점에만 네트워크로
///    실제 시각을 확인하고(신뢰 가능한 호스트의 HTTP `Date` 헤더), 기기 시계와의
///    차이를 `skew`로 저장한다. "대기 중 앱을 닫고 시계를 돌린 뒤 다시 열기"가
///    가장 흔한 우회 패턴인데, 이 패턴은 정확히 앱이 다시 열리는 그 순간에
///    감지된다 — 이 앱의 모든 예약 처리(processDue 등)도 정확히 그 순간에만
///    일어나므로 타이밍이 맞아떨어진다.
/// 2. **세션 중(앱을 계속 켜둔 채)** — Dart `Sto[REDACTED] OS 단조시계
///    (monotonic clock) 기반이라 날짜·시간 설정 변경에 영향을 안 받는다.
///    벽시계 경과시간과 Sto[REDACTED] 경과시간이 크게 어긋나면(기기 시계를 켜진
///    채로 돌린 것) 그 차이만큼 보정한다.
///
/// 네트워크가 없으면 마지막으로 저장된 skew를 그대로 쓴다(오프라인일 때
/// 기존 동작을 깨지 않기 위한 fail-open) — 즉 이 방어는 "온라인일 때 우회를
/// 어렵게 만든다"이지 "오프라인에서도 완벽 차단"은 아니다.
class TrustedTimeGuard {
  TrustedTimeGuard._();

  static const _skewKey = 'trusted_time_skew_ms';
  static const _sessionDriftThreshold = Duration(minutes: 2);
  // 콜드 부팅 경로(main.dart)에서 이 refresh()를 그대로 await하므로, 오프라인일
  // 때 첫 화면이 너무 늦어지지 않게 호스트 수·타임아웃을 짧게 유지한다(앱
  // 시작시간 렉은 과거에 심각한 사고였던 전례가 있어 특히 보수적으로 잡음).
  static const _networkHosts = [
    'https://www.apple.com',
    'https://www.cloudflare.com',
  ];
  static const _perHostTimeout = Duration(seconds: 2);

  static Duration _skew = Duration.zero;
  static DateTime? _sessionAnchorWallTime;
  static final Stopwatch _sessionStopwatch = Stopwatch();
  static bool _loadedPersisted = false;

  /// 잠금·예약 계산에 쓸 "보정된 지금" — `DateTime.now()` 대신 이걸 쓴다.
  static DateTime effectiveNow() {
    var now = DateTime.now().add(_skew);

    final anchor = _sessionAnchorWallTime;
    if (anchor != null && _sessionStopwatch.isRunning) {
      final wallElapsed = DateTime.now().difference(anchor);
      final monoElapsed = _sessionStopwatch.elapsed;
      final drift = wallElapsed - monoElapsed;
      // 벽시계가 단조시계보다 많이 앞서갔다 = 세션 중 기기 시계를 앞으로 돌림.
      if (drift > _sessionDriftThreshold) {
        now = now.subtract(drift);
      }
    }
    return now;
  }

  /// 앱 실행/포그라운드 복귀 시점에 호출 — 네트워크로 실제 시각을 재확인하고
  /// 세션 앵커(단조시계 기준점)를 새로 잡는다. main.dart/lifecycle 훅에서
  /// `processDue()`·`finalizeExpiredLocks()` 등 실제 잠금 판정 전에 먼저
  /// 호출해야 그 판정들이 보정된 skew를 쓸 수 있다.
  static Future<void> refresh() async {
    if (!_loadedPersisted) {
      _skew = Duration(milliseconds: IsleUserDefaults.trustedTimeSkewMs);
      _loadedPersisted = true;
    }

    _sessionAnchorWallTime = DateTime.now();
    _sessionStopwatch
      ..reset()
      ..start();

    final networkTime = await _fetchNetworkTime();
    if (networkTime == null) return; // 오프라인 — 마지막 skew 유지(fail-open)

    final freshSkew = networkTime.difference(DateTime.now());
    // 이미 알던 것보다 훨씬 큰(뒤로든 앞으로든) 새 skew가 감지되면 로그를
    // 남긴다 — 오탐(네트워크 지연 등)일 수도 있으니 강제 차단은 안 하고
    // 판정에만 반영한다.
    if ((freshSkew - _skew).abs() > _sessionDriftThreshold) {
      IsleAppLogService.log(
        'TrustedTimeGuard: clock skew changed from ${_skew.inMinutes}min '
        'to ${freshSkew.inMinutes}min — device clock may have been changed',
        level: IsleLogLevel.warn,
      );
    }
    _skew = freshSkew;
    await IsleUserDefaults.setTrustedTimeSkewMs(_skew.inMilliseconds);
  }

  static Future<DateTime?> _fetchNetworkTime() async {
    for (final host in _networkHosts) {
      try {
        final client = HttpClient()..connectionTimeout = _perHostTimeout;
        final req =
            await client.headUrl(Uri.parse(host)).timeout(_perHostTimeout);
        final res = await req.close().timeout(_perHostTimeout);
        final dateHeader = res.headers.value(HttpHeaders.dateHeader);
        client.close();
        if (dateHeader == null) continue;
        final parsed = HttpDate.parse(dateHeader);
        return parsed;
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
