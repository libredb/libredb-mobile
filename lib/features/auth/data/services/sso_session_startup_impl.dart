import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_auto_redirect_gate.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_session_startup.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/session_generation.dart';

/// [ISsoSessionStartup] over the token rotation and the stored session.
///
/// [run] checks the stored access token expiry: an access token that has expired is refreshed through [_rotation]
/// when a refresh token is stored, and the session ends when none is, or when the refresh is refused. A provider that
/// cannot be reached keeps the stored session.
///
/// Only the expiry the sign-in stored is checked, never a JWT `exp`, since a provider's access token need not be a
/// JWT. Nothing else uses the client at startup, and the client runs its operations one at a time.
///
/// An `oidc` sign-out runs [run] as well, so Studio's sign-out record goes out with an access token that has not expired.
///
/// The refresh follows the rules of `TokenRefreshInterceptor` for the session generation ([SessionGeneration]): an
/// answer that comes after the session ended is dropped, and what it stored while the session ended is taken back.
class SsoSessionStartup implements ISsoSessionStartup {
  SsoSessionStartup({
    required this._rotation,
    required this._secureStorage,
    required this._sessionRepository,
    required this._gate,
    this._now = DateTime.now,
  });

  static final _log = AppLogger.getLogger('SsoSessionStartup');

  final TokenRotation _rotation;
  final ISecureStorage _secureStorage;
  final IAuthSessionRepository _sessionRepository;
  final SsoAutoRedirectGate _gate;
  final DateTime Function() _now;

  @override
  Future<SsoStartupResult> run() async {
    // Noted before the first read: a wipe from here on ends it.
    final generation = SessionGeneration.current;
    final String? refreshToken;
    try {
      if (!_hasExpired(await _readExpiry())) return const SsoStartupUseStoredSession();
      refreshToken = await _secureStorage.read(SecureStorageKeys.refreshToken.key);
    } catch (error) {
      _logUnreadable(error);
      return _endSession(SsoSessionEndReason.storeUnreadable);
    }
    // The wipe that ended the session cleared it, and a session signed in to since must stay: nothing is ended again.
    if (SessionGeneration.hasEnded(generation)) return const SsoStartupSessionEnded(SsoSessionEndReason.endedElsewhere);
    if (refreshToken == null || refreshToken.isEmpty) {
      _log.info('startup: the access token has expired and no refresh token is stored, so the session ends');
      return _endSession(SsoSessionEndReason.noRefreshToken);
    }
    final result = await _rotation.rotate(refreshToken);
    if (SessionGeneration.hasEnded(generation)) {
      _log.warn('startup: the session ended while the refresh was on its way, so its answer is dropped');
      return const SsoStartupSessionEnded(SsoSessionEndReason.endedElsewhere);
    }
    switch (result) {
      case final TokensRotated rotated:
        final stored = _storedValues(rotated);
        try {
          await _store(stored);
        } catch (error) {
          _log.error('startup: the refreshed tokens could not be stored, so the session is cleared: {}', [
            error.runtimeType,
          ]);
          return _endSession(SsoSessionEndReason.refreshNotStored);
        }
        if (SessionGeneration.hasEnded(generation)) return _takeBackStored(stored);
        _log.info('startup: the expired access token was refreshed');
        return const SsoStartupUseStoredSession();
      case RotationRefused():
        _log.info('startup: the identity provider refused the refresh, so the session ends');
        return _endSession(SsoSessionEndReason.refreshRefused);
      case RotationUnavailable():
        _log.warn('startup: the identity provider could not be reached to refresh, so the stored session is kept');
        return const SsoStartupUseStoredSession();
    }
  }

  @override
  void giveUp() => _gate.close();

  Future<DateTime?> _readExpiry() async =>
      readAccessTokenExpiry(await _secureStorage.read(SecureStorageKeys.accessTokenExpiresAt.key));

  /// Whether the stored access token, which expires at [expiresAt], has to be refreshed. Without a stored expiry the
  /// stored session is read as it is.
  bool _hasExpired(DateTime? expiresAt) => expiresAt != null && !expiresAt.isAfter(_now());

  /// Logs that the stored session could not be read, which ends it.
  static void _logUnreadable(Object error) {
    // Only the type: the FormatException of a malformed expiry repeats the stored value.
    _log.error('startup: the stored session could not be read, so it is cleared: {}', [error.runtimeType]);
  }

  /// The fields of [rotated] that are present and not empty, in the order bearer, refresh token, ID token, expiry.
  static _StoredTokens _storedValues(TokensRotated rotated) {
    final expiresAt = rotated.accessTokenExpiresAt;
    return [
      for (final (key, value) in [
        (SecureStorageKeys.jwtToken, rotated.accessToken),
        (SecureStorageKeys.refreshToken, rotated.refreshToken),
        (SecureStorageKeys.oidcIdToken, rotated.oidcIdToken),
        (SecureStorageKeys.accessTokenExpiresAt, expiresAt == null ? null : encodeAccessTokenExpiry(expiresAt)),
      ])
        if (value != null && value.isNotEmpty) (key, value),
    ];
  }

  /// Writes [stored] in its order.
  Future<void> _store(_StoredTokens stored) async {
    for (final (key, value) in stored) {
      await _secureStorage.write(key.key, value);
    }
  }

  /// The session ended while [stored] was written, so the wipe may have run before a write landed: takes back what
  /// is still stored of it, and leaves a session stored since alone. A storage failure ends the session.
  Future<SsoStartupResult> _takeBackStored(_StoredTokens stored) async {
    _log.warn('startup: the session ended while the refreshed tokens were stored, so they are taken back');
    try {
      for (final (key, value) in stored) {
        if (await _secureStorage.read(key.key) == value) await _secureStorage.delete(key.key);
      }
    } catch (error) {
      _log.error('startup: the refreshed tokens could not be taken back, so the session is cleared: {}', [
        error.runtimeType,
      ]);
      return _endSession(SsoSessionEndReason.refreshNotStored);
    }
    return const SsoStartupSessionEnded(SsoSessionEndReason.endedElsewhere);
  }

  Future<SsoStartupResult> _endSession(SsoSessionEndReason reason) async {
    switch (await _sessionRepository.clear()) {
      case Success():
        break;
      case Failure(:final error):
        // Only the type: AuthSessionRepository.clear has logged the storage errors themselves.
        _log.error('startup: the stored session was not fully cleared: {}', [error.runtimeType]);
    }
    return SsoStartupSessionEnded(reason);
  }
}

/// The secure-storage values a refresh stored, in the order it wrote them.
typedef _StoredTokens = List<(SecureStorageKeys, String)>;
