import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingPageProvider = StateProvider<int>((ref) => 0);

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final onboardingCompletedProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('onboarding_completed') ?? false;
});

class OnboardingNotifier extends StateNotifier<void> {
  final SharedPreferences _prefs;
  OnboardingNotifier(this._prefs) : super(null);

  Future<void> completeOnboarding() async {
    await _prefs.setBool('onboarding_completed', true);
  }
}

final onboardingNotifierProvider = StateNotifierProvider<OnboardingNotifier, void>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingNotifier(prefs);
});
