import 'package:flutter_bloc_advance/core/logging/app_logger.dart';
import 'package:flutter_bloc_advance/core/result/result.dart';
import 'package:flutter_bloc_advance/features/connections/data/models/connection_policy_model.dart';
import 'package:flutter_bloc_advance/features/connections/data/models/connection_test_result_model.dart';
import 'package:flutter_bloc_advance/features/connections/data/models/managed_connections.dart';
import 'package:flutter_bloc_advance/features/connections/domain/entities/connection_policy.dart';
import 'package:flutter_bloc_advance/features/connections/domain/entities/connection_test_result.dart';
import 'package:flutter_bloc_advance/features/connections/domain/entities/studio_connection.dart';
import 'package:flutter_bloc_advance/features/connections/domain/repositories/connection_repository.dart';
import 'package:flutter_bloc_advance/infrastructure/http/api_client.dart';
import 'package:flutter_bloc_advance/infrastructure/studio/studio_errors.dart';

/// Studio's connection API. The paths are relative to `PROD_API_URL`, which ends in Studio's `/api`.
class ConnectionRepository implements IConnectionRepository {
  ConnectionRepository(this._apiClient);

  final ApiClient _apiClient;

  static final _log = AppLogger.getLogger('ConnectionRepository');

  @override
  Future<Result<List<StudioConnection>>> listManaged() async {
    try {
      final response = await _apiClient.get('/connections/managed');
      final connections = ManagedConnections.fromJsonString(ApiClient.decodeUTF8(response.data!));
      _log.debug('listManaged: {} connections', [connections.length]);
      return Success(connections);
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
      final response = await _apiClient.post('/db/test-connection', {'connectionId': connectionId});
      return Success(ConnectionTestResultModel.fromJsonString(ApiClient.decodeUTF8(response.data!)));
    } catch (e) {
      return _failure('test', e);
    }
  }

  static Failure<T> _failure<T>(String operation, Object e) {
    final error = studioError(e);
    _log.warn('{} failed: {}', [operation, error]);
    return Failure(error);
  }
}
