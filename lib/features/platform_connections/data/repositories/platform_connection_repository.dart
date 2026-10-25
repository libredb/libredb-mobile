import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_connections/data/models/platform_connections_model.dart';
import 'package:libredb_mobile/features/platform_connections/domain/repositories/platform_connection_repository.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';

/// LibreDB Platform's connection list. The path is relative to `PLATFORM_API_URL`, which ends in Platform's `/api`.
///
/// It reads only; the answer is never cached, since every `/v1/` path is networkOnly.
class PlatformConnectionRepository implements IPlatformConnectionRepository {
  PlatformConnectionRepository(this._apiClient);

  final PlatformApiClient _apiClient;

  static final _log = AppLogger.getLogger('PlatformConnectionRepository');

  @override
  Future<Result<List<PlatformConnection>>> list() async {
    try {
      final response = await _apiClient.get('/v1/connections');
      final connections = PlatformConnectionsModel.read(response.data!);
      // Only the count: a connection name stays out of the log.
      _log.debug('list: {} connections', [connections.length]);
      return Success(connections);
    } catch (e) {
      return _failure('list', e);
    }
  }

  static Failure<T> _failure<T>(String operation, Object e) {
    final error = platformError(e);
    _log.warn('{} failed: {}', [operation, error.code ?? error.runtimeType]);
    return Failure(error);
  }
}
