import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_connections/data/models/platform_connections_model.dart';
import 'package:libredb_mobile/features/platform_connections/domain/repositories/platform_connection_repository.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';

/// LibreDB Platform's connection list, and the enabling or disabling of one connection. The paths are relative to
/// `PLATFORM_API_URL`, which ends in Platform's `/api`.
///
/// No answer is cached, since every `/v1/` path is networkOnly, and the `PATCH` is never sent twice.
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

  @override
  Future<Result<PlatformConnection>> setActive(String id, {required bool active}) async {
    try {
      // `active` is the only field Platform accepts; the app never sends a name, a definition or a credential.
      final response = await _apiClient.patch('/v1/connections', {
        'active': active,
      }, pathParams: Uri.encodeComponent(id));
      final connection = PlatformConnectionsModel.readOne(response.data!);
      // The id and the answered status only: a connection name stays out of the log.
      _log.debug('setActive: {} is {}', [connection.id, connection.status]);
      return Success(connection);
    } catch (e) {
      return _failure('setActive', e);
    }
  }

  static Failure<T> _failure<T>(String operation, Object e) {
    final error = platformError(e);
    _log.warn('{} failed: {}', [operation, error.code ?? error.runtimeType]);
    return Failure(error);
  }
}
