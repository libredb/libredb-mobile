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
    this.preferredOrientations = const [DeviceOrientation.portraitUp],
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

  /// The app is held upright on every form factor, so this is `portraitUp` alone and no device can rotate it (#419).
  /// `ios/Runner/Info.plist` lists the same one orientation for both the iPhone and the iPad key, and `.MainActivity`
  /// fixes it in the Android manifest, so neither platform can draw a landscape frame before this call.
  /// No form factor is exempted, because an exemption would protect nothing: the only layout a rotation reaches is the
  /// one `AppBreakpoints.isCompactHeight` gates, a screen height below 480, and only a phone on its side reports that
  /// in full screen. What still reaches it is a window the system sizes — a split-screen or free-form window, which
  /// ignores an orientation restriction anyway — so `ResponsiveScaffold`'s rail stays live without this list's help.
  final List<DeviceOrientation> preferredOrientations;

  bool get isProduction => environment == Environment.prod;
}
