import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_test_result.dart';
import 'package:libredb_mobile/features/connections/domain/entities/studio_connection.dart';

abstract class IConnectionRepository {
  /// The connections Studio manages for the signed-in user: seed connections, or the granted ones under governance.
  Future<Result<List<StudioConnection>>> listManaged();

  /// What Studio allows for connections, and whether Platform governs it.
  Future<Result<ConnectionPolicy>> fetchPolicy();

  /// Connects to the managed connection [connectionId] (`seed:<id>`) once and reports how it went.
  Future<Result<ConnectionTestResult>> test(String connectionId);
}
