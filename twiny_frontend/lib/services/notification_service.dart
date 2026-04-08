import 'package:flutter/services.dart';
import 'remote/api_service.dart';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/dashboard/dashboard_providers.dart';

class NotificationService {
  static const _channel = MethodChannel('twiny/messages');
  final ApiService _apiService = ApiService();
  final ProviderContainer _container;

  NotificationService(this._container);

  void init() {
    _channel.setMethodCallHandler(_handleMethodCall);
    developer.log('NotificationService initialized', name: 'NotificationService');
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationReceived':
        final Map<dynamic, dynamic> data = call.arguments;
        final String key = data['key'];
        final String title = data['title'];
        final String text = data['text'];
        
        developer.log('Notification received: $title - $text', name: 'NotificationService');
        
        await _processAutoReply(key, title, text);
        break;
      default:
        developer.log('Unknown method called from Android: ${call.method}', name: 'NotificationService');
    }
  }

  Future<void> _processAutoReply(String key, String chatName, String message) async {
    try {
      if (chatName.isEmpty || message.isEmpty) return;

      final isAutoEnabled = _container.read(autoReplySettingsProvider.notifier).isEnabled(chatName);
      if (!isAutoEnabled) {
        developer.log('DEBUG: Auto-reply disabled for [$chatName] (Current settings: ${_container.read(autoReplySettingsProvider)})', name: 'NotificationService');
        return;
      }

      developer.log('DEBUG: Auto-reply ENABLED for [$chatName]. Checking history...', name: 'NotificationService');

      // ── Layer 2: History Validation ─────────────────────
      final appMsgsMap = _container.read(appMessagesProvider);
      final allMessages = [...appMsgsMap['whatsapp'] ?? [], ...appMsgsMap['teams'] ?? []];

      // Improved fuzzy matching: contains and ignore case
      final hasHistory = allMessages.any((m) {
        final histName = (m['chat_name'] as String).toLowerCase();
        final searchName = chatName.toLowerCase();
        return histName.contains(searchName) || searchName.contains(histName);
      });

      if (!hasHistory) {
        developer.log(
            'DEBUG: No chat history found for [$chatName]. History contains: ${allMessages.map((m) => m['chat_name']).toSet()}. Skipping to prevent hallucination.',
            name: 'NotificationService');
        return;
      }

      // ── Layer 3: Noise Filtering ────────────────────────
      final lowerMsg = message.toLowerCase();
      if (lowerMsg.contains("reacted to") ||
          lowerMsg.contains("typing...") ||
          message.length < 2) {
        developer.log('Interpreted notification as noise: "$message". Skipping.',
            name: 'NotificationService');
        return;
      }

      developer.log('Requesting AI response for: $chatName', name: 'NotificationService');
      final response = await _apiService.getNotificationReply(chatName, message);

      if (response.statusCode == 200) {
        final replyData = json.decode(response.body);
        final String replyText = replyData['reply'] ?? '';

        if (replyText.isNotEmpty) {
          developer.log('DEBUG: SUCCESS -> Sending Automated Reply: "$replyText" to [$chatName] (Key: $key)', name: 'NotificationService');
          await _channel.invokeMethod('sendNotificationReply', {
            'key': key,
            'message': replyText,
          });
        } else {
          developer.log('DEBUG: API returned empty reply for [$chatName]. Skipping.', name: 'NotificationService');
        }
      } else {
        developer.log('API Error: ${response.statusCode}', name: 'NotificationService');
      }
    } catch (e) {
      developer.log('Auto-reply failed: $e', name: 'NotificationService');
    }
  }
}
