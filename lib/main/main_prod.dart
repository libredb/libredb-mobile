import 'package:libredb_mobile/app/bootstrap/app_bootstrap.dart';
import 'package:libredb_mobile/app/bootstrap/app_bootstrap_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';

/// main entry point of PRODUCTION
void main() async {
  await AppBootstrap.run(
    const AppBootstrapConfig(
      environment: Environment.prod,
      defaultLanguage: 'en',
      defaultPalette: 'classic',
      defaultBrightness: 'dark',
    ),
  );
}
