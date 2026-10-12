package com.isle.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AppLimitPlugin())
        flutterEngine.plugins.add(BlockingPlugin())
        flutterEngine.plugins.add(KakaoUsagePlugin())
        flutterEngine.plugins.add(WebSessionPlugin())
    }
}
