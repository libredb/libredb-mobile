import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:libredb_mobile/app/localization/startup_language.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';

class AppBootstrapConfig {
  const AppBootstrapConfig({
    required this.environment,
    this.authDefines = const AuthDefines(),
    this.apiBaseUrl = AppConfig.prodApiUrl,
    this.platformApiUrl = AppConfig.platformApiUrl,
    this.defaultLanguage,
    this.defaultPalette = 'classic',
    this.defaultBrightness = 'light',
    this.preferredOrientations = const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
  });

  final Environment environment;

  /// How the user signs in. Each entry point decides its own provider: `main_mock.dart` never reaches these, because
  /// it passes its own dependencies, while `main_local.dart` and `main_prod.dart` name a real Keycloak. Every value
  /// defaults to its `--dart-define`, so a build can still be pointed elsewhere.
  final AuthDefines authDefines;

  /// LibreDB Studio's API, its origin plus `/api`. Defaults to the `PROD_API_URL` define; an entry point passes its
  /// own so it starts without flags.
  final String apiBaseUrl;

  /// LibreDB Platform's API, its origin plus `/api`, or empty for a build without Platform mode. Defaults to the
  /// `PLATFORM_API_URL` define.
  final String platformApiUrl;

  /// The language this build opens in whatever the phone says, or null — the default — to follow the phone.
  ///
  /// It stays an override so a test can pin a language and a future build can ship in one; every entry point leaves
  /// it out, because a Turkish phone should see its first run, onboarding included, in Turkish.
  final String? defaultLanguage;

  final String defaultPalette;
  final String defaultBrightness;

  /// Phones rotate between portrait and both landscape sides; the upside-down portrait stays off, as on most phones.
  /// `ios/Runner/Info.plist` lists the same three for the iPhone.
  final List<DeviceOrientation> preferredOrientations;

  bool get isProduction => environment == Environment.prod;

  /// The language the app opens in before one is stored on the device: [defaultLanguage] when this build pins one,
  /// otherwise the phone's own language if the app has it and English if it does not.
  ///
  /// [deviceLocales] defaults to what the engine reports for this device. A caller passes its own only to resolve a
  /// language for a device that is not this one, which is what the tests do.
  String startupLanguage({Iterable<Locale>? deviceLocales}) =>
      defaultLanguage ??
      resolveStartupLanguage(deviceLocales ?? PlatformDispatcher.instance.locales, S.delegate.supportedLocales);
}
