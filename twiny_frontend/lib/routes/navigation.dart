import 'package:flutter/material.dart';
import 'routes.dart';

class Navigation {
  static final Navigation instance = Navigation._internal();
  Navigation._internal();

  final GlobalKey<NavigatorState> navigationKey = GlobalKey<NavigatorState>();

  Future<dynamic> pushNamed(AppRoutes route, {Object? arguments}) {
    return navigationKey.currentState!.pushNamed(route.path, arguments: arguments);
  }

  Future<dynamic> pushReplacementNamed(AppRoutes route, {Object? arguments}) {
    return navigationKey.currentState!.pushReplacementNamed(route.path, arguments: arguments);
  }

  Future<dynamic> pushNamedAndRemoveUntil(AppRoutes route, {bool Function(Route<dynamic>)? predicate, Object? arguments}) {
    return navigationKey.currentState!.pushNamedAndRemoveUntil(
      route.path,
      predicate ?? (route) => false,
      arguments: arguments,
    );
  }

  void pop([Object? result]) {
    return navigationKey.currentState!.pop(result);
  }

  void popUntil(AppRoutes route) {
    return navigationKey.currentState!.popUntil(ModalRoute.withName(route.path));
  }
}
