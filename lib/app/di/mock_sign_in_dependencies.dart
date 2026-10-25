import 'package:flutter/foundation.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/mock_oidc_client.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';

/// The [AppDependencies] of the mock entry point, which signs in without a Keycloak server: the identity provider is
/// [MockOidcClient], and the rest of the sign-in, Studio's `GET /api/auth/me` included, runs as in production
/// against the mocked API.
///
/// Debug builds only: the constructor throws in a profile or release build. Only the mock entry point and the
/// tests import it, so it is never compiled into an entry point that signs in through a real Keycloak
/// (`test/architecture/mock_sign_in_test.dart`).
class MockSignInDependencies extends AppDependencies {
  MockSignInDependencies({super.appConfig, super.projectLinks})
    : super(
        authMode: OidcAuthMode(OidcSettings(issuer: issuer, clientId: 'libredb-mobile-local')),
      ) {
    if (!kDebugMode) throw StateError('The mock sign-in runs only in a debug build');
  }

  /// The issuer of the mock account, a name that never resolves.
  static final issuer = Uri.parse('https://local-sign-in.invalid');

  @override
  IOidcClient createOidcClient(OidcSettings settings) => MockOidcClient(issuer: settings.issuer);
}
