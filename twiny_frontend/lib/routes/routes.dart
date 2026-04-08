enum AppRoutes {
  dashboard('/'),
  onboarding('/onboarding'),
  auth('/auth');

  final String path;
  const AppRoutes(this.path);
}
