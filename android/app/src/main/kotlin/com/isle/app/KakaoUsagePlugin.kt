package com.isle.app

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

/// 카카오톡 포그라운드 → Dart `KakaoAndroidUsageBridge` (포모도로·세션 자동 기록)
class KakaoUsagePlugin : FlutterPlugin, EventChannel.StreamHandler {
    private var eventChannel: EventChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        eventChannel = EventChannel(binding.binaryMessenger, CHANNEL).also {
            it.setStreamHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        Companion.eventSink = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Companion.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        Companion.eventSink = null
    }

    companion object {
        const val CHANNEL = "com.isle.app/kakao_usage"
        const val KAKAO_PKG = "com.kakao.talk"

        @Volatile
        var eventSink: EventChannel.EventSink? = null

        fun onForegroundChanged(pkg: String, previousPkg: String?) {
            val sink = eventSink ?: return
            try {
                when {
                    pkg == KAKAO_PKG -> sink.success("started")
                    previousPkg == KAKAO_PKG -> sink.success("ended")
                }
            } catch (_: Exception) {
                // Flutter 엔진 없음 — 무시
            }
        }
    }
}
