import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/data/models/platform_grant_json.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';
import 'package:libredb_mobile/features/platform_grants/domain/repositories/platform_grant_repository.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';

/// LibreDB Platform's grants of a connection. The paths are relative to `PLATFORM_API_URL`, which ends in Platform's
/// `/api`; each id is one encoded path segment.
///
/// Nothing is cached, since every `/v1/` path is networkOnly, and a revoke is never sent twice.
class PlatformGrantRepository implements IPlatformGrantRepository {
  PlatformGrantRepository(this._apiClient);

  final PlatformApiClient _apiClient;

  static final _log = AppLogger.getLogger('PlatformGrantRepository');

  @override
  Future<Result<List<PlatformGrant>>> list(String connectionId) async {
    try {
      final response = await _apiClient.get(
        '/v1/connections',
        pathParams: '${Uri.encodeComponent(connectionId)}/grants',
      );
      final grants = PlatformGrantJson.read(response.data!);
      // Only the count: a username or an e-mail address stays out of the log.
      _log.debug('list: {} grants', [grants.length]);
      return Success(grants);
    } catch (e) {
      return _failure('list', e);
    }
  }

  @override
  Future<Result<void>> revoke(String connectionId, String grantId) async {
    try {
      // Platform answers 204 with no body, so the answer is not read.
      await _apiClient.delete(
        '/v1/connections',
        pathParams: '${Uri.encodeComponent(connectionId)}/grants/${Uri.encodeComponent(grantId)}',
      );
      return const Success(null);
    } catch (e) {
      return _failure('revoke', e);
    }
  }

  static Failure<T> _failure<T>(String operation, Object e) {
    final error = platformError(e);
    _log.warn('{} failed: {}', [operation, error.code ?? error.runtimeType]);
    return Failure(error);
  }
}
