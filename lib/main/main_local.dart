import 'package:libredb_mobile/app/bootstrap/app_bootstrap.dart';
import 'package:libredb_mobile/app/bootstrap/app_bootstrap_config.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';

/// Entry point for the LibreDB stack in the Lima VM `libredb-lab`: a real Studio, a real Platform and a real Keycloak
/// on the developer's own machine. Nothing is mocked, so this is where a change meets a server that answers like
/// production without being it.
///
/// The addresses below are defaults, so the build starts with no flags:
/// `fvm flutter run --target lib/main/main_local.dart`
/// Each one is still a `--dart-define`, so the same entry point can be pointed at another development stack, for
/// example `--dart-define=PROD_API_URL=https://localhost:9443/api`.
///
/// The VM is reachable from the Mac only: `lab.test` resolves through `/etc/hosts`, so a device needs its own route
/// to it. Start the stack with `limactl start libredb-lab`.
void main() async {
  await AppBootstrap.run(
    const AppBootstrapConfig(
      environment: Environment.local,
      authDefines: AuthDefines(
        oidcIssuer: String.fromEnvironment('OIDC_ISSUER', defaultValue: 'https://sso.lab.test/realms/libredb'),
        oidcClientId: String.fromEnvironment('OIDC_CLIENT_ID', defaultValue: 'libredb-mobile'),
      ),
      apiBaseUrl: String.fromEnvironment('PROD_API_URL', defaultValue: 'https://studio.lab.test/api'),
      platformApiUrl: String.fromEnvironment('PLATFORM_API_URL', defaultValue: 'https://libredb.lab.test/api'),
      defaultLanguage: 'en',
      defaultPalette: 'classic',
      defaultBrightness: 'light',
    ),
  );
}
