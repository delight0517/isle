package com.isle.app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent

/// 이벤트 기반 앱 차단 — 차단 대상 앱이 포그라운드로 오면 [BlockOverlayActivity] 표시.
///
/// Volt 친화: 폴링 타이머 없이 OS 가 주는 `TYPE_WINDOW_STATE_CHANGED` 이벤트만 처리한다.
/// 사용자가 설정 → 접근성에서 이 서비스를 켜야 동작 (OS 강제 아님 = best-effort, 정직히 표기됨).
class BlockingAccessibilityService : AccessibilityService() {
    private var lastForegroundPkg: String? = null
    private var lastBlockAt = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return

        // 자기 자신(차단 화면·앱 선택)·동일 패키지 반복은 무시.
        if (pkg == packageName) return
        if (pkg == lastForegroundPkg) return
        val previous = lastForegroundPkg
        lastForegroundPkg = pkg
        KakaoUsagePlugin.onForegroundChanged(pkg, previous)

        val targets = BlockingStore.targetSet(this)
        if (targets.isEmpty() || !targets.contains(pkg)) return

        // 짧은 시간 중복 트리거 방지 (앱 전환 시 이벤트 연속 발생).
        val now = SystemClock.elapsedRealtime()
        if (now - lastBlockAt < 800L) return
        lastBlockAt = now

        blockNow(pkg)
    }

    private fun blockNow(blockedPackage: String) {
        // 1) 차단된 앱에서 즉시 이탈 (홈).
        performGlobalAction(GLOBAL_ACTION_HOME)
        // 2) 차단 안내 전면 화면 표시.
        try {
            val intent = Intent(this, BlockOverlayActivity::class.java).apply {
                putExtra(BlockOverlayActivity.EXTRA_PACKAGE, blockedPackage)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(intent)
        } catch (_: Exception) {
            // 백그라운드 액티비티 시작이 막힌 경우 홈 이탈만으로 충분히 차단됨.
        }
    }

    override fun onInterrupt() {}

    override fun onServiceConnected() {
        super.onServiceConnected()
        lastForegroundPkg = null
    }
}
