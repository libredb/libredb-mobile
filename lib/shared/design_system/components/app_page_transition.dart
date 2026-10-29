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

      // `buildTransitions` is called again on every tick of both animations, so the values are read here rather than
      // wrapped in animation objects: a new `CurvedAnimation` per frame subscribes to the route animation per frame.
      final arrived = _entrance.transform(animation.value);
      final covered = _exit.transform(secondaryAnimation.value);
      final travel = _travel(type);

      return Opacity(
        // The page is drawn once it has arrived and no longer once the next page has covered it. One of the two
        // factors is always 1: a page is either coming in or being covered, never both at once.
        opacity: arrived * (1 - covered),
        child: FractionalTranslation(
          translation: Offset.lerp(travel.from, Offset.zero, arrived)! + travel.to * covered,
          child: child,
        ),
      );
    },
  );
}

/// The share of a transition the page being left has to itself before the page arriving starts to appear.
///
/// A transition hands one page over to the other; it does not dissolve one into the other. The page being covered
/// leaves over the first [_handover] of the transition and the page arriving takes the rest, so no frame draws the
/// two on top of each other. It also makes the exit shorter than the entrance, which is what the design system's
/// motion says a transition should be: 108 ms out, 252 ms in.
///
/// A builder that ignored `secondaryAnimation` left the page being covered fully opaque under the one fading in over
/// it, and 100% of the screen was composited from both pages for 14 consecutive frames (#421).
const double _handover = 0.3;

/// When the page arriving appears, and how it moves while it does. An entrance, so the design system's entrance curve.
const Curve _entrance = Interval(_handover, 1, curve: AppDurations.easeOut);

/// When the page being covered leaves. An exit, so the exit curve, and over in the first [_handover] of the
/// transition — before anything of the next page is drawn.
const Curve _exit = Interval(0, _handover, curve: AppDurations.easeIn);

/// Where a [type] page comes in [from] and where it goes [to] once the next page covers it, in fractions of its own
/// size.
///
/// Both moves are short, and that is the point of the fractions. A page moving a whole screen width arrives at the
/// hand-over with almost none of itself on screen, so the frame reads as the shell emptying: measured, a full-width
/// slide left 93% of the surface showing nothing but the shell at t=112 ms. A third of the width still says which
/// direction the stack went, which is all the move is for — the fade does the rest.
({Offset from, Offset to}) _travel(AppPageTransitionType type) => switch (type) {
  AppPageTransitionType.fade => (from: Offset.zero, to: Offset.zero),
  AppPageTransitionType.slideRight => (from: const Offset(0.3, 0), to: const Offset(-0.1, 0)),
  AppPageTransitionType.slideUp => (from: const Offset(0, 0.3), to: const Offset(0, -0.1)),
};
