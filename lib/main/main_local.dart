import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/app/bootstrap/app_bootstrap.dart';
import 'package:libredb_mobile/app/bootstrap/app_bootstrap_config.dart';
import 'package:libredb_mobile/app/bootstrap/debug_session_seed.dart';
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
  // On-device local twin only: when `--dart-define=SEED_SESSION=true` carries a session from a one-time host sign-in
  // (scripts/on-device-local-twin.sh), write it into secure storage before the app reads it, so the test lands on
  // the connection list without the Keycloak Custom Tab that integration_test cannot drive. A no-op in a normal run,
  // and compiled into this entry point only (test/architecture/debug_session_seed_isolation_test.dart).
  final seed = DebugSessionSeed.fromEnvironment();
  if (seed != null) {
    WidgetsFlutterBinding.ensureInitialized();
    await seed.seed();
  }

  await AppBootstrap.run(
    const AppBootstrapConfig(
      environment: Environment.local,
      authDefines: AuthDefines(
        oidcIssuer: String.fromEnvironment('OIDC_ISSUER', defaultValue: 'https://sso.lab.test/realms/libredb'),
        oidcClientId: String.fromEnvironment('OIDC_CLIENT_ID', defaultValue: 'libredb-mobile'),
      ),
      apiBaseUrl: String.fromEnvironment('PROD_API_URL', defaultValue: 'https://studio.lab.test/api'),
      platformApiUrl: String.fromEnvironment('PLATFORM_API_URL', defaultValue: 'https://libredb.lab.test/api'),
      defaultPalette: 'classic',
      defaultBrightness: 'light',
    ),
  );
}
