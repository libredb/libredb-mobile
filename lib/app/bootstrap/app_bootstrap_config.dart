import 'package:flutter/services.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';

class AppBootstrapConfig {
  const AppBootstrapConfig({
    required this.environment,
    this.authDefines = const AuthDefines(),
    this.apiBaseUrl = AppConfig.prodApiUrl,
    this.platformApiUrl = AppConfig.platformApiUrl,
    this.defaultLanguage = 'en',
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

  final String defaultLanguage;
  final String defaultPalette;
  final String defaultBrightness;

  /// Phones rotate between portrait and both landscape sides; the upside-down portrait stays off, as on most phones.
  /// `ios/Runner/Info.plist` lists the same three for the iPhone.
  final List<DeviceOrientation> preferredOrientations;

  bool get isProduction => environment == Environment.prod;
}
