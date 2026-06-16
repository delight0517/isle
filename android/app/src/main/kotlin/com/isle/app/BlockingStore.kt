package com.isle.app

import android.content.Context

/// 차단 대상 패키지 영속화 — `BlockingPlugin`(쓰기)·`BlockingAccessibilityService`(읽기) 공유.
/// CSV 형식 (예: "com.instagram.android,com.zhiliaoapp.musically"). Dart `BlockSelection.encoded` 와 동일 규약.
object BlockingStore {
    private const val PREFS = "isle_blocking"
    private const val KEY_TARGETS = "targets"
    private const val KEY_WEB_TARGETS = "web_targets"

    fun setTargets(context: Context, csv: String) {
        prefs(context).edit().putString(KEY_TARGETS, csv).apply()
    }

    fun targets(context: Context): String =
        prefs(context).getString(KEY_TARGETS, "") ?: ""

    fun targetSet(context: Context): Set<String> = csvToSet(targets(context))

    // ── 웹 차단 도메인 (VpnService) ──────────────────────────────────────
    fun setWebTargets(context: Context, csv: String) {
        prefs(context).edit().putString(KEY_WEB_TARGETS, csv).apply()
    }

    fun webTargets(context: Context): String =
        prefs(context).getString(KEY_WEB_TARGETS, "") ?: ""

    fun webTargetSet(context: Context): Set<String> = csvToSet(webTargets(context))

    private fun csvToSet(csv: String): Set<String> =
        csv.split(',').map { it.trim().lowercase() }.filter { it.isNotEmpty() }.toSet()

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
