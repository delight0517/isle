package com.isle.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/// 플랫폼 중립 차단 엔진의 Android 구현 — Dart `AndroidBlockingController` 와 1:1.
///
/// 채널 `com.isle.app/blocking`. 앱 차단은 [BlockingAccessibilityService](이벤트 기반)
/// 가 담당하고, 이 플러그인은 권한·대상 선택·대상 영속화만 한다. (웹 차단은 Phase 2 VPN)
class BlockingPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context
    private var activity: Activity? = null
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingVpnResult: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.isle.app/blocking")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)

            "authorizationStatus" ->
                result.success(if (isAccessibilityEnabled()) "approved" else "notDetermined")

            "requestAuthorization" -> {
                if (isAccessibilityEnabled()) {
                    result.success(mapOf("ok" to true))
                } else {
                    openAccessibilitySettings()
                    result.success(
                        mapOf(
                            "ok" to false,
                            "code" to "accessibility",
                            "message" to "설정 → 접근성 → Isle 차단 서비스를 켜 주세요. " +
                                "켠 뒤 다시 시도하면 차단이 활성화됩니다.",
                        ),
                    )
                }
            }

            "pickApps" -> {
                val act = activity
                if (act == null) {
                    result.success(null)
                    return
                }
                if (pendingPickResult != null) {
                    pendingPickResult?.success(null)
                }
                pendingPickResult = result
                val existing = call.argument<String>("existing") ?: BlockingStore.targets(appContext)
                val intent = Intent(act, AppPickerActivity::class.java).apply {
                    putExtra(AppPickerActivity.EXTRA_EXISTING, existing)
                }
                act.startActivityForResult(intent, REQUEST_PICK)
            }

            "applyAppShield" -> {
                val packages = call.argument<String>("packages") ?: ""
                BlockingStore.setTargets(appContext, packages)
                result.success(packages.isNotEmpty())
            }

            "clearAppShield" -> {
                BlockingStore.setTargets(appContext, "")
                result.success(null)
            }

            "applyWebBlock" -> {
                @Suppress("UNCHECKED_CAST")
                val domains = (call.argument<List<String>>("domains") ?: emptyList())
                BlockingStore.setWebTargets(appContext, domains.joinToString(","))
                if (domains.isEmpty()) {
                    BlockingVpnService.stop(appContext)
                    result.success(false)
                    return
                }
                val prepare = VpnService.prepare(activity ?: appContext)
                if (prepare == null) {
                    BlockingVpnService.start(appContext)
                    result.success(true)
                } else {
                    val act = activity
                    if (act == null) {
                        result.success(false)
                        return
                    }
                    if (pendingVpnResult != null) pendingVpnResult?.success(false)
                    pendingVpnResult = result
                    act.startActivityForResult(prepare, REQUEST_VPN)
                }
            }

            "clearWebBlock" -> {
                BlockingStore.setWebTargets(appContext, "")
                BlockingVpnService.stop(appContext)
                result.success(null)
            }

            "openSettings" -> {
                openAccessibilitySettings()
                result.success(null)
            }

            "isBatteryOptimizationIgnored" -> {
                val pm = appContext.getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(pm.isIgnoringBatteryOptimizations(appContext.packageName))
            }

            "openBatterySettings" -> {
                openBatteryOptimizationSettings()
                result.success(null)
            }

            "openManufacturerBatterySettings" -> {
                openManufacturerBatterySettings()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    // ── 접근성 권한 ──────────────────────────────────────────────────────
    private fun isAccessibilityEnabled(): Boolean {
        val expected = "${appContext.packageName}/${BlockingAccessibilityService::class.java.name}"
        val enabledServices = Settings.Secure.getString(
            appContext.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledServices)
        while (splitter.hasNext()) {
            if (splitter.next().equals(expected, ignoreCase = true)) return true
        }
        return false
    }

    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        appContext.startActivity(intent)
    }

    private fun openBatteryOptimizationSettings() {
        val pkg = appContext.packageName
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$pkg")
            }
        } else {
            Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
        }
        startActivitySafe(intent)
    }

    private fun openManufacturerBatterySettings() {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val intents = when {
            manufacturer.contains("samsung") -> listOf(
                Intent().setClassName(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.battery.ui.BatteryActivity",
                ),
                Intent().setClassName(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.battery.BatteryActivity",
                ),
            )
            manufacturer.contains("xiaomi") ||
                manufacturer.contains("redmi") ||
                manufacturer.contains("poco") -> listOf(
                Intent().setClassName(
                    "com.miui.securitycenter",
                    "com.miui.powercenter.PowerSettings",
                ),
            )
            else -> emptyList()
        }
        for (intent in intents) {
            if (startActivitySafe(intent)) return
        }
        openBatteryOptimizationSettings()
    }

    private fun startActivitySafe(intent: Intent): Boolean {
        return try {
            val act = activity
            if (act != null) {
                act.startActivity(intent)
            } else {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                appContext.startActivity(intent)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    // ── ActivityAware ────────────────────────────────────────────────────
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQUEST_PICK -> {
                val result = pendingPickResult
                pendingPickResult = null
                if (result == null) return true
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val encoded = data.getStringExtra(AppPickerActivity.EXTRA_RESULT) ?: ""
                    val count = data.getIntExtra(AppPickerActivity.EXTRA_COUNT, 0)
                    result.success(mapOf("encoded" to encoded, "appCount" to count))
                } else {
                    result.success(null)
                }
                return true
            }
            REQUEST_VPN -> {
                val result = pendingVpnResult
                pendingVpnResult = null
                if (result == null) return true
                if (resultCode == Activity.RESULT_OK) {
                    BlockingVpnService.start(appContext)
                    result.success(true)
                } else {
                    result.success(false)
                }
                return true
            }
            else -> return false
        }
    }

    companion object {
        private const val REQUEST_PICK = 50_021
        private const val REQUEST_VPN = 50_022
    }
}
