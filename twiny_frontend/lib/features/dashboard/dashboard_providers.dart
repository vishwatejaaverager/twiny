import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/remote/api_service.dart';
import '../onboarding/onboarding_providers.dart';

final dashboardPlatformProvider = Provider((ref) => const MethodChannel('twiny/messages'));
final apiServiceProvider = Provider((ref) => ApiService());

final researchModeProvider = StateProvider<bool>((ref) => false);
final accessibilityEnabledProvider = StateProvider<bool>((ref) => false);
final notificationAccessEnabledProvider = StateProvider<bool>((ref) => false);
final isExportingProvider = StateProvider<bool>((ref) => false);
final currentViewProvider = StateProvider<String>((ref) => 'whatsapp');

final notificationsProvider = StateProvider<List<dynamic>>((ref) => []);
final appMessagesProvider = StateProvider<Map<String, List<dynamic>>>((ref) => {
  'whatsapp': [],
  'teams': []
});
final appCountsProvider = StateProvider<Map<String, int>>((ref) => {
  'whatsapp': 0,
  'teams': 0
});

final autoReplySettingsProvider = StateNotifierProvider<AutoReplySettingsNotifier, Map<String, bool>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AutoReplySettingsNotifier(prefs);
});

class AutoReplySettingsNotifier extends StateNotifier<Map<String, bool>> {
  final SharedPreferences _prefs;
  static const String _key = 'auto_reply_settings';

  AutoReplySettingsNotifier(this._prefs) : super({}) {
    _load();
  }

  void _load() {
    final String? json = _prefs.getString(_key);
    if (json != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(json);
        state = decoded.map((k, v) => MapEntry(k, v as bool));
      } catch (_) {}
    }
  }

  Future<void> toggle(String chatName, bool value) async {
    final newState = {...state, chatName: value};
    state = newState;
    await _prefs.setString(_key, jsonEncode(newState));
  }

  bool isEnabled(String chatName) => state[chatName] ?? false; // Default to false
}

class DashboardNotifier extends StateNotifier<void> {
  final Ref ref;
  final MethodChannel _platform;
  Timer? _timer;

  DashboardNotifier(this.ref) : _platform = ref.read(dashboardPlatformProvider), super(null);

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _pollAll());
    _pollAll();
  }

  void stopPolling() {
    _timer?.cancel();
  }

  Future<void> _pollAll() async {
    await Future.wait([
      checkAccessibilityPermission(),
      checkNotificationPermission(),
      fetchResearchMode(),
      fetchCounts(),
      fetchNotifications(),
      fetchCurrentTab(),
    ]);
  }

  Future<void> checkNotificationPermission() async {
    try {
      final bool enabled = await _platform.invokeMethod('isNotificationListenerEnabled');
      ref.read(notificationAccessEnabledProvider.notifier).state = enabled;
    } catch (_) {}
  }

  Future<void> fetchNotifications() async {
    try {
      final String? json = await _platform.invokeMethod('getNotifications');
      if (json != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(const JsonDecoder().convert(json));
        final List<dynamic> list = data['notifications'] ?? [];
        ref.read(notificationsProvider.notifier).state = list.reversed.toList();
      }
    } catch (_) {}
  }

  Future<void> fetchResearchMode() async {
    try {
      final bool enabled = await _platform.invokeMethod('isResearchModeEnabled');
      ref.read(researchModeProvider.notifier).state = enabled;
    } catch (_) {}
  }

  Future<void> fetchCounts() async {
    try {
      final String? json = await _platform.invokeMethod('getAppCounts');
      if (json == null) return;
      final Map<String, dynamic> data = jsonDecode(json);
      final counts = ref.read(appCountsProvider);
      final newCounts = Map<String, int>.from(counts);
      for (final app in counts.keys) {
        newCounts[app] = data[app] as int? ?? 0;
      }
      ref.read(appCountsProvider.notifier).state = newCounts;
    } catch (_) {}
  }

  Future<void> fetchCurrentTab() async {
    final app = ref.read(currentViewProvider);
    try {
      final String? json = await _platform.invokeMethod(
        'getMessagesForApp',
        {'app': app},
      );
      if (json == null) return;
      final Map<String, dynamic> data = jsonDecode(json);
      final List<dynamic> msgs = data['messages'] ?? [];
      final messages = ref.read(appMessagesProvider);
      final newMessages = Map<String, List<dynamic>>.from(messages);
      newMessages[app] = msgs.reversed.toList();
      ref.read(appMessagesProvider.notifier).state = newMessages;
    } catch (_) {}
  }

  Future<void> checkAccessibilityPermission() async {
    try {
      final bool enabled = await _platform.invokeMethod('isAccessibilityEnabled');
      ref.read(accessibilityEnabledProvider.notifier).state = enabled;
      if (!enabled && ref.read(researchModeProvider)) {
         ref.read(researchModeProvider.notifier).state = false;
      }
    } catch (_) {}
  }

  Future<void> toggleResearchMode(bool value) async {
     try {
      await _platform.invokeMethod(value ? 'enableResearchMode' : 'disableResearchMode');
      ref.read(researchModeProvider.notifier).state = value;
    } catch (_) {}
  }

  Future<void> clearMessagesForChat(String app, String chatName) async {
    try {
      final bool success = await _platform.invokeMethod('clearMessagesForChat', {
        'app': app,
        'chatName': chatName,
      });
      if (success) {
        await fetchCurrentTab();
      }
    } catch (_) {}
  }

  // ── API Actions ────────────────────────────────────────────────────────────

  Future<bool> uploadFile(File file, String filename) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.uploadFile(file, filename);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> uploadIndividualChat(String app, String chatName, List<dynamic> messages) async {
    File? tempFile;
    try {
      final apiService = ref.read(apiServiceProvider);
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/temp_${chatName}_${DateTime.now().millisecondsSinceEpoch}.json');
      
      final data = {
        'app': app,
        'chat_name': chatName,
        'messages': messages,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await tempFile.writeAsString(jsonEncode(data));
      
      final response = await apiService.uploadFile(
        tempFile,
        'individual_${chatName}_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    } finally {
      try { await tempFile?.delete(); } catch (_) {}
    }
  }

  Future<bool> deletePerson(String personName) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.deletePerson(personName);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateMessage(String chatName, String sender, String text) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.updateMessage(chatName, sender, text);
    } catch (_) {}
  }

  Future<bool> brainSync(String chatName, String contextData) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.brainSync(chatName, contextData);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>?> getBrainSyncQuestions(String contextData) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getBrainSyncQuestions(contextData);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['questions'] ?? []);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> finalizeBrainSync(String originalIntent, String userAnswers) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.finalizeBrainSync(originalIntent, userAnswers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['brain_state'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

final dashboardNotifierProvider = Provider((ref) => DashboardNotifier(ref));
