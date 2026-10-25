import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';

abstract class IPlatformGrantRepository {
  /// The grants of the connection [connectionId], by username, expired ones included
  /// (`GET /api/v1/connections/{id}/grants`).
  Future<Result<List<PlatformGrant>>> list(String connectionId);

  /// Revokes the grant [grantId] of the connection [connectionId] (`DELETE /api/v1/connections/{id}/grants/{grantId}`).
  ///
  /// It names the grant id from [list], never the subject. A grant already revoked, or a connection that is gone,
  /// answers `platformNotFound`.
  Future<Result<void>> revoke(String connectionId, String grantId);

  /// Creates the grant of [subject], a Keycloak user id, on the connection [connectionId], or replaces the one the
  /// subject holds, with [level] (`read` or `write`) until [expiresAt], or with no expiry when it is null
  /// (`PUT /api/v1/connections/{id}/grants/{subject}`), and answers the grant id.
  ///
  /// A refusal on `level`, `subject` or `expiresAt` answers that field's code. It is never sent twice by the client.
  Future<Result<String>> put(
    String connectionId,
    String subject, {
    required String level,
    required DateTime? expiresAt,
  });
}
