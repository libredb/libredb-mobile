import 'package:flutter_bloc_advance/core/result/result.dart';
import 'package:flutter_bloc_advance/features/connections/domain/entities/studio_connection.dart';

abstract class IConnectionRepository {
  /// The connections Studio manages for the signed-in user: seed connections, or the granted ones under governance.
  Future<Result<List<StudioConnection>>> listManaged();
}
