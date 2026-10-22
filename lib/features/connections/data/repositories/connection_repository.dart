import 'package:flutter_bloc_advance/core/errors/app_api_exception.dart';
import 'package:flutter_bloc_advance/core/errors/app_error.dart';
import 'package:flutter_bloc_advance/core/errors/app_error_code.dart';
import 'package:flutter_bloc_advance/core/logging/app_logger.dart';
import 'package:flutter_bloc_advance/core/result/result.dart';
import 'package:flutter_bloc_advance/features/connections/data/models/managed_connections.dart';
import 'package:flutter_bloc_advance/features/connections/domain/entities/studio_connection.dart';
import 'package:flutter_bloc_advance/features/connections/domain/repositories/connection_repository.dart';
import 'package:flutter_bloc_advance/infrastructure/http/api_client.dart';

/// Studio's connection API. The paths are relative to `PROD_API_URL`, which ends in Studio's `/api`.
class ConnectionRepository implements IConnectionRepository {
  ConnectionRepository(this._apiClient);

  final ApiClient _apiClient;

  static final _log = AppLogger.getLogger('ConnectionRepository');

  @override
  Future<Result<List<StudioConnection>>> listManaged() async {
    _log.debug('BEGIN:listManaged repository start');
    try {
      final response = await _apiClient.get('/connections/managed');
      final connections = ManagedConnections.fromJsonString(ApiClient.decodeUTF8(response.data!));
      _log.debug('END:listManaged successful - connections: {}', [connections.length]);
      return Success(connections);
    } on UnauthorizedException catch (e) {
      _log.warn('END:listManaged auth error: {}', [e]);
      return Failure(AuthError(e.toString()));
    } on FetchDataException catch (e) {
      _log.warn('END:listManaged network error: {}', [e]);
      return Failure(_mapFetchDataException(e));
    } on FormatException catch (e) {
      _log.error('END:listManaged unreadable answer: {}', [e.message]);
      return Failure(ServerError(e.message));
    } catch (e) {
      _log.error('END:listManaged unknown error: {}', [e]);
      return Failure(UnknownError(e.toString()));
    }
  }

  /// An untrusted certificate carries [AppErrorCode.networkCertInvalid], as in the other repositories.
  static AppError _mapFetchDataException(FetchDataException e) {
    if (e is UntrustedCertificateException) {
      return NetworkError(e.toString(), code: AppErrorCode.networkCertInvalid.key);
    }
    final message = e.toString().toLowerCase();
    if (message.contains('timeout')) return TimeoutError(e.toString());
    return NetworkError(e.toString());
  }
}
