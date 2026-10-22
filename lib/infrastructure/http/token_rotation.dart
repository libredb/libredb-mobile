import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/logging/log_sanitizer.dart';

/// Decides whether a 401 means that the bearer is no longer valid, which is what makes `TokenRefreshInterceptor`
/// refresh the session, and end it when the refresh cannot fix the 401.
typedef SessionExpiredPredicate = bool Function(DioException error);

/// Decides whether a 401 for a request sent again with the token a refresh has just issued means that the server
/// refuses the session, which ends it. Any other 401 then reaches the caller and leaves the session as it is.
typedef SessionRefusedPredicate = bool Function(DioException error);

/// The default [SessionExpiredPredicate] and [SessionRefusedPredicate]: every 401 means the bearer is no longer valid.
bool isUnauthorized(DioException error) => error.response?.statusCode == 401;

/// How a token rotation ended.
sealed class TokenRotationResult {
  const TokenRotationResult();
}

/// The rotation gave a new access token, the new refresh token when the server rotates it, the new ID token when one is
/// returned, and the new access token's expiry.
final class TokensRotated extends TokenRotationResult {
  const TokensRotated({required this.accessToken, this.refreshToken, this.oidcIdToken, this.accessTokenExpiresAt});

  final String accessToken;
  final String? refreshToken;
  final String? oidcIdToken;
  final DateTime? accessTokenExpiresAt;

  /// Masks every token, so a log line that prints the result does not print a credential.
  @override
  String toString() =>
      'TokensRotated(accessToken: ${maskToken(accessToken)}, refreshToken: ${maskToken(refreshToken)}, '
      'oidcIdToken: ${maskToken(oidcIdToken)}, accessTokenExpiresAt: $accessTokenExpiresAt)';
}

/// The server refused the refresh token, or its answer was unusable: the session ends.
final class RotationRefused extends TokenRotationResult {
  const RotationRefused();
}

/// The server could not be reached: the session is kept, the request fails as a network error, and the next 401
/// tries the rotation again.
final class RotationUnavailable extends TokenRotationResult {
  const RotationUnavailable();
}

/// Trades a refresh token for new tokens. `TokenRefreshInterceptor` calls it once per refresh, and stores what it
/// returns; an implementation stores nothing itself.
abstract interface class TokenRotation {
  Future<TokenRotationResult> rotate(String refreshToken);
}

/// A [TokenRotation] that refuses every refresh and sends nothing, so the 401 ends the session.
///
/// A misconfigured build cannot reach the identity provider, so a session that an earlier build stored is never
/// refreshed.
final class RefusingTokenRotation implements TokenRotation {
  const RefusingTokenRotation();

  static final _log = AppLogger.getLogger('RefusingTokenRotation');

  @override
  Future<TokenRotationResult> rotate(String refreshToken) async {
    _log.warn('The session cannot be refreshed: single sign-on is not configured correctly in this build');
    return const RotationRefused();
  }
}
