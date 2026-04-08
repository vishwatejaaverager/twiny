import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'features/onboarding/onboarding_providers.dart';
import 'routes/app_router.dart';
import 'routes/navigation.dart';
import 'routes/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  NotificationService(container).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TwinyApp(),
    ),
  );
}

class TwinyApp extends ConsumerWidget {
  const TwinyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingCompleted = ref.watch(onboardingCompletedProvider);

    return MaterialApp(
      title: 'Twiny',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFF06D6A0),
          surface: Color(0xFF1A1A2E),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      navigatorKey: Navigation.instance.navigationKey,
      initialRoute: onboardingCompleted ? AppRoutes.dashboard.path : AppRoutes.onboarding.path,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
