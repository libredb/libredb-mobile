import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/onboarding_steps.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';

class OnboardingFeatureRoutes {
  /// The introduction, outside both shells and public like the login page.
  ///
  /// Named because `AnalyticsRouteObserver` logs no unnamed page, and the introduction is the first screen a new user
  /// meets — the one a usability evaluation most needs to see in the route trail. Built with [appPlatformPage] rather
  /// than a transition, matching the login page it hands over to.
  static final List<GoRoute> routes = <GoRoute>[
    GoRoute(
      name: 'welcome',
      path: ApplicationRoutesConstants.welcome,
      pageBuilder: (context, state) => appPlatformPage(
        state: state,
        child: OnboardingPage(
          returnUrl: state.uri.queryParameters['returnUrl'],
          heroBuilder: onboardingStepHero,
        ),
      ),
    ),
  ];
}
