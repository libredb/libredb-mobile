import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/bootstrap/app_bootstrap_config.dart';
import 'package:libredb_mobile/app/bootstrap/app_licenses.dart';
import 'package:libredb_mobile/app/bootstrap/sentry_device_check.dart';
import 'package:libredb_mobile/app/bootstrap/sentry_start.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/app/analytics/crash_reporter.dart';
import 'package:libredb_mobile/app/dev_console/time_travel/time_travel_bloc_observer.dart';
import 'package:libredb_mobile/core/logging/app_bloc_observer.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/connectivity/connectivity_service.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/shared/utils/app_constants.dart';

/// Builds the [AppDependencies] of a run from its [AppConfig].
typedef AppDependenciesFactory = AppDependencies Function(AppConfig appConfig);

class AppBootstrap {
  /// Starts the app as [config] says. [dependencies] builds what the app runs on, [definedDependencies] unless
  /// `main_local.dart` passes its local sign-in. [sentry] decides whether Sentry starts and starts it; a test passes
  /// its own.
  static Future<void> run(
    AppBootstrapConfig config, {
    AppDependenciesFactory dependencies = definedDependencies,
    @visibleForTesting SentryStart sentry = const SentryStart(),
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    registerAppLicenses();

    await AppConstants.initPackageInfo();

    AppLogger.configure(isProduction: config.isProduction);
    final log = AppLogger.getLogger('AppBootstrap');

    // Decided before anything reads the config: when Sentry may not start (a release build whose Android host did not
    // start the native SDK), the config loses its DSN, so the app runs exactly as without one.
    final appConfig = await sentry.gate(AppConfig.fromEnvironment(config.environment));
    final appDependencies = dependencies(appConfig);
    final secureStorage = appDependencies.createSecureStorage();

    final existingPalette = await AppLocalStorage().read(StorageKeys.theme.key);
    if (existingPalette == null) {
      await AppLocalStorage().save(StorageKeys.theme.key, config.defaultPalette);
    }
    // Don't save default brightness — let ThemeBloc use ThemeMode.system when no preference exists
    await AppLocalStorageCached.loadCache();

    // Connectivity monitoring
    await ConnectivityService.instance.initialize();

    // Analytics & crash reporting. When `--dart-define=SENTRY_DSN=...`
    // is provided in a production build, [AppDependencies] returns the
    // Sentry-backed implementation. Anywhere else, the local-only
    // logging implementation.
    //
    // CrashReporter always installs framework / PlatformDispatcher hooks for
    // local logging. When Sentry is active it installs its OWN hooks that both
    // capture the error and chain to ours, so we must NOT also forward uncaught
    // errors to the Sentry-backed analytics here — doing so reports every crash
    // twice. With Sentry off, forwarding to the local logging analytics is the
    // only sink, so it stays enabled.
    final analytics = appDependencies.createAnalyticsService();
    final sentryActive = appConfig.sentryDsn != null;
    CrashReporter.install(analytics, forwardToAnalytics: !sentryActive);

    Bloc.observer = kDebugMode ? TimeTravelBlocObserver() : AppBlocObserver();

    await SystemChrome.setPreferredOrientations(config.preferredOrientations);

    log.info('Starting app with env: {}, default language: {}, palette: {}, brightness: {}', [
      config.environment.name,
      config.defaultLanguage,
      config.defaultPalette,
      config.defaultBrightness,
    ]);

    // Hand the ISecureStorage created above to App so the entire widget tree shares one adapter instance, and
    // overriding it for tests or alternate environments is a single hand-off.
    // The Sentry options are configureSentryOptions (lib/app/bootstrap/sentry_start.dart). On Android the host app
    // starts the native SDK, so a native option set there must also be set in NativeSentry.kt of the Android host app
    // (under android/app/src/main/kotlin).
    await sentry.run(
      appConfig.sentryDsn,
      release: '${AppConstants.appVersion}+${AppConstants.appBuildNumber}',
      appRunner: () {
        runApp(
          App(
            language: config.defaultLanguage,
            dependencies: appDependencies,
            secureStorage: secureStorage,
            analytics: analytics,
          ),
        );
        // The device check of docs/crash-reporting.md, absent from every build without its define.
        if (sentryDeviceCheckDefined) runSentryDeviceCheck(analytics);
      },
    );
  }

  /// The [AppDependencies] of a build that signs in through the identity provider its `OIDC_*` defines name. An
  /// invalid OpenID Connect configuration does not stop the app: it starts, and the login page says that single
  /// sign-on is not configured correctly.
  static AppDependencies definedDependencies(AppConfig appConfig) {
    final authMode = AuthMode.fromDefines(const AuthDefines());
    if (authMode case OidcMisconfiguredAuthMode(:final reason)) {
      AppLogger.getLogger('AppBootstrap').error('OIDC configuration is invalid: {}', [reason]);
    }
    return AppDependencies(appConfig: appConfig, authMode: authMode);
  }
}
