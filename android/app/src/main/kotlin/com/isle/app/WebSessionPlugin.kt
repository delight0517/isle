package com.isle.app

import android.net.Uri
import android.webkit.CookieManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** YouTube·Instagram WebView 쿠키 — 재빌드 후 Keychain 미러 복원용 */
class WebSessionPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.isle.app/web_session")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "exportCookies" -> result.success(exportCookies())
            "importCookies" -> {
                @Suppress("UNCHECKED_CAST")
                val list = call.arguments as? List<Map<String, Any>> ?: emptyList()
                importCookies(list)
                result.success(true)
            }
            "syncSafariCookiesToWebView" -> result.success(syncSafariCookiesToWebView())
            "clearDomainCookies" -> {
                val hint = call.arguments as? String ?: ""
                clearDomainCookies(hint)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun exportCookies(): List<Map<String, Any>> {
        val cm = CookieManager.getInstance()
        val seeds = listOf(
            "https://www.youtube.com",
            "https://m.youtube.com",
            "https://accounts.google.com",
            "https://www.google.com",
            "https://www.instagram.com",
            "https://www.facebook.com",
        )
        val out = mutableListOf<Map<String, Any>>()
        val seen = mutableSetOf<String>()
        for (url in seeds) {
            val raw = cm.getCookie(url) ?: continue
            val host = Uri.parse(url).host ?: continue
            for (part in raw.split(";")) {
                val trimmed = part.trim()
                val eq = trimmed.indexOf('=')
                if (eq <= 0) continue
                val name = trimmed.substring(0, eq)
                val value = trimmed.substring(eq + 1)
                val key = "$name|$host"
                if (!seen.add(key)) continue
                out.add(
                    mapOf(
                        "name" to name,
                        "value" to value,
                        "domain" to host,
                        "path" to "/",
                    ),
                )
            }
        }
        cm.flush()
        return out
    }

    private fun syncSafariCookiesToWebView(): Int {
        val cm = CookieManager.getInstance()
        val seeds = listOf(
            "https://www.youtube.com",
            "https://m.youtube.com",
            "https://accounts.google.com",
            "https://www.instagram.com",
        )
        var count = 0
        for (url in seeds) {
            val raw = cm.getCookie(url) ?: continue
            if (raw.isNotBlank()) count += raw.split(";").count { it.contains("=") }
        }
        cm.flush()
        return count
    }

    private fun importCookies(list: List<Map<String, Any>>) {
        val cm = CookieManager.getInstance()
        for (item in list) {
            val name = item["name"] as? String ?: continue
            val value = item["value"] as? String ?: continue
            var domain = item["domain"] as? String ?: continue
            if (domain.startsWith(".")) domain = domain.substring(1)
            val path = item["path"] as? String ?: "/"
            val cookieStr = "$name=$value; domain=$domain; path=$path"
            cm.setCookie("https://$domain", cookieStr)
        }
        cm.flush()
    }

    private fun clearDomainCookies(hint: String) {
        val cm = CookieManager.getInstance()
        val needle = hint.lowercase()
        val hosts = listOf(
            "https://www.instagram.com",
            "https://instagram.com",
            "https://m.instagram.com",
        )
        for (url in hosts) {
            val host = Uri.parse(url).host ?: continue
            if (!host.contains(needle) && needle.isNotEmpty() && !needle.contains("instagram")) continue
            val raw = cm.getCookie(url) ?: continue
            for (part in raw.split(";")) {
                val trimmed = part.trim()
                val eq = trimmed.indexOf('=')
                if (eq <= 0) continue
                val name = trimmed.substring(0, eq)
                cm.setCookie(url, "$name=; Max-Age=0; path=/; domain=$host")
            }
        }
        cm.flush()
    }
}
