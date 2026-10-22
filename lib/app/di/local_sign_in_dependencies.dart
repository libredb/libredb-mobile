import 'package:flutter/foundation.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/local_oidc_client.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';

/// The [AppDependencies] of `main_local.dart`, which signs in without a Keycloak server: the identity provider is
/// [LocalOidcClient], and the rest of the sign-in, Studio's `GET /api/auth/me` included, runs as in production
/// against the mocked API.
///
/// Debug builds only: the constructor throws in a profile or release build. Only `main_local.dart` and the tests
/// import it, so it is never compiled into `main_prod.dart` (`test/architecture/local_sign_in_test.dart`).
class LocalSignInDependencies extends AppDependencies {
  LocalSignInDependencies({super.appConfig, super.projectLinks})
    : super(
        authMode: OidcAuthMode(OidcSettings(issuer: issuer, clientId: 'libredb-mobile-local')),
      ) {
    if (!kDebugMode) throw StateError('The local sign-in runs only in a debug build');
  }

  /// The issuer of the local account, a name that never resolves.
  static final issuer = Uri.parse('https://local-sign-in.invalid');

  @override
  IOidcClient createOidcClient(OidcSettings settings) => LocalOidcClient(issuer: settings.issuer);
}
