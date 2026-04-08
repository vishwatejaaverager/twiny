import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'routes.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final route = AppRoutes.values.firstWhere(
      (e) => e.path == settings.name,
      orElse: () => AppRoutes.dashboard,
    );

    switch (route) {
      case AppRoutes.dashboard:
        return PageTransition(
          child: const ResearchDashboard(),
          type: PageTransitionType.fade,
          settings: settings,
        );
      case AppRoutes.onboarding:
        return PageTransition(
          child: const OnboardingScreen(),
          type: PageTransitionType.fade,
          settings: settings,
        );
      case AppRoutes.auth:
        // Placeholder for auth screen
        return PageTransition(
          child: const Scaffold(body: Center(child: Text('Auth Screen'))),
          type: PageTransitionType.fade,
          settings: settings,
        );
    }
  }
}
