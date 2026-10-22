import 'dart:convert';

import 'package:libredb_mobile/shared/models/studio_identity.dart';

/// Reads Studio's `GET /api/auth/me`: `{"authenticated": true, "user": {role, username, idpSubject?, idpIssuer?, iat,
/// exp, channel?}}`.
final class StudioIdentityModel {
  const StudioIdentityModel._();

  /// Throws a [FormatException] for an answer that is not signed in, lacks the username, or names an unknown role.
  static StudioIdentity fromJsonString(String body) {
    final decoded = jsonDecode(body);
    final user = decoded is Map<String, dynamic> && decoded['authenticated'] == true ? decoded['user'] : null;
    if (user is! Map<String, dynamic>) throw const FormatException('The session answer is not signed in');
    final username = user['username'];
    if (username is! String || username.isEmpty) throw const FormatException('The session has no username');
    final role = switch (user['role']) {
      'admin' => StudioRole.admin,
      'user' => StudioRole.user,
      _ => throw const FormatException('The session names an unknown role'),
    };
    final exp = user['exp'];
    return StudioIdentity(
      username: username,
      role: role,
      subject: user['idpSubject'] is String ? user['idpSubject'] as String : null,
      issuer: user['idpIssuer'] is String ? user['idpIssuer'] as String : null,
      expiresAt: exp is int ? DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true) : null,
      viaBearer: user['channel'] == 'bearer',
    );
  }

  /// Reads Studio's `POST /api/auth/logout` answer, `{"success": true}`.
  ///
  /// The answer only says Studio accepted the request: Studio gives it as well when the bearer is expired or refused
  /// and it writes no audit line, so it does not prove the sign-out was recorded.
  ///
  /// Throws a [FormatException] for an answer that does not say the logout succeeded.
  static void readSignOutAccepted(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
      throw const FormatException('The logout answer does not say the logout succeeded');
    }
  }
}
