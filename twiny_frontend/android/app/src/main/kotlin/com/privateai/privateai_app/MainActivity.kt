package com.privateai.privateai_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import android.content.ComponentName
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import android.text.TextUtils

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "twiny/messages"
        private var channel: MethodChannel? = null

        fun notifyFlutter(method: String, arguments: Any?) {
            channel?.invokeMethod(method, arguments)
        }
    }

    // Maps app tab key -> filename in memory/
    private val APP_FILES = mapOf(
        "whatsapp"     to "whatsapp.json",
        "teams"        to "teams.json"
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        channel = MethodChannel(messenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
                when (call.method) {

                    // Returns messages for a specific app tab
                    // arg: { "app": "whatsapp" | "instagram" | "teams" }
                    "getMessagesForApp" -> {
                        val app = call.argument<String>("app") ?: "whatsapp"
                        result.success(readMessagesForApp(app))
                    }

                    // Returns counts for all apps: { whatsapp: N, instagram: N, teams: N }
                    "getAppCounts" -> {
                        result.success(getAppCounts())
                    }

                    // Legacy single-file read (kept for backward compat)
                    "getMessages" -> {
                        result.success(readLegacyMessages())
                    }

                    "enableResearchMode" -> {
                        MessageAccessibilityService.setResearchMode(true)
                        result.success(true)
                    }
                    "disableResearchMode" -> {
                        MessageAccessibilityService.setResearchMode(false)
                        result.success(true)
                    }
                    "getInternalFilePath" -> {
                        val app = call.argument<String>("app") ?: "whatsapp"
                        val fileName = APP_FILES[app]
                        if (fileName != null) {
                            val file = File(filesDir, "memory/$fileName")
                            result.success(file.absolutePath)
                        } else {
                            result.error("ERR", "Unknown app", null)
                        }
                    }
                    "exportMessages" -> {
                        val app = call.argument<String>("app")
                        result.success(exportMessages(app))
                    }
                    "isResearchModeEnabled" -> {
                        result.success(MessageAccessibilityService.isResearchModeEnabled)
                    }
                    "isAccessibilityEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }
                    "openAccessibilitySettings" -> {
                        openAccessibilitySettings()
                        result.success(true)
                    }
                    "isNotificationListenerEnabled" -> {
                        result.success(isNotificationListenerEnabled())
                    }
                    "openNotificationListenerSettings" -> {
                        openNotificationListenerSettings()
                        result.success(true)
                    }
                    "getNotifications" -> {
                        result.success(readNotifications())
                    }
                    "sendNotificationReply" -> {
                        val key = call.argument<String>("key") ?: ""
                        val message = call.argument<String>("message") ?: ""
                        result.success(MyNotificationListenerService.sendReply(key, message))
                    }
                    "clearNotifications" -> {
                        result.success(clearNotifications())
                    }
                    "clearMessages" -> {
                        val app = call.argument<String>("app")
                        result.success(clearMessages(app))
                    }
                    "clearMessagesForChat" -> {
                        val app = call.argument<String>("app") ?: "whatsapp"
                        val chatName = call.argument<String>("chatName") ?: ""
                        result.success(clearMessagesForChat(app, chatName))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return enabled != null && enabled.contains(packageName)
    }

    private fun openNotificationListenerSettings() {
        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }

    private fun readNotifications(): String {
        val file = File(filesDir, "memory/notifications.json")
        return if (file.exists()) file.readText() else "{\"notifications\":[]}"
    }

    private fun clearNotifications(): Boolean {
        return try {
            File(filesDir, "memory/notifications.json").takeIf { it.exists() }?.delete()
            true
        } catch (e: Exception) { false }
    }

    // ── Per-app readers ──────────────────────────────────

    private fun readMessagesForApp(app: String): String {
        val fileName = APP_FILES[app] ?: return "{\"app\":\"$app\",\"messages\":[]}"
        val file = File(filesDir, "memory/$fileName")
        return if (file.exists()) file.readText()
        else "{\"app\":\"$app\",\"messages\":[]}"
    }

    private fun getAppCounts(): String {
        val counts = JSONObject()
        for ((app, fileName) in APP_FILES) {
            try {
                val file = File(filesDir, "memory/$fileName")
                if (file.exists()) {
                    val root = JSONObject(file.readText())
                    counts.put(app, root.optJSONArray("messages")?.length() ?: 0)
                } else {
                    counts.put(app, 0)
                }
            } catch (e: Exception) {
                counts.put(app, 0)
            }
        }
        return counts.toString()
    }

    // ── Legacy single-file read ───────────────────────────

    private fun readLegacyMessages(): String {
        val file = File(filesDir, "memory/messages.json")
        return if (file.exists()) file.readText() else "{\"messages\":[]}"
    }

    // ── Clear ─────────────────────────────────────────────

    private fun clearMessages(app: String?): Boolean {
        return try {
            if (app != null) {
                val fileName = APP_FILES[app] ?: return false
                File(filesDir, "memory/$fileName").takeIf { it.exists() }?.delete()
            } else {
                // Clear all
                APP_FILES.values.forEach {
                    File(filesDir, "memory/$it").takeIf { f -> f.exists() }?.delete()
                }
                File(filesDir, "memory/messages.json").takeIf { it.exists() }?.delete()
            }
            MessageAccessibilityService.clearCache()
            true
        } catch (e: Exception) { false }
    }

    private fun clearMessagesForChat(app: String, chatName: String): Boolean {
        if (chatName.isEmpty()) return false
        val fileName = APP_FILES[app] ?: return false
        val file = File(filesDir, "memory/$fileName")
        if (!file.exists()) return true

        return try {
            val root = JSONObject(file.readText())
            val messages = root.optJSONArray("messages") ?: return true
            val filtered = JSONArray()
            for (i in 0 until messages.length()) {
                val msg = messages.getJSONObject(i)
                if (msg.optString("chat_name") != chatName) {
                    filtered.put(msg)
                }
            }
            root.put("messages", filtered)
            file.writeText(root.toString())
            MessageAccessibilityService.clearCache()
            true
        } catch (e: Exception) { false }
    }

    // ── Export ────────────────────────────────────────────

    private fun exportMessages(app: String?): String {
        val source = if (app != null) {
            val fileName = APP_FILES[app] ?: return "Unknown app"
            File(filesDir, "memory/$fileName")
        } else {
            File(filesDir, "memory/messages.json")
        }
        if (!source.exists()) return "No messages to export"

        val label = app ?: "all"
        val fileName = "twiny_${label}_${System.currentTimeMillis()}.json"

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE, "application/json")
                    put(MediaStore.Downloads.RELATIVE_PATH, "Download/")
                }
                val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                if (uri != null) {
                    contentResolver.openOutputStream(uri)?.use { out ->
                        source.inputStream().use { it.copyTo(out) }
                    }
                    "Saved to Downloads/$fileName"
                } else "Failed to create file"
            } else {
                val dl = android.os.Environment.getExternalStoragePublicDirectory(
                    android.os.Environment.DIRECTORY_DOWNLOADS
                )
                val target = File(dl, fileName)
                source.inputStream().use { inp -> target.outputStream().use { inp.copyTo(it) } }
                "Saved to Downloads/$fileName"
            }
        } catch (e: Exception) { "Error: ${e.message}" }
    }

    // ── Accessibility helpers ─────────────────────────────

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expected = ComponentName(this, MessageAccessibilityService::class.java).flattenToString()
        val enabled = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        while (splitter.hasNext()) {
            if (splitter.next().equals(expected, ignoreCase = true)) return true
        }
        return false
    }

    private fun openAccessibilitySettings() {
        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }
}
