import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';

abstract class IStudioIdentityRepository {
  /// Who Studio says the signed-in user is.
  ///
  /// A 401 here is ambiguous: Studio answers it for a refused token and also when it cannot reach the identity
  /// provider, so a caller must not end the session on this failure alone.
  Future<Result<StudioIdentity>> fetch();

  /// Tells Studio the user signs out, so the sign-out shows in its audit trail as a web sign-out does.
  ///
  /// Studio holds no state for a bearer session, so this only records the sign-out. It must be sent with a valid
  /// access token: for an expired one Studio writes no audit line and still answers success, so a [Success] only
  /// says Studio accepted the request. It is never retried.
  Future<Result<void>> recordSignOut();
}
