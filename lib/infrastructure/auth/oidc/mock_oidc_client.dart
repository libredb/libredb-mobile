import 'package:flutter/foundation.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';

/// A stand-in for the identity provider, so `main_local.dart` and the tests sign in against the mocked Studio of
/// `assets/mock/` without a Keycloak server.
///
/// It answers every sign-in at once with tokens that the mock API accepts and every refresh with new ones, and has no
/// provider logout. Everything above [IOidcClient] runs as in production: the session is stored, Studio's
/// `GET /api/auth/me` answers from `assets/mock/GET_auth_me.json`, and a 401 refreshes through the token rotation.
///
/// Debug builds only: the constructor throws in a profile or release build, and `main_prod.dart` never imports it
/// (`test/architecture/local_sign_in_test.dart`).
final class MockOidcClient implements IOidcClient {
  MockOidcClient({required Uri issuer, DateTime Function() now = DateTime.now})
    // ignore: prefer_initializing_formals
    : _issuer = issuer,
      // ignore: prefer_initializing_formals
      _now = now {
    if (!kDebugMode) throw StateError('The mock sign-in double runs only in a debug build');
  }

  static final _log = AppLogger.getLogger('MockOidcClient');

  /// How long the tokens of a sign-in or a refresh are valid.
  static const tokenLifetime = Duration(hours: 1);

  /// The access token the mock API accepts: it is not shaped like a JWT, so `MockInterceptor` never finds it expired.
  static const accessToken = 'MOCK_TOKEN';

  /// The claims of the mock account.
  static const subject = 'local-user';
  static const email = 'admin@example.com';

  final Uri _issuer;
  final DateTime Function() _now;

  @override
  Future<OidcSignInOutcome> signIn() async {
    _log.warn('Signed in through the mock sign-in double, not an identity provider');
    return OidcSignedIn(
      tokens: OidcTokens(
        accessToken: accessToken,
        idToken: 'LOCAL_ID_TOKEN',
        refreshToken: 'LOCAL_REFRESH_TOKEN',
        accessTokenExpiresAt: _now().toUtc().add(tokenLifetime),
      ),
      claims: {'iss': _issuer.toString(), 'sub': subject, 'email': email},
    );
  }

  @override
  Future<TokenRotationResult> refresh({
    required String refreshToken,
    required String idToken,
    required String accessToken,
    required DateTime accessTokenExpiresAt,
  }) async => TokensRotated(
    accessToken: MockOidcClient.accessToken,
    refreshToken: 'LOCAL_REFRESH_TOKEN',
    oidcIdToken: 'LOCAL_ID_TOKEN',
    accessTokenExpiresAt: _now().toUtc().add(tokenLifetime),
  );

  /// There is no provider session to end.
  @override
  Future<OidcLogoutOutcome> endProviderSession({String? idTokenHint}) async => const NoProviderLogout();
}
