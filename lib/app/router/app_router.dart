import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/router/app_root_page.dart';
import 'package:libredb_mobile/app/router/app_router_refresh_notifier.dart';
import 'package:libredb_mobile/app/router/not_found_page.dart';
// safeRedirectTarget lives in core/ so features/ guards can consume it too.
import 'package:libredb_mobile/core/security/safe_redirect.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/app/shell/app_shell.dart';
import 'package:libredb_mobile/app/shell/platform_shell.dart';
import 'package:libredb_mobile/app/theme/theme_bloc.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/app_lock/presentation/widgets/app_lock_settings_section.dart';
import 'package:libredb_mobile/features/auth/navigation/auth_routes.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/features/connections/navigation/connections_routes.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_cubit.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_state.dart';
import 'package:libredb_mobile/features/onboarding/navigation/onboarding_routes.dart';
import 'package:libredb_mobile/features/object_browser/navigation/object_browser_routes.dart';
import 'package:libredb_mobile/features/settings/navigation/settings_routes.dart';
import 'package:libredb_mobile/features/platform_audit/navigation/platform_audit_routes.dart';
import 'package:libredb_mobile/features/platform_connections/navigation/platform_connections_routes.dart';
import 'package:libredb_mobile/features/platform_grants/navigation/platform_grants_routes.dart';
import 'package:libredb_mobile/features/platform_home/navigation/platform_home_routes.dart';
import 'package:libredb_mobile/features/sql_editor/navigation/sql_editor_routes.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouterFactory {
  AppRouterFactory({required this._sessionCubit, OnboardingCubit? onboardingCubit, List<NavigatorObserver>? observers})
    : _onboarding = onboardingCubit,
      _observers = observers ?? [];

  static final _log = AppLogger.getLogger('AppRouterFactory');

  final SessionCubit _sessionCubit;

  /// Whether this device has shown the introduction, or null when there is no introduction to show. Nullable so a
  /// test that is about something else can build a router without one, and so `null` reads as "nothing to gate on"
  /// rather than as a missing dependency.
  final OnboardingCubit? _onboarding;

  final List<NavigatorObserver> _observers;

  GoRouter create() {
    final onboarding = _onboarding;
    // The redirect reads both, so it has to re-run when either changes: the session says whether the user is signed
    // in, the flag whether they have seen the introduction.
    final refreshNotifier = AppRouterRefreshNotifier([_sessionCubit.stream, if (onboarding != null) onboarding.stream]);

    return GoRouter(
      initialLocation: ApplicationRoutesConstants.root,
      debugLogDiagnostics: true,
      refreshListenable: refreshNotifier,
      observers: _observers,
      errorPageBuilder: (context, state) {
        // The page tells the user in the app language; the router's own error, in English, goes to the log.
        _log.warn('No page for location {}: {}', [state.uri, state.error]);
        return appRootPage(
          state: state,
          // An error state has no route name or path, and an unnamed page is invisible to analytics.
          name: ApplicationRoutesConstants.notFound,
          child: const NotFoundPage(),
        );
      },
      routes: [
        // The root has no page of its own: it opens the home of the signed-in session's target, or the login page.
        GoRoute(
          path: ApplicationRoutesConstants.root,
          redirect: (context, state) => switch (_sessionCubit.state) {
            SessionAuthenticated(:final target) => ApplicationRoutesConstants.homeFor(target),
            SessionUnknown() || SessionUnauthenticated() => ApplicationRoutesConstants.login,
          },
        ),
        // The Studio shell.
        ShellRoute(
          pageBuilder: (context, state, child) => appPlatformPage(
            state: state,
            child: AppShell(state: state, child: child),
          ),
          routes: [
            ...ConnectionsFeatureRoutes.routes,
            ...ObjectBrowserFeatureRoutes.routes,
            ...SqlEditorFeatureRoutes.routes,
            ...SettingsFeatureRoutes.routes(
              path: ApplicationRoutesConstants.settings,
              name: 'settings',
              securitySection: (context) => const AppLockSettingsSection(),
            ),
          ],
        ),
        // The Platform shell. Every route has a name, since analytics logs no unnamed page.
        ShellRoute(
          pageBuilder: (context, state, child) => appPlatformPage(
            state: state,
            child: PlatformShell(state: state, child: child),
          ),
          routes: [
            ...PlatformHomeFeatureRoutes.routes,
            ...PlatformConnectionsFeatureRoutes.routes,
            ...PlatformGrantsFeatureRoutes.routes,
            ...PlatformAuditFeatureRoutes.routes,
            ...SettingsFeatureRoutes.routes(
              path: ApplicationRoutesConstants.platformSettings,
              name: 'platformSettings',
              securitySection: (context) => const AppLockSettingsSection(),
            ),
          ],
        ),
        // Public like the login page, and outside both shells: the introduction comes before any session.
        ...OnboardingFeatureRoutes.routes,
        ...AuthFeatureRoutes.publicRoutes(
          loginBuilder: (context) => LoginScreen(
            onToggleTheme: () => context.read<ThemeBloc>().add(const ToggleBrightness()),
            startupSignInError: switch (_sessionCubit.state) {
              SessionUnauthenticated(:final signInError) => signInError,
              SessionUnknown() || SessionAuthenticated() => null,
            },
          ),
        ),
      ],
      redirect: (context, state) {
        final location = state.uri.path;
        final sessionState = _sessionCubit.state;
        final isPublic = _isPublicRoute(location);

        _log.debug('redirect - location: {}, session: {}', [location, sessionState.runtimeType]);

        // The callback URL reaching the router, such as a custom scheme link the platform pushes, must never become a
        // router location or a returnUrl: its query holds the authorization code and state.
        if (location == OidcSettings.redirectPath) return ApplicationRoutesConstants.login;

        if (sessionState case SessionAuthenticated(:final target)) {
          // An authenticated user on the login page, for example by opening /login while signed in, goes to the home
          // of the session's target, or to the returnUrl that the redirect below gives the login page, as the sign-in
          // on that page does: SessionCubit signs the user in on that page when the stored session answers only after
          // its restore time limit. Like the login screen, it honors only a local path, and only one of the target's
          // own routes.
          if (isPublic) {
            final home = ApplicationRoutesConstants.homeFor(target);
            final returnUrl = safeRedirectTarget(state.uri.queryParameters['returnUrl'], fallback: home);
            return ApplicationRoutesConstants.belongsTo(target, returnUrl) ? returnUrl : home;
          }
          // A session never reaches the other target's routes, and gets no returnUrl to them.
          final other = _otherTarget(target);
          if (ApplicationRoutesConstants.belongsTo(other, location)) return ApplicationRoutesConstants.homeFor(target);
          return null;
        }

        // A device that has never shown the introduction sees it before anything else, carrying where it was going
        // so the deep link survives. The authorization-code guard above stays first, and the authenticated branch
        // above returns before this one, so a signed-in session never reaches the introduction.
        if (_onboarding?.state is OnboardingRequired) {
          if (location == ApplicationRoutesConstants.welcome) return null;
          final fullPath = state.uri.toString();
          // Forwarded, never nested: the login page's own returnUrl is handed over as it stands, so the page gets
          // back exactly what it would have had.
          final pending = location == ApplicationRoutesConstants.login
              ? state.uri.queryParameters['returnUrl']
              : (_isBareLocation(fullPath) ? null : fullPath);
          return pending == null
              ? ApplicationRoutesConstants.welcome
              : '${ApplicationRoutesConstants.welcome}?returnUrl=${Uri.encodeQueryComponent(pending)}';
        }

        // The router never sees SessionUnknown at startup: App mounts it
        // only once SessionCubit.restore() has settled the session. Should
        // a later SessionUnknown reach this redirect, it still counts as
        // unauthenticated, the safe default, since we cannot route into
        // protected pages without proof of session. Token validity
        // (presence + `exp`) is owned by SessionCubit, which flips state
        // to SessionUnauthenticated when the JWT is missing or expired.
        if (!isPublic) {
          // Preserve the intended destination as `returnUrl` so login
          // success can land the user where they were going. The
          // home fallback handles the "user typed /login directly"
          // case where there's nothing meaningful to return to. The
          // login screen validates the value as a local path before
          // honoring it (see LoginScreen — open-redirect guard).
          final fullPath = state.uri.toString();
          if (_isBareLocation(fullPath)) return ApplicationRoutesConstants.login;
          final encoded = Uri.encodeQueryComponent(fullPath);
          return '${ApplicationRoutesConstants.login}?returnUrl=$encoded';
        }

        return null;
      },
    );
  }

  /// Whether [leaving] must close without asking about unsaved changes: a page that needs a session cannot stay once
  /// the session has ended, so logout, an idle timeout or a 401 always reach the login page; and a page of the other
  /// target than the signed-in session's cannot stay either.
  bool isExitForced(GoRouterState leaving) => switch (_sessionCubit.state) {
    SessionAuthenticated(:final target) => ApplicationRoutesConstants.belongsTo(
      _otherTarget(target),
      leaving.matchedLocation,
    ),
    SessionUnknown() || SessionUnauthenticated() => !_isPublicRoute(leaving.matchedLocation),
  };

  static SessionTarget _otherTarget(SessionTarget target) => switch (target) {
    SessionTarget.studio => SessionTarget.platform,
    SessionTarget.platform => SessionTarget.studio,
  };

  /// The routes a user reaches without a session: the login page, and the introduction that comes before it.
  ///
  /// Adding the introduction here buys three behaviours at once — the catch-all below stops bouncing `/welcome` to
  /// `/login?returnUrl=%2Fwelcome`, the authenticated branch sends a signed-in session off it to their home, and
  /// [isExitForced] treats leaving it as forced, so it never asks about unsaved changes.
  bool _isPublicRoute(String path) =>
      path == ApplicationRoutesConstants.login || path == ApplicationRoutesConstants.welcome;

  /// Whether [fullPath] is a landing location rather than somewhere the user asked for, so there is nothing worth
  /// carrying as a `returnUrl`.
  static bool _isBareLocation(String fullPath) =>
      fullPath == ApplicationRoutesConstants.root ||
      fullPath == ApplicationRoutesConstants.home ||
      fullPath == ApplicationRoutesConstants.platformHome ||
      fullPath == ApplicationRoutesConstants.login;
}
