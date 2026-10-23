import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/data/models/connection_policy_model.dart';
import 'package:libredb_mobile/features/connections/data/models/connection_test_result_model.dart';
import 'package:libredb_mobile/features/connections/data/models/managed_connections_model.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_test_result.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_errors.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';

/// Studio's connection API. The paths are relative to `PROD_API_URL`, which ends in Studio's `/api`.
///
/// Every list it reads replaces [ConnectionQueryTimeouts], which the statement routes wait for.
class ConnectionRepository implements IConnectionRepository {
  ConnectionRepository(this._apiClient, this._queryTimeouts);

  final ApiClient _apiClient;
  final ConnectionQueryTimeouts _queryTimeouts;

  static final _log = AppLogger.getLogger('ConnectionRepository');

  @override
  Future<Result<ManagedConnections>> listManaged() async {
    try {
      final response = await _apiClient.get('/connections/managed');
      final managed = ManagedConnectionsModel.read(ApiClient.decodeUTF8(response.data!));
      _queryTimeouts.replaceAll(managed.connections);
      _log.debug('listManaged: {} connections', [managed.connections.length]);
      return Success(managed);
    } catch (e) {
      return _failure('listManaged', e);
    }
  }

  @override
  Future<Result<ConnectionPolicy>> fetchPolicy() async {
    try {
      final response = await _apiClient.get('/connections/policy');
      return Success(ConnectionPolicyModel.fromJsonString(ApiClient.decodeUTF8(response.data!)));
    } catch (e) {
      return _failure('fetchPolicy', e);
    }
  }

  @override
  Future<Result<ConnectionTestResult>> test(String connectionId) async {
    try {
      // Studio opens a connection to the database host, which can take longer than the default on a slow host.
      final response = await _apiClient.post('/db/test-connection', {
        'connectionId': connectionId,
      }, receiveTimeout: studioStatementReceiveTimeout);
      return Success(ConnectionTestResultModel.fromJsonString(ApiClient.decodeUTF8(response.data!)));
    } catch (e) {
      return _failure('test', e);
    }
  }

  static Failure<T> _failure<T>(String operation, Object e) {
    final error = studioError(e);
    _log.warn('{} failed: {}', [operation, error.code ?? error.runtimeType]);
    return Failure(error);
  }
}
