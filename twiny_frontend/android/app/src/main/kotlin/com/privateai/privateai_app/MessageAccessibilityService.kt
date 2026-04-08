package com.privateai.privateai_app

import android.accessibilityservice.AccessibilityService
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.accessibilityservice.AccessibilityButtonController
import android.accessibilityservice.AccessibilityButtonController.AccessibilityButtonCallback
import org.json.JSONArray
import org.json.JSONObject
import android.widget.Toast
import java.io.File
import java.security.MessageDigest

class MessageAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "MsgAccessibility"

        private val TARGET_PACKAGES = setOf(
            "com.whatsapp",
            "com.microsoft.teams"
        )

        // Per-app file names
        private val APP_FILE_NAMES = mapOf(
            "com.whatsapp"   to "whatsapp.json",
            "com.microsoft.teams" to "teams.json"
        )

        var isResearchModeEnabled = false
            private set

        fun setResearchMode(enabled: Boolean) {
            isResearchModeEnabled = enabled
        }

        private var instance: MessageAccessibilityService? = null
        fun getInstance(): MessageAccessibilityService? = instance

        fun clearCache() {
            instance?.processedMessages?.clear()
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val processedMessages = mutableSetOf<String>()
    private var buttonCallback: AccessibilityButtonCallback? = null

    // ─── Confidence weights ───────────────────────────────
    private data class ChatSignals(
        val hasInputField: Boolean,        // REQUIRED, HIGH
        val inputHintMatches: Boolean,     // HIGH
        val hasSendButton: Boolean,        // HIGH
        val hasMessageList: Boolean,       // MEDIUM
        val hasConversationTitle: Boolean, // MEDIUM
        val hasStatusText: Boolean,        // MEDIUM
        val hasCallIcons: Boolean,         // MEDIUM
        val layoutPattern: Boolean         // IMPORTANT
    ) {
        fun confidenceScore(): Int {
            var score = 0
            if (hasInputField)        score += 30   // REQUIRED signal
            if (inputHintMatches)     score += 20
            if (hasSendButton)        score += 20
            if (hasMessageList)       score += 10
            if (hasConversationTitle) score += 10
            if (hasStatusText)        score += 5
            if (hasCallIcons)         score += 5
            if (layoutPattern)        score += 10
            return score  // max = 110 (over-complete satisfies all)
        }

        // Must have input field AND score >= 70
        fun isChatScreen() = hasInputField && confidenceScore() >= 70
    }

    // ─── Lifecycle ────────────────────────────────────────

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "Service Connected")
        loadProcessedMessages()

        // Setup Accessibility Button Shortcut
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val controller = accessibilityButtonController
            buttonCallback = object : AccessibilityButtonCallback() {
                override fun onClicked(controller: AccessibilityButtonController?) {
                    val newState = !isResearchModeEnabled
                    setResearchMode(newState)
                    val msg = if (newState) "Capturing Started" else "Capturing Stopped"
                    Toast.makeText(this@MessageAccessibilityService, msg, Toast.LENGTH_SHORT).show()
                    Log.d(TAG, "Accessibility button shortcut clicked: $msg")
                }
            }
            buttonCallback?.let { controller.registerAccessibilityButtonCallback(it) }
        }
    }

    override fun onInterrupt() { Log.d(TAG, "Service Interrupted") }

    override fun onDestroy() {
        super.onDestroy()
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            buttonCallback?.let { accessibilityButtonController.unregisterAccessibilityButtonCallback(it) }
        }
        instance = null
    }

    // ─── Main event handler ───────────────────────────────

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!isResearchModeEnabled || event == null) return

        val packageName = event.packageName?.toString() ?: return
        if (!TARGET_PACKAGES.contains(packageName)) return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED,
            AccessibilityEvent.TYPE_VIEW_SCROLLED,
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                val root = rootInActiveWindow ?: return
                val signals = analyzeSignals(root, packageName)

                Log.d(TAG, "[$packageName] ChatScreen=${signals.isChatScreen()} " +
                        "score=${signals.confidenceScore()} " +
                        "input=${signals.hasInputField} send=${signals.hasSendButton} " +
                        "list=${signals.hasMessageList} title=${signals.hasConversationTitle}")

                if (signals.isChatScreen()) {
                    extractMessages(root, packageName)
                }
                root.recycle()
            }
        }
    }

    // ─── Signal Analysis ─────────────────────────────────

    private fun analyzeSignals(root: AccessibilityNodeInfo, pkg: String): ChatSignals {
        var hasInputField        = false
        var inputHintMatches     = false
        var hasSendButton        = false
        var hasMessageList       = false
        var hasConversationTitle = false
        var hasStatusText        = false
        var hasCallIcons         = false
        var hasTopBar            = false
        var hasBottomInput       = false

        val inputKeywords  = setOf("message", "type", "chat", "write", "reply", "text a message", "aa message")
        val sendKeywords   = setOf("send", "reply", "voice", "mic", "record", "send message", "voice message")
        val statusKeywords = setOf("online", "active", "last seen", "typing", "available")
        val callKeywords   = setOf("audio call", "voice call", "video call", "call", "video")

        val screenHeight = resources.displayMetrics.heightPixels
        val topZone      = screenHeight * 0.20f
        val bottomZone   = screenHeight * 0.80f

        fun traverse(node: AccessibilityNodeInfo?) {
            if (node == null) return
            val cls   = node.className?.toString() ?: ""
            val text  = (node.text?.toString() ?: "").trim()
            val hint  = (node.hintText?.toString() ?: "").trim()
            val desc  = (node.contentDescription?.toString() ?: "").trim()
            val bounds = Rect().also { node.getBoundsInScreen(it) }

            // ── Signal 1: Input field ──────────────────────
            if (cls.contains("EditText") && node.isEditable) {
                hasInputField = true
                val combined = (text + hint + desc).lowercase()
                if (inputKeywords.any { combined.contains(it) } || hint.isNotEmpty()) {
                    inputHintMatches = true
                }
                if (bounds.top > bottomZone) hasBottomInput = true
            }

            // ── Signal 2: Send / Action button ────────────
            if (!hasSendButton && node.isClickable) {
                val combined = (text + desc).lowercase()
                if (sendKeywords.any { combined.contains(it) }) {
                    hasSendButton = true
                }
            }

            // ── Signal 3: Message list ─────────────────────
            if (cls.contains("RecyclerView") || cls.contains("ListView")) {
                if (node.childCount >= 3) {
                    hasMessageList = true
                }
            }

            // ── Signal 4a: Conversation title (top bar) ────
            if (!hasConversationTitle && bounds.top < topZone) {
                val isToolbarArea = cls.contains("Toolbar") || cls.contains("AppBar") ||
                        cls.contains("ActionBar")
                if (isToolbarArea && (text.length in 2..50 || desc.length in 2..50)) {
                    hasConversationTitle = true
                    hasTopBar = true
                }
                // Per-app known title IDs
                val titleIds = listOf(
                    "${pkg}:id/conversation_contact_name",
                    "${pkg}:id/action_bar_textview_title",
                    "${pkg}:id/toolbar_title",
                    "${pkg}:id/thread_name"
                )
                if (titleIds.any { desc.isNotEmpty() || text.isNotEmpty() } && bounds.top < topZone) {
                    hasConversationTitle = true
                }
            }

            // ── Signal 4b: Status text ─────────────────────
            if (!hasStatusText) {
                val combined = (text + desc).lowercase()
                if (statusKeywords.any { combined.contains(it) }) hasStatusText = true
            }

            // ── Signal 4c: Call icons ──────────────────────
            if (!hasCallIcons && node.isClickable) {
                val combined = (text + desc).lowercase()
                if (callKeywords.any { combined.contains(it) }) hasCallIcons = true
            }

            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                traverse(child)
                child.recycle()
            }
        }

        traverse(root)

        // ── Signal 5: Layout pattern ───────────────────────
        val layoutPattern = hasTopBar && hasMessageList && hasBottomInput

        return ChatSignals(
            hasInputField        = hasInputField,
            inputHintMatches     = inputHintMatches,
            hasSendButton        = hasSendButton,
            hasMessageList       = hasMessageList,
            hasConversationTitle = hasConversationTitle,
            hasStatusText        = hasStatusText,
            hasCallIcons         = hasCallIcons,
            layoutPattern        = layoutPattern
        )
    }

    // ─── Message Extraction ───────────────────────────────

    private fun extractMessages(root: AccessibilityNodeInfo, pkg: String) {
        val chatTitle = findChatTitle(root, pkg) ?: return  // skip if no title found
        val screenWidth = resources.displayMetrics.widthPixels

        val timeRegex  = Regex("""^\d{1,2}:\d{2}\s*(?:am|pm|AM|PM)?$""")
        val teamsTimeRegex = Regex("""^(?:Today|Yesterday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s+\d{1,2}:\d{2}\s*(?:am|pm|AM|PM)$""", RegexOption.IGNORE_CASE)
        val mediaRegex = Regex("""^\d+\s+(?:photo|video|voice|message|audio)s?$""", RegexOption.IGNORE_CASE)
        val dateRegex  = Regex("""^\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}$""")

        val uiNoise = setOf(
            "whatsapp", "instagram", "messenger", "teams",
            "chats", "updates", "communities", "calls", "status",
            "add status", "channels", "new community", "announcements",
            "view all", "today", "yesterday", "you", "type a message"
        )

        val messageNodes = mutableListOf<AccessibilityNodeInfo>()
        collectMessageNodes(root, messageNodes, uiNoise, timeRegex, teamsTimeRegex, mediaRegex, dateRegex, chatTitle)

        val newBatch = mutableListOf<JSONObject>()

        for (node in messageNodes) {
            val text = node.text?.toString()?.trim() ?: continue
            if (text.length < 2) continue

            val bounds = Rect()
            node.getBoundsInScreen(bounds)
            val screenWidth = resources.displayMetrics.widthPixels
            
            // As requested by user: If text starts from the left side, it is opposite person.
            val sender = if (bounds.left < screenWidth / 3) "other" else "me"
            
            // Detailed debug log for refinement
            Log.d(TAG, "Message: '$text' | L:${bounds.left} W:${screenWidth} -> $sender")

            val ts = System.currentTimeMillis()
            val msgId = hashMessage(chatTitle, text, ts / 60000L)  // 1-min bucket

            if (!processedMessages.contains(msgId)) {
                val msgObj = JSONObject().apply {
                    put("chat_name",   chatTitle)
                    put("sender",      sender)
                    put("text",        text)
                    put("timestamp",   ts / 1000L)
                    put("device_time", ts)
                }

                val contactMatch = matchContact(chatTitle)
                if (contactMatch != null) {
                    msgObj.put("contact_match", true)
                    msgObj.put("contact_name",  contactMatch)
                }

                newBatch.add(msgObj)
                processedMessages.add(msgId)
                Log.d(TAG, "[$pkg] [$chatTitle] $sender: $text")
            }
            node.recycle()
        }

        if (newBatch.isNotEmpty()) {
            saveMessagesBatch(pkg, chatTitle, newBatch)
        }
    }

    private fun collectMessageNodes(
        node: AccessibilityNodeInfo?,
        result: MutableList<AccessibilityNodeInfo>,
        uiNoise: Set<String>,
        timeRegex: Regex,
        teamsTimeRegex: Regex,
        mediaRegex: Regex,
        dateRegex: Regex,
        chatTitle: String
    ) {
        if (node == null) return
        val cls  = node.className?.toString() ?: ""
        val text = node.text?.toString()?.trim() ?: ""

        if (text.isNotBlank()) {
            val boundLog = android.graphics.Rect().also { node.getBoundsInScreen(it) }
            Log.d(TAG, "RAW-NODE -> cls: $cls | bnd: $boundLog | text: '$text'")
        }

        // Skip structural containers that are clearly not messages
        if (cls.contains("Toolbar") || cls.contains("AppBar") || cls.contains("ActionBar")) return
        if (cls.contains("EditText")) return

        if (cls.contains("TextView") && text.isNotBlank()) {
            val lower = text.lowercase()
            when {
                uiNoise.contains(lower)        -> { /* skip */ }
                timeRegex.matches(text)         -> { /* skip timestamps */ }
                teamsTimeRegex.matches(text)    -> { /* skip teams timestamps */ }
                mediaRegex.matches(text)        -> { /* skip "2 photos" etc */ }
                dateRegex.matches(text)         -> { /* skip date headers */ }
                text.matches(Regex("""^\+?\d[\d\s\-]{6,}$""")) -> { /* skip phone numbers */ }
                lower.startsWith("last seen")   -> { /* skip last seen */ }
                lower.startsWith("online")      -> { /* skip online status */ }
                lower.startsWith("typing")      -> { /* skip typing status */ }
                lower.startsWith("not a contact") -> { /* skip security warning */ }
                text.startsWith("~")            -> { /* skip sender aliases */ }
                text.equals(chatTitle, ignoreCase = true) -> { /* skip chat title repeated as message */ }
                text.matches(Regex("""^\d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{2,4}$""", RegexOption.IGNORE_CASE)) -> { /* skip word date headers */ }
                text.matches(Regex("""^(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)$""", RegexOption.IGNORE_CASE)) -> { /* skip day strings */ }
                else -> result.add(AccessibilityNodeInfo.obtain(node))
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectMessageNodes(child, result, uiNoise, timeRegex, teamsTimeRegex, mediaRegex, dateRegex, chatTitle)
            child.recycle()
        }
    }

    // ─── Chat Title Detection ─────────────────────────────

    private fun findChatTitle(root: AccessibilityNodeInfo, pkg: String): String? {
        // Try known view IDs per app
        val candidateIds = when (pkg) {
            "com.whatsapp" -> listOf(
                "com.whatsapp:id/conversation_contact_name"
            )
            else -> emptyList()
        }

        for (id in candidateIds) {
            val found = root.findAccessibilityNodeInfosByViewId(id)?.firstOrNull()
            val title = found?.text?.toString()?.trim()
            found?.recycle()
            if (!title.isNullOrBlank()) return title
        }

        // Fallback: first non-empty text in top toolbar
        val screenHeight = resources.displayMetrics.heightPixels
        val topZone = screenHeight * 0.18f
        var fallback: String? = null

        fun scanTop(node: AccessibilityNodeInfo?) {
            if (node == null || fallback != null) return
            val cls  = node.className?.toString() ?: ""
            val text = node.text?.toString()?.trim() ?: ""
            val bounds = Rect().also { node.getBoundsInScreen(it) }

            if (bounds.top < topZone && cls.contains("TextView") && text.length in 2..60) {
                fallback = text
                return
            }
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                scanTop(child)
                child.recycle()
            }
        }
        scanTop(root)
        return fallback
    }

    // ─── Storage ──────────────────────────────────────────

    private fun getStorageDir(): File {
        val dir = File(filesDir, "memory")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun saveMessagesBatch(pkg: String, chatTitle: String, newMessages: List<JSONObject>) {
        try {
            val fileName = APP_FILE_NAMES[pkg] ?: "${pkg.substringAfterLast('.')}.json"
            val file = File(getStorageDir(), fileName)

            val root = if (file.exists()) {
                JSONObject(file.readText())
            } else {
                JSONObject().put("app", pkg).put("messages", JSONArray())
            }

            val array = root.getJSONArray("messages")
            val newArray = JSONArray()

            // Prepend new batch (since user scrolls from bottom to top, these new messages are older)
            for (msg in newMessages) {
                newArray.put(msg)
            }
            
            // Append existing messages after
            for (i in 0 until array.length()) {
                newArray.put(array.getJSONObject(i))
            }

            root.put("messages", newArray)
            file.writeText(root.toString(2))
            Log.d(TAG, "Saved batch of ${newMessages.size} to $fileName")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving batch messages", e)
        }
    }

    private fun saveMessage(pkg: String, message: JSONObject) {
        try {
            val fileName = APP_FILE_NAMES[pkg] ?: "${pkg.substringAfterLast('.')}.json"
            val file = File(getStorageDir(), fileName)

            val root = if (file.exists()) {
                JSONObject(file.readText())
            } else {
                JSONObject().put("app", pkg).put("messages", JSONArray())
            }

            root.getJSONArray("messages").put(message)
            file.writeText(root.toString(2))
            Log.d(TAG, "Saved to $fileName")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving message", e)
        }
    }

    // ─── Contacts ─────────────────────────────────────────

    private fun matchContact(chatTitle: String?): String? {
        if (chatTitle == null) return null
        val contacts = getContacts()
        for ((name, _) in contacts) {
            if (name.contains(chatTitle, ignoreCase = true) ||
                chatTitle.contains(name, ignoreCase = true)) return name
        }
        return null
    }

    private fun getContacts(): Map<String, String> {
        val map = mutableMapOf<String, String>()
        if (androidx.core.content.ContextCompat.checkSelfPermission(
                this, android.Manifest.permission.READ_CONTACTS
            ) != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) return map

        val uri = android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI
        val proj = arrayOf(
            android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER
        )
        contentResolver.query(uri, proj, null, null, null)?.use { cursor ->
            val ni = cursor.getColumnIndex(android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val pi = cursor.getColumnIndex(android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER)
            while (cursor.moveToNext()) map[cursor.getString(ni)] = cursor.getString(pi)
        }
        return map
    }

    // ─── Helpers ──────────────────────────────────────────

    private fun hashMessage(chat: String, text: String, timeGroup: Long): String {
        val input = "$chat|$text|$timeGroup"
        return MessageDigest.getInstance("MD5")
            .digest(input.toByteArray())
            .joinToString("") { "%02x".format(it) }
    }

    private fun loadProcessedMessages() {
        try {
            APP_FILE_NAMES.values.forEach { fileName ->
                val file = File(getStorageDir(), fileName)
                if (!file.exists()) return@forEach
                val root  = JSONObject(file.readText())
                val array = root.optJSONArray("messages") ?: return@forEach
                for (i in 0 until array.length()) {
                    val m    = array.getJSONObject(i)
                    val chat = m.optString("chat_name", "Unknown")
                    val text = m.optString("text", "")
                    val time = m.optLong("timestamp", 0L)
                    processedMessages.add(hashMessage(chat, text, time / 60L))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading processed messages", e)
        }
    }
}
