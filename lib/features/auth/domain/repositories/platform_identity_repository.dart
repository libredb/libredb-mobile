import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';

abstract class IPlatformIdentityRepository {
  /// Who LibreDB Platform says the signed-in admin is (`GET /api/v1/me`).
  ///
  /// The first call of an account provisions its Platform user and takes an admin seat.
  ///
  /// A [probe] is sent once, past an open circuit, and counts toward no circuit, for a gate the user asks again by
  /// hand, such as the mode switch: its failure is the answer the user sees, and the next tap once Platform is back
  /// must reach Platform instead of waiting out a circuit the refusals opened.
  Future<Result<PlatformIdentity>> fetch({bool probe = false});
}
