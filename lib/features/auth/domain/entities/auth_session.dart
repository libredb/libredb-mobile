import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/core/logging/log_sanitizer.dart';

/// The tokens of a sign-in through the identity provider, which the application layer hands to the session
/// repository as one atom. The storage shape is the repository's concern.
///
/// [idToken] is the access token, the bearer LibreDB Studio accepts; the name is that of its storage key. [oidcIdToken]
/// is the provider's ID token and [accessTokenExpiresAt] the access token's expiry from the token response.
///
/// The session holds no username and no role: who the user is and what Studio lets them do come only from Studio's
/// `GET /api/auth/me`, never from a token, and are never stored.
class AuthSession extends Equatable {
  const AuthSession({required this.idToken, this.refreshToken, this.oidcIdToken, this.accessTokenExpiresAt})
    : assert(idToken != '', 'idToken must be non-empty');

  final String idToken;
  final String? refreshToken;
  final String? oidcIdToken;
  final DateTime? accessTokenExpiresAt;

  @override
  List<Object?> get props => [idToken, refreshToken, oidcIdToken, accessTokenExpiresAt];

  /// Whether the session carries the provider's ID token, outside [toString], which names the token only inside
  /// `maskToken`.
  bool get _hasOidcIdToken => oidcIdToken != null;

  /// Tokens are masked so this is safe to embed in log output. A field that is null is left out.
  @override
  String toString() =>
      'AuthSession('
      'idToken: ${maskToken(idToken)}, '
      'refreshToken: ${maskToken(refreshToken)}'
      '${_hasOidcIdToken ? ', oidcIdToken: ${maskToken(oidcIdToken)}' : ''}'
      '${accessTokenExpiresAt == null ? '' : ', accessTokenExpiresAt: $accessTokenExpiresAt'})';
}
