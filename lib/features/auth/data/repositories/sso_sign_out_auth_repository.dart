import 'dart:async';

import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/sso_sign_out_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_session_startup.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';

/// The [IAuthRepository] whose logout also ends the user's session at the identity provider.
///
/// Only a logout the user starts comes here: an idle timeout or an unrefreshable 401 clears the local session through
/// `SessionCubit`, since a provider logout needs a browser and the user is not there. Everything else is [_inner]'s.
/// The app signs out through [signOut], which answers before the provider logout has ended.
class SsoSignOutAuthRepository implements IAuthRepository, ISsoSignOutRepository {
  SsoSignOutAuthRepository({
    required this._inner,
    required this._client,
    required this._secureStorage,
    required this._settings,
    required this._studioIdentity,
    required this._sessionRefresh,
    this._studioSignOutTimeout = defaultStudioSignOutTimeout,
    this._now = DateTime.now,
  });

  /// How long a sign-out waits for the refresh of an expired access token and for Studio to record it, together,
  /// before it goes on without the record.
  static const defaultStudioSignOutTimeout = Duration(seconds: 3);

  static final _log = AppLogger.getLogger('SsoSignOutAuthRepository');

  final IAuthRepository _inner;
  final IOidcClient _client;
  final ISecureStorage _secureStorage;
  final OidcSettings _settings;
  final IStudioIdentityRepository _studioIdentity;

  /// The startup step's refresh of an expired stored access token, which also ends a session it cannot refresh.
  final ISsoSessionStartup _sessionRefresh;
  final Duration _studioSignOutTimeout;
  final DateTime Function() _now;

  /// Reads the stored ID token, records the sign-out at Studio, clears the local session through [_inner], starts the
  /// provider logout, and answers [_inner]'s result as [SsoSignOut.cleared] without waiting for the provider.
  ///
  /// Studio's record needs a valid access token, so it is sent before the wipe, and an expired stored access token is
  /// refreshed first: Studio writes no audit line for an expired token and still answers 200. The sign-out waits for
  /// both for a short timeout, [defaultStudioSignOutTimeout] unless the constructor gives another, and goes on whatever
  /// they answer: an unreachable or failing provider or Studio must not keep the user signed in.
  ///
  /// The ID token is sent as `id_token_hint` when `OIDC_LOGOUT_HINT` is on. It is written, rolled back and wiped
  /// together with the session it belongs to, so it is always the current session's, and it is sent even when it has
  /// expired: Keycloak gives it the access token's short life and still accepts it at its logout endpoint. It is read
  /// before the refresh, because a refresh that ends the session also deletes it.
  ///
  /// [SsoSignOut.providerLogout] fails with an [AuthError] of [AppErrorCode.authOidcLogoutIncomplete] when the
  /// provider logout failed.
  @override
  Future<SsoSignOut> signOut() async {
    String? idToken;
    try {
      idToken = await _secureStorage.read(SecureStorageKeys.oidcIdToken.key);
    } catch (error) {
      // Only the type: the error of a secure store may carry what it holds.
      _log.warn('logout: the stored ID token could not be read, so the provider logout sends no hint: {}', [
        error.runtimeType,
      ]);
    }
    await _recordSignOutAtStudio();
    final cleared = await _inner.logout();
    return SsoSignOut(cleared: cleared, providerLogout: _endProviderSession(_settings.logoutHint ? idToken : null));
  }

  /// Refreshes an expired stored access token, then asks Studio once to record the sign-out in its audit trail, and
  /// gives up on both after [_studioSignOutTimeout].
  ///
  /// A sign-out that leaves Studio without a record writes exactly one warn line naming the reason, never a token, a
  /// header, an answer body or Studio's error text. Once the budget has passed the attempt is abandoned: a refresh
  /// still on its way neither sends the record nor logs, and a request still on its way is left to end on its own.
  Future<void> _recordSignOutAtStudio() async {
    final attempt = _RecordAttempt();
    String? missed;
    try {
      missed = await _refreshThenRecord(attempt).timeout(_studioSignOutTimeout);
    } on TimeoutException {
      attempt.abandoned = true;
      missed = 'budget passed';
    }
    if (missed != null) _log.warn('logout: Studio has no record of this sign-out: {}', [missed]);
  }

  /// Answers null when Studio accepted the record, else the reason it has none. Never throws.
  Future<String?> _refreshThenRecord(_RecordAttempt attempt) async {
    try {
      switch (await _sessionRefresh.run()) {
        case SsoStartupUseStoredSession():
          break;
        case SsoStartupSessionEnded(:final reason):
          return _endReason(reason);
        case SsoStartupSignInFailed(:final errorCode):
          return errorCode.key;
      }
      // The startup step keeps an expired session when the provider cannot be reached, and Studio records nothing
      // for an expired bearer, so the expiry is read again and such a bearer is never sent.
      final DateTime? expiresAt;
      try {
        expiresAt = readAccessTokenExpiry(await _secureStorage.read(SecureStorageKeys.accessTokenExpiresAt.key));
      } catch (_) {
        return 'store unreadable';
      }
      if (expiresAt != null && !expiresAt.isAfter(_now())) return 'provider unreachable';
      if (attempt.abandoned) return null;
      switch (await _studioIdentity.recordSignOut()) {
        case Success():
          return null;
        case Failure(:final error):
          return error.code ?? error.runtimeType.toString();
      }
    } catch (error) {
      // Only the type: the sign-out goes on without Studio's record.
      return error.runtimeType.toString();
    }
  }

  static String _endReason(SsoSessionEndReason reason) => switch (reason) {
    SsoSessionEndReason.storeUnreadable => 'store unreadable',
    SsoSessionEndReason.noRefreshToken => 'no refresh token',
    SsoSessionEndReason.refreshRefused => 'refresh refused',
    SsoSessionEndReason.refreshNotStored => 'refresh not stored',
    SsoSessionEndReason.endedElsewhere => 'session already ended',
  };

  Future<Result<void>> _endProviderSession(String? idTokenHint) async {
    switch (await _client.endProviderSession(idTokenHint: idTokenHint)) {
      case ProviderLogoutFailed():
        _log.warn('logout: signed out of the app, but the session at the identity provider may still be active');
        return Failure(AuthError('provider logout incomplete', code: AppErrorCode.authOidcLogoutIncomplete.key));
      case ProviderSessionEnded() || NoProviderLogout():
        return const Success(null);
    }
  }

  /// [signOut], answered once the provider logout has ended as well.
  ///
  /// The answer is [_inner]'s, except that a failed provider logout after a clean wipe is an [AuthError] with
  /// [AppErrorCode.authOidcLogoutIncomplete]. A failed wipe wins over it: data left on this device matters more.
  @override
  Future<Result<void>> logout() async {
    final signedOut = await signOut();
    final providerLogout = await signedOut.providerLogout;
    return signedOut.cleared is Failure ? signedOut.cleared : providerLogout;
  }
}

/// One try at Studio's sign-out record, [abandoned] once its budget has passed.
class _RecordAttempt {
  bool abandoned = false;
}
