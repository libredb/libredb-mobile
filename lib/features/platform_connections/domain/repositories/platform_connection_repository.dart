import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';

abstract class IPlatformConnectionRepository {
  /// Every connection of the install tenant, active and inactive, newest first (`GET /api/v1/connections`).
  Future<Result<List<PlatformConnection>>> list();
}
