package com.isle.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import java.util.Calendar
import java.util.concurrent.TimeUnit

/// Usage Stats로 일일 한도 초과 시 알림 + 개입 화면
class AppLimitMonitorService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val tick = object : Runnable {
        override fun run() {
            try {
                checkLimits()
            } catch (_: Exception) {
            }
            handler.postDelayed(this, 60_000L)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureChannel()
        val notification =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Isle · 앱 시간 한도")
                .setContentText("백그라운드에서 사용 시간을 확인합니다")
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setOngoing(true)
                .build()
        startForeground(NOTIFICATION_ID, notification)
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        super.onDestroy()
    }

    private fun checkLimits() {
        val prefs = getSharedPreferences("isle_app_limits", Context.MODE_PRIVATE)
        val raw = prefs.getString("limits", "[]") ?: "[]"
        val arr = try {
            JSONArray(raw)
        } catch (_: Exception) {
            return
        }
        if (arr.length() == 0) return

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return
        val now = System.currentTimeMillis()
        val foreground = queryForegroundPackage(usm, now - TimeUnit.DAYS.toMillis(1), now)

        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (!o.optBoolean("enabled", true)) continue
            val id = o.optString("id")
            val pkg = o.optString("androidPackage")
            val limitMin = o.optInt("minutes", 0)
            val windowMinutes = o.optInt("windowMinutes", 1440)
            if (pkg.isEmpty() || limitMin <= 0) continue
            val windowStart = windowStartMs(windowMinutes, now)
            val used = usageMinutesForPackage(usm, pkg, windowStart, now)
            val exceededKey = "exceeded_$id"
            val windowKey = "window_$id"
            val currentWindowTag = windowTag(windowMinutes)

            if (prefs.getString(windowKey, "") != currentWindowTag) {
                prefs.edit().putString(windowKey, currentWindowTag).putBoolean(exceededKey, false).apply()
            }

            if (used >= limitMin) {
                if (!prefs.getBoolean(exceededKey, false)) {
                    prefs.edit().putBoolean(exceededKey, true).apply()
                    notifyLimitReached(o.optString("label", id), o.optString("interventionTitle"), id)
                }
                if (foreground == pkg) {
                    launchIntervention(
                        id,
                        o.optString("label", id),
                        o.optString("interventionTitle"),
                        o.optString("interventionBody"),
                        used,
                        limitMin,
                    )
                }
            }
        }
    }

    private fun queryForegroundPackage(usm: UsageStatsManager, start: Long, end: Long): String? {
        val events = usm.queryEvents(start, end) ?: return null
        val event = UsageEvents.Event()
        var lastPkg: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND
            ) {
                lastPkg = event.packageName
            }
        }
        return lastPkg
    }

    private fun usageMinutesForPackage(
        usm: UsageStatsManager,
        packageName: String,
        start: Long,
        end: Long,
    ): Int {
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
        val ms = stats?.filter { it.packageName == packageName }?.sumOf { it.totalTimeInForeground } ?: 0L
        return TimeUnit.MILLISECONDS.toMinutes(ms).toInt()
    }

    private fun windowStartMs(windowMinutes: Int, now: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = now }
        return if (windowMinutes == 60) {
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            cal.timeInMillis
        } else {
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            cal.timeInMillis
        }
    }

    private fun windowTag(windowMinutes: Int): String {
        val cal = Calendar.getInstance()
        return if (windowMinutes == 60) {
            val y = cal.get(Calendar.YEAR)
            val d = cal.get(Calendar.DAY_OF_YEAR)
            val h = cal.get(Calendar.HOUR_OF_DAY)
            "$y-$d-$h"
        } else {
            val y = cal.get(Calendar.YEAR)
            val d = cal.get(Calendar.DAY_OF_YEAR)
            "$y-$d"
        }
    }

    private fun notifyLimitReached(label: String, title: String, ruleId: String) {
        val intent = Intent(this, AppLimitInterventionActivity::class.java).apply {
            putExtra("ruleId", ruleId)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val pi = PendingIntent.getActivity(
            this,
            ruleId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(
            ruleId.hashCode(),
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(title.ifEmpty { "$label 한도 도달" })
                .setContentText("탭해서 개입 화면 보기")
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setContentIntent(pi)
                .setAutoCancel(true)
                .build(),
        )
    }

    private fun launchIntervention(
        ruleId: String,
        label: String,
        title: String,
        body: String,
        used: Int,
        limit: Int,
    ) {
        val intent =
            Intent(this, AppLimitInterventionActivity::class.java).apply {
                putExtra("ruleId", ruleId)
                putExtra("label", label)
                putExtra("title", title.ifEmpty { "$label · 오늘 ${used}분 / ${limit}분" })
                putExtra("body", body)
                putExtra("usedMinutes", used)
                putExtra("limitMinutes", limit)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
        startActivity(intent)
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Isle 앱 한도",
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
    }

    companion object {
        private const val CHANNEL_ID = "isle_app_limits"
        private const val NOTIFICATION_ID = 41001

        fun start(context: Context) {
            val intent = Intent(context, AppLimitMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
