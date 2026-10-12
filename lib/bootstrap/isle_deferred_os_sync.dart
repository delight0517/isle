import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/block_schedule/safety_baseline_service.dart';
import '../core/block_schedule/volt_schedule_boundary_service.dart';
import '../core/intervention/screen_time_persistence_service.dart';
import '../core/services/isle_app_log_service.dart';

/// [Volt] UI가 먼저 뜬 뒤 Screen Time·앱 한도 등 무거운 OS 동기화 — 부팅 직후 멈춤·크래시 방지.
class IsleDeferredOsSyncService {
  IsleDeferredOsSyncService._();

  static var _scheduled = false;
  static var _running = false;

  static void scheduleAfterUiReady() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runDeferred());
    });
  }

  static Future<void> _runDeferred() async {
    if (_running) return;
    _running = true;
    try {
      // 첫 프레임·스플래시 이후 — 메인 스레드 숨 고르기
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      IsleAppLogService.log('deferred OS sync: start');
      // 설치 후 최초 1회 "최소한의 안전 라인" 자동 심기(2026-07-16 사용자
      // 요청) — 여기서 하는 이유는 클래스 doc 참고. UI가 이미 떠 있으므로
      // 이 안에서 실패해도(실패는 이미 SafetyBaselineService 쪽에서 자체
      // try 없이 던지지만 이 바깥 try가 감싼다) 다른 배포된 OS 동기화·앱은
      // 멈추지 않는다.
      await SafetyBaselineService.seedIfNeeded();
      await ScreenTimePersistenceService.reapplyIfAuthorized(force: true);
      await VoltScheduleBoundaryService.reconcileAfterResume();
      IsleAppLogService.log('deferred OS sync: done');
    } catch (e, st) {
      IsleAppLogService.log(
        'deferred OS sync failed (app stays open): $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
    } finally {
      _running = false;
    }
  }
}
