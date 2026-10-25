import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';

abstract class IPlatformConnectionRepository {
  /// Every connection of the install tenant, active and inactive, newest first (`GET /api/v1/connections`).
  Future<Result<List<PlatformConnection>>> list();

  /// Enables ([active] true) or disables the connection [id] for every Studio user (`PATCH
  /// /api/v1/connections/{id}`, body `{"active": active}` only), and answers the connection as Platform now holds it.
  ///
  /// Setting the value it already has changes nothing and still answers the connection. Never sent twice.
  Future<Result<PlatformConnection>> setActive(String id, {required bool active});
}
