import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../routes/navigation.dart';
import '../../routes/routes.dart';
import '../dashboard/dashboard_providers.dart';
import 'onboarding_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibilityAndNavigate();
    }
  }

  Future<void> _checkAccessibilityAndNavigate() async {
    final curPage = ref.read(onboardingPageProvider);
    if (curPage == 3) {
      final platform = ref.read(dashboardPlatformProvider);
      final bool enabled = await platform.invokeMethod('isAccessibilityEnabled');
      if (enabled) {
        await ref.read(onboardingNotifierProvider.notifier).completeOnboarding();
        Navigation.instance.pushNamedAndRemoveUntil(AppRoutes.dashboard);
      }
    }
  }

  void _nextPage() {
    if (_pageController.page! < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
      );
    } else {
      _openAccessibilitySettings();
    }
  }

  void _openAccessibilitySettings() {
    ref.read(dashboardPlatformProvider).invokeMethod('openAccessibilitySettings');
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              ref.read(onboardingPageProvider.notifier).state = index;
            },
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _OnboardingStepWelcome(onStart: _nextPage),
              _OnboardingStepCapability(onBack: _prevPage, onNext: _nextPage),
              _OnboardingStepPrivacy(onBack: _prevPage, onNext: _nextPage),
              _OnboardingStepActivate(onBack: _prevPage, onEnable: _openAccessibilitySettings),
            ],
          ),
          _buildHeader(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final curPage = ref.watch(onboardingPageProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Image.asset('assets/twiny.png', width: 24, height: 24)
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 2.seconds, color: Colors.white24),
                const SizedBox(width: 10),
                Text(
                  'Twiny'.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    fontSize: 14,
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.2),
            _buildProgressBar(curPage + 1, 4),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(int step, int total) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 80,
          child: LinearProgressIndicator(
            value: step / total,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            color: const Color(0xFF7C3AED),
            minHeight: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$step / $total',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 800.ms).slideX(begin: 0.2);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1: Welcome to Twiny
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingStepWelcome extends StatelessWidget {
  final VoidCallback onStart;
  const _OnboardingStepWelcome({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Center(
              child: Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Image.asset('assets/twiny.png', fit: BoxFit.contain),
              )
                  .animate()
                  .scale(duration: 800.ms, curve: Curves.easeOutBack)
                  .fadeIn()
                  .shimmer(delay: 1.seconds, duration: 2.seconds),
            ),
            const SizedBox(height: 48),
            const Text(
              'Meet Twiny.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
            const SizedBox(height: 16),
            Text(
              'Your digital reflection that handles\nthe busywork, so you don\'t have to.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 18,
                height: 1.5,
              ),
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
            const Spacer(),
            _GradientButton(
              onPressed: onStart,
              child: const Text('Wake up Twiny', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ).animate().fadeIn(delay: 1.seconds).scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2: The Capability
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingStepCapability extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _OnboardingStepCapability({required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 100),
            const Text(
              'Intelligence\nthat learns\nfrom you.',
              style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, height: 1.1),
            ).animate().fadeIn().slideX(begin: -0.1),
            const SizedBox(height: 40),
            _buildFeatureItem(
              icon: Icons.psychology_outlined,
              title: 'Context Aware',
              desc: 'Twiny understands your tone and expertise to suggest the perfect responses.',
              delay: 200,
            ),
            _buildFeatureItem(
              icon: Icons.auto_awesome_outlined,
              title: 'Automation Ready',
              desc: 'Deploy Twiny on WhatsApp and Teams to bridge communication gaps instantly.',
              delay: 400,
            ),
            _buildFeatureItem(
              icon: Icons.timer_outlined,
              title: 'Time Saver',
              desc: 'Stop repeating yourself. Twiny handles frequent questions automatically.',
              delay: 600,
            ),
            const Spacer(),
            _buildNavButtons(onBack, onNext),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String title, required String desc, required int delay}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: const Color(0xFF06D6A0), size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3: Privacy
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingStepPrivacy extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _OnboardingStepPrivacy({required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFF131313),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_rounded, color: Color(0xFF7C3AED), size: 48),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(duration: 2.seconds, begin: const Offset(1, 1), end: const Offset(1.1, 1.1))
                .boxShadow(begin: const BoxShadow(blurRadius: 0), end: const BoxShadow(blurRadius: 20, color: Color(0x337C3AED))),
            const SizedBox(height: 48),
            const Text(
              'Your Data.\nStrictly Yours.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, height: 1.1),
            ).animate().fadeIn(),
            const SizedBox(height: 24),
            Text(
              'Twiny runs entirely on your device.\nNo chats ever leave this hardware.\nNo cloud. No leaks. Absolute Privacy.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16, height: 1.6),
            ).animate().fadeIn(delay: 300.ms),
            const Spacer(),
            _buildNavButtons(onBack, onNext),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 4: Activation
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingStepActivate extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onEnable;
  const _OnboardingStepActivate({required this.onBack, required this.onEnable});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 100),
            const Text(
              'Empower\nTwiny.',
              style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, height: 1.1),
            ).animate().fadeIn().slideX(begin: -0.1),
            const SizedBox(height: 24),
            Text(
              'To mirror your actions, Twiny needs Accessibility permission to see incoming messages and suggest replies.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16, height: 1.5),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 48),
            _buildPermissionItem(Icons.visibility_outlined, 'Real-time Awareness', 'Twiny monitors Teams and WhatsApp.'),
            _buildPermissionItem(Icons.security_outlined, 'Native Security', 'Powered by Android\'s secure accessibility layer.'),
            const Spacer(),
            _GradientButton(
              onPressed: onEnable,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Enable Accessibility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  SizedBox(width: 12),
                  Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ).animate().fadeIn(delay: 600.ms).shimmer(delay: 1.2.seconds, duration: 1.5.seconds),
            Center(
              child: TextButton(
                onPressed: onBack,
                child: const Text('Back', style: TextStyle(color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Color(0xFF131313), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Components
// ─────────────────────────────────────────────────────────────────────────────

Widget _buildNavButtons(VoidCallback onBack, VoidCallback onNext) {
  return Row(
    children: [
      Expanded(
        child: TextButton(
          onPressed: onBack,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: const Text('Back', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        flex: 2,
        child: _GradientButton(
          onPressed: onNext,
          child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    ],
  ).animate().fadeIn(delay: 400.ms);
}

class _GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  const _GradientButton({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF06D6A0)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: child,
      ),
    );
  }
}
