import 'package:flutter/services.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';

class AppBootstrapConfig {
  const AppBootstrapConfig({
    required this.environment,
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
  final String defaultLanguage;
  final String defaultPalette;
  final String defaultBrightness;

  /// Phones rotate between portrait and both landscape sides; the upside-down portrait stays off, as on most phones.
  /// `ios/Runner/Info.plist` lists the same three for the iPhone.
  final List<DeviceOrientation> preferredOrientations;

  bool get isProduction => environment == Environment.prod;
}
