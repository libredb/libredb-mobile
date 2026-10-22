import 'package:flutter_bloc_advance/core/result/result.dart';
import 'package:flutter_bloc_advance/shared/models/studio_identity.dart';

abstract class IStudioIdentityRepository {
  /// Who Studio says the signed-in user is.
  ///
  /// A 401 here is ambiguous: Studio answers it for a refused token and also when it cannot reach the identity
  /// provider, so a caller must not end the session on this failure alone.
  Future<Result<StudioIdentity>> fetch();
}
