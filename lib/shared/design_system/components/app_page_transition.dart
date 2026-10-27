import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../tokens/app_durations.dart';

/// Page transition types for go_router.
enum AppPageTransitionType { fade, slideRight, slideUp }

/// Creates a platform-adaptive [MaterialPage], built the way go_router 17 built pages for `builder:` routes.
///
/// go_router 18 only detects material_ui's MaterialApp. Under the SDK MaterialApp it turns `builder:` routes into
/// `NoTransitionPage`s, so every route must return an explicit page.
///
/// Unlike go_router 17, path and query parameters are not copied into the page arguments: nothing reads them, and
/// navigator observers such as Sentry's would otherwise record values like the email in `/login-otp-verify/:email`.
///
/// [name] replaces the route-derived name for a page that has no route of its own, such as the error page.
MaterialPage<void> appPlatformPage({required Widget child, required GoRouterState state, String? name}) {
  return MaterialPage<void>(
    key: state.pageKey,
    name: name ?? state.name ?? state.path,
    restorationId: state.pageKey.value,
    child: child,
  );
}

/// Creates a page with one of this app's transitions — except on iOS, where it creates the platform's page instead.
///
/// Named like [appPlatformPage], because navigator observers such as analytics identify a screen by its page name.
///
/// The iOS branch is not a style choice. A `CustomTransitionPage` does not carry the Cupertino back gesture, measured:
/// a route pushed with one does not pop when the user drags in from the left edge, and this builds every sub-page
/// outside the two shells — settings, the audit log, the object browser seven times over. Edge-swiping back is how
/// many people navigate on that platform, and on those pages the app bar's button was the only way out (#371).
Page<T> appTransitionPage<T>({
  required Widget child,
  required GoRouterState state,
  AppPageTransitionType type = AppPageTransitionType.fade,
}) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return MaterialPage<T>(
      key: state.pageKey,
      name: state.name ?? state.path,
      restorationId: state.pageKey.value,
      child: child,
    );
  }

  return CustomTransitionPage<T>(
    key: state.pageKey,
    name: state.name ?? state.path,
    child: child,
    transitionDuration: AppDurations.slow,
    reverseTransitionDuration: AppDurations.normal,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Respect reduced motion preferences
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        return child;
      }

      final curve = CurvedAnimation(parent: animation, curve: AppDurations.easeInOut);

      switch (type) {
        case AppPageTransitionType.fade:
          return FadeTransition(opacity: curve, child: child);

        case AppPageTransitionType.slideRight:
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(curve),
            child: FadeTransition(opacity: curve, child: child),
          );

        case AppPageTransitionType.slideUp:
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(curve),
            child: FadeTransition(opacity: curve, child: child),
          );
      }
    },
  );
}
