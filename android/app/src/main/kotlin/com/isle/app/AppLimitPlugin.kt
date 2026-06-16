package com.isle.app

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.concurrent.TimeUnit

class AppLimitPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.isle.app/app_limits")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(true)
            "requestAuthorization" -> {
                if (hasUsageAccess()) {
                    result.success(true)
                } else {
                    openUsageAccessSettings()
                    result.success(false)
                }
            }
            "hasUsageAccess" -> result.success(hasUsageAccess())
            "openUsageAccessSettings" -> {
                openUsageAccessSettings()
                result.success(null)
            }
            "registerLimit" -> {
                val id = call.argument<String>("id") ?: ""
                val minutes = call.argument<Int>("minutes") ?: 0
                val windowMinutes = call.argument<Int>("windowMinutes") ?: 1440
                val pkg = call.argument<String>("androidPackage") ?: ""
                val label = call.argument<String>("label") ?: id
                val title = call.argument<String>("interventionTitle") ?: ""
                val body = call.argument<String>("interventionBody") ?: ""
                if (id.isEmpty() || minutes <= 0 || pkg.isEmpty()) {
                    result.success(false)
                    return
                }
                saveLimit(id, minutes, windowMinutes, pkg, label, title, body)
                AppLimitMonitorService.start(appContext)
                result.success(true)
            }
            "unregisterLimit" -> {
                val id = call.argument<String>("id") ?: ""
                removeLimit(id)
                AppLimitMonitorService.start(appContext)
                result.success(null)
            }
            "usageMinutesToday" -> {
                val pkg = call.argument<String>("androidPackage") ?: ""
                result.success(usageMinutesToday(pkg))
            }
            else -> result.notImplemented()
        }
    }

    private fun prefs() =
        appContext.getSharedPreferences("isle_app_limits", Context.MODE_PRIVATE)

    private fun saveLimit(
        id: String,
        minutes: Int,
        windowMinutes: Int,
        pkg: String,
        label: String,
        title: String,
        body: String,
    ) {
        val arr = loadLimitsJson()
        val filtered = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.optString("id") != id) filtered.put(o)
        }
        filtered.put(
            JSONObject().apply {
                put("id", id)
                put("minutes", minutes)
                put("windowMinutes", windowMinutes)
                put("androidPackage", pkg)
                put("label", label)
                put("interventionTitle", title)
                put("interventionBody", body)
                put("enabled", true)
            },
        )
        prefs().edit().putString("limits", filtered.toString()).apply()
    }

    private fun removeLimit(id: String) {
        val arr = loadLimitsJson()
        val filtered = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.optString("id") != id) filtered.put(o)
        }
        prefs().edit().putString("limits", filtered.toString()).apply()
    }

    private fun loadLimitsJson(): JSONArray {
        val raw = prefs().getString("limits", "[]") ?: "[]"
        return try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = appContext.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    appContext.packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    appContext.packageName,
                )
            }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        appContext.startActivity(intent)
    }

    private fun usageMinutesToday(packageName: String): Int {
        if (packageName.isEmpty() || !hasUsageAccess()) return 0
        val usm = appContext.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, cal.timeInMillis, System.currentTimeMillis())
        val totalMs = stats?.filter { it.packageName == packageName }?.sumOf { it.totalTimeInForeground } ?: 0L
        return TimeUnit.MILLISECONDS.toMinutes(totalMs).toInt()
    }
}
