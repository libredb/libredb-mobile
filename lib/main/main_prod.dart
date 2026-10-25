import 'package:libredb_mobile/app/bootstrap/app_bootstrap.dart';
import 'package:libredb_mobile/app/bootstrap/app_bootstrap_config.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';

/// Entry point for PRODUCTION: LibreDB Studio and Keycloak as this deployment runs them.
///
/// The defaults below are this deployment's, so a hand-built APK needs no flags. They decide nothing else: the release
/// workflow passes every value explicitly from the repository variables, and `AppConfig.fromEnvironment` runs the same
/// checks on whatever the build ends up with — an empty `PROD_API_URL` still stops the app at start, and a non-https
/// override still refuses to build a session. Another organization points the app at its own Studio with
/// `--dart-define`, which is the only path, by design.
///
/// `PLATFORM_API_URL` has no default on purpose. The store build stays Studio-only until the owner approves it
/// ([docs/platform.md](../../docs/platform.md), [docs/release.md](../../docs/release.md); the team ledger carries the
/// same ruling), and a committed default would cross that line silently; the release workflow passes it only from
/// the owner's variable. To reach Platform from a hand-built APK, pass it:
/// `--dart-define=PLATFORM_API_URL=https://platform-dev.libredb.org/api`
void main() async {
  await AppBootstrap.run(
    const AppBootstrapConfig(
      environment: Environment.prod,
      authDefines: AuthDefines(
        oidcIssuer: String.fromEnvironment('OIDC_ISSUER', defaultValue: 'https://auth-dev.libredb.org/realms/libredb'),
        oidcClientId: String.fromEnvironment('OIDC_CLIENT_ID', defaultValue: 'libredb-mobile'),
      ),
      apiBaseUrl: String.fromEnvironment('PROD_API_URL', defaultValue: 'https://studio-dev.libredb.org/api'),
      defaultLanguage: 'en',
      defaultPalette: 'classic',
      defaultBrightness: 'dark',
    ),
  );
}
