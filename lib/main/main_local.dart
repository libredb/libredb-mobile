import 'package:libredb_mobile/app/bootstrap/app_bootstrap.dart';
import 'package:libredb_mobile/app/bootstrap/app_bootstrap_config.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';

/// main entry point of local computer development: the mocked API of `assets/mock/`, and a debug-only stand-in for
/// the identity provider, so the app signs in without a Keycloak server.
void main() async {
  await AppBootstrap.run(
    const AppBootstrapConfig(
      environment: Environment.dev,
      defaultLanguage: 'en',
      defaultPalette: 'classic',
      defaultBrightness: 'light',
    ),
    dependencies: (appConfig) => LocalSignInDependencies(appConfig: appConfig),
  );
}
