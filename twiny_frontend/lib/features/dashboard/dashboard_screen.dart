import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'dashboard_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// App tab config
// ─────────────────────────────────────────────────────────────────────────────

enum _BrainSyncStage { architect, legislator, activation }

class _AppTab {
  final String key; // matches MainActivity key
  final String label;
  final IconData icon;
  final Color color;

  const _AppTab({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const _kAppTabs = [
  _AppTab(
      key: 'whatsapp',
      label: 'WhatsApp',
      icon: Icons.chat_rounded,
      color: Color(0xFF25D366)),
  _AppTab(
      key: 'teams',
      label: 'Teams',
      icon: Icons.groups_rounded,
      color: Color(0xFF5B5FC7)),
  _AppTab(
      key: 'simulation',
      label: 'Simulation',
      icon: Icons.psychology_rounded,
      color: Color(0xFF06D6A0)),
];

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard
// ─────────────────────────────────────────────────────────────────────────────

class ResearchDashboard extends ConsumerStatefulWidget {
  const ResearchDashboard({super.key});

  @override
  ConsumerState<ResearchDashboard> createState() => _ResearchDashboardState();
}

class _ResearchDashboardState extends ConsumerState<ResearchDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardNotifierProvider).startPolling();
      Permission.contacts.request();
    });
  }

  @override
  void dispose() {
    // We can stop polling if the dashboard is ever disposed (e.g., on logout)
    // ref.read(dashboardNotifierProvider).stopPolling();
    super.dispose();
  }

  // ── Accessibility ─────────────────────────────────────

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Accessibility Required'),
        content: const Text(
          'Enable the Twiny Accessibility Service in Android Settings to start capturing.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED)),
            onPressed: () {
              Navigator.pop(context);
              ref.read(dashboardPlatformProvider).invokeMethod('openAccessibilitySettings');
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accessibilityEnabled = ref.watch(accessibilityEnabledProvider);
    final notificationAccessEnabled = ref.watch(notificationAccessEnabledProvider);
    final currentView = ref.watch(currentViewProvider);
    final notifications = ref.watch(notificationsProvider);
    final appMessages = ref.watch(appMessagesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (!accessibilityEnabled) _buildPermissionBanner(),
          if (!notificationAccessEnabled) _buildNotificationPermissionBanner(),
          _buildControlBar(),
          _buildViewSwitcher(),
          Expanded(
            child: (currentView == 'whatsapp'
                ? _AppMessageList(
                    tab: _kAppTabs[0],
                    messages: appMessages['whatsapp'] ?? [],
                  )
                : currentView == 'teams'
                    ? _AppMessageList(
                        tab: _kAppTabs[1],
                        messages: appMessages['teams'] ?? [],
                      )
                    : currentView == 'notifications'
                        ? _NotificationList(notifications: notifications)
                        : const _SimulationView()).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSwitcher() {
    final currentView = ref.watch(currentViewProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(
              value: 'whatsapp', label: Text('WhatsApp'), icon: Icon(Icons.chat)),
          ButtonSegment(
              value: 'teams', label: Text('Teams'), icon: Icon(Icons.groups_rounded)),
          ButtonSegment(
              value: 'notifications',
              label: Text('Notifications'),
              icon: Icon(Icons.notifications)),
          ButtonSegment(
              value: 'simulation',
              label: Text('Simulation'),
              icon: Icon(Icons.psychology)),
        ],
        selected: {currentView},
        onSelectionChanged: (newSelection) {
          ref.read(currentViewProvider.notifier).state = newSelection.first;
        },
        style: SegmentedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A2E),
          selectedBackgroundColor: const Color(0xFF7C3AED),
          selectedForegroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildNotificationPermissionBanner() {
    return Container(
      color: Colors.blue.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.notification_important, color: Colors.blue, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Notification Access disabled',
                style: TextStyle(color: Colors.blue, fontSize: 13)),
          ),
          TextButton(
            onPressed: () =>
                ref.read(dashboardPlatformProvider).invokeMethod('openNotificationListenerSettings'),
            child: const Text('ENABLE', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D0D),
      elevation: 0,
      title: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Image.asset('assets/twiny.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 10),
          const Text(
            'Twiny',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      color: Colors.orange.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Accessibility Service disabled',
                style: TextStyle(color: Colors.orange, fontSize: 13)),
          ),
          TextButton(
            onPressed: () => ref.read(dashboardPlatformProvider).invokeMethod('openAccessibilitySettings'),
            child: const Text('ENABLE', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    final researchMode = ref.watch(researchModeProvider);
    final accessibilityEnabled = ref.watch(accessibilityEnabledProvider);
    final appCounts = ref.watch(appCountsProvider);
    
    final totalCount = appCounts.values.fold(0, (a, b) => a + b);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          // Status dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: researchMode ? const Color(0xFF06D6A0) : Colors.grey,
              boxShadow: researchMode
                  ? [
                      BoxShadow(
                          color: const Color(0xFF06D6A0).withValues(alpha: 0.5),
                          blurRadius: 8)
                    ]
                  : [],
            ),
          ).animate(target: researchMode ? 1 : 0).shimmer(duration: 2.seconds).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), curve: Curves.easeInOut),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  researchMode ? 'Capturing...' : 'Capture Paused',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: researchMode ? const Color(0xFF06D6A0) : Colors.grey,
                  ),
                ),
                Text(
                  '$totalCount messages collected',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MiniCounter(tab: _kAppTabs[0], count: appCounts['whatsapp'] ?? 0),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: researchMode,
            onChanged: (value) async {
              if (value && !accessibilityEnabled) {
                _showPermissionDialog();
                return;
              }
              if (value) await Permission.contacts.request();
              await ref.read(dashboardNotifierProvider).toggleResearchMode(value);
            },
            activeTrackColor: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-app message list
// ─────────────────────────────────────────────────────────────────────────────

class _AppMessageList extends StatelessWidget {
  final _AppTab tab;
  final List<dynamic> messages;

  const _AppMessageList({required this.tab, required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, size: 52, color: tab.color.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No ${tab.label} messages yet',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enable capture and open the app',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Group by chat_name
    final Map<String, List<dynamic>> grouped = {};
    for (final msg in messages) {
      final chat = msg['chat_name'] as String? ?? 'Unknown';
      grouped.putIfAbsent(chat, () => []).add(msg);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final chatName = grouped.keys.elementAt(index);
        final chatMsgs = grouped[chatName]!;
        return _ConversationCard(
          tab: tab,
          chatName: chatName,
          messages: chatMsgs,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conversation card
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationCard extends ConsumerStatefulWidget {
  final _AppTab tab;
  final String chatName;
  final List<dynamic> messages;

  const _ConversationCard({
    required this.tab,
    required this.chatName,
    required this.messages,
  });

  @override
  ConsumerState<_ConversationCard> createState() => _ConversationCardState();
}

class _ConversationCardState extends ConsumerState<_ConversationCard> {
  bool _expanded = false;
  bool _isUploading = false;

  Future<void> _uploadIndividualChat() async {
    setState(() => _isUploading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final success = await ref.read(dashboardNotifierProvider).uploadIndividualChat(
            widget.tab.key,
            widget.chatName,
            widget.messages,
          );

      if (success) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Chat uploaded successfully!')),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Upload failed')),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Upload Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _clearIndividualDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Clear or Delete Chat?'),
        content: Text('Would you like to clear local messages for "${widget.chatName}" or delete all data from the server?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(dashboardNotifierProvider).clearMessagesForChat(widget.tab.key, widget.chatName);
            },
            child: const Text('CLEAR LOCAL', style: TextStyle(color: Colors.orangeAccent)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(dashboardNotifierProvider).deletePerson(widget.chatName);
              if (success) {
                ref.read(dashboardNotifierProvider).clearMessagesForChat(widget.tab.key, widget.chatName);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Person deleted from server successfully')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete person from server')),
                  );
                }
              }
            },
            child: const Text('DELETE SERVER', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showBrainSyncBottomSheet(BuildContext context, String chatName) {
    _BrainSyncStage stage = _BrainSyncStage.architect;
    final architectController = TextEditingController();
    List<String> questions = [];
    final Map<int, TextEditingController> answerControllers = {};
    String rulebook = '';
    bool isLoading = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0D0D0D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Color(0xFF7C3AED), width: 2)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stage == _BrainSyncStage.architect
                                ? 'Stage 1: The Architect'
                                : stage == _BrainSyncStage.legislator
                                    ? 'Stage 2: The Legislator'
                                    : 'Stage 3: Activation',
                            style: const TextStyle(
                                color: Color(0xFF7C3AED),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.2),
                          ),
                          Text(
                            chatName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),

                  // --- Stages Switcher ---
                  AnimatedSwitcher(
                    duration: 800.ms,
                    switchInCurve: Curves.easeOutBack,
                    child: _buildStageContent(
                      context,
                      stage,
                      architectController,
                      questions,
                      answerControllers,
                      rulebook,
                      isLoading,
                      (newStage, [newQuestions, newRulebook]) {
                        setState(() {
                          stage = newStage;
                          if (newQuestions != null) {
                            questions = newQuestions;
                            answerControllers.clear();
                            for (int i = 0; i < questions.length; i++) {
                              answerControllers[i] = TextEditingController();
                            }
                          }
                          if (newRulebook != null) rulebook = newRulebook;
                          errorMessage = null;
                        });
                      },
                      (loading) => setState(() => isLoading = loading),
                      (err) => setState(() => errorMessage = err),
                      chatName,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStageContent(
    BuildContext context,
    _BrainSyncStage stage,
    TextEditingController architectController,
    List<String> questions,
    Map<int, TextEditingController> answerControllers,
    String rulebook,
    bool isLoading,
    void Function(_BrainSyncStage, [List<String>?, String?]) onNext,
    void Function(bool) setLoading,
    void Function(String?) setError,
    String chatName,
  ) {
    if (stage == _BrainSyncStage.architect) {
      return Column(
        key: const ValueKey('architect'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The Architect: Discovery',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            'Describe the current situation (e.g. "I am in a meeting, pretend I am finishing the demo").',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: architectController,
            maxLines: 3,
            autofocus: true,
            decoration: _inputDecoration('e.g. I am going to a cafe...'),
          ),
          const SizedBox(height: 24),
          _actionButton(
            'START DISCOVERY',
            isLoading,
            () async {
              final text = architectController.text.trim();
              if (text.isEmpty) return;
              setLoading(true);
              final fetchedQuestions = await ref.read(dashboardNotifierProvider).getBrainSyncQuestions(text);
              setLoading(false);
              if (fetchedQuestions != null) {
                onNext(_BrainSyncStage.legislator, fetchedQuestions);
              } else {
                setError('Failed to start discovery. (Check if contact exists)');
              }
            },
          ),
        ],
      );
    } else if (stage == _BrainSyncStage.legislator) {
      return Column(
        key: const ValueKey('legislator'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The Legislator: Rules Generation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            'Answer these discovery questions to tailor your agent response style.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...List.generate(questions.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Q: ${questions[index]}',
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: answerControllers[index],
                    decoration: _inputDecoration('Your answer...'),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          _actionButton(
            'GENERATE RULEBOOK',
            isLoading,
            () async {
              String combinedAnswers = '';
              for (int i = 0; i < questions.length; i++) {
                combinedAnswers += 'Q: ${questions[i]} A: ${answerControllers[i]?.text}\n';
              }
              setLoading(true);
              final fetchedRulebook = await ref.read(dashboardNotifierProvider).finalizeBrainSync(
                    architectController.text.trim(),
                    combinedAnswers,
                  );
              setLoading(false);
              if (fetchedRulebook != null) {
                onNext(_BrainSyncStage.activation, null, fetchedRulebook);
              } else {
                setError('Failed to generate rules.');
              }
            },
          ),
        ],
      );
    } else {
      return Column(
        key: const ValueKey('activation'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activation: Confirm Brain State',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: SingleChildScrollView(
              child: MarkdownBody(
                data: rulebook,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: Colors.white70, fontSize: 13),
                  h1: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  h2: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  listBullet: const TextStyle(color: Color(0xFF7C3AED)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _actionButton(
            'ACTIVATE AGENT',
            isLoading,
            () async {
              setLoading(true);
              final success = await ref.read(dashboardNotifierProvider).brainSync(chatName, rulebook);
              setLoading(false);
              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Manage Mode Activated'), backgroundColor: Colors.green),
                );
              } else {
                setError('Activation failed.');
              }
            },
          ),
        ],
      );
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1)),
    );
  }

  Widget _actionButton(String label, bool isLoading, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.messages.last;
    final previewText = preview['text'] as String? ?? '';
    final isContact = preview['contact_match'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isContact
              ? widget.tab.color.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          // Header row (always visible)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.tab.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.chatName.isNotEmpty
                            ? widget.chatName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: widget.tab.color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + preview
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.chatName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Auto Reply Toggle
                            Column(
                              children: [
                                const Text('Auto', style: TextStyle(fontSize: 8, color: Colors.grey)),
                                Transform.scale(
                                  scale: 0.6,
                                  child: Switch(
                                    value: ref.watch(autoReplySettingsProvider)[widget.chatName] ?? true,
                                    onChanged: (val) {
                                      ref.read(autoReplySettingsProvider.notifier).toggle(widget.chatName, val);
                                    },
                                    activeColor: const Color(0xFF06D6A0),
                                  ),
                                ),
                              ],
                            ),
                            // Brain Sync Icon
                            IconButton(
                              icon: const Icon(Icons.psychology_outlined, size: 20, color: Color(0xFF7C3AED)),
                              tooltip: 'Brain Sync',
                              onPressed: () => _showBrainSyncBottomSheet(context, widget.chatName),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            if (isContact)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF06D6A0).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '✓ contact',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF06D6A0),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          previewText,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Count + actions
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              if (_isUploading)
                                const SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.cloud_upload_outlined, size: 22, color: Colors.blueAccent),
                                  tooltip: 'Upload this chat',
                                  onPressed: _uploadIndividualChat,
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 22, color: Colors.redAccent),
                                tooltip: 'Clear this chat',
                                onPressed: _clearIndividualDialog,
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: widget.tab.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${widget.messages.length}',
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.tab.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (_expanded) ...[
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            ...(() {
              final List<dynamic> sorted = List.from(widget.messages);
              sorted.sort((a, b) {
                final int tsA = a['timestamp'] ?? 0;
                final int tsB = b['timestamp'] ?? 0;
                return tsA.compareTo(tsB);
              });
              return sorted;
            }()).map((msg) => _MessageBubbleRow(
                  msg: msg,
                  accentColor: widget.tab.color,
                )),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual message bubble row
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubbleRow extends StatelessWidget {
  final dynamic msg;
  final Color accentColor;

  const _MessageBubbleRow({required this.msg, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final bool isMe = (msg['sender'] as String?) == 'me';
    final text = msg['text'] as String? ?? '';
    final ts = msg['timestamp'];
    final time = ts != null ? _formatTime((ts as int) * 1000) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 12,
              backgroundColor: accentColor.withValues(alpha: 0.2),
              child: Icon(Icons.person, size: 14, color: accentColor),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF7C3AED).withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isMe ? 12 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 12),
                ),
                border: Border.all(
                  color: isMe
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(text, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
              child: const Icon(Icons.person, size: 14, color: Color(0xFF7C3AED)),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification List
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationList extends StatelessWidget {
  final List<dynamic> notifications;

  const _NotificationList({required this.notifications});

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 52, color: Colors.grey),
            SizedBox(height: 16),
            Text('No Teams notifications yet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        return _NotificationTile(note: notifications[index]);
      },
    );
  }
}

class _NotificationTile extends ConsumerStatefulWidget {
  final dynamic note;
  const _NotificationTile({required this.note});

  @override
  ConsumerState<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends ConsumerState<_NotificationTile> {
  final _controller = TextEditingController();
  bool _sending = false;

  Future<void> _sendReply() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final key = widget.note['key'];
      final success = await ref.read(dashboardPlatformProvider).invokeMethod('sendNotificationReply', {
        'key': key,
        'message': text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(success == true
                  ? 'Reply sent!'
                  : 'Failed to send reply (Notification might be gone)')),
        );
        if (success == true) {
          _controller.clear();
          // Sync manual reply to server
          ref.read(dashboardNotifierProvider).updateMessage(
            widget.note['title'] as String? ?? 'Unknown',
            'me',
            text,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.note['title'] as String? ?? '';
    final body = widget.note['text'] as String? ?? '';
    final ts = widget.note['timestamp'] as int? ?? 0;
    final time = DateTime.fromMillisecondsSinceEpoch(ts)
        .toLocal()
        .toString()
        .split('.')
        .first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 16, color: Color(0xFF6264A7)),
              const SizedBox(width: 8),
              const Text('Teams',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const Spacer(),
              Text(time,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Type a reply...',
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _sending ? null : _sendReply,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded, color: Color(0xFF7C3AED)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini counter badge (control bar)
// ─────────────────────────────────────────────────────────────────────────────

class _MiniCounter extends StatelessWidget {
  final _AppTab tab;
  final int count;

  const _MiniCounter({required this.tab, required this.count});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${tab.label}: $count messages',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tab.icon, size: 14, color: tab.color),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              color: tab.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Simulation View
// ─────────────────────────────────────────────────────────────────────────────

class _SimulationView extends ConsumerStatefulWidget {
  const _SimulationView();

  @override
  ConsumerState<_SimulationView> createState() => _SimulationViewState();
}

class _SimulationViewState extends ConsumerState<_SimulationView> {
  final List<Map<String, dynamic>> _messages = [];
  final _messageController = TextEditingController();
  final _chatNameController = TextEditingController(text: 'Simulation User');
  final _scrollController = ScrollController();
  bool _isLoading = false;

  void _addMessage(String text, bool isMe) {
    setState(() {
      _messages.add({
        'sender': isMe ? 'me' : 'ai',
        'text': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    final chatName = _chatNameController.text.trim();
    if (text.isEmpty || chatName.isEmpty) return;

    _messageController.clear();
    _addMessage(text, true);

    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getNotificationReply(chatName, text);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['reply'] as String? ?? '';
        if (reply.isNotEmpty) {
          _addMessage(reply, false);
        } else {
          _addMessage('No reply from AI', false);
        }
      } else {
        _addMessage('Error: ${response.statusCode}', false);
      }
    } catch (e) {
      _addMessage('Failed to connect: $e', false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildChatSettings(),
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _MessageBubbleRow(
                      msg: msg,
                      accentColor: const Color(0xFF06D6A0),
                    );
                  },
                ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06D6A0)),
            ),
          ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildChatSettings() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _chatNameController,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Simulated Chat Name',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.psychology_outlined, size: 64, color: const Color(0xFF06D6A0).withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            'Simulation Mode',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Type a message to see how the AI responds.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (_) => _handleSend(),
              decoration: InputDecoration(
                hintText: 'Simulate a message...',
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF7C3AED),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _handleSend,
            ),
          ),
        ],
      ),
    );
  }
}
