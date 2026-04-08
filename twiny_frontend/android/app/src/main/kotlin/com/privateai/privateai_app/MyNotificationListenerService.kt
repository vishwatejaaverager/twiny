package com.privateai.privateai_app

import android.app.Notification
import android.app.RemoteInput
import android.content.Intent
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap

class MyNotificationListenerService : NotificationListenerService() {

    private val TAG = "MyNotificationListener"
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // Update this IP to your local server's IP
    private val API_URL = "https://862a-2401-4900-1c0e-108f-4c5a-4d3b-de6c-2499.ngrok-free.app/api/notification/reply"

    companion object {
        private var instance: MyNotificationListenerService? = null
        private val notificationMap = ConcurrentHashMap<String, StatusBarNotification>()
        // Set to track which notifications we've already replied to in this session
        private val repliedNotificationKeys = java.util.Collections.newSetFromMap(ConcurrentHashMap<String, Boolean>())

        fun sendReply(notificationKey: String, message: String): Boolean {
            val sbn = notificationMap.get(notificationKey) ?: return false
            return instance?.replyToNotification(sbn, message) ?: false
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        if (instance == this) instance = null
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val pkg = sbn.packageName ?: return
        // Filter for Teams and WhatsApp
        if (pkg != "com.microsoft.teams" && pkg != "com.whatsapp") return

        val extras = sbn.notification.extras
        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val ts = sbn.postTime
        val key = sbn.key ?: return

        notificationMap.put(key, sbn)

        Log.d(TAG, "Incoming Notification ($pkg): $title - $text (Key: $key)")

        // 1. Store notification
        saveNotification(key, pkg, title, text, ts)

        // 2. Notify Flutter via Method Channel
        val notificationData = mapOf(
            "key" to key,
            "package" to pkg,
            "title" to title,
            "text" to text,
            "timestamp" to ts
        )
        MainActivity.notifyFlutter("onNotificationReceived", notificationData)

        // 3. Direct API fallback for immediate reply
        serviceScope.launch {
            try {
                val reply = fetchAiReply(title, text)
                if (reply != null && reply.isNotEmpty()) {
                    Log.d(TAG, "AI thinking... sending reply: $reply")
                    replyToNotification(sbn, reply)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Direct API call failed", e)
            }
        }
    }

    private suspend fun fetchAiReply(chatName: String, message: String): String? = withContext(Dispatchers.IO) {
        try {
            val url = URL(API_URL)
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.doOutput = true

            val jsonBody = JSONObject().apply {
                put("chat_name", chatName)
                put("message", message)
            }

            OutputStreamWriter(conn.outputStream).use { it.write(jsonBody.toString()) }

            if (conn.responseCode == 200) {
                val response = conn.inputStream.bufferedReader().use { it.readText() }
                val jsonObj = JSONObject(response)
                jsonObj.optString("reply")
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        val k = sbn?.key
        if (k != null) {
            notificationMap.remove(k)
        }
    }

    fun replyToNotification(sbn: StatusBarNotification, message: String): Boolean {
        val actions = sbn.notification.actions ?: return false
        
        for (action in actions) {
            val remoteInputs = action.remoteInputs ?: continue
            for (remoteInput in remoteInputs) {
                try {
                    val resultBundle = Bundle()
                    resultBundle.putCharSequence(remoteInput.resultKey, message)
                    
                    val intent = Intent()
                    RemoteInput.addResultsToIntent(arrayOf(remoteInput), intent, resultBundle)
                    
                    action.actionIntent.send(applicationContext, 0, intent)
                    Log.d(TAG, "Reply sent successfully for ${sbn.key}")
                    return true
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to send reply: ${e.message}")
                }
            }
        }
        return false
    }

    private fun saveNotification(key: String, pkg: String, title: String, text: String, ts: Long) {
        try {
            val dir = File(filesDir, "memory")
            if (!dir.exists()) dir.mkdirs()

            val file = File(dir, "notifications.json")
            val root = if (file.exists()) {
                try { JSONObject(file.readText()) } catch (e: Exception) { JSONObject() }
            } else {
                JSONObject()
            }

            if (!root.has("notifications")) {
                root.put("notifications", JSONArray())
            }

            val notifications = root.getJSONArray("notifications")
            
            for (i in 0 until notifications.length()) {
                val item = notifications.getJSONObject(i)
                if (item.optString("key") == key) {
                    return // Already saved
                }
            }

            val notificationObj = JSONObject().apply {
                put("key", key)
                put("package", pkg)
                put("title", title)
                put("text", text)
                put("timestamp", ts)
            }

            notifications.put(notificationObj)
            file.writeText(root.toString(2))
        } catch (e: Exception) {
            Log.e(TAG, "Error saving notification: ${e.message}")
        }
    }
}
