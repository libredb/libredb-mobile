import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/sso_auth_repository.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';

/// [ISsoAuthRepository] over [IOidcClient].
///
/// A sign-in becomes a session only when the verified ID token carries a string `sub` and `iss`. The session is then
/// persisted through [IAuthSessionRepository]: the access token is the bearer, and the OIDC ID token and the access
/// token's expiry go with it. No role and no username is read from a token: who the user is and what Studio lets them
/// do come only from Studio's `GET /api/auth/me`, which the sign-in asks next.
class SsoAuthRepository implements ISsoAuthRepository {
  SsoAuthRepository({required this._client, required this._sessionRepository});

  static final _log = AppLogger.getLogger('SsoAuthRepository');

  final IOidcClient _client;
  final IAuthSessionRepository _sessionRepository;

  @override
  Future<SsoProviderSignIn> signIn() async => _toResult(await _client.signIn());

  Future<SsoProviderSignIn> _toResult(OidcSignInOutcome outcome) async => switch (outcome) {
    OidcSignedIn(:final tokens, :final claims) => await _persist(tokens, claims),
    OidcSignInCancelled() => const SsoProviderCancelled(),
    OidcSignInFailed(failure: OidcFailure.discovery) => const SsoProviderRejected(AppErrorCode.authOidcDiscovery),
    OidcSignInFailed(failure: OidcFailure.failed) => const SsoProviderRejected(AppErrorCode.authOidcFailed),
  };

  Future<SsoProviderSignIn> _persist(OidcTokens tokens, Map<String, Object?> claims) async {
    if (_nonEmptyString(claims['sub']) == null || _nonEmptyString(claims['iss']) == null) {
      _log.warn('The ID token has no string sub or iss, so the sign-in is refused');
      return const SsoProviderRejected(AppErrorCode.authOidcNoClaims);
    }
    final persisted = await _sessionRepository.persist(
      AuthSession(
        idToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        oidcIdToken: tokens.idToken,
        accessTokenExpiresAt: tokens.accessTokenExpiresAt,
      ),
    );
    switch (persisted) {
      case Success():
        _log.info('Signed in through the identity provider');
        return const SsoProviderSignedIn();
      case Failure(:final error):
        _log.error('The single sign-on session could not be stored: {}', [error.message]);
        return const SsoProviderRejected(AppErrorCode.authSessionPersistFailed);
    }
  }

  static String? _nonEmptyString(Object? value) => value is String && value.isNotEmpty ? value : null;
}
