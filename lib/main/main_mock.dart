import 'package:libredb_mobile/app/bootstrap/app_bootstrap.dart';
import 'package:libredb_mobile/app/bootstrap/app_bootstrap_config.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';

/// Entry point for work that needs no backend: `MockInterceptor` answers every request from `assets/mock/`, and
/// [MockSignInDependencies] stands in for Keycloak, so the app signs in without a server.
///
/// It names no URL, because it calls nothing. Run it with:
/// `fvm flutter run --target lib/main/main_mock.dart`
void main() async {
  await AppBootstrap.run(
    const AppBootstrapConfig(
      environment: Environment.mock,
      defaultLanguage: 'en',
      defaultPalette: 'classic',
      defaultBrightness: 'light',
    ),
    dependencies: (appConfig) => MockSignInDependencies(appConfig: appConfig),
  );
}
