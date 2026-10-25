import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/sso_auth_repository.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/storage/temporary_share_files.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// [ISsoAuthRepository] over [IOidcClient].
///
/// A sign-in becomes a session only when the verified ID token carries a string `sub` and `iss`. The session is then
/// persisted through [IAuthSessionRepository]: the access token is the bearer, and the OIDC ID token and the access
/// token's expiry go with it. No role and no username is read from a token: who the user is and what Studio lets them
/// do come only from Studio's `GET /api/auth/me`, which the sign-in asks next.
///
/// Before the session is stored, the files a share left ([TemporaryShareFiles]) are removed: a share the app was
/// killed in, followed by a session that ended without the wipe (a restore that timed out, lost tokens), would leave
/// them to the account that signs in next. A removal the phone refuses refuses the sign-in.
class SsoAuthRepository implements ISsoAuthRepository {
  SsoAuthRepository({required this._client, required this._sessionRepository, TemporaryShareFiles? shareFiles})
    : _shareFiles = shareFiles ?? TemporaryShareFiles();

  static final _log = AppLogger.getLogger('SsoAuthRepository');

  final IOidcClient _client;
  final IAuthSessionRepository _sessionRepository;
  final TemporaryShareFiles _shareFiles;

  @override
  Future<SsoProviderSignIn> signIn({required SessionTarget target}) async => _toResult(await _client.signIn(), target);

  Future<SsoProviderSignIn> _toResult(OidcSignInOutcome outcome, SessionTarget target) async => switch (outcome) {
    OidcSignedIn(:final tokens, :final claims) => await _persist(tokens, claims, target),
    OidcSignInCancelled() => const SsoProviderCancelled(),
    OidcSignInFailed(failure: OidcFailure.discovery) => const SsoProviderRejected(AppErrorCode.authOidcDiscovery),
    OidcSignInFailed(failure: OidcFailure.failed) => const SsoProviderRejected(AppErrorCode.authOidcFailed),
    OidcSignInFailed(failure: OidcFailure.insecureEndpoint) => const SsoProviderRejected(AppErrorCode.authOidcConfig),
    OidcSignInFailed(failure: OidcFailure.untrustedCertificate) => const SsoProviderRejected(
      AppErrorCode.networkCertInvalid,
    ),
  };

  Future<SsoProviderSignIn> _persist(OidcTokens tokens, Map<String, Object?> claims, SessionTarget target) async {
    if (_nonEmptyString(claims['sub']) == null || _nonEmptyString(claims['iss']) == null) {
      _log.warn('The ID token has no string sub or iss, so the sign-in is refused');
      return const SsoProviderRejected(AppErrorCode.authOidcNoClaims);
    }
    try {
      await _shareFiles.clear();
    } catch (e) {
      // The type only: the message of a file system error holds the path, which names an object.
      _log.error('The files a share left could not be removed, so the sign-in is refused: {}', [e.runtimeType]);
      return const SsoProviderRejected(AppErrorCode.authShareFilesNotRemoved);
    }
    final persisted = await _sessionRepository.persist(
      AuthSession(
        target: target,
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
