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
}
