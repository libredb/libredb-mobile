import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/analytics/analytics_route_observer.dart';
import 'package:libredb_mobile/app/app_scroll_behavior.dart';
import 'package:libredb_mobile/app/app_status_gate.dart';
import 'package:libredb_mobile/app/app_target_reachability.dart';
import 'package:libredb_mobile/app/bootstrap/app_session_listeners.dart';
import 'package:libredb_mobile/app/connectivity/app_connectivity_scope.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/app/di/app_scope.dart';
import 'package:libredb_mobile/app/localization/locale_cubit.dart';
import 'package:libredb_mobile/app/lock/app_lock_gate.dart';
import 'package:libredb_mobile/app/theme/theme_bloc.dart';
import 'package:libredb_mobile/app/router/app_router.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/core/analytics/analytics_service.dart';
import 'package:libredb_mobile/core/analytics/log_analytics_service.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_cubit.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_state.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/widgets/unsaved_changes_guard.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

class App extends StatefulWidget {
  const App({super.key, required this.language, required this.dependencies, this.secureStorage, this._analytics});

  /// The configured default language: the app shows it until a language is stored on the device, see [LocaleCubit].
  final String language;
  final AppDependencies dependencies;

  /// Single [ISecureStorage] instance created in bootstrap. Threaded
  /// through so every runtime consumer (repositories, interceptors,
  /// SessionCubit) uses the same adapter, which avoids divergent instances
  /// if adapter configuration ever varies and makes overriding for tests
  /// or alternate environments trivial.
  /// When null, [AppScope] falls back to [AppDependencies.createSecureStorage].
  final ISecureStorage? secureStorage;
  final IAnalyticsService? _analytics;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  /// The ScaffoldMessenger of MaterialApp.router. [AppSessionListeners] sits above MaterialApp, where its context finds
  /// no ScaffoldMessenger, so it shows its notices through this key.
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final analytics = widget._analytics ?? LogAnalyticsService();
    return AppScope(
      dependencies: widget.dependencies,
      secureStorage: widget.secureStorage,
      defaultLocale: Locale(widget.language),
      child: AppSessionListeners(
        scaffoldMessengerKey: _scaffoldMessengerKey,
        child: AppConnectivityScope(
          checksPlatform: switch (widget.dependencies.appConfig.platform) {
            PlatformConfigured() => true,
            PlatformNotConfigured() => false,
          },
          child: _AppView(analytics: analytics, scaffoldMessengerKey: _scaffoldMessengerKey),
        ),
      ),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView({required this.analytics, required this.scaffoldMessengerKey});

  final IAnalyticsService analytics;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  GoRouter? _router;
  UnsavedChangesRegistry? _unsavedChanges;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_router != null) return;
    final routerFactory = AppRouterFactory(
      sessionCubit: context.read<SessionCubit>(),
      onboardingCubit: context.read<OnboardingCubit>(),
      observers: [
        AnalyticsRouteObserver(widget.analytics),
        // Sentry breadcrumbs from navigation. Only meaningful when the
        // Sentry SDK was initialized in bootstrap (production + DSN);
        // outside that window the observer is harmless overhead.
        if (context.read<AppConfig>().sentryDsn != null) SentryNavigatorObserver(),
      ],
    );
    final router = _router = routerFactory.create();
    _unsavedChanges = UnsavedChangesRegistry(isExitForced: routerFactory.isExitForced);
    // The Router is mounted only once the session is restored (see build), and go_router's route information provider
    // receives the routes the platform pushes, such as an iOS universal link that opens the app, only while something
    // listens to it. This listener keeps it receiving them from the start, so the Router opens a route pushed during
    // the restore when it mounts.
    router.routeInformationProvider.addListener(_receivePlatformRoutes);
  }

  @override
  void dispose() {
    _router?.routeInformationProvider.removeListener(_receivePlatformRoutes);
    super.dispose();
  }

  /// Does nothing itself: while it listens, the route information provider is registered with [WidgetsBinding] and
  /// keeps the routes the platform pushes.
  static void _receivePlatformRoutes() {}

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, LocaleState>(
      // A new language, or the end of restore, which lets the router in.
      buildWhen: (previous, current) => previous.locale != current.locale || previous is LocaleRestoring,
      builder: (context, localeState) => BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            scaffoldMessengerKey: widget.scaffoldMessengerKey,
            // The name the task switcher shows, in the app language.
            onGenerateTitle: (context) => S.of(context).app_title,
            theme: AppTheme.light(themeState.palette),
            darkTheme: AppTheme.dark(themeState.palette),
            themeMode: themeState.themeMode,
            themeAnimationDuration: Duration.zero,
            // Every scrollable in the app, on both platforms: no elastic overscroll and no overscroll glow (#418).
            scrollBehavior: const AppScrollBehavior(),
            // Off in every build, debug included. The owner does not want it on the emulator at all, and it is the
            // one thing on screen that no golden and no release build can show — so nothing but a person looking at
            // a device would ever report it. `app_test.dart` holds it off.
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
            locale: localeState.locale,
            routerConfig: _router!,
            // The router's first redirect must see the restored session: while the session is unknown it treats a
            // signed-in user as signed out, shows the login page and loses a deep link. So the router is mounted, and
            // its first route parsed, only once restore has settled the session. Later sign-ins and sign-outs are left
            // to its redirect. It also waits for the stored language, so the first page shows in it, and for whether
            // this device has shown the introduction, so a first run does not paint the login page and then jump.
            // The registry sits above the router, so the routes' onExit and the pages' UnsavedChangesScope find it.
            // AppStatusGate shows Studio's or Platform's unreachable page over it while that server does not answer
            // and keeps it mounted underneath, so the open pages and the session are as they were once it answers. In
            // a build with a Platform target each gate covers only its own target's session, and the login page shows
            // on each entry whether its server answers (AppTargetReachability); in a build without one, the Studio
            // gate also covers the restore and the login page.
            // AppLockGate covers all of it, the unreachable page included, with the lock screen while the app is
            // locked.
            builder: (context, router) => AppLockGate(
              router: _router!,
              child: RepositoryProvider<UnsavedChangesRegistry>.value(
                value: _unsavedChanges!,
                child: AppStatusGate(
                  child: AppTargetReachability(
                    child: BlocBuilder<SessionCubit, SessionState>(
                      buildWhen: (previous, current) => previous is SessionUnknown,
                      builder: (context, session) => switch (session) {
                        SessionUnknown() => const _RestoreView(),
                        SessionAuthenticated() || SessionUnauthenticated() => switch (localeState) {
                          LocaleRestoring() => const _RestoreView(),
                          LocaleReady() ||
                          LocaleChanging() ||
                          LocaleChangeFailure() => BlocBuilder<OnboardingCubit, OnboardingState>(
                            // The end of restore, which lets the router in. Nothing later changes what it shows.
                            buildWhen: (previous, current) => previous is OnboardingRestoring,
                            builder: (context, onboarding) => switch (onboarding) {
                              OnboardingRestoring() => const _RestoreView(),
                              OnboardingRequired() || OnboardingSeen() => router!,
                            },
                          ),
                        },
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shown while [SessionCubit.restore] reads the stored session, [LocaleCubit.restore] the stored language and
/// [OnboardingCubit.restore] whether this device has shown the introduction: a 56 px ring spinner with a 4 px stroke,
/// centered on the theme background.
class _RestoreView extends StatelessWidget {
  const _RestoreView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surface,
      child: Center(
        child: SizedBox.square(
          dimension: 56,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            strokeAlign: CircularProgressIndicator.strokeAlignInside,
            color: colorScheme.onSurfaceVariant,
            backgroundColor: colorScheme.outline,
            semanticsLabel: S.of(context).loading,
          ),
        ),
      ),
    );
  }
}
