import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';

abstract class IPlatformIdentityRepository {
  /// Who LibreDB Platform says the signed-in admin is (`GET /api/v1/me`).
  ///
  /// The first call of an account provisions its Platform user and takes an admin seat.
  Future<Result<PlatformIdentity>> fetch();
}
